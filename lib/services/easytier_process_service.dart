import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/network_config.dart';
import '../models/peer_info.dart';
import 'easytier_path_resolver.dart';

typedef LogCallback = void Function(String line, {bool isError});
typedef StatusCallback = void Function(bool isRunning, String virtualIp);

class EasyTierProcessService {
  Process? _process;
  bool _isRunning = false;
  String _virtualIp = '';
  DateTime? _startedAt;
  String _resolvedCorePath = '';

  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  bool get isRunning => _isRunning;
  String get virtualIp => _virtualIp;
  DateTime? get startedAt => _startedAt;
  String get currentCorePath => _resolvedCorePath;

  Timer? _mockStatsTimer;

  /// 检查核心程序是否存在或可用
  static Future<bool> checkCoreAvailable(String path) async {
    try {
      final realPath =
          await EasyTierPathResolver.resolveCorePath(customPath: path);
      final workDir =
          File(realPath).existsSync() ? File(realPath).parent.path : null;
      final result = await Process.run(
        realPath,
        ['--version'],
        workingDirectory: workDir,
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 启动 EasyTier 核心
  Future<bool> start({
    required String corePath,
    required NetworkConfig config,
    required String configFilePath,
    String? username,
    required LogCallback onLog,
    required StatusCallback onStatusChange,
  }) async {
    if (_isRunning) {
      onLog('[警告] 核心服务已经在运行中，请先停止再启动。', isError: true);
      return false;
    }

    // 智能解析真实路径（内置 bin/ 优先）
    _resolvedCorePath =
        await EasyTierPathResolver.resolveCorePath(customPath: corePath);
    final coreFile = File(_resolvedCorePath);
    final isFileExist = await coreFile.exists();
    final workDir = isFileExist ? coreFile.parent.path : null;

    final args = ['--config-file', configFilePath];
    if (config.additionalArgs.trim().isNotEmpty) {
      args.addAll(
        config.additionalArgs
            .trim()
            .split(RegExp(r'\s+'))
            .where((arg) => arg.isNotEmpty),
      );
    }
    args.addAll([
      '--dhcp',
      config.useDhcp ? 'true' : 'false',
    ]);
    if (!config.useDhcp && config.ipv4.isNotEmpty) {
      args.addAll(['--ipv4', config.ipv4]);
    }
    // 如果配置了自定义用户名，通过 --hostname 注入标识该节点
    if (username != null &&
        username.trim().isNotEmpty &&
        !args.contains('--hostname')) {
      args.addAll(['--hostname', username.trim()]);
    }

    onLog('========================================================');
    onLog('[启动] 正在启动 EasyTier 核心服务...');
    onLog(
        '[可执行文件] $_resolvedCorePath ${isFileExist ? "(已定位到本地程序)" : "(依赖系统 PATH)"}');
    if (workDir != null) {
      onLog('[工作目录] $workDir (支持加载同目录 wintun.dll 等驱动)');
    }
    onLog('[启动参数] ${args.join(' ')}');
    onLog('========================================================');

    try {
      final process = await Process.start(
        _resolvedCorePath,
        args,
        workingDirectory: workDir,
        runInShell: false,
      );
      _process = process;
      _isRunning = true;
      _startedAt = DateTime.now();
      _virtualIp = config.useDhcp ? '获取中...' : config.ipv4;
      onStatusChange(_isRunning, _virtualIp);

      // 处理标准输出
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logController.add(line);
        onLog(line, isError: false);
        _parseLogForStatus(line, (detectedIp) {
          _virtualIp = detectedIp;
          onStatusChange(_isRunning, _virtualIp);
        });
      });

      // 处理错误输出
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logController.add(line);
        onLog(line, isError: true);
      });

      // 监听退出
      process.exitCode.then((code) {
        onLog('[退出] EasyTier 核心服务已终止，退出码: $code', isError: code != 0);
        if (!identical(_process, process)) return;
        _isRunning = false;
        _virtualIp = '';
        _startedAt = null;
        _process = null;
        _mockStatsTimer?.cancel();
        onStatusChange(false, '');
      });

      return true;
    } catch (e) {
      onLog('[异常] 无法启动 $_resolvedCorePath: $e', isError: true);
      onLog('[提示] 请检查项目根目录的 .\\bin 目录下是否存在 easytier-core.exe 与 wintun.dll。',
          isError: true);
      _isRunning = false;
      onStatusChange(false, '');
      return false;
    }
  }

  /// 停止 EasyTier 核心
  Future<void> stop() async {
    final process = _process;
    if (process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          throw StateError('无法终止 EasyTier 核心进程 (PID ${process.pid})');
        }
      }
      if (identical(_process, process)) {
        _process = null;
      }
    }
    _mockStatsTimer?.cancel();
    _isRunning = false;
    _virtualIp = '';
    _startedAt = null;
  }

  /// 从日志输出中自动解析虚拟 IP
  void _parseLogForStatus(String line, void Function(String ip) onIpDetected) {
    final ipRegex = RegExp(
        r'(?:ipv4|ip|assigned)[\s:=]+((?:10|172|192)\.\d{1,3}\.\d{1,3}\.\d{1,3}(?:/\d{1,2})?)',
        caseSensitive: false);
    final match = ipRegex.firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      final ip = _normalizeIpv4Address(match.group(1)!);
      if (ip != null) {
        onIpDetected(ip);
      }
    }
  }

  /// 获取当前 Peers 列表 (尝试通过 easytier-cli 查询)
  Future<List<PeerInfo>> fetchPeers({int rpcPort = 15888}) async {
    if (!_isRunning) return [];

    try {
      final cliPath = await EasyTierPathResolver.resolveCliPath(
          customCorePath: _resolvedCorePath);
      final cliFile = File(cliPath);
      final workDir = cliFile.existsSync() ? cliFile.parent.path : null;

      final result = await Process.run(
        cliPath,
        ['--rpc-portal', '127.0.0.1:$rpcPort', 'peer', 'list'],
        workingDirectory: workDir,
        runInShell: false,
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode == 0) {
        return parsePeerOutput(result.stdout.toString());
      }
    } catch (_) {
      // 忽略无法连接 cli 的异常，进入缺省处理
    }

    return [];
  }

  List<PeerInfo> parsePeerOutput(String output) {
    final peers = <PeerInfo>[];
    List<String>? headers;

    for (final line in const LineSplitter().convert(output)) {
      if (!line.contains('|')) continue;
      final cells =
          line.split('|').map((cell) => cell.trim()).toList(growable: true);
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isEmpty ||
          cells.every((cell) => RegExp(r'^[-+=:]+$').hasMatch(cell))) {
        continue;
      }

      final normalized = cells.map((cell) => cell.toLowerCase()).toList();
      if (normalized.contains('ipv4') &&
          normalized.contains('hostname') &&
          normalized.contains('cost')) {
        headers = normalized;
        continue;
      }
      if (headers == null || cells.length < headers.length) continue;

      String value(String column) {
        final index = headers!.indexOf(column);
        return index >= 0 ? cells[index] : '';
      }

      final ipv4 = value('ipv4');
      final cost = value('cost');
      if (cost.toLowerCase() == 'local') {
        _virtualIp = _normalizeIpv4Address(ipv4) ?? '';
        continue;
      }

      final hostname = value('hostname');
      if (hostname.isEmpty) continue;

      final rawTunnelType = cost.toLowerCase();
      final tunnelType =
          rawTunnelType.contains('p2p') || rawTunnelType.contains('direct')
              ? 'P2P Direct'
              : rawTunnelType.contains('relay')
                  ? 'Relay'
                  : '未知';
      final tunnelIndex = headers.indexWhere(
        (header) => header == 'tunnel' || header == 'protocol',
      );
      final tunnel = tunnelIndex >= 0 ? cells[tunnelIndex] : '';

      peers.add(
        PeerInfo(
          peerId: value('peer_id'),
          ipv4: _normalizeIpv4Address(ipv4) ?? '',
          hostname: hostname,
          tunnelType: tunnelType,
          protocol: tunnel.isEmpty ? '未知' : tunnel,
          latencyMs: double.tryParse(value('lat(ms)'))?.round() ?? 0,
          rxBytes: _parseTrafficBytes(value('rx')),
          txBytes: _parseTrafficBytes(value('tx')),
        ),
      );
    }
    return peers;
  }

  String? _normalizeIpv4Address(String value) {
    final match = RegExp(r'^(\d{1,3}(?:\.\d{1,3}){3})(?:/(\d{1,2}))?$')
        .firstMatch(value.trim());
    if (match == null) return null;
    final parts = match.group(1)!.split('.');
    final prefix = match.group(2);
    if (prefix != null) {
      final prefixLength = int.tryParse(prefix);
      if (prefixLength == null || prefixLength > 32) return null;
    }

    final isValid = parts.every((part) {
      final octet = int.tryParse(part);
      return octet != null && octet >= 0 && octet <= 255;
    });
    if (!isValid) return null;

    return parts.join('.');
  }

  int _parseTrafficBytes(String value) {
    final match = RegExp(
      r'^([\d.]+)\s*(B|kB|KB|MB|GB)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return 0;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null) return 0;
    final unit = (match.group(2) ?? 'B').toLowerCase();
    final multiplier = switch (unit) {
      'kb' => 1000,
      'mb' => 1000 * 1000,
      'gb' => 1000 * 1000 * 1000,
      _ => 1,
    };
    return (amount * multiplier).round();
  }

  void dispose() {
    unawaited(
      stop().then<void>(
        (_) => _logController.close(),
        onError: (Object error, StackTrace stackTrace) {
          stderr.writeln('Failed to stop EasyTier during disposal: $error');
          return _logController.close();
        },
      ),
    );
  }
}
