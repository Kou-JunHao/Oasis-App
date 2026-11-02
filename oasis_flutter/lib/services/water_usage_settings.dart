import 'package:shared_preferences/shared_preferences.dart';

import '../models/water_estimate.dart';

/// 预估水量设置的持久化。
///
/// 存储格式与 life798 保持一致的三元组：显示开关、基准金额、基准水量，
/// 但键名统一加上 `water_` 前缀，避免和项目里其他 SP 键冲突。
class WaterUsageSettings {
  static const String _keyVisible = 'water_estimate_visible';
  static const String _keyAmountYuan = 'water_estimate_amount_yuan';
  static const String _keyVolumeMl = 'water_estimate_volume_ml';

  static const WaterEstimate defaults = WaterEstimate();

  /// 读取设置。任何一项缺失或非法时回退到默认值。
  static Future<WaterEstimate> read() async {
    final prefs = await SharedPreferences.getInstance();
    final visible = prefs.getBool(_keyVisible) ?? defaults.visible;
    final amount = prefs.getDouble(_keyAmountYuan) ?? defaults.amountYuan;
    final volume = prefs.getDouble(_keyVolumeMl) ?? defaults.volumeMl;
    final estimate = WaterEstimate(
      visible: visible,
      amountYuan: amount,
      volumeMl: volume,
    );
    // 历史数据可能被写成 0 或负数，读出来时兜底
    return estimate.isValid ? estimate : defaults.copyWith(visible: visible);
  }

  /// 同步读取（供需要在 build 里立刻拿值的场景使用）。
  static WaterEstimate readSync(SharedPreferences prefs) {
    final visible = prefs.getBool(_keyVisible) ?? defaults.visible;
    final amount = prefs.getDouble(_keyAmountYuan) ?? defaults.amountYuan;
    final volume = prefs.getDouble(_keyVolumeMl) ?? defaults.volumeMl;
    final estimate = WaterEstimate(
      visible: visible,
      amountYuan: amount,
      volumeMl: volume,
    );
    return estimate.isValid ? estimate : defaults.copyWith(visible: visible);
  }

  /// 保存设置。只接受合法值，非法输入直接拒绝以免写进坏数据。
  static Future<bool> save(WaterEstimate estimate) async {
    if (!estimate.isValid) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVisible, estimate.visible);
    await prefs.setDouble(_keyAmountYuan, estimate.amountYuan);
    await prefs.setDouble(_keyVolumeMl, estimate.volumeMl);
    return true;
  }

  /// 恢复默认（0.16 元 ≈ 500 ml，显示打开）。
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVisible, defaults.visible);
    await prefs.setDouble(_keyAmountYuan, defaults.amountYuan);
    await prefs.setDouble(_keyVolumeMl, defaults.volumeMl);
  }
}
