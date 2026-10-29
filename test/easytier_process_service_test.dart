import 'package:easytier_gui/services/easytier_process_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses actual CLI peer table and excludes the local node', () {
    final service = EasyTierProcessService();
    const output = '''
| ipv4         | hostname            | cost  | lat(ms) | loss | rx      | tx      | tunnel          | NAT       |
|--------------|---------------------|-------|---------|------|---------|---------|-----------------|-----------|
| 10.144.144.2 | DF_3Mz              | Local | -       | -    | -       | -       | -               | Symmetric |
|              | PublicServer_server | p2p   | 35.20   | 0.0% | 2.76 kB | 3.43 kB | udp,tcp6,udp6    | NoNat     |
''';

    final peers = service.parsePeerOutput(output);

    expect(service.virtualIp, '10.144.144.2');
    expect(peers, hasLength(1));
    expect(peers.single.hostname, 'PublicServer_server');
    expect(peers.single.ipv4, isEmpty);
    expect(peers.single.tunnelType, 'P2P Direct');
    expect(peers.single.protocol, 'udp,tcp6,udp6');
    expect(peers.single.latencyMs, 35);
    expect(peers.single.rxBytes, 2760);
    expect(peers.single.txBytes, 3430);

    service.dispose();
  });

  test('extracts local IPv4 from CLI CIDR output', () {
    final service = EasyTierProcessService();
    const output = '''
| ipv4             | hostname            | cost  | lat(ms) | loss | rx      | tx      | tunnel | NAT           |
|------------------|---------------------|-------|---------|------|---------|---------|--------|---------------|
| 10.126.126.1/24  | DF_3Mz              | Local | -       | -    | -       | -       | -      | PortRestricted |
|                  | PublicServer_server | p2p   | 25.79   | 0.0% | 1.63 kB | 2.25 kB | udp,tcp | NoNat          |
''';

    final peers = service.parsePeerOutput(output);

    expect(service.virtualIp, '10.126.126.1');
    expect(peers, hasLength(1));
    expect(peers.single.ipv4, isEmpty);

    service.dispose();
  });

  test('returns no invented peers for empty or non-table output', () {
    final service = EasyTierProcessService();

    expect(service.parsePeerOutput(''), isEmpty);
    expect(service.parsePeerOutput('RPC unavailable'), isEmpty);

    service.dispose();
  });
}
