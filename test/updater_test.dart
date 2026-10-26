import 'package:flutter_test/flutter_test.dart';
import 'package:easytier_gui/models/core_version_info.dart';
import 'package:easytier_gui/services/easytier_updater_service.dart';

void main() {
  test('Version comparison logic', () {
    expect(CoreVersionInfo.isNewerVersion('2.6.4', '2.6.5'), isTrue);
    expect(CoreVersionInfo.isNewerVersion('2.6.4', '2.7.0'), isTrue);
    expect(CoreVersionInfo.isNewerVersion('2.6.4', '3.0.0'), isTrue);
    expect(CoreVersionInfo.isNewerVersion('v2.6.4', 'v2.6.4'), isFalse);
    expect(CoreVersionInfo.isNewerVersion('2.6.4', '2.6.4'), isFalse);
    expect(CoreVersionInfo.isNewerVersion('2.6.4', '2.6.3'), isFalse);
    expect(CoreVersionInfo.isNewerVersion('未知', '2.6.4'), isTrue);
  });

  test('GitHub Release latest fetch test', () async {
    final info = await EasyTierUpdaterService.checkUpdate();
    expect(info.latestVersion.isNotEmpty, isTrue);
    expect(info.downloadUrl.isNotEmpty, isTrue);
    expect(info.downloadUrl.contains('easytier-windows-x86_64'), isTrue);
  });
}

