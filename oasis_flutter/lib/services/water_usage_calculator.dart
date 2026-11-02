import '../models/score_models.dart';
import '../models/water_estimate.dart';

/// 把积分流水汇总成「今日 / 本月 / 今年」的用水量与花费。
///
/// 服务端不提供专门的用水统计接口：接水扣费混在积分流水里（type 105/107），
/// 金额单位是厘（1000 = 1 元），所以这里按记录时间分桶累加。
class WaterUsageCalculator {
  const WaterUsageCalculator._();

  /// 汇总最近的积分流水。
  ///
  /// [records] 至少要覆盖到今年；[now] 用于确定「今日/本月/今年」的边界。
  static WaterUsageSummary summarize(
    List<ScoreRecord> records, {
    required WaterEstimate estimate,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final monthStart = DateTime(today.year, today.month);
    final yearStart = DateTime(today.year);

    double todayYuan = 0;
    double monthYuan = 0;
    double yearYuan = 0;

    for (final record in records) {
      if (!record.isWaterConsumption) continue;
      final time = record.time;
      if (time == null) continue;
      if (time.isBefore(yearStart)) continue;

      final yuan = record.spentYuan;
      if (yuan <= 0) continue;

      yearYuan += yuan;
      if (!time.isBefore(monthStart)) {
        monthYuan += yuan;
        if (!time.isBefore(todayStart)) todayYuan += yuan;
      }
    }

    return WaterUsageSummary(
      todayYuan: todayYuan,
      monthYuan: monthYuan,
      yearYuan: yearYuan,
      todayMillilitres: estimate.millilitresForYuan(todayYuan),
      monthMillilitres: estimate.millilitresForYuan(monthYuan),
      yearMillilitres: estimate.millilitresForYuan(yearYuan),
    );
  }

  /// 汇总一屏能直接用的文案：「今日 约 970 ml」。
  static String todayText(WaterUsageSummary summary, WaterEstimate estimate) {
    if (estimate.millilitresForYuan(summary.todayYuan) <= 0) return '今日暂无用水';
    final millilitres = estimate.millilitresForYuan(summary.todayYuan);
    final money = '¥${summary.todayYuan.toStringAsFixed(2)}';
    return '今日 $money · 约 ${WaterEstimate.waterTextOf(millilitres)}';
  }
}
