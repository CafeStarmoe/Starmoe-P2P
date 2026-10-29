import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/network_config.dart';
import '../providers/easytier_provider.dart';

class ConfigView extends StatefulWidget {
  const ConfigView({super.key});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _profileNameCtrl;
  late TextEditingController _networkNameCtrl;
  late TextEditingController _networkSecretCtrl;
  late TextEditingController _ipv4Ctrl;
  late TextEditingController _ipv6Ctrl;
  late TextEditingController _rpcPortCtrl;
  late TextEditingController _listenPortCtrl;
  late TextEditingController _additionalArgsCtrl;

  bool _useDhcp = true;
  List<String> _peers = [];
  List<String> _proxyNetworks = [];

  String? _currentEditingId;

  @override
  void initState() {
    super.initState();
    _profileNameCtrl = TextEditingController();
    _networkNameCtrl = TextEditingController();
    _networkSecretCtrl = TextEditingController();
    _ipv4Ctrl = TextEditingController();
    _ipv6Ctrl = TextEditingController();
    _rpcPortCtrl = TextEditingController();
    _listenPortCtrl = TextEditingController();
    _additionalArgsCtrl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EasyTierProvider>();
      if (provider.currentConfig != null) {
        _loadConfig(provider.currentConfig!);
      }
    });
  }

  void _loadConfig(NetworkConfig config) {
    setState(() {
      _currentEditingId = config.id;
      _profileNameCtrl.text = config.profileName;
      _networkNameCtrl.text = config.networkName;
      _networkSecretCtrl.text = config.networkSecret;
      _useDhcp = config.useDhcp;
      _ipv4Ctrl.text = config.ipv4;
      _ipv6Ctrl.text = config.ipv6;
      _peers = List.from(config.peers);
      _proxyNetworks = List.from(config.proxyNetworks);
      _rpcPortCtrl.text = config.rpcPort.toString();
      _listenPortCtrl.text = config.listenPort.toString();
      _additionalArgsCtrl.text = config.additionalArgs;
    });
  }

  NetworkConfig _buildCurrentConfig() {
    return NetworkConfig(
      id: _currentEditingId ?? 'cfg_${DateTime.now().millisecondsSinceEpoch}',
      profileName: _profileNameCtrl.text.trim(),
      networkName: _networkNameCtrl.text.trim(),
      networkSecret: _networkSecretCtrl.text.trim(),
      useDhcp: _useDhcp,
      ipv4: _ipv4Ctrl.text.trim(),
      ipv6: _ipv6Ctrl.text.trim(),
      peers: _peers,
      proxyNetworks: _proxyNetworks,
      rpcPort: int.tryParse(_rpcPortCtrl.text) ?? 15888,
      listenPort: int.tryParse(_listenPortCtrl.text) ?? 11010,
      additionalArgs: _additionalArgsCtrl.text.trim(),
    );
  }

  void _saveCurrentConfig() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<EasyTierProvider>();
    final config = _buildCurrentConfig();

    provider.saveConfig(config);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('配置 [${config.profileName}] 已保存！')),
    );
  }

  /// 导入原版 config.yaml
  Future<void> _importYamlConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择 EasyTier 配置文件 (config.yaml / *.yml)',
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml', 'toml'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final fileName = result.files.single.name;

        final newConfig = NetworkConfig.fromYaml(
          content,
          defaultName: fileName.replaceAll(RegExp(r'\.(yaml|yml|toml)$'), ''),
        );

        if (!mounted) return;
        final provider = context.read<EasyTierProvider>();
        await provider.saveConfig(newConfig);
        _loadConfig(newConfig);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入配置文件: $fileName')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入配置文件失败: $e')),
      );
    }
  }

  /// 导出当前配置为 config.yaml 文件
  Future<void> _exportYamlConfig() async {
    try {
      final config = _buildCurrentConfig();
      final yamlContent = config.toYaml();

      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出为 EasyTier 配置文件',
        fileName: 'config.yaml',
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(yamlContent);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功导出配置文件至: $outputFile')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  /// 弹窗预览与复制 YAML 配置
  void _showYamlPreview() {
    final config = _buildCurrentConfig();
    final yaml = config.toYaml();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description_outlined),
            SizedBox(width: 8),
            Text('原版 config.yaml 预览'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              yaml,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('保存为文件'),
            onPressed: () {
              Navigator.pop(ctx);
              _exportYamlConfig();
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制配置文本'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: yaml));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制 config.yaml 内容到剪贴板')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _addPeerDialog() {
    final ctrl = TextEditingController(text: 'tcp://public.easytier.cn:11010');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加对等节点 (Peer)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入对等节点 URI，格式如: tcp://ip:port 或 udp://ip:port'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: '节点地址',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _peers.add(ctrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _addProxyNetworkDialog() {
    final ctrl = TextEditingController(text: '192.168.1.0/24');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加子网代理 (Subnet Proxy)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将本地局域网段发布给房间中的其他对等节点使用，CIDR 格式：'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: '网段 CIDR (例: 192.168.1.0/24)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _proxyNetworks.add(ctrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _profileNameCtrl.dispose();
    _networkNameCtrl.dispose();
    _networkSecretCtrl.dispose();
    _ipv4Ctrl.dispose();
    _ipv6Ctrl.dispose();
    _rpcPortCtrl.dispose();
    _listenPortCtrl.dispose();
    _additionalArgsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EasyTierProvider>();
    final theme = Theme.of(context);

    return Row(
      children: [
        // 左侧：配置列表
        Container(
          width: 270,
          decoration: BoxDecoration(
            border: Border(
                right: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(50))),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text('Easytier 配置',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    // IconButton(
                    //   icon: const Icon(Icons.file_upload_outlined),
                    //   tooltip: '导入 config.yaml 配置文件',
                    //   onPressed: _importYamlConfig,
                    // ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: '新建配置',
                      onPressed: () {
                        final newCfg = NetworkConfig.createDefault(
                            name: '新建_${provider.configs.length + 1}');
                        provider.saveConfig(newCfg);
                        _loadConfig(newCfg);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.configs.length,
                  itemBuilder: (ctx, i) {
                    final cfg = provider.configs[i];
                    final isSelected = cfg.id == _currentEditingId;
                    final isRunningThis = provider.isRunning &&
                        provider.currentConfig?.id == cfg.id;

                    return ListTile(
                      selected: isSelected,
                      title: Text(cfg.profileName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        cfg.networkName.isEmpty ? '未配置房间/用户名' : cfg.networkName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      leading: Icon(
                        isRunningThis
                            ? Icons.radio_button_checked
                            : Icons.sports_esports_outlined,
                        color: isRunningThis ? Colors.green : null,
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (val) {
                          if (val == 'clone') {
                            final cloned = cfg.clone();
                            provider.saveConfig(cloned);
                            _loadConfig(cloned);
                          } else if (val == 'export') {
                            _exportYamlConfig();
                          } else if (val == 'delete') {
                            if (provider.configs.length > 1) {
                              provider.deleteConfig(cfg.id);
                              if (_currentEditingId == cfg.id) {
                                _loadConfig(provider.configs.first);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('至少需要保留一份配置')),
                              );
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                              value: 'clone', child: Text('克隆副本')),
                          const PopupMenuItem(
                              value: 'export', child: Text('导出为 YAML')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('删除配置')),
                        ],
                      ),
                      onTap: () {
                        provider.selectConfig(cfg);
                        _loadConfig(cfg);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 右侧：编辑表单
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '编辑配置',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('导入 YAML'),
                        onPressed: _importYamlConfig,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('导出 YAML'),
                        onPressed: _exportYamlConfig,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.code),
                        label: const Text('查看 YAML'),
                        onPressed: _showYamlPreview,
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('保存修改'),
                        onPressed: _saveCurrentConfig,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 基础配置
                  Card(
                    elevation: 0,
                    color:
                        theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color:
                              theme.colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Easytier 基础参数',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _profileNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '配置别名',
                                    hintText: '如: 幻兽帕鲁联机 / 我的世界开黑',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => v!.isEmpty ? '请输入别名' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _networkNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '房间 (network-name)',
                                    hintText: '对等节点需要进入相同房间才能互相连接',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? '请输入房间名' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _networkSecretCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '房间密码 (network-secret)',
                              hintText: '留空则不设密码',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // IP 规划
                  Card(
                    elevation: 0,
                    color:
                        theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color:
                              theme.colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('虚拟局域网 IP 与 DHCP',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title:
                                const Text('启用 DHCP 自动分配局域网 IP (-d, --dhcp)'),
                            subtitle:
                                const Text('由 EasyTier 自动向房间内各节点分配不冲突的虚拟 IP'),
                            value: _useDhcp,
                            onChanged: (val) => setState(() => _useDhcp = val),
                          ),
                          if (!_useDhcp) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _ipv4Ctrl,
                                    decoration: const InputDecoration(
                                      labelText: '静态局域网 IPv4 (-i, --ipv4)',
                                      hintText: '例: 10.144.144.1',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _ipv6Ctrl,
                                    decoration: const InputDecoration(
                                      labelText: '静态局域网 IPv6 (--ipv6)',
                                      hintText: '可选',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 对等节点 (Peers)
                  Card(
                    elevation: 0,
                    color:
                        theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color:
                              theme.colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('节点与中继 (-p, --peers)',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('用于初始连接打通或中继协助的节点地址',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('添加节点'),
                                onPressed: _addPeerDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_peers.isEmpty)
                            const Text('暂无节点，点击上方按钮添加',
                                style: TextStyle(color: Colors.grey))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _peers.map((peer) {
                                return Chip(
                                  avatar: const Icon(Icons.link, size: 16),
                                  label: Text(peer),
                                  onDeleted: () =>
                                      setState(() => _peers.remove(peer)),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 子网代理
                  Card(
                    elevation: 0,
                    color:
                        theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color:
                              theme.colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('子网代理 (-n, --proxy-networks)',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('导出本地网段到虚拟网，使其他节点可访问本地设备',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('添加网段'),
                                onPressed: _addProxyNetworkDialog,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_proxyNetworks.isEmpty)
                            const Text('未配置子网代理',
                                style: TextStyle(color: Colors.grey))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _proxyNetworks.map((proxy) {
                                return Chip(
                                  avatar: const Icon(Icons.alt_route, size: 16),
                                  label: Text(proxy),
                                  onDeleted: () => setState(
                                      () => _proxyNetworks.remove(proxy)),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 端口与高级参数
                  Card(
                    elevation: 0,
                    color:
                        theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color:
                              theme.colorScheme.outlineVariant.withAlpha(50)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('端口与高级选项',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _rpcPortCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'RPC 监听端口 (--rpc-portal)',
                                    hintText: '默认 15888',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _listenPortCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'P2P 监听端口 (--listeners)',
                                    hintText: '默认 11010',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _additionalArgsCtrl,
                            decoration: const InputDecoration(
                              labelText: '附加启动参数',
                              hintText: '例: --multi-thread --no-tun 等',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
