import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../config/score_secrets.dart';
import '../models/score_models.dart';
import 'api_service.dart';

/// 积分奖励提交签名
///
/// 服务端只对 `POST /acc/score/score-send` 校验签名，算法（实测自原厂客户端）：
///
///   sign = md5( adId + ((服务器时间) / 30000) * 30 + token后8位 + uid后8位 + 盐 )
///
/// - 时间戳为 **30 秒粒度**，且必须用服务器时间（本地时钟偏差会导致校验失败）
/// - App 端：`ApplicationType: 1,1`、URL 追加 `&s=1`、盐 [saltApp]
/// - 主平台：`ApplicationType: 1,5`、versioncode 固定 2.0.178、盐 [saltMain]
///
/// 注意：life-798 开源仓库里的 `Signer.java` 是**错误的占位实现**
/// （10 秒粒度且无时钟校正），不能照抄。
class ScoreSigner {
  ScoreSigner._();

  /// App 端盐值（来自 gitignore 的 lib/config/score_secrets.dart）
  static const String saltApp = kScoreSaltApp;

  /// 主平台盐值（同上）
  static const String saltMain = kScoreSaltMain;

  /// 是否已配置盐值：未配置时签到/任务提交必然被服务端拒绝
  static bool get configured =>
      saltApp.trim().isNotEmpty || saltMain.trim().isNotEmpty;

  /// 时间窗口：30 秒
  static const int windowMs = 30000;

  static String saltOf(ScorePlatform platform) =>
      platform == ScorePlatform.app ? saltApp : saltMain;

  /// 时间戳取值：(t / 30000) * 30
  static int windowValue(int nowMs) => (nowMs ~/ windowMs) * 30;

  static String tail8(String value) =>
      value.length <= 8 ? value : value.substring(value.length - 8);

  static String sign({
    required String adId,
    required String token,
    required String uid,
    required String salt,
    required int nowMs,
  }) {
    final raw = '$adId${windowValue(nowMs)}${tail8(token)}${tail8(uid)}$salt';
    return md5.convert(utf8.encode(raw)).toString();
  }
}

