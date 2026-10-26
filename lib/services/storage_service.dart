import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_config.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _configsKey = 'easytier_configs';
  static const String _settingsKey = 'easytier_settings';

  /// 保存所有网络配置
  static Future<void> saveConfigs(List<NetworkConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = configs.map((c) => c.toJson()).toList();
    await prefs.setString(_configsKey, jsonEncode(jsonList));
  }

  /// 加载所有网络配置
  static Future<List<NetworkConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configsKey);
    if (raw == null || raw.isEmpty) {
      // 默认提供一个开箱即用的配置
      return [NetworkConfig.createDefault(name: '默认网络 (官方公共中继)')];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => NetworkConfig.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [NetworkConfig.createDefault()];
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

