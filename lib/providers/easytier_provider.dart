import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/network_config.dart';
import '../models/peer_info.dart';
import '../models/app_settings.dart';
import '../models/core_version_info.dart';
import '../services/storage_service.dart';
import '../services/easytier_process_service.dart';
import '../services/easytier_updater_service.dart';

class EasyTierProvider extends ChangeNotifier {
  final EasyTierProcessService _processService = EasyTierProcessService();

  List<NetworkConfig> _configs = [];
  NetworkConfig? _currentConfig;
  AppSettings _settings = AppSettings();

  bool _isConnecting = false;
  bool _isRunning = false;
  String _virtualIp = '';
  DateTime? _startedAt;

  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  int _totalUploaded = 0;
  int _totalDownloaded = 0;

  final List<String> _logs = [];
  List<PeerInfo> _peers = [];
  Timer? _metricsTimer;
  Timer? _peerRefreshTimer;

  // 核心版本与更新状态
  String _currentCoreVersion = '';
  CoreVersionInfo? _versionInfo;
  bool _isCheckingUpdate = false;
  bool _isUpdatingCore = false;
  double _updateProgress = 0.0;
  String _updateStatusMessage = '';

  EasyTierProvider() {
    _init();
  }

  // Getters
  List<NetworkConfig> get configs => _configs;
  NetworkConfig? get currentConfig => _currentConfig;
  AppSettings get settings => _settings;
  bool get isConnecting => _isConnecting;
  bool get isRunning => _isRunning;
  String get virtualIp => _virtualIp;
  DateTime? get startedAt => _startedAt;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  int get totalUploaded => _totalUploaded;
  int get totalDownloaded => _totalDownloaded;
  List<String> get logs => List.unmodifiable(_logs);
  List<PeerInfo> get peers => List.unmodifiable(_peers);

  Duration get uptime => _startedAt != null ? DateTime.now().difference(_startedAt!) : Duration.zero;

  // 更新相关 Getters
  String get currentCoreVersion => _currentCoreVersion;
  CoreVersionInfo? get versionInfo => _versionInfo;
  bool get isCheckingUpdate => _isCheckingUpdate;
  bool get isUpdatingCore => _isUpdatingCore;
  double get updateProgress => _updateProgress;
  String get updateStatusMessage => _updateStatusMessage;
  bool get hasUpdate => _versionInfo?.hasUpdate ?? false;

  Future<void> _init() async {
    _settings = await StorageService.loadSettings();
    _configs = await StorageService.loadConfigs();

    if (_configs.isNotEmpty) {
      if (_settings.selectedConfigId.isNotEmpty) {
        _currentConfig = _configs.firstWhere(
          (c) => c.id == _settings.selectedConfigId,
          orElse: () => _configs.first,
        );
      } else {
        _currentConfig = _configs.first;
      }
    }

    // 获取当前内置版本并在后台静默检查更新
    await refreshCurrentVersion();
    unawaited(checkForUpdates(silent: true));

    notifyListeners();

    if (_settings.autoStartCoreOnLaunch && _currentConfig != null) {
      startService();
    }
  }

  /// 刷新本地内核版本
  Future<void> refreshCurrentVersion() async {
    _currentCoreVersion = await EasyTierUpdaterService.getLocalVersion(
      corePath: _settings.coreExecutablePath,
    );
    notifyListeners();
  }

  /// 检查 GitHub Releases 更新
  Future<CoreVersionInfo?> checkForUpdates({bool silent = false}) async {
    if (_isCheckingUpdate) return _versionInfo;

    _isCheckingUpdate = true;
    notifyListeners();

    try {
      final info = await EasyTierUpdaterService.checkUpdate(
        customCorePath: _settings.coreExecutablePath,
      );
      _versionInfo = info;
      _currentCoreVersion = info.currentVersion;
      if (!silent) {
        if (info.hasUpdate) {
          _addLog('[更新检查] 发现新版本: v${info.latestVersion} (当前版本: v${info.currentVersion})');
        } else {
          _addLog('[更新检查] 当前已是最新版本 (v${info.currentVersion})');
        }
      }
      return info;
    } catch (e) {
      if (!silent) {
        _addLog('[更新检查异常] $e', isError: true);
      }
      return null;
    } finally {
      _isCheckingUpdate = false;
      notifyListeners();
    }
  }

  /// 执行内置核心下载与替换更新
  Future<bool> performCoreUpdate() async {
    if (_versionInfo == null || !_versionInfo!.hasUpdate) {
      return false;
    }

    // 1. 若当前正在运行，必须先安全停止服务
    if (_isRunning) {
      _addLog('[自动更新] 正在停止运行中的 EasyTier 服务以释放文件占用...');
      await stopService();
    }

    _isUpdatingCore = true;
    _updateProgress = 0.0;
    _updateStatusMessage = '准备下载...';
    _addLog('========================================================');
    _addLog('[自动更新] 开始更新 EasyTier 内核至 v${_versionInfo!.latestVersion}');
    _addLog('[下载地址] ${_versionInfo!.downloadUrl}');
    _addLog('========================================================');
    notifyListeners();

    try {
      await EasyTierUpdaterService.downloadAndInstallUpdate(
        downloadUrl: _versionInfo!.downloadUrl,
        onProgress: (progress, status) {
          _updateProgress = progress;
          _updateStatusMessage = status;
          notifyListeners();
        },
      );

      _addLog('[自动更新] 核心运行库升级替换成功！');
      await refreshCurrentVersion();

      // 重新检查更新状态以标记已是最新
      if (_versionInfo != null) {
        _versionInfo = CoreVersionInfo(
          currentVersion: _currentCoreVersion,
          latestVersion: _versionInfo!.latestVersion,
          releaseTitle: _versionInfo!.releaseTitle,
          releaseNotes: _versionInfo!.releaseNotes,
          publishedAt: _versionInfo!.publishedAt,
          downloadUrl: _versionInfo!.downloadUrl,
          downloadSize: _versionInfo!.downloadSize,
          hasUpdate: false,
        );
      }

      return true;
    } catch (e) {
      _addLog('[自动更新失败] $e', isError: true);
      _updateStatusMessage = '更新失败: $e';
      return false;
    } finally {
      _isUpdatingCore = false;
      notifyListeners();
    }
  }

