import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/easytier_provider.dart';
import '../widgets/peer_card.dart';

class PeersView extends StatefulWidget {
  const PeersView({super.key});

  @override
  State<PeersView> createState() => _PeersViewState();
}

class _PeersViewState extends State<PeersView> {
  String _filter = 'all'; // all, p2p, relay
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EasyTierProvider>();
    final theme = Theme.of(context);
    final peers = provider.peers.where((p) {
      if (_filter == 'p2p' && !(p.tunnelType.contains('P2P') || p.tunnelType.contains('Direct'))) {
        return false;
      }
      if (_filter == 'relay' && !p.tunnelType.contains('Relay')) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.hostname.toLowerCase().contains(q) ||
            p.ipv4.toLowerCase().contains(q) ||
            p.peerId.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '对等网络拓扑',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('全部')),
                  ButtonSegment(value: 'p2p', label: Text('P2P 直连')),
                  ButtonSegment(value: 'relay', label: Text('中继转发')),
                ],
                selected: {_filter},
                onSelectionChanged: (set) => setState(() => _filter = set.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: '搜索节点 IP、主机名或 Peer ID...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: !provider.isRunning
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.device_hub, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          '组网未连接',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('启动 EasyTier 后即可实时监控网络内各节点的连通方式与延迟'),
                      ],
                    ),
                  )
                : peers.isEmpty
                    ? const Center(child: Text('没有符合条件的节点'))
                    : ListView.builder(
                        itemCount: peers.length,
                        itemBuilder: (context, index) => PeerCard(peer: peers[index]),
                      ),
          ),
        ],
      ),
    );
  }
}

