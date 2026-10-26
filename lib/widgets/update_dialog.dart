import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/core_version_info.dart';
import '../providers/easytier_provider.dart';

class UpdateDialog extends StatefulWidget {
  final CoreVersionInfo versionInfo;

  const UpdateDialog({super.key, required this.versionInfo});

  static Future<void> show(BuildContext context, CoreVersionInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(versionInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isSuccess = false;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    final provider = context.read<EasyTierProvider>();
    setState(() {
      _errorMessage = null;
    });

    final success = await provider.performCoreUpdate();
    if (mounted) {
      setState(() {
        _isSuccess = success;
        if (!success) {
          _errorMessage = provider.updateStatusMessage;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<EasyTierProvider>();
    final isUpdating = provider.isUpdatingCore;
    final info = widget.versionInfo;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.system_update_alt, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          const Text('EasyTier 核心更新', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本对比横幅
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前版本', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                      const SizedBox(height: 2),
                      Text(
                        'v${info.currentVersion}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.arrow_forward, size: 20, color: Colors.grey),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('最新版本', style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                      const SizedBox(height: 2),
                      Text(
                        'v${info.latestVersion}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (info.formattedSize.isNotEmpty)
                    Chip(
                      label: Text(info.formattedSize, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 更新状态或更新日志
            if (isUpdating) ...[
              const Text('正在自动下载与替换运行库，请勿关闭窗口...', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: provider.updateProgress > 0 ? provider.updateProgress : null,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                provider.updateStatusMessage,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline, fontFamily: 'monospace'),
              ),
            ] else if (_isSuccess) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('更新成功！', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                          const SizedBox(height: 2),
                          Text('内置 EasyTier 核心已升级至最新版本 v${provider.currentCoreVersion}。', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withAlpha(80)),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
              Text('更新日志 (Release Notes)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(40)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    info.releaseNotes.isEmpty ? '暂无详细更新说明。' : info.releaseNotes,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!isUpdating) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isSuccess ? '完成' : '稍后再说'),
          ),
          if (!_isSuccess)
            FilledButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('立即更新'),
              onPressed: _startUpdate,
            ),
        ],
      ],
    );
  }
}

