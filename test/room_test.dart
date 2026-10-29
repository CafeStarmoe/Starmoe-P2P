import 'package:flutter_test/flutter_test.dart';
import 'package:easytier_gui/models/room.dart';

void main() {
  test('Virtual Room creation and config mapping', () {
    final room = Room.create(
      name: '幻兽帕鲁开黑组',
      description: '局域网游戏联机',
      category: RoomCategory.gaming,
    );

    expect(room.name, '幻兽帕鲁开黑组');
    expect(room.category, RoomCategory.gaming);
    expect(room.enableUdpBroadcast, isTrue);

    final config = room.toNetworkConfig();
    expect(config.networkName, room.networkName);
    expect(config.networkSecret, room.networkSecret);
    expect(config.additionalArgs.contains('--enable-udp-broadcast-relay'), isTrue);
  });

  test('Virtual Room share code export and import', () {
    final original = Room.create(
      name: '团队晨会语音',
      category: RoomCategory.voip,
      customSecret: 'SECRET12345',
    );

    final shareCode = original.toShareCode();
    expect(shareCode.startsWith('easytier://room?data='), isTrue);

    final imported = Room.fromShareCode(shareCode);
    expect(imported, isNotNull);
    expect(imported!.name, '团队晨会语音');
    expect(imported.category, RoomCategory.voip);
    expect(imported.networkSecret, 'SECRET12345');
    expect(imported.networkName, original.networkName);
  });
}

