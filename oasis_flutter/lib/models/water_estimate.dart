/// 积分与水量之间的换算比例。
///
/// 服务端并不直接下发「本次接了多少毫升」，只下发花费金额（积分，单位为厘）。
/// 这里按用户设置的比例把金额折算成水量：`volumeMl / amountYuan` 即「每元多少毫升」。
///
/// 默认 0.16 元 ≈ 500 ml（校园直饮水常见定价），与 life798 的默认值一致。
class WaterEstimate {
  /// 是否在界面上显示预估水量
  final bool visible;

  /// 换算基准金额（元）
  final double amountYuan;

  /// 换算基准水量（毫升）
  final double volumeMl;

  const WaterEstimate({
    this.visible = true,
    this.amountYuan = defaultAmountYuan,
    this.volumeMl = defaultVolumeMl,
  });

  static const double defaultAmountYuan = 0.16;
  static const double defaultVolumeMl = 500.0;

  /// 每元对应的毫升数。amountYuan 非法时返回 0。
  double get mlPerYuan {
    if (!amountYuan.isFinite || amountYuan <= 0) return 0;
    if (!volumeMl.isFinite || volumeMl <= 0) return 0;
    return volumeMl / amountYuan;
  }

  /// 参数是否可用（金额与水量都必须是正数，且比例不能溢出）
  bool get isValid {
    final ratio = mlPerYuan;
    return ratio.isFinite && ratio > 0;
  }

  /// 把花费金额（元）换算成毫升数。
  double millilitresForYuan(double yuan) {
    if (!yuan.isFinite || yuan <= 0) return 0;
    final ratio = mlPerYuan;
    if (ratio <= 0) return 0;
    return yuan * ratio;
  }

  /// 把积分（厘，1/1000 元）换算成毫升数。
  double millilitresForScore(int score) {
    if (score <= 0) return 0;
    return millilitresForYuan(score / 1000.0);
  }

  /// 把毫升数格式化成「xxx ml」/「x.x L」。
  ///
  /// 不足 1000 ml 时向下取整到 10 ml（避免给出虚假精度）；
  /// 超过 1000 ml 用升表示，保留一位小数。
  static String waterTextOf(double millilitres) {
    if (!millilitres.isFinite || millilitres <= 0) return '--';
    if (millilitres >= 1000) {
      return '${(millilitres / 1000).toStringAsFixed(1)} L';
    }
    // 与 life-798 一致：四舍五入到 10ml，避免出现 312ml 这种假精度
    final rounded = ((millilitres + 5) / 10).floor() * 10;
    return '$rounded ml';
  }

  /// 把花费金额格式化成「约 xxx ml」/「约 x.x L」。
  String waterTextForYuan(double yuan) =>
      waterTextOf(millilitresForYuan(yuan));

  /// 把积分（厘）格式化成水量文案。
  String waterTextForScore(int score) => waterTextForYuan(score / 1000.0);

  WaterEstimate copyWith({
    bool? visible,
    double? amountYuan,
    double? volumeMl,
  }) {
    return WaterEstimate(
      visible: visible ?? this.visible,
      amountYuan: amountYuan ?? this.amountYuan,
      volumeMl: volumeMl ?? this.volumeMl,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WaterEstimate &&
      other.visible == visible &&
      other.amountYuan == amountYuan &&
      other.volumeMl == volumeMl;

  @override
  int get hashCode => Object.hash(visible, amountYuan, volumeMl);

  @override
  String toString() =>
      'WaterEstimate(visible: $visible, amountYuan: $amountYuan, '
      'volumeMl: $volumeMl)';
}

/// 今日 / 本月 / 今年的用水汇总。
class WaterUsageSummary {
  /// 今日花费（元）
  final double todayYuan;

  /// 本月花费（元）
  final double monthYuan;

  /// 今年花费（元）
  final double yearYuan;

  /// 今日用水（毫升，已按比例折算）
  final double todayMillilitres;

  /// 本月用水（毫升）
  final double monthMillilitres;

  /// 今年用水（毫升）
  final double yearMillilitres;

  const WaterUsageSummary({
    this.todayYuan = 0,
    this.monthYuan = 0,
    this.yearYuan = 0,
    this.todayMillilitres = 0,
    this.monthMillilitres = 0,
    this.yearMillilitres = 0,
  });

  bool get isEmpty => todayYuan <= 0 && monthYuan <= 0 && yearYuan <= 0;

  WaterUsageSummary copyWith({
    double? todayYuan,
    double? monthYuan,
    double? yearYuan,
    double? todayMillilitres,
    double? monthMillilitres,
    double? yearMillilitres,
  }) {
    return WaterUsageSummary(
      todayYuan: todayYuan ?? this.todayYuan,
      monthYuan: monthYuan ?? this.monthYuan,
      yearYuan: yearYuan ?? this.yearYuan,
      todayMillilitres: todayMillilitres ?? this.todayMillilitres,
      monthMillilitres: monthMillilitres ?? this.monthMillilitres,
      yearMillilitres: yearMillilitres ?? this.yearMillilitres,
    );
  }
}
