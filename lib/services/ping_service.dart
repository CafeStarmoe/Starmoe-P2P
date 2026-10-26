import 'dart:async';
import 'dart:io';

class PingResult {
  final String host;
  final int latencyMs;
  final bool isSuccess;
  final String rawOutput;

  const PingResult({
    required this.host,
    required this.latencyMs,
    required this.isSuccess,
    this.rawOutput = '',
  });
}

class PingService {
  /// 对指定 IP 或主机名执行 Ping
  static Future<PingResult> ping(String target, {int count = 2}) async {
    final host = target.replaceAll(RegExp(r'^(tcp|udp|wg|wss)://'), '').split(':').first;
    try {
      final isWindows = Platform.isWindows;
      final args = isWindows ? ['-n', '$count', host] : ['-c', '$count', host];

      final result = await Process.run('ping', args, runInShell: true)
          .timeout(const Duration(seconds: 4));

      final output = result.stdout.toString();
      final isSuccess = result.exitCode == 0;

      int latency = 0;
      if (isSuccess) {
        // 解析平均延迟：如 "Average = 25ms" 或 "min/avg/max = 12/25/30 ms"
        final match = RegExp(r'(?:Average|avg)[^\d]*(\d+)\s*ms', caseSensitive: false).firstMatch(output);
        if (match != null) {
          latency = int.tryParse(match.group(1) ?? '0') ?? 0;
        } else {
          // 备用：匹配任意 time=xx ms
          final timeMatch = RegExp(r'time[=<](\d+)\s*ms', caseSensitive: false).firstMatch(output);
          latency = int.tryParse(timeMatch?.group(1) ?? '20') ?? 20;
        }
      }

      return PingResult(
        host: host,
        latencyMs: latency,
        isSuccess: isSuccess,
        rawOutput: output,
      );
    } catch (e) {
      return PingResult(
        host: host,
        latencyMs: -1,
        isSuccess: false,
        rawOutput: 'Ping 失败: $e',
      );
    }
  }
}

