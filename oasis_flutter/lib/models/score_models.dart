/// 积分任务相关模型
///
/// 接口结构（实测自原厂 App / life-798 实现）：
///   GET /api/v1/acc/score/mission-lst
///     data.missions[]      {refId, name|title, score, limit}
///     data.accScoreRsp     {validScore, totalScore, daily:{week}}
///     data.dailyRSP        {adId, score, config:[{rule, score, msg}]}
///   GET /api/v1/acc/score/score-lst?page=0&size=N&hasCount=1
///     data[]               {ctime, data:{...}, score|spend|...}
library;

/// 积分平台
///
/// - [app]：App 端，`ApplicationType: 1,1`，versioncode 跟随动态伪装值，提交时 URL 追加 `&s=1`
/// - [main]：主平台，`ApplicationType: 1,5`，versioncode 固定 2.0.178
enum ScorePlatform { app, main }

/// 积分任务
class ScoreMission {
  final String refId;
  final String name;
  final int score;
  final int limit;
  final ScorePlatform platform;

  const ScoreMission({
    required this.refId,
    required this.name,
    required this.score,
    required this.limit,
    required this.platform,
  });

  static ScoreMission? fromJson(Map<String, dynamic> json, ScorePlatform platform) {
    final refId = (json['refId'] ?? '').toString().trim();
    if (refId.isEmpty) return null;
    final name = (json['name'] ?? json['title'] ?? '任务').toString().trim();
    return ScoreMission(
      refId: refId,
      name: name.isEmpty ? '任务' : name,
      score: _int(json['score']),
      limit: _int(json['limit']),
      platform: platform,
    );
  }

  /// 这些任务不参与执行（与 life-798 的过滤规则一致：理财/借贷类）
  bool get executables => score > 0 && limit > 0 && !_skipped(name);

  static bool _skipped(String name) =>
      ['免费权益', '借贷', '贷款'].any((k) => name.contains(k));
}

/// 连续签到奖励规则
class SignInRule {
  final int weekMask;
  final int score;
  final String message;

  const SignInRule({
    required this.weekMask,
    required this.score,
    required this.message,
  });
}

/// 每日签到信息
class DailySignIn {
  final String adId;
  final int baseScore;
  final int weekMask;
  final List<SignInRule> rules;
  final ScorePlatform platform;

  const DailySignIn({
    required this.adId,
    required this.baseScore,
    required this.weekMask,
    required this.rules,
    required this.platform,
  });

  bool get available => adId.isNotEmpty;

  /// [weekDay]：1=周一 … 7=周日
  bool signedOn(int weekDay) => (weekMask & (1 << (weekDay - 1))) != 0;

  /// 今日签到后能拿到的额外连签奖励
  List<SignInRule> rewardsFor(int weekDay) {
    const validMask = 0x7F;
    final today = 1 << (weekDay - 1);
    if (signedOn(weekDay)) return const [];
    final before = weekMask & validMask;
    final after = before | today;
    return rules
        .where((r) =>
            r.weekMask > 0 &&
            r.weekMask & validMask == r.weekMask &&
            r.score > 0 &&
            before & r.weekMask != r.weekMask &&
            after & r.weekMask == r.weekMask)
        .toList();
  }
}

/// 当前积分 + 任务 + 签到概览
class ScoreOverview {
  final int validScore;
  final int totalScore;
  final List<ScoreMission> missions;
  final DailySignIn? daily;

  const ScoreOverview({
    required this.validScore,
    required this.totalScore,
    required this.missions,
    this.daily,
  });

  static const empty = ScoreOverview(
    validScore: 0,
    totalScore: 0,
    missions: [],
  );

  /// 积分折算金额（与原厂一致：1000 积分 ≈ 1 元）
  double get money => validScore / 1000.0;

  String get moneyText => '≈¥${money.toStringAsFixed(2)}';
}

/// 积分明细（服务端执行记录）
class ScoreRecord {
  final DateTime? time;
  final int score;
  final bool isIncome;
  final String title;

  /// 关联的任务/广告 id，用于统计今日各任务已完成次数
  final String adId;

  const ScoreRecord({
    required this.time,
    required this.score,
    required this.isIncome,
    required this.title,
    this.adId = '',
  });

  /// 是否为今天的记录
  bool isToday(DateTime now) {
    final t = time;
    if (t == null) return false;
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  String get scoreText => score > 0 ? '+$score' : '$score';
}

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? 0;
}

