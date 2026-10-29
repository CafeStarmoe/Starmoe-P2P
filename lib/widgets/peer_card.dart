import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/peer_info.dart';

class PeerCard extends StatelessWidget {
  final PeerInfo peer;

  const PeerCard({super.key, required this.peer});

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Color _getLatencyColor(int latency) {
    if (latency <= 30) {
      return Colors.green;
    }
    if (latency <= 80) {
      return Colors.amber;
    }
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isP2P =
        peer.tunnelType.contains('P2P') || peer.tunnelType.contains('Direct');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isP2P
                      ? Colors.teal.withAlpha(30)
                      : Colors.orange.withAlpha(30),
                  child: Icon(
                    isP2P ? Icons.person_outline : Icons.router,
                    color: isP2P ? Colors.teal : Colors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              peer.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (peer.customUsername != null &&
                              peer.customUsername!.isNotEmpty &&
                              peer.hostname.isNotEmpty &&
                              peer.hostname != peer.customUsername) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${peer.hostname})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isP2P
                                  ? Colors.green.withAlpha(20)
                                  : Colors.orange.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isP2P
                                    ? Colors.green.withAlpha(80)
                                    : Colors.orange.withAlpha(80),
                              ),
                            ),
                            child: Text(
                              peer.tunnelType,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isP2P
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            peer.ipv4.isEmpty ? '未分配 IP' : peer.ipv4,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: peer.ipv4.isEmpty
                                  ? theme.colorScheme.outline
                                  : theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (peer.ipv4.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              tooltip: '复制 IP',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: peer.ipv4),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已复制 IP: ${peer.ipv4}'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed,
                            size: 16, color: _getLatencyColor(peer.latencyMs)),
                        const SizedBox(width: 4),
                        Text(
                          '${peer.latencyMs} ms',
                          style: TextStyle(
                            color: _getLatencyColor(peer.latencyMs),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      peer.protocol,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.arrow_downward,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '下载: ${_formatBytes(peer.rxBytes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward,
                        size: 14, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      '上传: ${_formatBytes(peer.txBytes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                if (peer.peerId.isNotEmpty)
                  Text(
                    'ID: ${peer.peerId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
