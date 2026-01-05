import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

/// GitHub镜像源配置管理
class GitHubMirrorConfig {
  static const String _keySelectedMirror = 'github_mirror_selected';
  static const String _keyCustomMirrors = 'github_mirror_custom';

  /// 预设的GitHub镜像源
  static final List<GitHubMirror> presetMirrors = [
    GitHubMirror(
      name: 'GitHub官方',
      apiUrl: 'https://api.github.com',
      rawUrl: 'https://github.com',
      description: '官方源，稳定可靠',
    ),
    GitHubMirror(
      name: 'gh-proxy.org',
      apiUrl: 'https://gh-proxy.org/https://api.github.com',
      rawUrl: 'https://gh-proxy.org/https://github.com',
      description: 'gh-proxy 镜像（国内备用）',
    ),
  ];

  /// 测试镜像源连通性
  static Future<bool> testMirrorConnectivity(String apiUrl) async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 16.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36',
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
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('连接超时'),
      );
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前选中的镜像源
  static Future<GitHubMirror> getSelectedMirror() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedIndex = prefs.getInt(_keySelectedMirror) ?? 0;
    
    // 获取自定义镜像源
    final customMirrors = await getCustomMirrors();
    final allMirrors = [...presetMirrors, ...customMirrors];
    
    if (selectedIndex >= 0 && selectedIndex < allMirrors.length) {
      return allMirrors[selectedIndex];
    }
    
    return presetMirrors[0];
  }

  /// 设置当前选中的镜像源
  static Future<void> setSelectedMirror(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySelectedMirror, index);
  }

  /// 获取所有镜像源（预设+自定义）
  static Future<List<GitHubMirror>> getAllMirrors() async {
    final customMirrors = await getCustomMirrors();
    return [...presetMirrors, ...customMirrors];
  }

  /// 获取自定义镜像源
  static Future<List<GitHubMirror>> getCustomMirrors() async {
    final prefs = await SharedPreferences.getInstance();
    final customJson = prefs.getStringList(_keyCustomMirrors) ?? [];
    
    return customJson.map((json) {
      final parts = json.split('|||');
      if (parts.length >= 3) {
        return GitHubMirror(
          name: parts[0],
          apiUrl: parts[1],
          rawUrl: parts[2],
          description: parts.length > 3 ? parts[3] : '',
        );
      }
      return null;
    }).whereType<GitHubMirror>().toList();
  }

  /// 添加自定义镜像源
  static Future<void> addCustomMirror(GitHubMirror mirror) async {
    final prefs = await SharedPreferences.getInstance();
    final customJson = prefs.getStringList(_keyCustomMirrors) ?? [];
    
    final mirrorString = '${mirror.name}|||${mirror.apiUrl}|||${mirror.rawUrl}|||${mirror.description}';
    customJson.add(mirrorString);
    
    await prefs.setStringList(_keyCustomMirrors, customJson);
  }

  /// 删除自定义镜像源
  static Future<void> removeCustomMirror(int customIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final customJson = prefs.getStringList(_keyCustomMirrors) ?? [];
    
    if (customIndex >= 0 && customIndex < customJson.length) {
      customJson.removeAt(customIndex);
      await prefs.setStringList(_keyCustomMirrors, customJson);
    }
  }
}

/// GitHub镜像源数据模型
class GitHubMirror {
  final String name;
  final String apiUrl;
  final String rawUrl;
  final String description;

  GitHubMirror({
    required this.name,
    required this.apiUrl,
    required this.rawUrl,
    this.description = '',
  });
}
