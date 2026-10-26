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

  final StreamController<String> _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  bool get isRunning => _isRunning;
  String get virtualIp => _virtualIp;
  DateTime? get startedAt => _startedAt;
  String get currentCorePath => _resolvedCorePath;

  Timer? _mockStatsTimer;

  /// 检查核心程序是否存在或可用
  static Future<bool> checkCoreAvailable(String path) async {
    try {
      final realPath = await EasyTierPathResolver.resolveCorePath(customPath: path);
      final workDir = File(realPath).existsSync() ? File(realPath).parent.path : null;
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
    required LogCallback onLog,
    required StatusCallback onStatusChange,
  }) async {
    if (_isRunning) {
      onLog('[警告] 核心服务已经在运行中，请先停止再启动。', isError: true);
      return false;
    }

    // 智能解析真实路径（内置 bin/ 优先）
    _resolvedCorePath = await EasyTierPathResolver.resolveCorePath(customPath: corePath);
    final coreFile = File(_resolvedCorePath);
    final isFileExist = await coreFile.exists();
    final workDir = isFileExist ? coreFile.parent.path : null;

    final args = config.toCommandLineArgs();
    onLog('========================================================');
    onLog('[启动] 正在启动 EasyTier 核心服务...');
    onLog('[可执行文件] $_resolvedCorePath ${isFileExist ? "(已定位到本地程序)" : "(依赖系统 PATH)"}');
    if (workDir != null) {
      onLog('[工作目录] $workDir (支持加载同目录 wintun.dll 等驱动)');
    }
    onLog('[启动参数] ${args.join(' ')}');
    onLog('========================================================');

    try {
      _process = await Process.start(
        _resolvedCorePath,
        args,
        workingDirectory: workDir,
        runInShell: true,
      );
      _isRunning = true;
      _startedAt = DateTime.now();
      _virtualIp = config.useDhcp ? '获取中...' : config.ipv4;
      onStatusChange(_isRunning, _virtualIp);

      // 处理标准输出
      _process!.stdout
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
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logController.add(line);
        onLog(line, isError: true);
      });

      // 监听退出
      _process!.exitCode.then((code) {
        onLog('[退出] EasyTier 核心服务已终止，退出码: $code', isError: code != 0);
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
      onLog('[提示] 请检查项目根目录的 .\\bin 目录下是否存在 easytier-core.exe 与 wintun.dll。', isError: true);
      _isRunning = false;
      onStatusChange(false, '');
      return false;
    }
  }

  /// 停止 EasyTier 核心
  Future<void> stop() async {
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 500));
      _process?.kill(ProcessSignal.sigkill);
      _process = null;
    }
    _mockStatsTimer?.cancel();
    _isRunning = false;
    _virtualIp = '';
    _startedAt = null;
  }

  /// 从日志输出中自动解析虚拟 IP
  void _parseLogForStatus(String line, void Function(String ip) onIpDetected) {
    final ipRegex = RegExp(r'(?:ipv4|ip|assigned)[\s:=]+((?:10|172|192)\.\d{1,3}\.\d{1,3}\.\d{1,3})', caseSensitive: false);
    final match = ipRegex.firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      final ip = match.group(1);
      if (ip != null && ip.isNotEmpty) {
        onIpDetected(ip);
      }
    }
  }

  /// 获取当前 Peers 列表 (尝试通过 easytier-cli 查询)
  Future<List<PeerInfo>> fetchPeers({int rpcPort = 15888}) async {
    if (!_isRunning) return [];

    try {
      final cliPath = await EasyTierPathResolver.resolveCliPath(customCorePath: _resolvedCorePath);
      final cliFile = File(cliPath);
      final workDir = cliFile.existsSync() ? cliFile.parent.path : null;

      final result = await Process.run(
        cliPath,
        ['--rpc-portal', '127.0.0.1:$rpcPort', 'peer'],
        workingDirectory: workDir,
        runInShell: true,
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode == 0) {
        return _parseCliPeerOutput(result.stdout.toString());
      }
    } catch (_) {
      // 忽略无法连接 cli 的异常，进入缺省处理
    }

    return [];
  }

  List<PeerInfo> _parseCliPeerOutput(String output) {
    final List<PeerInfo> peers = [];
    final lines = const LineSplitter().convert(output);
    for (final line in lines) {
      final parts = line.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 4 && parts[0] != 'peer_id') {
        peers.add(PeerInfo(
          peerId: parts[0],
          ipv4: parts.length > 1 ? parts[1] : '10.144.144.x',
          tunnelType: parts.any((e) => e.contains('p2p')) ? 'P2P Direct' : 'Relay',
          latencyMs: 15,
        ));
      }
    }
    return peers;
  }

  void dispose() {
    _mockStatsTimer?.cancel();
    stop();
    _logController.close();
  }
}
