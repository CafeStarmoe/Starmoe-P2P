import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/easytier_provider.dart';
import '../widgets/status_badge.dart';
import 'dashboard_view.dart';
import 'peers_view.dart';
import 'config_view.dart';
import 'logs_view.dart';
import 'tools_view.dart';
import 'settings_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _views = const [
    DashboardView(),
    PeersView(),
    ConfigView(),
    LogsView(),
    ToolsView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<EasyTierProvider>();

    return Scaffold(
      body: Row(
        children: [
          // 桌面侧边导航栏
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hub_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Starmoe',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(
                    isRunning: provider.isRunning,
                    isConnecting: provider.isConnecting,
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'v1.0.0-DEV',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('仪表盘'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub),
                label: Text('节点拓扑'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: Text('网络配置'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: Text('运行日志'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.build_circle_outlined),
                selectedIcon: Icon(Icons.build_circle),
                label: Text('诊断工具'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('客户端设置'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // 主视图内容展示区
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _views,
            ),
          ),
        ],
      ),
    );
  }
}
