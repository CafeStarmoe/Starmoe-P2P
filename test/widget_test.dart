import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:easytier_gui/main.dart';
import 'package:easytier_gui/providers/easytier_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => EasyTierProvider(),
        child: const EasyTierApp(),
      ),
    );

    expect(find.text('EasyTier'), findsWidgets);
  });
}
