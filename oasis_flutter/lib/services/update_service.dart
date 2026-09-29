import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_globals.dart';
import '../utils/github_update_checker.dart';
import '../widgets/update_bottom_sheet.dart';

/// 检查结果
enum UpdateCheckOutcome {
  /// 发现新版本并已弹出更新面板
  updateAvailable,

  /// 已是最新版本
  upToDate,

  /// 检查失败（网络异常等）
  failed,
}

/// 应用更新服务
///
/// 负责「自动检查更新」开关的持久化，以及全局检查入口：
/// 发现新版本时把更新面板挂在根导航器上，因此在任何页面都能弹出，
/// 不再局限于登录页。
class UpdateService {
  UpdateService._();

  /// 自动检查开关的存储键
  static const String prefsKeyAutoCheck = 'auto_check_update';

  /// 是否开启自动检查更新（默认开启）
  static Future<bool> isAutoCheckEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKeyAutoCheck) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setAutoCheckEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKeyAutoCheck, enabled);
    } catch (e) {
      debugPrint('保存自动检查更新开关失败: $e');
    }
  }

  /// 启动后按开关自动检查一次（静默失败，不打扰用户）
  static Future<void> autoCheckOnStartup() async {
    if (!await isAutoCheckEnabled()) return;
    await checkAndShow();
  }

  /// 检查更新并按需弹出面板
  ///
  /// [manual] 为 true 时（用户主动点击）会在已是最新或失败时给出提示。
  static Future<UpdateCheckOutcome> checkAndShow({bool manual = false}) async {
    try {
      final info = await GitHubUpdateChecker.checkForUpdates();
      if (info == null) {
        if (manual) _toast('当前已是最新版本');
        return UpdateCheckOutcome.upToDate;
      }

      final context = appNavigatorKey.currentContext;
      if (context == null) {
        // 界面尚未就绪（极少见）
        return UpdateCheckOutcome.updateAvailable;
      }
      if (!context.mounted) return UpdateCheckOutcome.updateAvailable;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UpdateBottomSheet(updateInfo: info),
      );
      return UpdateCheckOutcome.updateAvailable;
    } catch (e) {
      debugPrint('检查更新失败: $e');
      if (manual) _toast('检查更新失败，请稍后重试');
      return UpdateCheckOutcome.failed;
    }
  }

  static void _toast(String message) {
    appScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
