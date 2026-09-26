import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// 伪装版本号的当前状态（供设置页展示）
class ClientVersionStatus {
  /// 当前实际生效、会被写进请求头的版本号
  final String version;

  /// 取值来源：custom / remote / cache / baseline
  final String source;

  const ClientVersionStatus(this.version, this.source);

  /// 取值来源的中文说明
  String get sourceLabel => switch (source) {
    'custom' => '用户自定义',
    'remote' => '已从原厂商店获取最新',
    'cache' => '本地缓存',
    _ => '内置基线',
  };
}

/// 伪装客户端版本号服务
///
/// 请求头 `versioncode` / `User-Agent` 需要冒充原厂客户端版本号，取值优先级：
///   1. **用户自定义**（设置页手动指定，最高优先级，此时不再抓取）；
///   2. **动态抓取**（启动后从原厂应用商店详情页拿到的最新版本号，抓到就用）；
///   3. **落盘缓存**（上次抓取成功的结果，过期也照用）；
///   4. **内置基线**（[AppConfig.baselineClientVersion]，全新安装且离线时的兜底）。
///
/// 全程静默降级：任何异常都不会抛到业务层，单次请求等待解析也不会超过
/// [AppConfig.clientVersionWaitTimeout]。
class ClientVersionService {
  ClientVersionService._();

  /// 当前生效的伪装版本号（同步读取，随时可用，永不抛异常）
  static String get current => _effective;

  /// 版本号状态变化通知（设置页监听它刷新显示）
  static final ValueNotifier<ClientVersionStatus> statusNotifier =
      ValueNotifier<ClientVersionStatus>(
        const ClientVersionStatus(AppConfig.baselineClientVersion, 'baseline'),
      );

  static String? _custom; // 用户自定义
  static String? _remote; // 动态抓取
  static String? _cache; // 落盘缓存

  static Future<String>? _inflight;
  static bool _fetchedThisProcess = false;
  static bool _prefsLoaded = false;
  static bool _customTouchedByUser = false;
  static DateTime? _nextAttemptAt;

  static String get _effective =>
      _custom ?? _remote ?? _cache ?? AppConfig.baselineClientVersion;

  static String get _source {
    if (_custom != null) return 'custom';
    if (_remote != null) return 'remote';
    if (_cache != null) return 'cache';
    return 'baseline';
  }

  /// 当前是否使用用户自定义版本号
  static bool get hasCustomVersion => _custom != null;

  /// 当前是否已成功从线上抓取过
  static bool get hasRemoteVersion => _remote != null;

  /// 仅供测试：替换线上抓取实现（返回 null 表示抓取失败）
  @visibleForTesting
  static Future<String?> Function()? htmlFetcherForTest;

  /// 仅供测试：重置进程内状态
  @visibleForTesting
  static void resetForTest() {
    _custom = null;
    _remote = null;
    _cache = null;
    _inflight = null;
    _fetchedThisProcess = false;
    _prefsLoaded = false;
    _customTouchedByUser = false;
    _nextAttemptAt = null;
    htmlFetcherForTest = null;
    _publish();
  }

  /// 校验版本号格式：x.y 或 x.y.z
  static bool isValidVersion(String version) {
    if (version.length > 24) return false;
    return RegExp(r'^\d+\.\d+(\.\d+)?$').hasMatch(version);
  }

  /// 从原厂应用商店详情页 HTML 中解析版本号（纯函数，便于测试）
  static String? parseVersionFromHtml(String html) {
    final match = RegExp(AppConfig.clientVersionPattern).firstMatch(html);
    final version = match?.group(1);
    if (version == null || !isValidVersion(version)) return null;
    return version;
  }

  /// 解析版本号；并发调用共享同一个 Future。
  /// 用户自定义时直接返回自定义值，不产生任何网络请求。
  static Future<String> resolve() {
    if (_custom != null) return Future.value(_custom!);
    if (_fetchedThisProcess) return Future.value(_effective);
    if (_nextAttemptAt != null && DateTime.now().isBefore(_nextAttemptAt!)) {
      // 抓取失败冷却中，先用当前已知值，避免离线时每个请求都发起抓取
      return Future.value(_effective);
    }
    return _inflight ??= _resolve().whenComplete(() => _inflight = null);
  }