/// 宽松解析整数：服务端的总数可能是字符串（如 "6"）
int _parseIntLenient(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

/// 提交结果
class ScoreSubmitResult {
  final bool success;
  final String message;
  final int gained;

  const ScoreSubmitResult({
    required this.success,
    required this.message,
    this.gained = 0,
  });
}

/// 积分任务服务
class ScoreService {
  final ApiService _api;

  ScoreService(this._api);

  /// 服务器时间与本地时间的偏差（毫秒），由响应 Date 头推算
  int _clockOffsetMs = 0;
  int get clockOffsetMs => _clockOffsetMs;
  int get _serverNowMs => DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;

  /// 主平台请求头（versioncode 固定，跳过动态伪装注入）
  static Options get _mainPlatformOptions => Options(
        headers: {
          'ApplicationType': '1,5',
          'versioncode': '2.0.178',
          'User-Agent': 'Android_ilife798_2.0.178',
        },
        extra: const {'skipVersionHeaders': true},
      );

  static Options _optionsFor(ScorePlatform platform) =>
      platform == ScorePlatform.app ? Options() : _mainPlatformOptions;

  /// 用响应头里的 Date 校正服务器时间
  void _syncClock(Response response) {
    final raw = response.headers.value(HttpHeaders.dateHeader);
    if (raw == null) return;
    try {
      final serverMs = HttpDate.parse(raw).millisecondsSinceEpoch;
      _clockOffsetMs = serverMs - DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      // 解析失败就沿用上次的偏差
    }
  }

  /// 取 uid（签名需要）
  Future<String> fetchUid() async {
    final response = await _api.get('api/v1/acc/view-info');
    _syncClock(response);
    final data = response.data is Map ? (response.data as Map)['data'] : null;
    if (data is Map) return (data['id'] ?? '').toString();
    return '';
  }

  /// 拉取积分概览（积分、任务列表、签到状态）
  Future<ScoreOverview> fetchOverview() async {
    final appResponse = await _api.get('api/v1/acc/score/mission-lst');
    _syncClock(appResponse);
    var overview = parseScoreOverview(appResponse.data, ScorePlatform.app);

    // App 端接口不带签到信息时，回退主平台取签到数据
    if (overview.daily == null) {
      try {
        final mainResponse = await _api.get(
          'api/v1/acc/score/mission-lst',
          options: _mainPlatformOptions,
        );
        _syncClock(mainResponse);
        final main = parseScoreOverview(mainResponse.data, ScorePlatform.main);
        final merged = [...overview.missions];
        for (final mission in main.missions) {
          if (!merged.any((m) => m.refId == mission.refId)) merged.add(mission);
        }
        overview = ScoreOverview(
          validScore: overview.validScore != 0 ? overview.validScore : main.validScore,
          totalScore: overview.totalScore != 0 ? overview.totalScore : main.totalScore,
          missions: merged,
          daily: main.daily,
        );
      } catch (_) {
        // 主平台不可用时忽略，仅影响签到展示
      }
    }
    return overview;
  }

  /// 积分明细 / 服务端执行记录（分页）
  ///
  /// 服务端在 `hasCount=1` 时会在响应里带上 `size` 字段（总数）。
  Future<({List<ScoreRecord> items, int total})> fetchRecords({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      'api/v1/acc/score/score-lst',
      queryParameters: {'page': page, 'size': size, 'hasCount': 1},
    );
    _syncClock(response);
    final items = parseScoreRecords(response.data);
    final body = response.data;
    // 注意：服务端返回的 size 是字符串（如 "9"），需要宽松解析
    final total = body is Map
        ? _parseIntLenient(body['size'], items.length)
        : items.length;
    return (items: items, total: total);
  }

  /// 每日签到
  Future<ScoreSubmitResult> submitSignIn({
    required DailySignIn daily,
    required int weekDay,
    required String uid,
  }) =>
      _submit(
        adId: daily.adId,
        platform: daily.platform,
        uid: uid,
        body: {'weekDay': weekDay, 'adId': daily.adId},
      );

  /// 执行单个任务
  Future<ScoreSubmitResult> submitTask({
    required ScoreMission mission,
    required String uid,
  }) =>
      _submit(
        adId: mission.refId,
        platform: mission.platform,
        uid: uid,
        body: {'adId': mission.refId, 'type': 101},
        fallbackGain: mission.score,
      );


  // ==================== 积分兑换 ====================

  /// 把积分兑换到指定结算端点（钱包）
  ///
  /// 流程（与 life-798 一致，防重复兑换）：
  ///   1. `POST /acc/score/score-use`，body `{ep:{id}, score, type:1}`
  ///   2. 响应 `data.sn` 是账单号；**拿不到账单号一律按「待确认」处理**，不自动重试
  ///   3. `GET /bill/view-full?id=<账单号>`，校验 `bill.id` 匹配且 `bill.status == 3`
  Future<ScoreExchangeResult> exchange({
    required String endpointId,
    required int score,
  }) async {
    if (endpointId.trim().isEmpty) {
      return const ScoreExchangeResult(success: false, message: '请选择兑换到的钱包');
    }
    if (!isValidExchangeScore(score)) {
      return const ScoreExchangeResult(
        success: false,
        message: '兑换积分必须是 100 的正整数倍',
      );
    }

    final Response response;
    try {
      response = await _api.post(
        'api/v1/acc/score/score-use',
        data: {
          'ep': {'id': endpointId},
          'score': score,
          'type': 1,
        },
      );
    } catch (e) {
      return ScoreExchangeResult(
        success: false,
        pending: true,
        message: '兑换请求未完成（$e），请先核对官方记录，勿重复兑换',
      );
    }
    _syncClock(response);

    final body = response.data;
    if (body is! Map) {
      return const ScoreExchangeResult(
        success: false,
        pending: true,
        message: '服务端返回格式异常，请核对官方记录后再操作',
      );
    }
    final code = body['code'];
    if (code != 0) {
      final message = (body['msg'] ?? '').toString().trim();
      return ScoreExchangeResult(
        success: false,
        message: message.isEmpty ? '兑换失败（code=$code）' : message,
      );
    }

    final billId = exchangeBillIdOf(body);
    if (billId == null) {
      return const ScoreExchangeResult(
        success: false,
        pending: true,
        message: '兑换结果待确认，请先核对官方记录，勿重复兑换',
      );
    }

    try {
      final billResponse = await _api.get(
        'api/v1/bill/view-full',
        queryParameters: {'id': billId},
      );
      _syncClock(billResponse);
      final completed = exchangeCompletedOf(billResponse.data, billId);
      if (completed == true) {
        return ScoreExchangeResult(
          success: true,
          billId: billId,
          message: '兑换已完成',
        );
      }
      if (completed == false) {
        return ScoreExchangeResult(
          success: false,
          pending: true,
          billId: billId,
          message: '兑换结果待确认，请先核对官方记录，勿重复兑换',
        );
      }
      return ScoreExchangeResult(
        success: false,
        pending: true,
        billId: billId,
        message: '兑换账单不匹配，请核对官方记录后再操作',
      );
    } catch (e) {
      return ScoreExchangeResult(
        success: false,
        pending: true,
        billId: billId,
        message: '兑换已提交但账单查询失败，请核对官方记录',
      );
    }
  }

  Future<ScoreSubmitResult> _submit({
    required String adId,
    required ScorePlatform platform,
    required String uid,
    required Map<String, dynamic> body,
    int fallbackGain = 0,
  }) async {
    final token = _api.token;
    if (token == null || token.isEmpty) {
      return const ScoreSubmitResult(success: false, message: '登录状态异常，请重新登录');
    }
    if (uid.isEmpty) {
      return const ScoreSubmitResult(success: false, message: '无法获取账号 uid，签到不可用');
    }

    final signature = ScoreSigner.sign(
      adId: adId,
      token: token,
      uid: uid,
      salt: ScoreSigner.saltOf(platform),
      nowMs: _serverNowMs,
    );
    final suffix = platform == ScorePlatform.app ? '&s=1' : '';
    final path = 'api/v1/acc/score/score-send?sign=$signature$suffix';

    final response = await _api.post(
      path,
      data: body,
      options: _optionsFor(platform),
    );
    _syncClock(response);

    final data = response.data;
    if (data is! Map) {
      return const ScoreSubmitResult(success: false, message: '服务端返回格式异常');
    }
    final code = data['code'];
    final message = (data['msg'] ?? '').toString().trim();
    if (code == 0) {
      return ScoreSubmitResult(
        success: true,
        message: message.isEmpty ? '提交成功' : message,
        gained: _gainFrom(data['data']) ?? fallbackGain,
      );
    }
    return ScoreSubmitResult(
      success: false,
      message: message.isEmpty ? '提交失败（code=$code）' : message,
    );
  }

  int? _gainFrom(dynamic data) {
    if (data is num) return data.toInt();
    if (data is Map) {
      for (final key in ['score', 'gain', 'validScore', 'addScore']) {
        final v = data[key];
        if (v is num) return v.toInt();
      }
    }
    return null;
  }
}
