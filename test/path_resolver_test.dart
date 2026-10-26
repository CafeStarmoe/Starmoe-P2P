import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:easytier_gui/services/easytier_path_resolver.dart';

void main() {
  test('Resolve core path from bin', () async {
    final path = await EasyTierPathResolver.resolveCorePath();
    expect(path.contains('easytier-core'), isTrue);
    expect(File(path).existsSync(), isTrue);
  });
}