  /// 带超时的解析：超时返回当前已知值，后台继续解析（不阻塞业务请求）
  static Future<String> resolveBounded([Duration? timeout]) async {
    try {
      return await resolve().timeout(
        timeout ?? AppConfig.clientVersionWaitTimeout,
        onTimeout: () => _effective,
      );
    } catch (e) {
      _log('解析版本号异常: $e');
      return _effective;
    }
  }

  /// 设置用户自定义版本号（写入本地并立即生效）
  static Future<void> setCustomVersion(String version) async {
    final value = version.trim();
    if (!isValidVersion(value)) {
      _log('拒绝非法自定义版本号: $value');
      return;
    }
    _custom = value;
    _customTouchedByUser = true;
    _publish();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.keyCustomClientVersion, value);
    } catch (e) {
      _log('保存自定义版本号失败: $e');
    }
    _log('用户自定义伪装版本号: $value');
  }

  /// 取消自定义，恢复"动态获取 → 缓存 → 基线"链路
  static Future<void> clearCustomVersion() async {
    _custom = null;
    _customTouchedByUser = true;
    _publish();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConfig.keyCustomClientVersion);
    } catch (e) {
      _log('清除自定义版本号失败: $e');
    }
    _log('已取消自定义伪装版本号，当前值: $_effective ($_source)');
    // 自定义期间跳过了抓取，这里补一次（失败会自动降级）
    unawaited(resolve());
  }

  static Future<String> _resolve() async {
    // 1) 先读本地：自定义值 + 上次抓取的缓存，保证抓取完成前也有值可用
    await _loadPrefs();
    if (_custom != null) return _custom!;

    // 2) 抓取原厂最新版本号
    try {
      final html = await (htmlFetcherForTest?.call() ?? _fetchHtml());

      if (html != null) {
        final version = parseVersionFromHtml(html);
        if (version != null) {
          _remote = version;
          _fetchedThisProcess = true;
          _nextAttemptAt = null;
          _publish();
          await _saveCache(version);
          _log('动态获取到原厂客户端版本号: $version');
          return _effective;
        }
        _log('详情页未匹配到版本号，沿用 $_source 值: $_effective');
      } else {
        _log('详情页抓取失败，沿用 $_source 值: $_effective');
      }
    } catch (e) {
      _log('抓取版本号失败: $e，沿用 $_source 值: $_effective');
    }

    // 3) 抓取失败：进入冷却，避免离线时反复重试
    _nextAttemptAt = DateTime.now().add(AppConfig.clientVersionRetryCooldown);
    _publish();
    return _effective;
  }

  /// 抓取原厂应用商店详情页 HTML，失败返回 null
  static Future<String?> _fetchHtml() async {
    final response = await http
        .get(Uri.parse(AppConfig.clientVersionSourceUrl))
        .timeout(AppConfig.clientVersionFetchTimeout);
    if (response.statusCode != 200) {
      _log('详情页响应异常 HTTP ${response.statusCode}');
      return null;
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static Future<void> _loadPrefs() async {
    if (_prefsLoaded) return;
    _prefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      final cached = prefs.getString(AppConfig.keyClientVersion);
      if (cached != null && isValidVersion(cached)) {
        _cache = cached;
      }

      if (!_customTouchedByUser) {
        final custom = prefs.getString(AppConfig.keyCustomClientVersion);
        if (custom != null && isValidVersion(custom)) {
          _custom = custom;
        }
      }

      _log('本地读取完成：自定义=${_custom ?? "无"}, 缓存=${_cache ?? "无"}');
      _publish();
    } catch (e) {
      _log('读取本地版本号配置失败: $e');
    }
  }

  static Future<void> _saveCache(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.keyClientVersion, version);
      await prefs.setInt(
        AppConfig.keyClientVersionAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _log('写入版本号缓存失败: $e');
    }
  }

  static void _publish() {
    statusNotifier.value = ClientVersionStatus(_effective, _source);
  }

  static void _log(String message) {
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('[伪装版本号] $message');
    }
  }
}
