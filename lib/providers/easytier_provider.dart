import 'dart:async';
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
  bool _isInitialized = false;
  bool _isRunning = false;
  String? _configError;
  String? _dataDirectoryPath;
  String? _configDirectoryPath;
  String _virtualIp = '';
  DateTime? _startedAt;

  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  int _totalUploaded = 0;
  int _totalDownloaded = 0;

  final List<String> _logs = [];
  List<PeerInfo> _peers = [];
  Timer? _peerRefreshTimer;
  DateTime? _lastTrafficSampleAt;
  int _lastUploadedSample = 0;
  int _lastDownloadedSample = 0;

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
  bool get isInitialized => _isInitialized;
  String? get configError => _configError;
  String? get dataDirectoryPath => _dataDirectoryPath;
  String? get configDirectoryPath => _configDirectoryPath;
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

  Duration get uptime => _startedAt != null
      ? DateTime.now().difference(_startedAt!)
      : Duration.zero;

  // 更新相关 Getters
  String get currentCoreVersion => _currentCoreVersion;
  CoreVersionInfo? get versionInfo => _versionInfo;
  bool get isCheckingUpdate => _isCheckingUpdate;
  bool get isUpdatingCore => _isUpdatingCore;
  double get updateProgress => _updateProgress;
  String get updateStatusMessage => _updateStatusMessage;
  bool get hasUpdate => _versionInfo?.hasUpdate ?? false;

  Future<void> _init() async {
    try {
      final dataDirectory = await StorageService.getDataDirectory();
      _dataDirectoryPath = dataDirectory.path;
      _settings = await StorageService.loadSettings(
        dataDirectory: dataDirectory,
      );
      final configDirectory = await StorageService.getConfigDirectory();
      _configDirectoryPath = configDirectory.path;
      _configs = await StorageService.loadConfigs(
        configDirectory: configDirectory,
        dataDirectory: dataDirectory,
      );
      if (_configs.isNotEmpty) {
        _currentConfig = _configs.firstWhere(
          (config) => config.id == 'default',
          orElse: () => _configs.first,
        );
      }
    } catch (error) {
      _configError = error.toString();
    }

    _isInitialized = true;

    // 获取当前内置版本并在后台静默检查更新
    await refreshCurrentVersion();
    unawaited(checkForUpdates(silent: true));

    notifyListeners();

    if (_settings.autoStartCoreOnLaunch &&
        _currentConfig != null &&
        _configError == null) {
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
          _addLog(
              '[更新检查] 发现新版本: v${info.latestVersion} (当前版本: v${info.currentVersion})');
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
    if (_isRunning) return;
    _currentConfig = config;
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
    final selectedId = _currentConfig?.id;
    _configs = await StorageService.saveConfigs(_configs);
    _currentConfig = _configs.isEmpty
        ? null
        : _configs.firstWhere(
            (saved) => saved.id == (selectedId ?? config.id),
            orElse: () => _configs.first,
          );
    _configError = null;
    notifyListeners();
  }

  /// 删除配置
  Future<void> deleteConfig(String configId) async {
    _configs.removeWhere((config) => config.id == configId);
    _configs = await StorageService.saveConfigs(_configs);
    if (_configs.isEmpty) {
      _currentConfig = null;
    } else if (_currentConfig?.id == configId) {
      _currentConfig = _configs.first;
    } else {
      _currentConfig = _configs.firstWhere(
        (config) => config.id == _currentConfig?.id,
        orElse: () => _configs.first,
      );
    }
    _configError = null;
    notifyListeners();
  }

  /// 更新应用偏好设置
  Future<void> updateSettings(AppSettings newSettings) async {
    await StorageService.saveSettings(newSettings);
    _settings = newSettings;
    await refreshCurrentVersion();
    notifyListeners();
  }

  String get username => _settings.username;

  /// 更新自定义用户名
  Future<void> updateUsername(String newName) async {
    final settings = AppSettings.fromJson(_settings.toJson())
      ..username = newName.trim();
    await StorageService.saveSettings(settings);
    _settings = settings;
    _addLog('[用户] 用户名已更新为:「${_settings.username}」');
    notifyListeners();
  }

  /// 启动组网服务
  Future<bool> startService() async {
    if (_currentConfig == null) {
      _addLog('[错误] 没有选择有效的网络配置！', isError: true);
      return false;
    }

    final String configFilePath;
    try {
      configFilePath =
          await StorageService.getConfigFilePath(_currentConfig!.id);
    } catch (error) {
      _addLog('[配置错误] 无法定位 TOML 配置文件: $error', isError: true);
      return false;
    }

    _isConnecting = true;
    notifyListeners();

    final success = await _processService.start(
      corePath: _settings.coreExecutablePath,
      config: _currentConfig!,
      configFilePath: configFilePath,
      username: _settings.username,
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
      _virtualIp = _processService.virtualIp;
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
    _lastTrafficSampleAt = null;
    _lastUploadedSample = 0;
    _lastDownloadedSample = 0;
    _refreshPeers();
    _peerRefreshTimer?.cancel();
    _peerRefreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _refreshPeers());
  }

  /// 停止监控
  void _stopMetrics() {
    _peerRefreshTimer?.cancel();
    _uploadSpeed = 0;
    _downloadSpeed = 0;
    _totalUploaded = 0;
    _totalDownloaded = 0;
    _lastTrafficSampleAt = null;
    _lastUploadedSample = 0;
    _lastDownloadedSample = 0;
    _peers = [];
  }

  /// 刷新对等节点信息
  Future<void> _refreshPeers() async {
    if (!_isRunning) return;
    final livePeers = await _processService.fetchPeers(
      rpcPort: _currentConfig?.rpcPort ?? 15888,
    );
    if (!_isRunning) return;
    _peers = livePeers;
    final uploaded = livePeers.fold<int>(
      0,
      (total, peer) => total + peer.txBytes,
    );
    final downloaded = livePeers.fold<int>(
      0,
      (total, peer) => total + peer.rxBytes,
    );
    final sampledAt = DateTime.now();
    final previousSampleAt = _lastTrafficSampleAt;
    if (previousSampleAt != null) {
      final elapsedSeconds =
          sampledAt.difference(previousSampleAt).inMicroseconds / 1000000;
      if (elapsedSeconds > 0) {
        _uploadSpeed = uploaded >= _lastUploadedSample
            ? ((uploaded - _lastUploadedSample) / elapsedSeconds).round()
            : 0;
        _downloadSpeed = downloaded >= _lastDownloadedSample
            ? ((downloaded - _lastDownloadedSample) / elapsedSeconds).round()
            : 0;
      }
    } else {
      _uploadSpeed = 0;
      _downloadSpeed = 0;
    }
    _totalUploaded = uploaded;
    _totalDownloaded = downloaded;
    _lastUploadedSample = uploaded;
    _lastDownloadedSample = downloaded;
    _lastTrafficSampleAt = sampledAt;
    _virtualIp = _processService.virtualIp;
    notifyListeners();
  }

  @override
  void dispose() {
    _processService.dispose();
    _peerRefreshTimer?.cancel();
    super.dispose();
  }
}
