import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../providers/easytier_provider.dart';

class RoomsView extends StatefulWidget {
  const RoomsView({super.key});

  @override
  State<RoomsView> createState() => _RoomsViewState();
}

class _RoomsViewState extends State<RoomsView> {
  RoomCategory? _selectedCategory;

  IconData _getCategoryIcon(RoomCategory category) {
    switch (category) {
      case RoomCategory.gaming:
        return Icons.sports_esports;
      case RoomCategory.voip:
        return Icons.headset_mic;
      case RoomCategory.office:
        return Icons.laptop_chromebook;
      case RoomCategory.fileShare:
        return Icons.folder_shared;
      case RoomCategory.custom:
        return Icons.tune;
    }
  }

  /// 弹出新建开黑房间对话框
  void _showCreateRoomDialog() {
    final nameCtrl = TextEditingController(text: '我的房间');
    final descCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    RoomCategory selectedCat = RoomCategory.gaming;
    bool enableUdpBroadcast = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.meeting_room_outlined),
                SizedBox(width: 8),
                Text('创建房间', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('房间名称：',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        hintText: '如：幻兽帕鲁服务器、泰拉瑞亚开黑、求生之路2',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.drive_file_rename_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('游戏类型 / 场景：',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: RoomCategory.values.map((cat) {
                        final isSel = selectedCat == cat;
                        return ChoiceChip(
                          avatar: Icon(_getCategoryIcon(cat), size: 16),
                          label: Text(cat.label),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedCat = cat;
                                if (cat == RoomCategory.gaming) {
                                  enableUdpBroadcast = true;
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedCat.description,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('房间密码 (留空则自动生成口令)：',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: secretCtrl,
                      decoration: const InputDecoration(
                        hintText: '队友需要输入此密码或使用口令进入房间',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enableUdpBroadcast,
                      title: const Text('启用局域网广播转发 (强烈建议)',
                          style: TextStyle(fontSize: 14)),
                      subtitle: const Text(
                          '开启后游戏自带的“局域网联机搜寻”(如 Minecraft、求生之路) 可直接搜到房间',
                          style: TextStyle(fontSize: 11)),
                      onChanged: (val) => setDialogState(
                          () => enableUdpBroadcast = val ?? true),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('创建房间'),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  final newRoom = Room.create(
                    name: name,
                    description: descCtrl.text.trim(),
                    category: selectedCat,
                    customSecret: secretCtrl.text.trim().isNotEmpty
                        ? secretCtrl.text.trim()
                        : null,
                    enableUdpBroadcast: enableUdpBroadcast,
                  );

                  context.read<EasyTierProvider>().saveRoom(newRoom);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('房间「$name」创建成功！')),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJoinRoomDialog() {
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.input_rounded),
            SizedBox(width: 8),
            Text('加入房间', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('粘贴房主分享给你的口令：'),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'easytier://room?data=...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            child: const Text('立即加入'),
            onPressed: () {
              final raw = codeCtrl.text.trim();
              final room = Room.fromShareCode(raw);
              if (room == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('口令格式无效，请确认复制了完整的口令')),
                );
                return;
              }
              context.read<EasyTierProvider>().saveRoom(room);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('成功加入房间「${room.name}」！')),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 显示房间分享口令
  void _showShareDialog(Room room) {
    final code = room.toShareCode();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(_getCategoryIcon(room.category),
                color: Color(room.category.colorValue)),
            const SizedBox(width: 8),
            Text('邀请好友加入「${room.name}」'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('将下方口令发送给好友，对方在客户端点击「加入房间」即可加入对方房间：'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  code,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制口令'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('口令已复制到剪贴板！')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EasyTierProvider>();
    final theme = Theme.of(context);

    final filteredRooms = provider.rooms.where((r) {
      if (_selectedCategory == null) return true;
      return r.category == _selectedCategory;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题与功能操作栏
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '房间大厅',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '创建房间或粘贴好友口令',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.input_rounded),
                label: const Text('加入房间'),
                onPressed: _showJoinRoomDialog,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('创建房间'),
                onPressed: _showCreateRoomDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 场景分类标签过滤
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('全部游戏/场景'),
                  selected: _selectedCategory == null,
                  onSelected: (val) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...RoomCategory.values.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(_getCategoryIcon(cat), size: 16),
                      label: Text(cat.label),
                      selected: _selectedCategory == cat,
                      onSelected: (val) =>
                          setState(() => _selectedCategory = val ? cat : null),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 房间列表
          Expanded(
            child: filteredRooms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('暂无此分类的房间', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        const Text('点击右上角「创建房间」即可创建你的专属房间'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      final room = filteredRooms[index];
                      final isConnectedCurrent = provider.isRunning &&
                          provider.currentRoom?.id == room.id;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isConnectedCurrent
                                ? theme.colorScheme.primary.withAlpha(120)
                                : theme.colorScheme.outlineVariant
                                    .withAlpha(50),
                            width: isConnectedCurrent ? 2 : 1,
                          ),
                        ),
                        color: isConnectedCurrent
                            ? theme.colorScheme.primaryContainer.withAlpha(30)
                            : theme.colorScheme.surfaceContainerHighest
                                .withAlpha(40),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // 场景图标徽章
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(room.category.colorValue)
                                    .withAlpha(30),
                                child: Icon(
                                  _getCategoryIcon(room.category),
                                  color: Color(room.category.colorValue),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // 房间信息
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          room.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color:
                                                Color(room.category.colorValue)
                                                    .withAlpha(20),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Color(room
                                                        .category.colorValue)
                                                    .withAlpha(60)),
                                          ),
                                          child: Text(
                                            room.category.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(
                                                  room.category.colorValue),
                                            ),
                                          ),
                                        ),
                                        if (room.enableUdpBroadcast) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withAlpha(20),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text('广播转发已开启',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '房间代码: ${room.networkName}  |  进房口令: ${room.networkSecret}',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                    if (room.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        room.description,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // 操作按钮群
                              IconButton(
                                icon: const Icon(Icons.share_outlined),
                                tooltip: '分享口令',
                                onPressed: () => _showShareDialog(room),
                              ),
                              PopupMenuButton<String>(
                                tooltip: '更多操作',
                                onSelected: (action) {
                                  if (action == 'delete') {
                                    provider.deleteRoom(room.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('已删除房间「${room.name}」')),
                                    );
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('删除房间',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),

                              // 房间连接状态与连接按钮
                              if (isConnectedCurrent)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.redAccent),
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: const Text('退出房间'),
                                  onPressed: () => provider.leaveRoom(),
                                )
                              else
                                FilledButton.icon(
                                  icon: const Icon(Icons.login, size: 18),
                                  label: const Text('进入房间'),
                                  onPressed: () =>
                                      provider.joinAndConnectRoom(room),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
