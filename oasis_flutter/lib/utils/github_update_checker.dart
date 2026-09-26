import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'github_mirror_config.dart';

/// 版本信息内部类
class _VersionInfo {
  final String version;
  final int versionCode;
  final String description;
  final String downloadUrl;
  final String htmlUrl;
  final String publishedAt;
  final bool isPrerelease;

  _VersionInfo({
    required this.version,
    required this.versionCode,
    required this.description,
    required this.downloadUrl,
    required this.htmlUrl,
    required this.publishedAt,
    required this.isPrerelease,
  });
}

/// 更新信息(UI显示用)
class UpdateInfo {
  final String tagName;
  final String body;
  final String htmlUrl;
  final String downloadUrl;
  final String publishedAt;

  UpdateInfo({
    required this.tagName,
    required this.body,
    required this.htmlUrl,
    required this.downloadUrl,
    required this.publishedAt,
  });
}

/// GitHub更新检查器 - 对应Kotlin的GitHubUpdateChecker
class GitHubUpdateChecker {
  static const String _repoPath = 'Kou-JunHao/Oasis-App';

  /// 检查更新
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      if (kDebugMode) {
        print('开始检查更新');
      }

      // 获取所有可用的镜像源
      final allMirrors = await GitHubMirrorConfig.getAllMirrors();
      final selectedMirror = await GitHubMirrorConfig.getSelectedMirror();
      
      // 将选中的镜像源放在第一位，其他的作为备用
      final mirrorList = [
        selectedMirror,
        ...allMirrors.where((m) => m.apiUrl != selectedMirror.apiUrl),
      ];

      _VersionInfo? latestVersionInfo;
      
      // 依次尝试每个镜像源
      for (final mirror in mirrorList) {
        final apiUrl = '${mirror.apiUrl}/repos/$_repoPath/releases/latest';
        
        if (kDebugMode) {
          print('尝试镜像源: ${mirror.name}');
          print('API地址: $apiUrl');
        }

        latestVersionInfo = await _getLatestVersionFromGitHub(apiUrl);
        
        if (latestVersionInfo != null) {
          if (kDebugMode) {
            print('成功从 ${mirror.name} 获取版本信息');
          }
          break; // 成功获取，跳出循环
        } else {
          if (kDebugMode) {
            print('从 ${mirror.name} 获取失败，尝试下一个镜像源');
          }
        }
      }
      
      if (latestVersionInfo == null) {
        if (kDebugMode) {
          print('所有镜像源均无法获取版本信息');
        }
        return null;
      }

      final currentVersion = await _getCurrentVersion();
      if (kDebugMode) {
        print('当前版本: $currentVersion, 最新版本: ${latestVersionInfo.version}');
      }

