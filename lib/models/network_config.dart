import 'dart:convert';

import 'package:toml/toml.dart';

/// EasyTier 组网配置模型
class NetworkConfig {
  final String id;
  String profileName;
  String networkName;
  String networkSecret;
  bool useDhcp;
  String ipv4;
  String ipv6;
  List<String> peers;
  List<String> externalNodes;
  List<String> proxyNetworks;
  int rpcPort;
  int listenPort;
  bool enableEncryption;
  String additionalArgs;

  NetworkConfig({
    required this.id,
    this.profileName = '默认网络',
    this.networkName = 'easytier_net',
    this.networkSecret = '',
    this.useDhcp = true,
    this.ipv4 = '10.144.144.1',
    this.ipv6 = '',
    List<String>? peers,
    List<String>? externalNodes,
    List<String>? proxyNetworks,
    this.rpcPort = 15888,
    this.listenPort = 11010,
    this.enableEncryption = true,
    this.additionalArgs = '',
  })  : peers = peers ?? ['tcp://public.easytier.cn:11010'],
        externalNodes = externalNodes ?? [],
        proxyNetworks = proxyNetworks ?? [];

  /// 生成一份全新的默认配置
  factory NetworkConfig.createDefault({String? name}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return NetworkConfig(
      id: 'cfg_$timestamp',
      profileName: name ?? '新建网络配置',
      networkName: 'my_easytier',
      networkSecret: '',
      useDhcp: true,
      ipv4: '10.144.144.1',
      peers: ['tcp://public.easytier.cn:11010'],
      externalNodes: [],
      proxyNetworks: [],
      rpcPort: 15888,
      listenPort: 11010,
      enableEncryption: true,
      additionalArgs: '',
    );
  }

  /// 转换为 easytier-core 启动参数
  List<String> toCommandLineArgs() {
    final List<String> args = [];

    // 网络名称与密码
    if (networkName.isNotEmpty) {
      args.addAll(['--network-name', networkName]);
    }
    if (networkSecret.isNotEmpty) {
      args.addAll(['--network-secret', networkSecret]);
    }

    // IP 配置
    if (useDhcp) {
      args.add('-d'); // 启用 DHCP
    } else if (ipv4.isNotEmpty) {
      args.addAll(['-i', ipv4]);
    }

    if (ipv6.isNotEmpty) {
      args.addAll(['--ipv6', ipv6]);
    }

    // Peers
    for (final peer in peers) {
      if (peer.trim().isNotEmpty) {
        args.addAll(['-p', peer.trim()]);
      }
    }

    // External nodes
    for (final ext in externalNodes) {
      if (ext.trim().isNotEmpty) {
        args.addAll(['-e', ext.trim()]);
      }
    }

    // Proxy networks (子网代理)
    for (final proxy in proxyNetworks) {
      if (proxy.trim().isNotEmpty) {
        args.addAll(['-n', proxy.trim()]);
      }
    }

    // RPC Portal
    if (rpcPort > 0) {
      args.addAll(['--rpc-portal', '127.0.0.1:$rpcPort']);
    }

    // Listeners
    if (listenPort > 0) {
      args.addAll([
        '--listeners',
        'tcp://0.0.0.0:$listenPort',
        'udp://0.0.0.0:$listenPort'
      ]);
    }

    // 解析用户附加参数
    if (additionalArgs.trim().isNotEmpty) {
      final extraParts = additionalArgs
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty);
      args.addAll(extraParts);
    }

