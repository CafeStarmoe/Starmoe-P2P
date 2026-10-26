import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/easytier_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/peer_card.dart';
import '../widgets/update_dialog.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String _formatTotalBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 发现新版本更新横幅
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
                  Icon(Icons.new_releases, color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '发现 EasyTier 核心更新 v${provider.versionInfo!.latestVersion} (当前 v${provider.currentCoreVersion})',
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
                    onPressed: () => UpdateDialog.show(context, provider.versionInfo!),
                  ),
                ],
              ),
            ),
          ],

          // 头部主卡片：状态与启停控制
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              '虚拟 IP: ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              isRunning && provider.virtualIp.isNotEmpty
                                  ? provider.virtualIp
                                  : '未分配 (组网未连接)',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: isRunning ? theme.colorScheme.primary : null,
                              ),
                            ),
                            if (isRunning && provider.virtualIp.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                tooltip: '复制虚拟 IP',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: provider.virtualIp));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已复制虚拟 IP 到剪贴板'),
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
                          '网络名称: ${currentConfig?.networkName ?? "未配置"}  |  已运行: ${_formatDuration(provider.uptime)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                      backgroundColor: isRunning ? Colors.redAccent : theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: provider.isConnecting
                        ? null
                        : () => provider.toggleService(),
                    icon: Icon(
                      isRunning ? Icons.stop : Icons.play_arrow,
                      size: 24,
                    ),
                    label: Text(
                      isRunning ? '停止组网' : '连接组网',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    title: '实时下载',
                    value: isRunning ? _formatSpeed(provider.downloadSpeed) : '0 B/s',
                    icon: Icons.arrow_downward,
                    color: Colors.blue,
                  ),
                  StatCard(
                    title: '实时上传',
                    value: isRunning ? _formatSpeed(provider.uploadSpeed) : '0 B/s',
                    icon: Icons.arrow_upward,
                    color: Colors.purple,
                  ),
                  StatCard(
                    title: '累计接收',
                    value: isRunning ? _formatTotalBytes(provider.totalDownloaded) : '0 B',
                    icon: Icons.cloud_download_outlined,
                    color: Colors.teal,
                  ),
                  StatCard(
                    title: '在线节点',
                    value: isRunning ? '${provider.peers.length} 台' : '0 台',
                    subtitle: isRunning ? '组网拓扑正常' : '已离线',
                    icon: Icons.hub_outlined,
                    color: Colors.indigo,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // 组网节点概览
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '活跃节点列表 (${provider.peers.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(40)),
              ),
              child: Column(
                children: [
                  Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    '组网服务未运行',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '点击上方“连接组网”按钮开始连接异地虚拟局域网。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          else if (provider.peers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('正在探测对等节点...'),
            )
          else
            Column(
              children: provider.peers.map((peer) => PeerCard(peer: peer)).toList(),
            ),
        ],
      ),
    );
  }
}

