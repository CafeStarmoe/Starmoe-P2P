import 'dart:convert';
import 'dart:math';
import 'network_config.dart';

/// 房间游戏/应用场景预设
enum RoomCategory {
  gaming('游戏联机', 'games', 0xFF4CAF50, '低延迟优化，默认开启局域网广播转发，适合Minecraft、幻兽帕鲁、泰拉瑞亚等联机游戏'),
  voip('语音开黑/连麦', 'headset_mic', 0xFF2196F3, '针对游戏组队连麦与实时语音优化，保障低丢包与平稳语音交互'),
  office('自建服务器/主控', 'sports_esports', 0xFF9C27B0, '适合开黑服主建房、远程服务器管理与开服端口打通'),
  fileShare('游戏MOD/地图互传', 'folder_shared', 0xFFFF9800, '多路并发与高速互传优化，适合联机队友之间共享大体积游戏整合包与地图'),
  custom('自定义模式', 'tune', 0xFF607D8B, '自由配置房间名称与进房密码的专属私密开黑通道');

  final String label;
  final String iconName;
  final int colorValue;
  final String description;

  const RoomCategory(
      this.label, this.iconName, this.colorValue, this.description);
}

/// 虚拟房间模型 — 每个房间映射为一个独立且隔离的 EasyTier 网络空间
class Room {
  final String id;
  String name;
  String description;
  RoomCategory category;
  String networkName;
  String networkSecret;
  List<String> peers;
  bool enableUdpBroadcast;
  DateTime createdAt;
  bool isConnected;

  Room({
    required this.id,
    required this.name,
    this.description = '',
    this.category = RoomCategory.gaming,
    required this.networkName,
    this.networkSecret = '',
    List<String>? peers,
    this.enableUdpBroadcast = true,
    DateTime? createdAt,
    this.isConnected = false,
  })  : peers = peers ?? ['tcp://public.easytier.cn:11010'],
        createdAt = createdAt ?? DateTime.now();

  /// 创建全新房间并自动生成唯一的网络名和房间安全码
  factory Room.create({
    required String name,
    String description = '',
    RoomCategory category = RoomCategory.gaming,
    String? customSecret,
    bool? enableUdpBroadcast,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    final autoNetName = 'room_${category.name}_$rand';
    final secret = (customSecret != null && customSecret.isNotEmpty)
        ? customSecret
        : _generateRoomCode();

    return Room(
      id: 'room_$ts',
      name: name,
      description: description,
      category: category,
      networkName: autoNetName,
      networkSecret: secret,
      enableUdpBroadcast:
          enableUdpBroadcast ?? (category == RoomCategory.gaming),
      createdAt: DateTime.now(),
    );
  }

  static String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// 转换为启动 EasyTier 所需的 NetworkConfig
  NetworkConfig toNetworkConfig() {
    final List<String> extraArgs = [];
    if (enableUdpBroadcast) {
      extraArgs.add('--enable-udp-broadcast-relay');
    }

    return NetworkConfig(
      id: 'room_cfg_$id',
      profileName: '房间: $name',
      networkName: networkName,
      networkSecret: networkSecret,
      useDhcp: true,
      ipv4: '10.144.144.1',
      peers: peers,
      rpcPort: 15888,
      listenPort: 11010,
      enableEncryption: true,
      additionalArgs: extraArgs.join(' '),
    );
  }

  /// 生成供分享给其他成员的房间邀请口令
  String toShareCode() {
    final payload = {
      'v': 1,
      'n': name,
      'c': category.name,
      'net': networkName,
      'sec': networkSecret,
      'p': peers,
      'b': enableUdpBroadcast,
    };
    final jsonStr = jsonEncode(payload);
    return 'easytier://room?data=${base64Url.encode(utf8.encode(jsonStr))}';
  }

  /// 从口令解析导入房间
  static Room? fromShareCode(String input) {
    try {
      String rawBase64 = input.trim();
      if (rawBase64.startsWith('easytier://room?data=')) {
        rawBase64 = rawBase64.replaceFirst('easytier://room?data=', '');
      }

      final jsonStr = utf8.decode(base64Url.decode(rawBase64));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      RoomCategory cat = RoomCategory.gaming;
      final catStr = map['c'] as String?;
      if (catStr != null) {
        cat = RoomCategory.values.firstWhere(
          (c) => c.name == catStr,
          orElse: () => RoomCategory.gaming,
        );
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      return Room(
        id: 'room_$ts',
        name: map['n'] as String? ?? '导入的房间',
        category: cat,
        networkName: map['net'] as String? ?? 'room_$ts',
        networkSecret: map['sec'] as String? ?? '',
        peers:
            (map['p'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
                ['tcp://public.easytier.cn:11010'],
        enableUdpBroadcast: map['b'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.name,
        'networkName': networkName,
        'networkSecret': networkSecret,
        'peers': peers,
        'enableUdpBroadcast': enableUdpBroadcast,
        'createdAt': createdAt.toIso8601String(),
        'isConnected': isConnected,
      };

  factory Room.fromJson(Map<String, dynamic> json) {
    RoomCategory cat = RoomCategory.gaming;
    final catStr = json['category'] as String?;
    if (catStr != null) {
      cat = RoomCategory.values.firstWhere(
        (c) => c.name == catStr,
        orElse: () => RoomCategory.gaming,
      );
    }

    return Room(
      id: json['id'] as String? ??
          'room_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? '未命名房间',
      description: json['description'] as String? ?? '',
      category: cat,
      networkName: json['networkName'] as String? ?? '',
      networkSecret: json['networkSecret'] as String? ?? '',
      peers: (json['peers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['tcp://public.easytier.cn:11010'],
      enableUdpBroadcast: json['enableUdpBroadcast'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isConnected: json['isConnected'] as bool? ?? false,
    );
  }
}
