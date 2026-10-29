import 'package:easytier_gui/models/network_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports NetworkConfig as EasyTier TOML and parses it back', () {
    final config = NetworkConfig(
      id: 'cfg_test',
      profileName: '测试网络',
      networkName: 'office_mesh',
      networkSecret: 'secret "with quotes"',
      useDhcp: false,
      ipv4: '10.144.144.5',
      ipv6: 'fd00::5',
      peers: ['tcp://1.1.1.1:11010', 'udp://2.2.2.2:11010'],
      proxyNetworks: ['192.168.1.0/24'],
      rpcPort: 15888,
      listenPort: 11010,
      enableEncryption: false,
    );

    final toml = config.toToml();
    expect(toml, contains('dhcp = false'));
    expect(toml, contains("instance_name = '测试网络'"));
    expect(toml, contains('[network_identity]'));
    expect(toml, contains("network_name = 'office_mesh'"));
    expect(toml, contains('[[peer]]'));
    expect(toml, contains('[[proxy_network]]'));

    final imported = NetworkConfig.fromToml(toml);
    expect(imported.profileName, config.profileName);
    expect(imported.networkName, config.networkName);
    expect(imported.networkSecret, config.networkSecret);
    expect(imported.useDhcp, config.useDhcp);
    expect(imported.ipv4, config.ipv4);
    expect(imported.ipv6, config.ipv6);
    expect(imported.peers, config.peers);
    expect(imported.proxyNetworks, config.proxyNetworks);
    expect(imported.rpcPort, config.rpcPort);
    expect(imported.listenPort, config.listenPort);
    expect(imported.enableEncryption, config.enableEncryption);
  });

  test('imports EasyTier TOML array tables and nested network identity', () {
    const toml = '''
instance_name = "home_network"
dhcp = false
ipv4 = "10.144.144.5"
listeners = ["tcp://0.0.0.0:12010", "udp://0.0.0.0:12010"]
rpc_portal = "127.0.0.1:15889"

[network_identity]
network_name = "home_vpn"
network_secret = "secret999"

[[peer]]
uri = "tcp://public.easytier.cn:11010"

[[peer]]
uri = "udp://public.easytier.cn:11010"

[[proxy_network]]
cidr = "10.0.0.0/24"

[flags]
enable_encryption = false
''';

    final config = NetworkConfig.fromToml(toml);
    expect(config.profileName, 'home_network');
    expect(config.networkName, 'home_vpn');
    expect(config.networkSecret, 'secret999');
    expect(config.useDhcp, isFalse);
    expect(config.ipv4, '10.144.144.5');
    expect(config.peers, [
      'tcp://public.easytier.cn:11010',
      'udp://public.easytier.cn:11010',
    ]);
    expect(config.proxyNetworks, ['10.0.0.0/24']);
    expect(config.rpcPort, 15889);
    expect(config.listenPort, 12010);
    expect(config.enableEncryption, isFalse);
  });

  test('uses the selected import name when provided', () {
    final config = NetworkConfig.fromToml(
      'instance_name = "internal_name"\n'
      '[network_identity]\n'
      'network_name = "network"\n',
      defaultName: 'Imported profile',
    );

    expect(config.profileName, 'Imported profile');
  });

  test('rejects invalid TOML', () {
    expect(
      () => NetworkConfig.fromToml('network_name = ['),
      throwsA(isA<Exception>()),
    );
  });
}