/// 解析 mission-lst 响应
ScoreOverview parseScoreOverview(dynamic body, ScorePlatform platform) {
  if (body is! Map) return ScoreOverview.empty;
  final data = body['data'];
  if (data is! Map) return ScoreOverview.empty;

  final scoreInfo = data['accScoreRsp'];
  final validScore = scoreInfo is Map ? _int(scoreInfo['validScore']) : 0;
  final totalScore =
      scoreInfo is Map ? _int(scoreInfo['totalScore'] ?? validScore) : validScore;

  final missions = <ScoreMission>[];
  final rawMissions = data['missions'];
  if (rawMissions is List) {
    for (final item in rawMissions) {
      if (item is Map<String, dynamic>) {
        final m = ScoreMission.fromJson(item, platform);
        if (m != null) missions.add(m);
      }
    }
  }

  DailySignIn? daily;
  final dailyRsp = data['dailyRSP'];
  if (dailyRsp is Map) {
    final weekRaw = scoreInfo is Map ? scoreInfo['daily'] : null;
    final week = weekRaw is Map ? _int(weekRaw['week']) : 0;
    final rules = <SignInRule>[];
    final config = dailyRsp['config'];
    if (config is List) {
      for (final item in config) {
        if (item is Map) {
          rules.add(SignInRule(
            weekMask: _int(item['rule']),
            score: _int(item['score']),
            message: (item['msg'] ?? '').toString().trim(),
          ));
        }
      }
    }
    final adId = (dailyRsp['adId'] ?? '').toString().trim();
    if (adId.isNotEmpty) {
      daily = DailySignIn(
        adId: adId,
        baseScore: _int(dailyRsp['score']),
        weekMask: week,
        rules: rules,
        platform: platform,
      );
    }
  }

  return ScoreOverview(
    validScore: validScore,
    totalScore: totalScore,
    missions: missions,
    daily: daily,
  );
}

/// 解析 score-lst 响应（字段名在不同版本间有差异，这里做兼容）
List<ScoreRecord> parseScoreRecords(dynamic body) {
  if (body is! Map) return const [];
  final data = body['data'];
  if (data is! List) return const [];

  const scoreKeys = [
    'score', 'spend', 'changeScore', 'change_score',
    'amount', 'value', 'num', 'points',
  ];
  const titleKeys = [
    'msg', 'name', 'title', 'desc', 'remark', 'memo', 'typeName',
  ];
  const dataTitleKeys = [
    'msg', 'name', 'title', 'desc', 'remark', 'memo', 'typeName',
    'adName', 'adId',
  ];

  int? pick(Map map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) return _int(map[k]);
    }
    return null;
  }

  String? pickText(Map map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  final out = <ScoreRecord>[];
  for (final item in data) {
    if (item is! Map) continue;
    final inner = item['data'] is Map ? item['data'] as Map : const {};
    final raw = pick(item, scoreKeys) ?? pick(inner, scoreKeys) ?? 0;

    // 方向判定：type/src 101 视为收入，107 或带 spend 字段视为支出
    final type = item['type'] != null ? _int(item['type']) : _int(inner['type']);
    final src = _int(item['src']);
    final spendField = inner.containsKey('spend');
    bool isIncome;
    if (type == 107 || spendField) {
      isIncome = false;
    } else if (type == 101 || src == 101) {
      isIncome = true;
    } else {
      isIncome = raw >= 0;
    }
    final score = raw == 0 ? 0 : (isIncome ? raw.abs() : -raw.abs());

    final ctime = _int(item['ctime'] ?? inner['ctime']);
    final adId = (inner['adId'] ?? item['adId'] ?? '').toString().trim();
    out.add(ScoreRecord(
      time: ctime > 0 ? DateTime.fromMillisecondsSinceEpoch(ctime) : null,
      score: score,
      isIncome: isIncome,
      title: pickText(item, titleKeys) ??
          pickText(inner, dataTitleKeys) ??
          (isIncome ? '积分获得' : '积分使用'),
      adId: adId,
    ));
  }
  return out;
}


/// 积分兑换结果
class ScoreExchangeResult {
  /// 是否确认兑换成功（账单状态已完成）
  final bool success;

  /// 是否处于「待确认」状态：请求可能已生效，但账单未确认，
  /// 此时必须提示用户去官方记录核对，**不要重复兑换**
  final bool pending;

  final String message;
  final String? billId;

  const ScoreExchangeResult({
    required this.success,
    required this.message,
    this.pending = false,
    this.billId,
  });
}

/// 可兑换档位（每份积分），与原厂一致
const List<int> scoreExchangeAmounts = [100, 1000];

/// 校验兑换请求参数：积分必须为正且是 100 的整数倍
bool isValidExchangeScore(int score) => score > 0 && score % 100 == 0;

/// 份数是否有效（档位合法、份数 > 0、且不超过可用积分）
bool isValidExchangeQuantity({
  required int unitScore,
  required int quantity,
  required int available,
}) {
  if (!scoreExchangeAmounts.contains(unitScore)) return false;
  if (quantity <= 0) return false;
  return quantity <= available ~/ unitScore;
}

/// 从兑换响应中取账单号（data.sn）
String? exchangeBillIdOf(dynamic body) {
  if (body is! Map) return null;
  final data = body['data'];
  if (data is! Map) return null;
  final sn = data['sn']?.toString().trim() ?? '';
  if (sn.isEmpty || sn == 'null') return null;
  return sn;
}

/// 校验账单查询结果：
/// - true  → 账单 id 匹配且 status == 3（兑换已完成）
/// - false → 账单 id 匹配但未完成
/// - null  → 账单缺失或 id 不匹配（视为待确认）
bool? exchangeCompletedOf(dynamic body, String expectedBillId) {
  if (body is! Map) return null;
  final data = body['data'];
  if (data is! Map) return null;
  final bill = data['bill'];
  if (bill is! Map) return null;
  if (bill['id']?.toString() != expectedBillId) return null;
  return (bill['status'] is num ? (bill['status'] as num).toInt() : -1) == 3;
}
