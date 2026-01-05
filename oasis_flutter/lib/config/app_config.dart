import 'package:flutter/material.dart';

/// 应用配置类
class AppConfig {
  // 应用信息
  static const String appName = 'Oasis';
  static const String appVersion = '2.0.0';
  static const String packageName = 'uno.skkk.oasis';
  
  // API 配置
  static const String apiBaseUrl = 'https://i.ilife798.com/';
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // HTTP 请求头配置
  static const Map<String, String> commonHeaders = {
    'Connection': 'keep-alive',
    'ApplicationType': '1,1',
    'Accept': '*/*',
    'User-Agent': 'Android_ilife798_2.0.11',
    'Accept-Language': 'zh-TW,zh-Hant;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'versioncode': '2.0.11',
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
  
  // 分页配置
  static const int pageSize = 20;
  
  // 缓存配置
  static const Duration cacheExpiry = Duration(hours: 24);
  
  // 调试模式
  static const bool isDebugMode = true; // 发布时设置为 false
}
