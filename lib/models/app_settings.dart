import 'package:flutter/material.dart';

/// 应用偏好设置
class AppSettings {
  String coreExecutablePath;
  ThemeMode themeMode;
  bool autoStartCoreOnLaunch;
  bool autoStartOnBoot;
  String selectedConfigId;

  AppSettings({
    this.coreExecutablePath = 'builtin',
    this.themeMode = ThemeMode.system,
    this.autoStartCoreOnLaunch = false,
    this.autoStartOnBoot = false,
    this.selectedConfigId = '',
  });

  Map<String, dynamic> toJson() => {
        'coreExecutablePath': coreExecutablePath,
        'themeMode': themeMode.name,
        'autoStartCoreOnLaunch': autoStartCoreOnLaunch,
        'autoStartOnBoot': autoStartOnBoot,
        'selectedConfigId': selectedConfigId,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    ThemeMode mode = ThemeMode.system;
    final modeStr = json['themeMode'] as String?;
    if (modeStr == 'light') mode = ThemeMode.light;
    if (modeStr == 'dark') mode = ThemeMode.dark;

    final corePath = json['coreExecutablePath'] as String? ?? 'builtin';
    return AppSettings(
      coreExecutablePath: (corePath.isEmpty || corePath == 'easytier-core') ? 'builtin' : corePath,
      themeMode: mode,
      autoStartCoreOnLaunch: json['autoStartCoreOnLaunch'] as bool? ?? false,
      autoStartOnBoot: json['autoStartOnBoot'] as bool? ?? false,
      selectedConfigId: json['selectedConfigId'] as String? ?? '',
    );
  }
}

