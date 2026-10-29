import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/network_config.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _legacyConfigsKey = 'easytier_configs';
  static const String _settingsKey = 'easytier_settings';

  static Future<Directory> getConfigDirectory() async {
    final Directory appRoot;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      appRoot = Directory(p.dirname(Platform.resolvedExecutable));
    } else {
      appRoot = await getApplicationSupportDirectory();
    }

    final directory = Directory(p.join(appRoot.path, 'config'));
    await directory.create(recursive: true);
    return directory;
  }

  static Future<String> getConfigFilePath(String configId) async {
    final directory = await getConfigDirectory();
    if (configId != 'default' &&
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(configId)) {
      throw FormatException('配置 ID 不能用于文件名: $configId');
    }
    final filename =
        configId == 'default' ? 'default.toml' : 'profile_$configId.toml';
    return p.join(directory.path, filename);
  }

  /// 加载 config 目录中的 EasyTier TOML 配置。
  static Future<List<NetworkConfig>> loadConfigs({
    Directory? configDirectory,
  }) async {
    final directory = configDirectory ?? await getConfigDirectory();
    await directory.create(recursive: true);
    final prefs = await SharedPreferences.getInstance();

    final tomlFiles = await directory
        .list()
        .where(
          (entity) =>
              entity is File &&
              p.extension(entity.path).toLowerCase() == '.toml' &&
              _isManagedConfigFile(entity.path),
        )
        .cast<File>()
        .toList();
    final defaultFile = File(p.join(directory.path, 'default.toml'));

    final profileFiles = tomlFiles
        .where(
          (file) =>
              p.basenameWithoutExtension(file.path).startsWith('profile_'),
        )
        .toList();
    final selectedConfigId = _selectedConfigId(prefs.getString(_settingsKey));
    profileFiles.sort((a, b) {
      final aId = _profileIdFromPath(a.path);
      final bId = _profileIdFromPath(b.path);
      if (aId == selectedConfigId) return -1;
      if (bId == selectedConfigId) return 1;
      return a.path.compareTo(b.path);
    });

    if (profileFiles.isNotEmpty) {
      return [
        for (final file in profileFiles)
          await _readTomlFile(
            file,
            id: _profileIdFromPath(file.path),
          ),
      ];
    }

    if (await defaultFile.exists()) {
      return [await _readTomlFile(defaultFile, id: 'default')];
    }

    if (tomlFiles.isEmpty) {
      final legacyConfigs = prefs.getString(_legacyConfigsKey);
      if (legacyConfigs != null && legacyConfigs.isNotEmpty) {
        final configs = _readLegacyConfigs(legacyConfigs);
        final selectedIndex = configs.indexWhere(
          (config) => config.id == selectedConfigId,
        );
        final ordered = <NetworkConfig>[
          if (selectedIndex >= 0) configs[selectedIndex],
          for (var index = 0; index < configs.length; index++)
            if (index != selectedIndex) configs[index],
        ];
        final migrated = ordered
            .map(
              (config) => _withId(
                config,
                config.id == 'default' ? 'cfg_migrated_default' : config.id,
              ),
            )
            .toList();
        final saved = await saveConfigs(migrated, configDirectory: directory);
        if (selectedIndex >= 0 && configs[selectedIndex].id == 'default') {
          await _saveSelectedConfigId(prefs, 'cfg_migrated_default');
        }
        await prefs.remove(_legacyConfigsKey);
        return saved;
      }
    }

    return [];
  }

  /// 保存配置为未加密的 EasyTier TOML 文件。
  static Future<List<NetworkConfig>> saveConfigs(
    List<NetworkConfig> configs, {
    Directory? configDirectory,
  }) async {
    final directory = configDirectory ?? await getConfigDirectory();
    await directory.create(recursive: true);

    final normalized = List<NetworkConfig>.from(configs);

    final ids = <String>{};
    for (final config in normalized) {
      if (!ids.add(config.id)) {
        throw FormatException('重复的配置 ID: ${config.id}');
      }
      if (config.id != 'default' &&
          !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(config.id)) {
        throw FormatException('配置 ID 不能用于文件名: ${config.id}');
      }
    }

    final retainedPaths = <String>{};
    for (final config in normalized) {
      final filename =
          config.id == 'default' ? 'default.toml' : 'profile_${config.id}.toml';
      final file = File(p.join(directory.path, filename));
      await file.writeAsString(config.toToml(), flush: true);
      retainedPaths.add(p.normalize(file.absolute.path));
    }

    await for (final entity in directory.list()) {
      if (entity is File &&
          p.extension(entity.path).toLowerCase() == '.toml' &&
          p.basenameWithoutExtension(entity.path).startsWith('profile_') &&
          !retainedPaths.contains(p.normalize(entity.absolute.path))) {
        await entity.delete();
      }
    }

    return normalized;
  }

  static List<NetworkConfig> _readLegacyConfigs(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final configs = decoded
          .map(
            (item) => NetworkConfig.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      if (configs.isEmpty) {
        throw const FormatException('旧版配置列表为空');
      }
      return configs;
    } catch (error) {
      throw FormatException('无法迁移旧版网络配置: $error');
    }
  }

  static Future<NetworkConfig> _readTomlFile(
    File file, {
    required String id,
  }) async {
    try {
      return NetworkConfig.fromToml(
        await file.readAsString(),
        id: id,
      );
    } catch (error) {
      throw FormatException('无法读取配置文件 ${file.path}: $error');
    }
  }

  static NetworkConfig _withId(NetworkConfig config, String id) {
    return NetworkConfig.fromJson({...config.toJson(), 'id': id});
  }

  static bool _isManagedConfigFile(String path) {
    final filename = p.basename(path).toLowerCase();
    return filename == 'default.toml' || filename.startsWith('profile_');
  }

  static String _profileIdFromPath(String path) {
    final filename = p.basenameWithoutExtension(path);
    final rawId = filename.substring('profile_'.length);
    return rawId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  static Future<void> _saveSelectedConfigId(
    SharedPreferences prefs,
    String configId,
  ) async {
    final rawSettings = prefs.getString(_settingsKey);
    if (rawSettings == null || rawSettings.isEmpty) return;
    try {
      final settings = jsonDecode(rawSettings) as Map<String, dynamic>;
      settings['selectedConfigId'] = configId;
      await prefs.setString(_settingsKey, jsonEncode(settings));
    } catch (error) {
      throw FormatException('无法更新迁移后的配置选择: $error');
    }
  }

  static String _selectedConfigId(String? rawSettings) {
    if (rawSettings == null || rawSettings.isEmpty) return '';
    try {
      return (jsonDecode(rawSettings)
              as Map<String, dynamic>)['selectedConfigId'] as String? ??
          '';
    } catch (_) {
      return '';
    }
  }

  /// 保存应用偏好设置
  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// 加载应用偏好设置
  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return AppSettings();
    }
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }
}
