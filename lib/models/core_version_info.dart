/// EasyTier 核心版本及 GitHub Release 信息模型
class CoreVersionInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseTitle;
  final String releaseNotes;
  final String publishedAt;
  final String downloadUrl;
  final int downloadSize;
  final bool hasUpdate;

  const CoreVersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.publishedAt,
    required this.downloadUrl,
    required this.downloadSize,
    required this.hasUpdate,
  });

  /// 格式化文件大小
  String get formattedSize {
    if (downloadSize <= 0) return '';
    if (downloadSize < 1024 * 1024) {
      return '${(downloadSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(downloadSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 比较两个版本号字符串 (如 "2.6.4" vs "2.6.5", 支持带 "v" 前缀)
  static bool isNewerVersion(String current, String latest) {
    if (latest.isEmpty) return false;
    if (current.isEmpty || current == '未知') return true;

    final curClean = current.replaceAll(RegExp(r'^[vV]'), '').split('-').first.trim();
    final latClean = latest.replaceAll(RegExp(r'^[vV]'), '').split('-').first.trim();

    final curParts = curClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latParts = latClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 补齐长度
    while (curParts.length < latParts.length) {
      curParts.add(0);
    }
    while (latParts.length < curParts.length) {
      latParts.add(0);
    }

    for (int i = 0; i < latParts.length; i++) {
      if (latParts[i] > curParts[i]) return true;
      if (latParts[i] < curParts[i]) return false;
    }

    return false;
  }
}

