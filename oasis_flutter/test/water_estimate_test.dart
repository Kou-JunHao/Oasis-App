import 'package:flutter_test/flutter_test.dart';
import 'package:oasis_flutter/models/score_models.dart';
import 'package:oasis_flutter/models/water_estimate.dart';
import 'package:oasis_flutter/services/water_usage_calculator.dart';

ScoreRecord consumption({
  required DateTime time,
  required int score,
  int type = 105,
}) {
  return ScoreRecord(
    time: time,
    score: -score,
    isIncome: false,
    title: '用户消费积分',
    type: type,
  );
}

ScoreRecord income({required DateTime time, required int score}) {
  return ScoreRecord(
    time: time,
    score: score,
    isIncome: true,
    title: '慧积分发放',
    type: 101,
  );
}

void main() {
  group('估算喝水量换算', () {
    test('默认比例 ¥0.16 = 500ml，¥1 折 3125ml', () {
      const estimate = WaterEstimate();
      expect(estimate.isValid, isTrue);
      expect(estimate.millilitresForYuan(0.16), 500.0);
      expect(estimate.millilitresForYuan(1.0), 3125.0);
    });

    test('积分按厘折算：100 积分 = ¥0.10', () {
      const estimate = WaterEstimate();
      expect(estimate.millilitresForScore(100), closeTo(312.5, 0.001));
    });

    test('文本格式：小于 1L 显示整数毫升（按 10 取整）', () {
      expect(WaterEstimate.waterTextOf(0), '--');
      expect(WaterEstimate.waterTextOf(312.5), '310 ml');
      expect(WaterEstimate.waterTextOf(5), '10 ml');
    });

    test('文本格式：大于等于 1L 显示一位小数的升', () {
      expect(WaterEstimate.waterTextOf(1000), '1.0 L');
      expect(WaterEstimate.waterTextOf(3125), '3.1 L');
    });

    test('自定义比例：¥1 = 1000ml 时 100 积分 = ¥0.1 = 100ml', () {
      const estimate = WaterEstimate(amountYuan: 1, volumeMl: 1000);
      expect(estimate.millilitresForScore(100), 100.0);
    });

    test('非法比例视为不可用，换算返回 0', () {
      const estimate = WaterEstimate(amountYuan: 0, volumeMl: 500);
      expect(estimate.isValid, isFalse);
      expect(estimate.mlPerYuan, 0);
      expect(estimate.millilitresForYuan(1), 0);
    });
  });

  group('接水消费记录识别', () {
    test('type 105 与 107 都算接水消费', () {
      final now = DateTime(2026, 11, 2, 10);
      expect(consumption(time: now, score: 100, type: 105).isWaterConsumption,
          isTrue);
      expect(consumption(time: now, score: 100, type: 107).isWaterConsumption,
          isTrue);
    });

    test('任务/签到收入不算消费', () {
      final now = DateTime(2026, 11, 2, 10);
      expect(income(time: now, score: 30).isWaterConsumption, isFalse);
    });

    test('消费记录的金额按厘折算', () {
      final now = DateTime(2026, 11, 2, 10);
      expect(consumption(time: now, score: 100).spentYuan, 0.1);
      expect(consumption(time: now, score: 2520).spentYuan, 2.52);
    });
  });

  group('用水汇总', () {
    const estimate = WaterEstimate();
    final now = DateTime(2026, 11, 2, 15, 30);

    test('按今日/本月/今年分桶累加', () {
      final records = [
        consumption(time: DateTime(2026, 11, 2, 9), score: 100),
        consumption(time: DateTime(2026, 11, 2, 12), score: 200),
        consumption(time: DateTime(2026, 11, 1, 12), score: 300),
        consumption(time: DateTime(2026, 5, 1, 12), score: 400),
      ];
      final summary = WaterUsageCalculator.summarize(
        records,
        estimate: estimate,
        now: now,
      );
      expect(summary.todayYuan, closeTo(0.3, 1e-9));
      expect(summary.monthYuan, closeTo(0.6, 1e-9));
      expect(summary.yearYuan, closeTo(1.0, 1e-9));
      expect(summary.todayMillilitres, closeTo(937.5, 0.001));
    });

    test('忽略去年的记录与收入记录', () {
      final records = [
        consumption(time: DateTime(2025, 12, 31, 23), score: 999),
        income(time: DateTime(2026, 11, 2, 9), score: 30),
      ];
      final summary = WaterUsageCalculator.summarize(
        records,
        estimate: estimate,
        now: now,
      );
      expect(summary.isEmpty, isTrue);
    });

    test('空列表安全返回', () {
      final summary = WaterUsageCalculator.summarize(
        const [],
        estimate: estimate,
        now: now,
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.todayMillilitres, 0);
      expect(WaterUsageCalculator.todayText(summary, estimate), '今日暂无用水');
    });

    test('今天的文案带金额与水量', () {
      final records = [consumption(time: DateTime(2026, 11, 2, 9), score: 100)];
      final summary = WaterUsageCalculator.summarize(
        records,
        estimate: estimate,
        now: now,
      );
      final text = WaterUsageCalculator.todayText(summary, estimate);
      expect(text.contains('0.10'), isTrue);
      expect(text.contains('ml'), isTrue);
    });
  });
}
