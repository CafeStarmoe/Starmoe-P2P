import 'dart:convert';
import 'dart:io';

import 'package:easytier_gui/models/app_settings.dart';
import 'package:easytier_gui/models/network_config.dart';
import 'package:easytier_gui/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory configDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    configDirectory = await Directory.systemTemp.createTemp('easytier-config-');
  });

  tearDown(() async {
    await configDirectory.delete(recursive: true);
  });

  test('does not create a config when no config file exists', () async {
    final configs = await StorageService.loadConfigs(
      configDirectory: configDirectory,
    );

    expect(configs, isEmpty);
    expect(
      await File(p.join(configDirectory.path, 'default.toml')).exists(),
      isFalse,
    );
    expect(
      (await configDirectory.list().toList())
          .whereType<File>()
          .where((file) => p.extension(file.path) == '.toml'),
      isEmpty,
    );
  });

  test('loads default.toml when no profile config exists', () async {
    final defaultConfig = NetworkConfig.createDefault(
      id: 'default',
      name: '手动默认配置',
    );
    final file = File(p.join(configDirectory.path, 'default.toml'));
    await file.writeAsString(defaultConfig.toToml());

    final configs = await StorageService.loadConfigs(
      configDirectory: configDirectory,
    );

    expect(configs, hasLength(1));
    expect(configs.single.id, 'default');
    expect(configs.single.profileName, '手动默认配置');
    expect(await file.exists(), isTrue);
    final toml = await file.readAsString();
    expect(toml, contains('[network_identity]'));
    expect(toml, contains('network_secret'));
    expect(
        NetworkConfig.fromToml(toml).networkName, configs.single.networkName);
  });

  test('stores user settings as JSON in the data directory', () async {
    final settings = AppSettings(username: 'LocalUser');
    await StorageService.saveSettings(
      settings,
      dataDirectory: configDirectory,
    );

    final settingsFile = File(p.join(configDirectory.path, 'settings.json'));
    expect(await settingsFile.exists(), isTrue);
    expect(
        await settingsFile.readAsString(), contains('"username": "LocalUser"'));
    expect(
      (await StorageService.loadSettings(dataDirectory: configDirectory))
          .username,
      'LocalUser',
    );
    expect(
      (await SharedPreferences.getInstance()).getString('easytier_settings'),
      isNull,
    );
  });

  test('migrates legacy preferences out of SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'easytier_settings',
      jsonEncode(AppSettings(username: 'MigratedUser').toJson()),
    );

    final settings = await StorageService.loadSettings(
      dataDirectory: configDirectory,
    );

    expect(settings.username, 'MigratedUser');
    expect(
      await File(p.join(configDirectory.path, 'settings.json')).exists(),
      isTrue,
    );
    expect(prefs.getString('easytier_settings'), isNull);
  });

  test('migrates legacy config TOML into the data config directory', () async {
    final legacyDirectory =
        await Directory.systemTemp.createTemp('easytier-legacy-config-');
    addTearDown(() => legacyDirectory.delete(recursive: true));
    final legacyFile = File(p.join(legacyDirectory.path, 'default.toml'));
    final config = NetworkConfig.createDefault(
      id: 'default',
      name: '旧目录配置',
    );
    await legacyFile.writeAsString(config.toToml());

    final loaded = await StorageService.loadConfigs(
      configDirectory: configDirectory,
      dataDirectory: configDirectory,
      legacyConfigDirectory: legacyDirectory,
    );

    expect(loaded.single.profileName, '旧目录配置');
    expect(await legacyFile.exists(), isFalse);
    expect(
      await File(p.join(configDirectory.path, 'default.toml')).exists(),
      isTrue,
    );
  });

  test('default TOML is accepted by the bundled EasyTier core', () async {
    final core = File(
      p.join(Directory.current.path, 'bin', 'easytier-core.exe'),
    );
    if (!Platform.isWindows || !await core.exists()) return;

    final config = NetworkConfig.createDefault(id: 'default');
    final configFile = File(p.join(configDirectory.path, 'default.toml'));
    await configFile.writeAsString(config.toToml());

    final result = await Process.run(
      core.path,
      [
        '--check-config',
        '--config-file',
        configFile.path,
        '--dhcp',
        'true',
      ],
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });

  test('prefers profile configs and preserves default.toml as fallback',
      () async {
    final defaultConfig = NetworkConfig.createDefault(id: 'default');
    final secondaryConfig = NetworkConfig.createDefault(
      id: 'cfg_secondary',
      name: '备用网络',
    )..networkName = 'secondary';

    await StorageService.saveConfigs(
      [defaultConfig, secondaryConfig],
      configDirectory: configDirectory,
    );
    final defaultFile = File(p.join(configDirectory.path, 'default.toml'));
    await defaultFile.writeAsString(defaultConfig.toToml());

    final loaded = await StorageService.loadConfigs(
      configDirectory: configDirectory,
    );

    expect(loaded.map((config) => config.id), ['cfg_secondary']);
    expect(loaded.single.networkName, 'secondary');
    expect(await defaultFile.exists(), isTrue);
    expect(
      await File(
        p.join(configDirectory.path, 'profile_cfg_secondary.toml'),
      ).exists(),
      isTrue,
    );
  });

  test('preserves unmanaged TOML files in the config directory', () async {
    final manualFile = File(p.join(configDirectory.path, 'manual.toml'));
    const manualToml = 'unknown_option = "keep this file unchanged"';
    await manualFile.writeAsString(manualToml);

    final configs = await StorageService.loadConfigs(
      configDirectory: configDirectory,
    );
    await StorageService.saveConfigs(
      configs,
      configDirectory: configDirectory,
    );

    expect(await manualFile.readAsString(), manualToml);
  });

  test('migrates existing preferences to profile TOML files', () async {
    final previousDefault = NetworkConfig.createDefault(
      id: 'cfg_old',
      name: 'Old default',
    );
    final previouslySelected = NetworkConfig.createDefault(
      id: 'cfg_selected',
      name: 'Selected network',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'easytier_configs',
      jsonEncode([previousDefault.toJson(), previouslySelected.toJson()]),
    );
    await StorageService.saveSettings(
      AppSettings(selectedConfigId: previouslySelected.id),
      dataDirectory: configDirectory,
    );

    final migrated = await StorageService.loadConfigs(
      configDirectory: configDirectory,
      dataDirectory: configDirectory,
    );

    expect(migrated.first.id, 'cfg_selected');
    expect(migrated.first.profileName, 'Selected network');
    expect(migrated, hasLength(2));
    expect(
      await File(
        p.join(configDirectory.path, 'profile_cfg_selected.toml'),
      ).exists(),
      isTrue,
    );
    expect(
      await File(p.join(configDirectory.path, 'default.toml')).exists(),
      isFalse,
    );
    expect(prefs.getString('easytier_configs'), isNull);
  });

  test('reports invalid TOML with the file path', () async {
    await File(p.join(configDirectory.path, 'default.toml'))
        .writeAsString('network_identity = [');

    await expectLater(
      StorageService.loadConfigs(configDirectory: configDirectory),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('default.toml'),
        ),
      ),
    );
  });
}