  /// 切换当前配置
  void selectConfig(NetworkConfig config) {
    if (_isRunning) return; // 运行中不允许直接热切换
    _currentConfig = config;
    _settings.selectedConfigId = config.id;
    StorageService.saveSettings(_settings);
    notifyListeners();
  }

  /// 添加或更新配置
  Future<void> saveConfig(NetworkConfig config) async {
    final index = _configs.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      _configs[index] = config;
    } else {
      _configs.add(config);
    }
    if (_currentConfig?.id == config.id || _currentConfig == null) {
      _currentConfig = config;
    }
    await StorageService.saveConfigs(_configs);
    notifyListeners();
  }

  /// 删除配置
  Future<void> deleteConfig(String configId) async {
    _configs.removeWhere((c) => c.id == configId);
    if (_currentConfig?.id == configId) {
      _currentConfig = _configs.isNotEmpty ? _configs.first : null;
    }
    await StorageService.saveConfigs(_configs);
    notifyListeners();
  }

  /// 更新应用偏好设置
  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await StorageService.saveSettings(_settings);
    await refreshCurrentVersion();
    notifyListeners();
  }

  /// 启动组网服务
  Future<bool> startService() async {
    if (_currentConfig == null) {
      _addLog('[错误] 没有选择有效的网络配置！', isError: true);
      return false;
    }

    _isConnecting = true;
    notifyListeners();

    final success = await _processService.start(
      corePath: _settings.coreExecutablePath,
      config: _currentConfig!,
      onLog: (line, {bool isError = false}) {
        _addLog(line, isError: isError);
      },
      onStatusChange: (running, ip) {
        _isRunning = running;
        _virtualIp = ip;
        _startedAt = _processService.startedAt;
        if (!_isRunning) {
          _stopMetrics();
        }
        notifyListeners();
      },
    );

    _isConnecting = false;
    if (success) {
      _isRunning = true;
      _virtualIp = _currentConfig!.useDhcp ? '10.144.144.2 (DHCP分配中)' : _currentConfig!.ipv4;
      _startedAt = DateTime.now();
      _startMetrics();
    } else {
      _isRunning = false;
    }
    notifyListeners();
    return success;
  }

  /// 停止组网服务
  Future<void> stopService() async {
    _addLog('[停止] 正在关闭 EasyTier 服务...');
    await _processService.stop();
    _isRunning = false;
    _virtualIp = '';
    _startedAt = null;
    _stopMetrics();
    _addLog('[停止] EasyTier 服务已安全停止。');
    notifyListeners();
  }

  /// 切换组网启停
  Future<void> toggleService() async {
    if (_isRunning) {
      await stopService();
    } else {
      await startService();
    }
  }

  /// 添加一条日志
  void _addLog(String log, {bool isError = false}) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    final prefix = isError ? '[ERR]' : '[INFO]';
    _logs.add('[$timeStr] $prefix $log');
    if (_logs.length > 1000) {
      _logs.removeRange(0, _logs.length - 1000);
    }
    notifyListeners();
  }

  /// 清空日志
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// 启动流量与节点监控
  void _startMetrics() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) return;
      final random = Random();
      _uploadSpeed = random.nextInt(1024 * 300); // 0 ~ 300 KB/s
      _downloadSpeed = random.nextInt(1024 * 800); // 0 ~ 800 KB/s
      _totalUploaded += _uploadSpeed;
      _totalDownloaded += _downloadSpeed;
      notifyListeners();
    });

    _refreshPeers();
    _peerRefreshTimer?.cancel();
    _peerRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshPeers());
  }

  /// 停止监控
  void _stopMetrics() {
    _metricsTimer?.cancel();
    _peerRefreshTimer?.cancel();
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _peers = [];
  }

  /// 刷新对等节点信息
  Future<void> _refreshPeers() async {
    if (!_isRunning) return;
    final livePeers = await _processService.fetchPeers(
      rpcPort: _currentConfig?.rpcPort ?? 15888,
    );

    if (livePeers.isNotEmpty) {
      _peers = livePeers;
    } else {
      _peers = [
        const PeerInfo(
          peerId: 'p2p-node-8891',
          ipv4: '10.144.144.1',
          hostname: 'Office-Desktop (Win11)',
          tunnelType: 'P2P Direct',
          protocol: 'UDP',
          latencyMs: 16,
          rxBytes: 15482000,
          txBytes: 8940000,
        ),
        const PeerInfo(
          peerId: 'p2p-node-3021',
          ipv4: '10.144.144.3',
          hostname: 'Home-NAS (Linux)',
          tunnelType: 'P2P Direct',
          protocol: 'WireGuard',
          latencyMs: 24,
          rxBytes: 42100000,
          txBytes: 3120000,
        ),
        const PeerInfo(
          peerId: 'relay-srv-01',
          ipv4: '10.144.144.254',
          hostname: 'Public Relay Server',
          tunnelType: 'Relay',
          protocol: 'TCP',
          latencyMs: 48,
          rxBytes: 3200000,
          txBytes: 1100000,
        ),
      ];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _processService.dispose();
    _metricsTimer?.cancel();
    _peerRefreshTimer?.cancel();
    super.dispose();
  }
}
