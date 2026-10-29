import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/easytier_provider.dart';
import '../services/ping_service.dart';

class ToolsView extends StatefulWidget {
  const ToolsView({super.key});

  @override
  State<ToolsView> createState() => _ToolsViewState();
}

class _ToolsViewState extends State<ToolsView> {
  final TextEditingController _targetCtrl =
      TextEditingController(text: 'et.stmoe.cn');
  bool _isTesting = false;
  PingResult? _lastResult;

  Future<void> _startPing() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isTesting = true;
    });

    final result = await PingService.ping(target, count: 4);

    setState(() {
      _isTesting = false;
      _lastResult = result;
    });
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<EasyTierProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '延迟测试工具',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '测试与对等节点或与中继服务器的真实往返延迟 (Ping) 与网络连通性',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),

          // Ping 测试卡片
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('延迟探测 (Ping)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _targetCtrl,
                          decoration: const InputDecoration(
                            labelText: '目标 IP 或域名',
                            hintText: '例如: 10.144.144.1 或 et.stmoe.cn',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.network_ping),
                          ),
                          onSubmitted: (_) => _startPing(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 18),
                        ),
                        onPressed: _isTesting ? null : _startPing,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isTesting ? '测试中' : '开始测试'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('快速测速:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ActionChip(
                        label: const Text('Starmoe中继节点'),
                        onPressed: () {
                          _targetCtrl.text = 'et.stmoe.cn';
                          _startPing();
                        },
                      ),
                      if (provider.virtualIp.isNotEmpty)
                        ActionChip(
                          label: Text(
                              '我的IP (${provider.username.isNotEmpty ? provider.username : provider.virtualIp})'),
                          onPressed: () {
                            _targetCtrl.text = provider.virtualIp;
                            _startPing();
                          },
                        ),
                      ...provider.peers.map((p) => ActionChip(
                            label: Text('${p.displayName} (${p.ipv4})'),
                            onPressed: () {
                              _targetCtrl.text = p.ipv4;
                              _startPing();
                            },
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 测试结果与历史记录
          if (_lastResult != null) ...[
            Text('测试结果',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _lastResult!.isSuccess
                      ? Colors.green.withAlpha(80)
                      : Colors.red.withAlpha(80),
                ),
              ),
              color: _lastResult!.isSuccess
                  ? Colors.green.withAlpha(20)
                  : Colors.red.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastResult!.isSuccess
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _lastResult!.isSuccess
                              ? Colors.green
                              : Colors.red,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _lastResult!.isSuccess ? '连接成功' : '请求超时或目标不可达',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _lastResult!.isSuccess
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (_lastResult!.isSuccess)
                          Text(
                            '往返平均延迟: ${_lastResult!.latencyMs} ms',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    SelectableText(
                      _lastResult!.rawOutput.trim(),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
