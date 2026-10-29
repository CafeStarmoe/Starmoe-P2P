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
      if (_filter == 'p2p' &&
          !(p.tunnelType.contains('P2P') || p.tunnelType.contains('Direct'))) {
        return false;
      }
      if (_filter == 'relay' && !p.tunnelType.contains('Relay')) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.displayName.toLowerCase().contains(q) ||
            p.hostname.toLowerCase().contains(q) ||
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
                ' 对等节点列表',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('全部节点')),
                  ButtonSegment(value: 'p2p', label: Text('直连 (P2P)')),
                  ButtonSegment(value: 'relay', label: Text('中继通道')),
                ],
                selected: {_filter},
                onSelectionChanged: (set) =>
                    setState(() => _filter = set.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: '搜索节点昵称、用户名或设备 ID',
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
                        Icon(Icons.sports_esports_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          '未启动服务',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text('开启服务或进入房间后，即可在此查看房间内所有节点的连通状态与延迟'),
                      ],
                    ),
                  )
                : peers.isEmpty
                    ? const Center(child: Text('当前房间暂无其他节点在线'))
                    : ListView.builder(
                        itemCount: peers.length,
                        itemBuilder: (context, index) =>
                            PeerCard(peer: peers[index]),
                      ),
          ),
        ],
      ),
    );
  }
}
