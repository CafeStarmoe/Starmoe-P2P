import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:easytier_gui/main.dart';
import 'package:easytier_gui/providers/easytier_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final provider = EasyTierProvider();
    provider.settings.username = 'TestPlayer';

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const EasyTierApp(),
      ),
    );
    await tester.pump();

    expect(find.textContaining('EasyTier'), findsWidgets);
  });
}

