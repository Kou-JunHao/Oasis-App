import 'dart:io';

import 'package:dio/dio.dart';

import '../models/score_models.dart';
import 'api_service.dart';
import 'score_signer.dart';

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
  ///
  /// 3.1.10 协议下 `mission-lst` 统一用 App 通道头（`ApplicationType: 1,1`），
  /// 响应已同时包含 `accScoreRsp.daily` 与 `dailyRSP`，无需再回退 1,5 主平台。
  Future<ScoreOverview> fetchOverview() async {
    final response = await _api.get('api/v1/acc/score/mission-lst');
    _syncClock(response);
    return parseScoreOverview(response.data);
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
  ///
  /// 请求体字段名必须是**全小写** `weekday`（3.1.10 协议）；
  /// `addScore` 传服务端下发的当日基础分，`addScoreType` 固定 1。
  Future<ScoreSubmitResult> submitSignIn({
    required DailySignIn daily,
    required int weekDay,
    required String uid,
  }) =>
      _submit(
        adId: daily.adId,
        uid: uid,
        body: {
          'adId': daily.adId,
          'weekday': weekDay,
          'addScore': daily.baseScore,
          'addScoreType': 1,
        },
      );

  /// 执行单个任务
  Future<ScoreSubmitResult> submitTask({
    required ScoreMission mission,
    required String uid,
  }) =>
      _submit(
        adId: mission.refId,
        uid: uid,
        // 服务端不要求 addScore/addScoreType（已实测：带上或省略都返回 code=0），
        // 这里仍按官方客户端的字段发送，便于服务端统计。
        body: {
          'adId': mission.refId,
          'type': 101,
          'addScore': mission.score,
          'addScoreType': mission.refId == '1705776998' ? 2 : 4,
        },
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

    // 签名用的时间必须贴近服务器时间：先刷新一次时钟偏差，再取当前值
    final signature = ScoreSigner.sign(
      adId: adId,
      token: token,
      uid: uid,
      nowMs: _serverNowMs,
    );
    final path = 'api/v1/acc/score/score-send?sign=$signature&s=1';

    final response = await _api.post(path, data: body);
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
