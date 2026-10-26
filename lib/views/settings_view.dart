import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/easytier_provider.dart';
import '../services/easytier_process_service.dart';
import '../services/easytier_path_resolver.dart';
import '../widgets/update_dialog.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _corePathCtrl;
  String _coreStatusText = '';
  String _resolvedPathText = '';
  bool _isCheckingCore = false;
  bool _isUsingBuiltin = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<EasyTierProvider>().settings;
    _isUsingBuiltin = settings.coreExecutablePath == 'builtin';
    _corePathCtrl = TextEditingController(
      text: _isUsingBuiltin ? '' : settings.coreExecutablePath,
    );
    _checkCore(settings.coreExecutablePath);
  }

  Future<void> _checkCore(String path) async {
    setState(() {
      _isCheckingCore = true;
    });

    final realPath = await EasyTierPathResolver.resolveCorePath(
      customPath: _isUsingBuiltin ? null : path,
    );
    final available = await EasyTierProcessService.checkCoreAvailable(
      _isUsingBuiltin ? 'builtin' : path,
    );

    if (mounted) {
      context.read<EasyTierProvider>().refreshCurrentVersion();
      setState(() {
        _isCheckingCore = false;
        _resolvedPathText = realPath;
        if (available) {
          _coreStatusText = _isUsingBuiltin
              ? '已成功加载内置 EasyTier 运行库 (就绪)'
              : '自定义 EasyTier 核心可用 (就绪)';
        } else {
          _coreStatusText = '未检测到程序，请确认 .\\bin 目录下包含 easytier-core.exe 或指定自定义路径';
        }
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 easytier-core 可执行文件',
      type: FileType.custom,
      allowedExtensions: ['exe', ''],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _isUsingBuiltin = false;
        _corePathCtrl.text = path;
      });
      _updateCorePath(path);
      _checkCore(path);
    }
  }

  void _switchToBuiltin() {
    setState(() {
      _isUsingBuiltin = true;
      _corePathCtrl.text = '';
    });
    _updateCorePath('builtin');
    _checkCore('builtin');
  }

  void _updateCorePath(String path) {
    final provider = context.read<EasyTierProvider>();
    final settings = provider.settings..coreExecutablePath = path;
    provider.updateSettings(settings);
  }

  Future<void> _onCheckUpdatePressed() async {
    final provider = context.read<EasyTierProvider>();
    final info = await provider.checkForUpdates(silent: false);

    if (!mounted) return;

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查更新失败，请检查网络或稍后重试')),
      );
      return;
    }

    if (info.hasUpdate) {
      UpdateDialog.show(context, info);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('当前内置核心已是最新版本 (v${info.currentVersion})')),
      );
    }
  }

  @override
  void dispose() {
    _corePathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<EasyTierProvider>();
    final settings = provider.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '系统与客户端设置',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // 核心程序与自动更新卡片
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'EasyTier 核心运行库',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      if (provider.currentCoreVersion.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
                          ),
                          child: Text(
                            'v${provider.currentCoreVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      const Spacer(),
                      FilterChip(
                        selected: _isUsingBuiltin,
                        avatar: Icon(
                          _isUsingBuiltin ? Icons.check : Icons.all_inbox,
                          size: 16,
                          color: _isUsingBuiltin ? Colors.green : null,
                        ),
                        label: const Text('使用内置库 (.\\bin)'),
                        onSelected: (val) {
                          if (val) {
                            _switchToBuiltin();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '本项目已将 EasyTier 运行库（包含 easytier-core、wintun.dll、Packet.dll 等）内置于 .\\bin 目录中。',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  ),

                  // 发现新版本横幅
                  if (provider.hasUpdate && provider.versionInfo != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.new_releases, color: Colors.amber.shade800, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '发现 EasyTier 内核新版本: v${provider.versionInfo!.latestVersion}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '来自官方仓库 EasyTier/EasyTier，点击即可自动下载并替换内置库',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.upgrade, size: 18),
                            label: const Text('立即更新'),
                            onPressed: () => UpdateDialog.show(context, provider.versionInfo!),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  if (!_isUsingBuiltin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _corePathCtrl,
                            decoration: const InputDecoration(
                              labelText: '自定义可执行文件路径',
                              hintText: '输入外部 easytier-core.exe 完整路径',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.terminal),
                            ),
                            onSubmitted: (val) {
                              _updateCorePath(val.trim());
                              _checkCore(val.trim());
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open),
                          label: const Text('浏览...'),
                          onPressed: _pickFile,
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.restore),
                          label: const Text('恢复内置'),
                          onPressed: _switchToBuiltin,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 实际生效路径与检查更新操作栏
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(40)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('当前运行程序与版本：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                              icon: provider.isCheckingUpdate
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.system_update_alt, size: 16),
                              label: Text(provider.isCheckingUpdate ? '正在检查...' : '检查更新'),
                              onPressed: provider.isCheckingUpdate ? null : _onCheckUpdatePressed,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: _isCheckingCore
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                              tooltip: '重新探测本地文件',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _checkCore(_isUsingBuiltin ? 'builtin' : _corePathCtrl.text),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _resolvedPathText.isEmpty ? '探测中...' : _resolvedPathText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _coreStatusText.contains('就绪') ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 16,
                        color: _coreStatusText.contains('就绪') ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _coreStatusText,
                          style: TextStyle(
                            fontSize: 13,
                            color: _coreStatusText.contains('就绪') ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 个性化与行为
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('个性化与启动行为', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('主题外观'),
                    subtitle: const Text('切换明亮或暗黑模式'),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('系统')),
                        ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                        ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (set) {
                        final s = settings..themeMode = set.first;
                        provider.updateSettings(s);
                      },
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('客户端启动时自动组网'),
                    subtitle: const Text('打开本客户端后立即连接当前选中的网络'),
                    value: settings.autoStartCoreOnLaunch,
                    onChanged: (val) {
                      final s = settings..autoStartCoreOnLaunch = val;
                      provider.updateSettings(s);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 关于 EasyTier
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('关于 EasyTier', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('EasyTier 是一款基于 Rust 打造的简单、安全、去中心化的异地组网工具，全链路零拷贝与智能 P2P 穿透。'),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Text('官网与使用指南: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(
                        'https://easytier.cn/guide/introduction.html',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text('GitHub 官方仓库: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(
                        'https://github.com/EasyTier/EasyTier',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