    return args;
  }

  /// 转换为 easytier-core 使用的 TOML 配置格式。
  String toToml() {
    final config = <String, dynamic>{
      'instance_name': profileName,
      'dhcp': useDhcp,
      'listeners': listenPort > 0
          ? [
              'tcp://0.0.0.0:$listenPort',
              'udp://0.0.0.0:$listenPort',
            ]
          : <String>[],
      'rpc_portal': '127.0.0.1:$rpcPort',
      'network_identity': {
        'network_name': networkName,
        'network_secret': networkSecret,
      },
      'flags': {'enable_encryption': enableEncryption},
    };

    if (!useDhcp && ipv4.isNotEmpty) {
      config['ipv4'] = ipv4;
    }
    if (ipv6.isNotEmpty) {
      config['ipv6'] = ipv6;
    }
    final configuredPeers =
        peers.where((peer) => peer.trim().isNotEmpty).toList();
    if (configuredPeers.isNotEmpty) {
      config['peer'] =
          configuredPeers.map((uri) => {'uri': uri.trim()}).toList();
    }
    final configuredProxyNetworks =
        proxyNetworks.where((network) => network.trim().isNotEmpty).toList();
    if (configuredProxyNetworks.isNotEmpty) {
      config['proxy_network'] =
          configuredProxyNetworks.map((cidr) => {'cidr': cidr.trim()}).toList();
    }

    return TomlDocument.fromMap(config).toString();
  }

  /// 从 easytier-core TOML 配置解析 NetworkConfig。
  static NetworkConfig fromToml(String tomlString, {String? defaultName}) {
    final decoded = TomlDocument.parse(tomlString).toMap();
    final config = _stringKeyedMap(decoded);
    if (config.isEmpty && tomlString.trim().isNotEmpty) {
      throw const FormatException('无效的 TOML 配置文件格式');
    }

    final identity = _stringKeyedMap(config['network_identity']);
    dynamic firstValue(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key)) return map[key];
      }
      return null;
    }

    final networkName = (firstValue(identity, ['network_name']) ??
            firstValue(config, ['network_name', 'network', 'net_name']) ??
            '')
        .toString();
    final networkSecret = (firstValue(identity, ['network_secret']) ??
            firstValue(config, ['network_secret', 'secret']) ??
            '')
        .toString();

    final dhcpValue = firstValue(config, ['dhcp', 'use_dhcp', 'useDhcp']);
    final useDhcp = dhcpValue is bool ? dhcpValue : true;

    List<String> stringList(Object? value, {String? tableValueKey}) {
      if (value is! Iterable) return [];
      return value
          .map((item) {
            if (item is Map && tableValueKey != null) {
              return _stringKeyedMap(item)[tableValueKey]?.toString();
            }
            return item?.toString();
          })
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    final peerList = stringList(
      config['peer'] ?? config['peers'],
      tableValueKey: 'uri',
    );
    final proxyList = stringList(
      config['proxy_network'] ?? config['proxy_networks'],
      tableValueKey: 'cidr',
    );
    final externalNodes =
        stringList(config['external_nodes'] ?? config['external_node']);

    int portFrom(Object? value, int fallback) {
      if (value == null) return fallback;
      final match = RegExp(r':(\d+)(?:/)?$').firstMatch(value.toString());
      return match == null
          ? fallback
          : int.tryParse(match.group(1)!) ?? fallback;
    }

    final listeners = stringList(config['listeners'] ?? config['listener']);
    final flags = _stringKeyedMap(config['flags']);
    final encryptionValue = firstValue(flags, ['enable_encryption']) ??
        firstValue(config, ['enable_encryption', 'enableEncryption']);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final configuredProfileName =
        firstValue(config, ['instance_name'])?.toString();
    final profileName = defaultName ??
        (configuredProfileName != null &&
                configuredProfileName.trim().isNotEmpty
            ? configuredProfileName
            : networkName.isNotEmpty
                ? '配置_$networkName'
                : '导入配置_$timestamp');

    return NetworkConfig(
      id: 'cfg_$timestamp',
      profileName: profileName,
      networkName: networkName,
      networkSecret: networkSecret,
      useDhcp: useDhcp,
      ipv4: firstValue(config, ['ipv4', 'ip'])?.toString() ?? '10.144.144.1',
      ipv6: firstValue(config, ['ipv6'])?.toString() ?? '',
      peers:
          peerList.isNotEmpty ? peerList : ['tcp://public.easytier.cn:11010'],
      externalNodes: externalNodes,
      proxyNetworks: proxyList,
      rpcPort: portFrom(config['rpc_portal'] ?? config['rpc_port'], 15888),
      listenPort: listeners.isEmpty ? 11010 : portFrom(listeners.first, 11010),
      enableEncryption: encryptionValue is bool ? encryptionValue : true,
      additionalArgs: '',
    );
  }

  static Map<String, dynamic> _stringKeyedMap(Object? value) {
    if (value is! Map) return {};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileName': profileName,
        'networkName': networkName,
        'networkSecret': networkSecret,
        'useDhcp': useDhcp,
        'ipv4': ipv4,
        'ipv6': ipv6,
        'peers': peers,
        'externalNodes': externalNodes,
        'proxyNetworks': proxyNetworks,
        'rpcPort': rpcPort,
        'listenPort': listenPort,
        'enableEncryption': enableEncryption,
        'additionalArgs': additionalArgs,
      };

  factory NetworkConfig.fromJson(Map<String, dynamic> json) => NetworkConfig(
        id: json['id'] as String? ??
            'cfg_${DateTime.now().millisecondsSinceEpoch}',
        profileName: json['profileName'] as String? ?? '默认配置',
        networkName: json['networkName'] as String? ?? '',
        networkSecret: json['networkSecret'] as String? ?? '',
        useDhcp: json['useDhcp'] as bool? ?? true,
        ipv4: json['ipv4'] as String? ?? '10.144.144.1',
        ipv6: json['ipv6'] as String? ?? '',
        peers: (json['peers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['tcp://public.easytier.cn:11010'],
        externalNodes: (json['externalNodes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        proxyNetworks: (json['proxyNetworks'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        rpcPort: json['rpcPort'] as int? ?? 15888,
        listenPort: json['listenPort'] as int? ?? 11010,
        enableEncryption: json['enableEncryption'] as bool? ?? true,
        additionalArgs: json['additionalArgs'] as String? ?? '',
      );

  NetworkConfig clone({String? newId, String? newName}) {
    return NetworkConfig.fromJson(jsonDecode(jsonEncode(toJson())))
      ..profileName = newName ?? '$profileName (副本)';
  }
}
