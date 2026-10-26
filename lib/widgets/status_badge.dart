import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final bool isRunning;
  final bool isConnecting;

  const StatusBadge({
    super.key,
    required this.isRunning,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    if (isConnecting) {
      bg = Colors.amber.withAlpha(40);
      fg = Colors.amber.shade800;
      text = '正在连接...';
      icon = Icons.sync;
    } else if (isRunning) {
      bg = Colors.green.withAlpha(40);
      fg = Colors.green.shade700;
      text = '组网运行中';
      icon = Icons.check_circle_outline;
    } else {
      bg = Colors.grey.withAlpha(40);
      fg = Colors.grey.shade600;
      text = '未连接';
      icon = Icons.power_settings_new;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