      if (isNewerVersion(currentVersion, latestVersionInfo.version)) {
        if (kDebugMode) {
          print('发现新版本: ${latestVersionInfo.version}');
        }
        return UpdateInfo(
          tagName: latestVersionInfo.version,
          body: latestVersionInfo.description,
          htmlUrl: latestVersionInfo.htmlUrl,
          downloadUrl: latestVersionInfo.downloadUrl,
          publishedAt: latestVersionInfo.publishedAt,
        );
      } else {
        if (kDebugMode) {
          print('当前已是最新版本');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('检查更新时发生错误: $e');
      }
      rethrow;
    }
  }

  /// 获取当前应用版本
  static Future<String> _getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      if (kDebugMode) {
        print('无法获取当前版本: $e');
      }
      return '1.0.0'; // 默认版本
    }
  }

  /// 从GitHub API获取最新版本信息
  static Future<_VersionInfo?> _getLatestVersionFromGitHub(String apiUrl) async {
    try {
      if (kDebugMode) {
        print('开始请求GitHub API: $apiUrl');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36',
          'sec-ch-ua': '"Chromium";v="143", "Not A(Brand)";v="24"',
          'sec-ch-ua-mobile': '?1',
          'sec-ch-ua-platform': '"Android"',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Sec-Fetch-User': '?1',
          'Upgrade-Insecure-Requests': '1',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('请求超时');
        },
      );

      if (kDebugMode) {
        print('GitHub API响应码: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        // 手动解码UTF-8，允许格式错误
        final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
        final jsonData = jsonDecode(bodyText);
        return await _parseVersionInfo(jsonData);
      } else {
        if (kDebugMode) {
          print('GitHub API请求失败，响应码: ${response.statusCode}');
          if (response.statusCode == 403) {
            try {
              final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
              final errorData = jsonDecode(bodyText);
              if (errorData['message'] != null) {
                print('错误信息: ${errorData['message']}');
              }
            } catch (e) {
              // 忽略JSON解析错误
            }
          }
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('请求GitHub API时发生错误: $e');
      }
      return null;
    }
  }

  /// 解析GitHub API返回的版本信息
  static Future<_VersionInfo?> _parseVersionInfo(Map<String, dynamic> json) async {
    try {
      final tagName = json['tag_name'] as String;
      final releaseName = json['name'] as String? ?? '';

      // 提取版本号
      String version;
      if (releaseName.contains(RegExp(r'[vV]?\d+\.\d+'))) {
        version = _extractVersionFromString(releaseName);
      } else if (tagName.contains(RegExp(r'[vV]?\d+\.\d+'))) {
        version = _extractVersionFromString(tagName);
      } else {
        version = tagName.replaceFirst('v', '').replaceFirst('V', '');
      }

      final description = json['body'] as String? ?? '';
      final htmlUrl = json['html_url'] as String;
      final publishedAt = json['published_at'] as String;
      final isPrerelease = json['prerelease'] as bool;

      // 获取设备架构并查找匹配的APK下载链接
      String downloadUrl = '';
      final assets = json['assets'] as List<dynamic>;
      
      if (Platform.isAndroid) {
        // 获取设备CPU架构
        final deviceAbi = await _getDeviceAbi();
        
        if (kDebugMode) {
          print('设备架构: $deviceAbi');
        }

        downloadUrl = pickApkUrlForAbi(assets, deviceAbi);
      } else {
        // 非Android平台，直接查找第一个APK
        for (final asset in assets) {
          final name = asset['name'] as String;
          if (name.toLowerCase().endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }
      }

      if (downloadUrl.isEmpty) {
        // 如果没有找到APK，使用Release页面链接
        downloadUrl = htmlUrl;
      }

      final versionCode = _extractVersionCode(version);

      if (kDebugMode) {
        print('解析版本信息成功: tag_name=$tagName, 提取的版本=$version');
      }

      return _VersionInfo(
        version: version,
        versionCode: versionCode,
        description: description,
        downloadUrl: downloadUrl,
        htmlUrl: htmlUrl,
        publishedAt: publishedAt,
        isPrerelease: isPrerelease,
      );
    } catch (e) {
      if (kDebugMode) {
        print('解析版本信息时发生错误: $e');
      }
      return null;
    }
  }

  /// 从字符串中提取版本号
  static String _extractVersionFromString(String input) {
    final versionRegex = RegExp(r'[vV]?(\d+\.\d+(?:\.\d+)?)');
    final match = versionRegex.firstMatch(input);
    return match?.group(1) ?? input.replaceFirst('v', '').replaceFirst('V', '');
  }

  /// 从版本字符串中提取版本代码
  static int _extractVersionCode(String version) {
    try {
      final cleanVersion = _extractVersionFromString(version);
      final parts = cleanVersion.split('.');

      int code = 0;
      for (int i = 0; i < parts.length && i < 3; i++) {
        final partValue = int.tryParse(parts[i]) ?? 0;
        code += partValue *
            (i == 0
                ? 10000 // 主版本号
                : i == 1
                    ? 100 // 次版本号
                    : 1); // 修订版本号
      }

      return code;
    } catch (e) {
      if (kDebugMode) {
        print('提取版本代码时发生错误: $e');
      }
      return 0;
    }
  }

  /// 比较版本号（[latestVersion] 是否比 [currentVersion] 新）
  @visibleForTesting
  static bool isNewerVersion(String currentVersion, String latestVersion) {
    try {
      final currentCode = _extractVersionCode(currentVersion);
      final latestCode = _extractVersionCode(latestVersion);

      if (kDebugMode) {
        print('版本比较: 当前版本代码=$currentCode, 最新版本代码=$latestCode');
      }

      return latestCode > currentCode;
    } catch (e) {
      if (kDebugMode) {
        print('版本比较时发生错误: $e');
      }
      return latestVersion != currentVersion;
    }
  }

  /// 打开下载页面
  static Future<void> openDownloadPage(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (kDebugMode) {
          print('打开下载页面: $url');
        }
      } else {
        throw Exception('无法打开URL: $url');
      }
    } catch (e) {
      if (kDebugMode) {
        print('无法打开下载页面: $e');
      }
      // 如果无法打开下载链接,尝试打开releases页面
      await openReleasePage();
    }
  }

  /// 打开GitHub releases页面
  static Future<void> openReleasePage() async {
    try {
      // 获取当前选中的镜像源
      final mirror = await GitHubMirrorConfig.getSelectedMirror();
      final releaseUrl = '${mirror.rawUrl}/$_repoPath/releases';
      
      final uri = Uri.parse(releaseUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (kDebugMode) {
          print('打开GitHub releases页面: $releaseUrl');
        }
      } else {
        throw Exception('无法打开GitHub releases页面');
      }
    } catch (e) {
      if (kDebugMode) {
        print('无法打开GitHub releases页面: $e');
      }
    }
  }

  /// 从 release 资产中挑选与设备架构匹配的 APK 下载地址（纯函数，便于测试）
  ///
  /// 依次尝试：精确匹配 `app-<abi>-release.apk` → 文件名包含架构标识 →
  /// universal/通用包 → 第一个 APK。返回空字符串表示没有可用的 APK。
  @visibleForTesting
  static String pickApkUrlForAbi(List<dynamic> assets, String deviceAbi) {
    String urlOf(dynamic asset) => asset['browser_download_url'] as String;
    String nameOf(dynamic asset) => (asset['name'] as String).toLowerCase();

    // 1) 精确匹配发布规范里的命名，避免 'x86' 命中 'x86_64' 这类子串误判
    final exactName = 'app-${deviceAbi.toLowerCase()}-release.apk';
    for (final asset in assets) {
      if (nameOf(asset) == exactName) {
        return urlOf(asset);
      }
    }

    // 2) 文件名包含架构标识
    for (final asset in assets) {
      final name = nameOf(asset);
      if (name.endsWith('.apk') && name.contains(deviceAbi.toLowerCase())) {
        return urlOf(asset);
      }
    }

    // 3) universal / 未标注架构的通用包
    for (final asset in assets) {
      final name = nameOf(asset);
      if (name.endsWith('.apk') &&
          (name.contains('universal') ||
              (!name.contains('arm') && !name.contains('x86')))) {
        return urlOf(asset);
      }
    }

    // 4) 兜底：第一个 APK
    for (final asset in assets) {
      if (nameOf(asset).endsWith('.apk')) {
        return urlOf(asset);
      }
    }

    return '';
  }

  /// 获取设备CPU架构
  ///
  /// 直接读取系统上报的 ABI 列表（已按优先级排序），不再用 Platform.version
  /// 字符串去猜：那种写法里 `contains('x64')` 会先命中第一分支、把 x86_64 设备
  /// 误判成 arm64-v8a，而 `contains('x86')` 又会命中 'x86_64'。
  static Future<String> _getDeviceAbi() async {
    if (!Platform.isAndroid) return 'unknown';

    // 与发布资产命名保持一致的四种架构
    const knownAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final abis = info.supportedAbis;

      if (kDebugMode) {
        print('系统上报的ABI列表: $abis');
      }

      for (final abi in abis) {
        if (knownAbis.contains(abi)) {
          return abi;
        }
      }
      if (abis.isNotEmpty) {
        return abis.first;
      }
    } catch (e) {
      if (kDebugMode) {
        print('获取设备架构失败: $e');
      }
    }

    // 兜底：绝大多数真机是 arm64
    return 'arm64-v8a';
  }
}
