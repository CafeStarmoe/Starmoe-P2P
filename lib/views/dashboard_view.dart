import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/easytier_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/peer_card.dart';
import '../widgets/update_dialog.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool _hasPromptedUsername = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeUsername();
    });
  }

  void _checkFirstTimeUsername() {
    if (_hasPromptedUsername) return;
    final provider = context.read<EasyTierProvider>();
    if (!provider.isInitialized) return;
    if (provider.username.isEmpty) {
      _hasPromptedUsername = true;
      _showUsernameDialog(isFirstTime: true);
    }
  }

  void _showUsernameDialog({bool isFirstTime = false}) {
    final provider = context.read<EasyTierProvider>();
    final ctrl = TextEditingController(text: provider.username);

    showDialog(
      context: context,
      barrierDismissible: !isFirstTime,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.sports_esports_outlined),
            const SizedBox(width: 8),
            Text(isFirstTime ? '欢迎来到 Starmoe P2P - 请设置用户名' : '修改用户名'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFirstTime
                    ? '设置一个你的联机游戏昵称，网络中的对等节点将直接看到你的昵称：'
                    : '设置后，联机队友列表中将优先展示此昵称：',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  hintText: '如：DF_3Mz, VKG_Kassa',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isFirstTime)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                provider.updateUsername(name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('用户名已设置为: $name')),
                );
              }
            },
            child: Text(isFirstTime ? '进入软件' : '保存修改'),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String _formatTotalBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EasyTierProvider>();
    final theme = Theme.of(context);
    final isRunning = provider.isRunning;
    final currentConfig = provider.currentConfig;
    final currentUsername =
        provider.username.isNotEmpty ? provider.username : '未设置';

    if (provider.isInitialized && !_hasPromptedUsername) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkFirstTimeUsername();
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.configError != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '读取 config 文件夹中的 TOML 配置失败：${provider.configError}',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
          if (provider.hasUpdate && provider.versionInfo != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade700.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.new_releases,
                      color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '发现内核新版本 v${provider.versionInfo!.latestVersion} (当前 v${provider.currentCoreVersion})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber.shade900,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.upgrade, size: 16),
                    label: const Text('查看更新'),
                    onPressed: () =>
                        UpdateDialog.show(context, provider.versionInfo!),
                  ),
                ],
              ),
            ),
          ],

          // 头部主卡片：状态与启停控制 + 玩家昵称栏
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isRunning
                    ? theme.colorScheme.primary.withAlpha(80)
                    : theme.colorScheme.outlineVariant.withAlpha(50),
              ),
            ),
            color: isRunning
                ? theme.colorScheme.primaryContainer.withAlpha(40)
                : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(
                              isRunning: isRunning,
                              isConnecting: provider.isConnecting,
                            ),
                            const SizedBox(width: 12),
                            if (currentConfig != null)
                              Text(
                                currentConfig.profileName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(width: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () =>
                                  _showUsernameDialog(isFirstTime: false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withAlpha(80),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sports_esports,
                                        size: 14,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '用户名: $currentUsername',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit,
                                        size: 12,
                                        color: theme.colorScheme.outline),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '局域网 IP: ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              isRunning && provider.virtualIp.isNotEmpty
                                  ? provider.virtualIp
                                  : '未分配',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: isRunning
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                            if (isRunning && provider.virtualIp.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: '复制 IP',
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: provider.virtualIp));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已复制 IP 到剪贴板'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '网络标识: ${currentConfig?.networkName ?? "未配置"}  |  启动时长: ${_formatDuration(provider.uptime)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 20),
                      backgroundColor: isRunning
                          ? Colors.redAccent
                          : theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: provider.isConnecting
                        ? null
                        : () => provider.toggleService(),
                    icon: Icon(
                      isRunning ? Icons.stop : Icons.play_arrow,
                      size: 24,
                    ),
                    label: Text(
                      isRunning ? '关闭服务' : '启动服务',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 核心监控指标 (4格栅格)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 1.8 : 1.4,
                children: [
                  StatCard(
                    title: '下行网速',
                    value: isRunning
                        ? _formatSpeed(provider.downloadSpeed)
                        : '0 B/s',
                    icon: Icons.arrow_downward,
                    color: Colors.blue,
                  ),
                  StatCard(
                    title: '上行网速',
                    value: isRunning
                        ? _formatSpeed(provider.uploadSpeed)
                        : '0 B/s',
                    icon: Icons.arrow_upward,
                    color: Colors.purple,
                  ),
                  StatCard(
                    title: '本局流量',
                    value: isRunning
                        ? _formatTotalBytes(provider.totalDownloaded)
                        : '0 B',
                    icon: Icons.data_usage,
                    color: Colors.teal,
                  ),
                  StatCard(
                    title: '节点列表',
                    value: isRunning ? '${provider.peers.length} 人' : '0 人',
                    subtitle: isRunning ? 'P2P通道就绪' : '未连接',
                    icon: Icons.sports_esports_outlined,
                    color: Colors.indigo,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '对等节点列表 (${provider.peers.length})',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (isRunning)
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('刷新'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (!isRunning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant.withAlpha(40)),
              ),
              child: Column(
                children: [
                  Icon(Icons.videogame_asset_off_outlined,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    '未启动服务',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // const SizedBox(height: 6),
                ],
              ),
            )
          else if (provider.peers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('正在寻找网络中的其他对等节点...'),
            )
          else
            Column(
              children:
                  provider.peers.map((peer) => PeerCard(peer: peer)).toList(),
            ),
        ],
      ),
    );
  }
}
