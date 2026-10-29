import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/core_version_info.dart';
import 'easytier_path_resolver.dart';
import 'storage_service.dart';

typedef UpdateProgressCallback = void Function(double progress, String status);

class EasyTierUpdaterService {
  static const String _releasesApiUrl =
      'https://api.github.com/repos/EasyTier/EasyTier/releases/latest';

  /// 获取本地核心的当前版本号 (如 "2.6.4")
  static Future<String> getLocalVersion({String? corePath}) async {
    try {
      final realPath =
          await EasyTierPathResolver.resolveCorePath(customPath: corePath);
      final file = File(realPath);
      if (!await file.exists()) {
        return '未安装';
      }

      final workDir = file.parent.path;
      final result = await Process.run(
        realPath,
        ['--version'],
        workingDirectory: workDir,
        runInShell: true,
      ).timeout(const Duration(seconds: 4));

      if (result.exitCode == 0) {
        final out = result.stdout.toString().trim();
        // 匹配版本号 (例如 "easytier-core 2.6.4-8428a89d" -> "2.6.4")
        final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(out);
        if (match != null) {
          return match.group(1)!;
        }
        return out;
      }
    } catch (_) {
      // 忽略检测失败异常
    }
    return '未知';
  }

  /// 检查 GitHub Releases 是否有新版本
  static Future<CoreVersionInfo> checkUpdate({String? customCorePath}) async {
    final currentVer = await getLocalVersion(corePath: customCorePath);

    final response = await http.get(
      Uri.parse(_releasesApiUrl),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'EasyTier-GUI-Client',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
          '无法连接到 GitHub Releases API (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name']?.toString() ?? '';
    final releaseTitle = data['name']?.toString() ?? tagName;
    final releaseNotes = data['body']?.toString() ?? '';
    final publishedAt = data['published_at']?.toString() ?? '';
    final assets = (data['assets'] as List<dynamic>?) ?? [];

    // 匹配当前操作系统的 Release Asset (Windows 64位)
    String downloadUrl = '';
    int downloadSize = 0;

    for (final asset in assets) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      if (Platform.isWindows) {
        if (name.contains('windows') &&
            (name.contains('x86_64') || name.contains('x64')) &&
            name.endsWith('.zip')) {
          downloadUrl = asset['browser_download_url']?.toString() ?? '';
          downloadSize = (asset['size'] as num?)?.toInt() ?? 0;
          break;
        }
      } else if (Platform.isMacOS) {
        if (name.contains('macos') || name.contains('darwin')) {
          downloadUrl = asset['browser_download_url']?.toString() ?? '';
          downloadSize = (asset['size'] as num?)?.toInt() ?? 0;
          break;
        }
      } else if (Platform.isLinux) {
        if (name.contains('linux') &&
            (name.contains('x86_64') || name.contains('x64'))) {
          downloadUrl = asset['browser_download_url']?.toString() ?? '';
          downloadSize = (asset['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }
    }

    final cleanLatest = tagName.replaceAll(RegExp(r'^[vV]'), '');
    final hasUpdate = CoreVersionInfo.isNewerVersion(currentVer, cleanLatest);

    return CoreVersionInfo(
      currentVersion: currentVer,
      latestVersion: cleanLatest,
      releaseTitle: releaseTitle,
      releaseNotes: releaseNotes,
      publishedAt: publishedAt,
      downloadUrl: downloadUrl,
      downloadSize: downloadSize,
      hasUpdate: hasUpdate,
    );
  }

  /// 下载最新 Release 压缩包并更新替换本地内置 bin 目录中的核心文件
  static Future<void> downloadAndInstallUpdate({
    required String downloadUrl,
    required UpdateProgressCallback onProgress,
    String? targetBinDir,
  }) async {
    if (downloadUrl.isEmpty) {
      throw Exception('未找到适配当前平台的安装包下载地址');
    }

    // 1. 确定安装目标目录 (优先使用传入路径或当前内置 bin/ 目录)
    String binDirPath = targetBinDir ?? '';
    if (binDirPath.isEmpty) {
      final builtinCore = await EasyTierPathResolver.findBuiltinCorePath();
      if (builtinCore != null) {
        binDirPath = File(builtinCore).parent.path;
      } else {
        // 回退到项目或应用目录下的 bin
        binDirPath = p.join(Directory.current.path, 'bin');
      }
    }

    final binDir = Directory(binDirPath);
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    // 2. 准备临时下载路径
    final dataDirectory = await StorageService.getDataDirectory();
    final updateDirectory = Directory(p.join(dataDirectory.path, 'updates'));
    await updateDirectory.create(recursive: true);
    final tempZipFile = File(
      p.join(
        updateDirectory.path,
        'easytier_update_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );

    final client = http.Client();
    try {
      onProgress(0.05, '正在建立连接...');
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'EasyTier-GUI-Client';
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('下载失败，服务器返回 HTTP ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;
      final fileSink = tempZipFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress =
              0.05 + (receivedBytes / totalBytes) * 0.70; // 5% ~ 75%
          final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          final pct = (progress * 100).toInt();
          onProgress(progress, '正在下载更新包 $receivedMb / $totalMb MB ($pct%)');
        } else {
          onProgress(0.4, '正在下载中...');
        }
      }
      await fileSink.flush();
      await fileSink.close();

      // 3. 解压缩
      onProgress(0.78, '正在解压更新包...');
      final zipBytes = await tempZipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      onProgress(0.85, '正在替换内置运行库与可执行文件...');
      for (final file in archive) {
        if (!file.isFile) continue;

        // 去除 zip 可能包含的顶层包裹文件夹名，仅保留文件名
        final fileName = p.basename(file.name);
        if (fileName.isEmpty) continue;

        final targetFilePath = p.join(binDirPath, fileName);
        final targetFile = File(targetFilePath);

        // 如果旧文件存在且被占用，尝试短延时重试
        int retry = 0;
        bool writeSuccess = false;
        while (retry < 3 && !writeSuccess) {
          try {
            await targetFile.writeAsBytes(file.content as List<int>,
                flush: true);
            writeSuccess = true;
          } catch (e) {
            retry++;
            if (retry >= 3) {
              throw Exception(
                  '写入 $fileName 失败，文件可能正在被系统占用，请确认 EasyTier 进程已退出: $e');
            }
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }

      onProgress(1.0, '核心更新完成！');
    } finally {
      client.close();
      // 清理临时文件
      if (await tempZipFile.exists()) {
        try {
          await tempZipFile.delete();
        } catch (_) {}
      }
    }
  }
}
