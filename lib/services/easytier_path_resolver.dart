import 'dart:io';
import 'package:path/path.dart' as p;

/// EasyTier 核心及工具的可执行文件路径解析器
class EasyTierPathResolver {
  /// 获取当前解析到的 easytier-core 绝对路径
  /// [customPath] 用户在设置中自定义的路径
  static Future<String> resolveCorePath({String? customPath}) async {
    // 1. 如果用户自定义了有效路径，优先使用用户配置
    if (customPath != null &&
        customPath.trim().isNotEmpty &&
        customPath.trim() != 'builtin' &&
        customPath.trim() != 'easytier-core') {
      final customFile = File(customPath.trim());
      if (await customFile.exists()) {
        return customFile.path;
      }
    }

    // 2. 探测内置核心 (多种环境匹配)
    final builtinPath = await findBuiltinCorePath();
    if (builtinPath != null) {
      return builtinPath;
    }

    // 3. 回退为默认命令名称（依赖系统 PATH）
    return Platform.isWindows ? 'easytier-core.exe' : 'easytier-core';
  }

  /// 获取当前解析到的 easytier-cli 绝对路径
  static Future<String> resolveCliPath({String? customCorePath}) async {
    final core = await resolveCorePath(customPath: customCorePath);
    final coreDir = File(core).parent.path;
    final cliName = Platform.isWindows ? 'easytier-cli.exe' : 'easytier-cli';
    final cliFile = File(p.join(coreDir, cliName));
    if (await cliFile.exists()) {
      return cliFile.path;
    }
    return cliName;
  }

  /// 搜索内置的 easytier-core 路径
  static Future<String?> findBuiltinCorePath() async {
    final exeName = Platform.isWindows ? 'easytier-core.exe' : 'easytier-core';

    // 候选目录列表
    final List<String> candidatePaths = [];

    try {
      // 候选 1: 发布打包后，位于可执行文件同级的 bin 目录
      final appDir = File(Platform.resolvedExecutable).parent.path;
      candidatePaths.add(p.join(appDir, 'bin', exeName));
      candidatePaths.add(p.join(appDir, exeName));

      // 候选 2: 开发/调试时，在当前工作目录的 bin 目录 (VS Code 或命令行启动)
      final currentWorkDir = Directory.current.path;
      candidatePaths.add(p.join(currentWorkDir, 'bin', exeName));

      // 候选 3: 若在 build/windows/... 输出目录下运行，向上寻找到项目根目录下的 bin
      final parentDir = File(appDir).parent.path;
      candidatePaths.add(p.join(parentDir, 'bin', exeName));
      final rootDir = Directory(appDir).parent.parent.parent.parent.path;
      candidatePaths.add(p.join(rootDir, 'bin', exeName));
    } catch (_) {
      // 忽略平台路径获取异常
    }

    // 逐一检查文件是否存在
    for (final candidate in candidatePaths) {
      final file = File(candidate);
      if (await file.exists()) {
        return p.canonicalize(file.path);
      }
    }

    return null;
  }

  /// 检查是否成功定位到了内置核心
  static Future<bool> hasBuiltinCore() async {
    final path = await findBuiltinCorePath();
    return path != null;
  }
}
