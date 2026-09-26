import 'package:flutter/material.dart';

/// 应用配置类
class AppConfig {
  // 应用信息
  static const String appName = 'Oasis';
  static const String packageName = 'uno.skkk.oasis';

  // API 配置
  static const String apiBaseUrl = 'https://i.ilife798.com/';
  static const Duration apiTimeout = Duration(seconds: 30);

  // ==================== 伪装客户端版本号 ====================

  /// 原厂 App 在小米应用商店的详情页（伪装版本号的动态来源）
  static const String clientVersionSourceUrl =
      'https://app.mi.com/details?id=com.cloudora.android';

  /// 从详情页 HTML 中提取版本号的表达式
  static const String clientVersionPattern =
      r'版本号\s*</div>\s*<div[^>]*>\s*([0-9]+(?:\.[0-9]+){1,3})';

  /// 基线版本号：动态获取失败且本地无缓存、用户也未自定义时的最后兜底
  static const String baselineClientVersion = '3.1.9';

  /// 单次抓取的超时时间
  static const Duration clientVersionFetchTimeout = Duration(seconds: 5);

  /// 单次请求最多等待版本号解析多久，超时先用当前已知值，后台继续解析
  static const Duration clientVersionWaitTimeout = Duration(seconds: 2);

  /// 抓取失败后的冷却时间，避免离线时每个请求都触发一次抓取
  static const Duration clientVersionRetryCooldown = Duration(minutes: 10);

  /// 与版本号无关的固定请求头
  static const Map<String, String> baseHeaders = {
    'Connection': 'keep-alive',
    'ApplicationType': '1,1',
    'Accept': '*/*',
    'Accept-Language': 'zh-TW,zh-Hant;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
  };

  /// 组装完整请求头（伪装版本号由 [ClientVersionService] 在运行时决定）
  static Map<String, String> commonHeadersFor(String clientVersion) => {
        ...baseHeaders,
        'User-Agent': 'Android_ilife798_$clientVersion',
        'versioncode': clientVersion,
      };

  // 主题配置
  static const Color primaryColor = Color(0xFF4CAF50); // 绿色
  static const Color secondaryColor = Color(0xFF8BC34A); // 浅绿色

  // 数据库配置
  static const String databaseName = 'oasis.db';
  static const int databaseVersion = 1;

  // SharedPreferences 键名
  static const String keyThemeMode = 'theme_mode';
  static const String keyUseDynamicColor = 'use_dynamic_color';
  static const String keyUserToken = 'user_token';
  static const String keyUserId = 'user_id';

  /// 动态抓取到的伪装版本号缓存
  static const String keyClientVersion = 'spoof_client_version';

  /// 上次抓取成功的时间戳
  static const String keyClientVersionAt = 'spoof_client_version_at';

  /// 用户自定义的伪装版本号
  static const String keyCustomClientVersion = 'spoof_client_version_custom';

  // 分页配置
  static const int pageSize = 20;

  // 缓存配置
  static const Duration cacheExpiry = Duration(hours: 24);

  // 日志开关（按当前需求：release 保留日志）
  static const bool isDebugMode = true;
}
