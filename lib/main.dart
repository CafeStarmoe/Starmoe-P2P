import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/easytier_provider.dart';
import 'views/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => EasyTierProvider(),
      child: const EasyTierApp(),
    ),
  );
}

class EasyTierApp extends StatelessWidget {
  const EasyTierApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EasyTierProvider>();

    return MaterialApp(
      title: 'Starmoe EasyTier Tools',
      debugShowCheckedModeBanner: false,
      themeMode: provider.settings.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.light,
        ),
        fontFamily: 'MiSans',
        fontFamilyFallback: const [
          'MiSans Normal',
          'Segoe UI',
          'Microsoft YaHei',
          'sans-serif',
        ],
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'MiSans',
        fontFamilyFallback: const [
          'MiSans Normal',
          'Segoe UI',
          'Microsoft YaHei',
          'sans-serif',
        ],
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
        ),
      ),
      home: const MainLayout(),
    );
  }
}
