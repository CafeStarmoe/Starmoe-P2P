import 'package:flutter_test/flutter_test.dart';
import 'package:easytier_gui/models/network_config.dart';

void main() {
  test('Export NetworkConfig to YAML', () {
    final config = NetworkConfig(
      id: 'cfg_test',
      profileName: '测试网络',
      networkName: 'office_mesh',
      networkSecret: 'mypassword123',
      useDhcp: false,
      ipv4: '10.144.144.5',
      peers: ['tcp://1.1.1.1:11010', 'udp://2.2.2.2:11010'],
      proxyNetworks: ['192.168.1.0/24'],
      rpcPort: 15888,
      listenPort: 11010,
    );

    final yaml = config.toYaml();
    expect(yaml.contains('network_name: "office_mesh"'), isTrue);
    expect(yaml.contains('network_secret: "mypassword123"'), isTrue);
    expect(yaml.contains('dhcp: false'), isTrue);
    expect(yaml.contains('ipv4: "10.144.144.5"'), isTrue);
    expect(yaml.contains('- "tcp://1.1.1.1:11010"'), isTrue);
    expect(yaml.contains('- "192.168.1.0/24"'), isTrue);
  });

  test('Import NetworkConfig from YAML', () {
    const yamlString = '''
network_name: "home_vpn"
network_secret: "secret999"
dhcp: true
ipv4: "10.144.144.1"
peers:
  - "tcp://public.easytier.cn:11010"
  - "udp://public.easytier.cn:11010"
proxy_networks:
  - "10.0.0.0/24"
rpc_portal: "127.0.0.1:15888"
listeners:
  - "tcp://0.0.0.0:11010"
''';

    final config = NetworkConfig.fromYaml(yamlString, defaultName: '导入的家庭网络');
    expect(config.profileName, '导入的家庭网络');
    expect(config.networkName, 'home_vpn');
    expect(config.networkSecret, 'secret999');
    expect(config.useDhcp, isTrue);
    expect(config.peers.length, 2);
    expect(config.peers.first, 'tcp://public.easytier.cn:11010');
    expect(config.proxyNetworks.length, 1);
    expect(config.proxyNetworks.first, '10.0.0.0/24');
    expect(config.rpcPort, 15888);
    expect(config.listenPort, 11010);
  });
}

