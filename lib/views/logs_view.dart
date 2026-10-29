import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/easytier_provider.dart';

class LogsView extends StatefulWidget {
  const LogsView({super.key});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filterKeyword = '';

  @override
  void didUpdateWidget(covariant LogsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToBottomIfNeeded();
  }

  void _scrollToBottomIfNeeded() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EasyTierProvider>();
    final theme = Theme.of(context);
    final logs = provider.logs.where((l) {
      if (_filterKeyword.isEmpty) return true;
      return l.toLowerCase().contains(_filterKeyword.toLowerCase());
    }).toList();

    _scrollToBottomIfNeeded();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Easytier-core 日志',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Row(
                children: [
                  const Text('自动滚动'),
                  Switch(
                    value: _autoScroll,
                    onChanged: (val) => setState(() => _autoScroll = val),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('复制全部'),
                onPressed: provider.logs.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(
                            ClipboardData(text: provider.logs.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('已复制所有Easytier-core 日志到剪贴板')),
                        );
                      },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空'),
                onPressed:
                    provider.logs.isEmpty ? null : () => provider.clearLogs(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: '过滤日志关键字 (如 ERR, IP, tun, handshake)...',
              prefixIcon: const Icon(Icons.filter_alt_outlined),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _filterKeyword = val),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF14171A)
                    : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withAlpha(50)),
              ),
              padding: const EdgeInsets.all(16),
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无Easytier-core 日志。开启服务后，核心服务进程的运行日志将实时在此输出。',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final line = logs[index];
                        Color textColor = const Color(0xFFDDDDDD);
                        if (line.contains('[ERR]') ||
                            line.contains('ERROR') ||
                            line.contains('错误') ||
                            line.contains('失败')) {
                          textColor = const Color(0xFFFF6B6B);
                        } else if (line.contains('[启动]') ||
                            line.contains('[退出]')) {
                          textColor = const Color(0xFF4DABF7);
                        } else if (line.contains('WARN') ||
                            line.contains('警告')) {
                          textColor = const Color(0xFFFCC419);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: SelectableText(
                            line,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: textColor,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
