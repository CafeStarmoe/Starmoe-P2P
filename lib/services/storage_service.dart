import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_config.dart';
import '../models/app_settings.dart';
import '../models/room.dart';

class StorageService {
  static const String _configsKey = 'easytier_configs';
  static const String _settingsKey = 'easytier_settings';
  static const String _roomsKey = 'easytier_rooms';

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

  /// 保存所有虚拟房间
  static Future<void> saveRooms(List<Room> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = rooms.map((r) => r.toJson()).toList();
    await prefs.setString(_roomsKey, jsonEncode(jsonList));
  }

  /// 加载所有虚拟房间 (初始无数据时内置2个常用场景房间供体验)
  static Future<List<Room>> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_roomsKey);
    if (raw == null || raw.isEmpty) {
      return [
        Room.create(
          name: '游戏开黑联机房',
          description: '低延迟优化，已自动开启广播转发，适合局域网联机',
          category: RoomCategory.gaming,
        ),
        Room.create(
          name: '高清音视频通话室',
          description: '专用会议通道，保障低丢包与平稳语音交互',
          category: RoomCategory.voip,
        ),
      ];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => Room.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
