import 'package:flutter/foundation.dart';

import '../models/score_models.dart';
import '../services/api_service.dart';
import '../services/score_service.dart';

/// 一次任务执行的本地记录
class ScoreLogEntry {
  final DateTime time;
  final String title;
  final bool success;
  final int gained;

  const ScoreLogEntry({
    required this.time,
    required this.title,
    required this.success,
    this.gained = 0,
  });
}

/// 积分任务状态管理
class ScoreProvider extends ChangeNotifier {
  final ScoreService _service;

  ScoreProvider(ApiService apiService) : _service = ScoreService(apiService);

  /// 服务端限制：同一账号 30 秒内只能提交一次
  static const Duration submitInterval = Duration(seconds: 30);

  /// 积分明细每页条数
  static const int recordPageSize = 20;

  ScoreOverview _overview = ScoreOverview.empty;
  List<ScoreRecord> _records = const [];
  final List<ScoreLogEntry> _logs = [];
  String _uid = '';
  bool _loading = false;
  bool _submitting = false;
  String? _error;
  DateTime? _lastSubmitAt;
  bool _loadedOnce = false;
  bool _isLoadingMoreRecords = false;
  int _recordPage = 0;
  int _recordTotal = 0;

  ScoreOverview get overview => _overview;
  List<ScoreRecord> get records => _records;
  List<ScoreLogEntry> get logs => List.unmodifiable(_logs);
  bool get isLoading => _loading;
  bool get isSubmitting => _submitting;
  String? get error => _error;
  String get uid => _uid;

  /// 今天星期几（1=周一 … 7=周日，与接口约定一致）
  int get weekDay => DateTime.now().weekday;

  bool get signedInToday => _overview.daily?.signedOn(weekDay) ?? false;

  /// 积分明细总数（服务端）
  int get recordTotal => _recordTotal;

  /// 是否还有更多积分明细
  bool get hasMoreRecords => _records.length < _recordTotal;

  bool get isLoadingMoreRecords => _isLoadingMoreRecords;

  /// 冷却剩余时间，null 表示可以提交
  Duration? get cooldownRemaining {
    final last = _lastSubmitAt;
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= submitInterval) return null;
    return submitInterval - elapsed;
  }

  /// 可执行的任务（有分数、有次数、非理财类）
  List<ScoreMission> get executableMissions =>
      _overview.missions.where((m) => m.executables).toList();

  /// 今日某任务已完成次数（按服务端明细里的 adId 统计）
  int doneTodayCount(String refId) {
    if (refId.isEmpty) return 0;
    final now = DateTime.now();
    return _records
        .where((r) => r.adId == refId && r.isToday(now) && r.isIncome)
        .length;
  }

  /// 今日剩余可执行次数
  int remainingCount(ScoreMission mission) {
    final remaining = mission.limit - doneTodayCount(mission.refId);
    return remaining < 0 ? 0 : remaining;
  }

  /// 首次进入钱包页时顺带取一次积分（已加载过则直接返回）
  Future<void> ensureLoaded() async {
    if (_loadedOnce || _loading) return;
    _loadedOnce = true;
    await refresh();
  }

  /// 拉取积分、任务列表、签到状态与明细
  Future<void> refresh() async {
    _loadedOnce = true;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_uid.isEmpty) {
        _uid = await _service.fetchUid();
      }
      _overview = await _service.fetchOverview();
      try {
        final page = await _service.fetchRecords(page: 0, size: recordPageSize);
        _records = page.items;
        _recordTotal = page.total;
        _recordPage = 0;
      } catch (e) {
        // 明细失败不影响主信息
        _records = const [];
        _recordTotal = 0;
        _recordPage = 0;
        _recordError('积分明细获取失败: $e');
      }
    } catch (e) {
      _error = _describeError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 每日签到
  Future<ScoreSubmitResult> signIn() async {
    final daily = _overview.daily;
    if (daily == null) {
      return const ScoreSubmitResult(success: false, message: '暂未获取到签到信息');
    }
    if (daily.signedOn(weekDay)) {
      return const ScoreSubmitResult(success: false, message: '今日已签到');
    }
    return _submit(
      title: '每日签到',
      action: () => _service.submitSignIn(
        daily: daily,
        weekDay: weekDay,
        uid: _uid,
      ),
    );
  }

  /// 执行单个任务
  Future<ScoreSubmitResult> runMission(ScoreMission mission) => _submit(
        title: mission.name,
        action: () => _service.submitTask(mission: mission, uid: _uid),
      );

  /// 积分兑换：把积分兑换到指定钱包（结算端点）
  ///
  /// 成功后自动刷新积分与任务状态；「待确认」结果不会自动重试，
  /// 由界面提示用户去官方记录核对。
  Future<ScoreExchangeResult> exchange({
    required String endpointId,
    required int score,
    String walletName = '',
  }) async {
    if (_submitting) {
      return const ScoreExchangeResult(
        success: false,
        message: '正在处理上一个操作，请稍候',
      );
    }
    _submitting = true;
    notifyListeners();

    ScoreExchangeResult result;
    try {
      result = await _service.exchange(endpointId: endpointId, score: score);
    } catch (e) {
      result = ScoreExchangeResult(success: false, message: _describeError(e));
    }

    _submitting = false;
    _logs.insert(
      0,
      ScoreLogEntry(
        time: DateTime.now(),
        title: '积分兑换${walletName.isEmpty ? '' : ' → $walletName'}',
        success: result.success,
      ),
    );
    if (_logs.length > 100) _logs.removeLast();
    notifyListeners();

    if (result.success) await refresh();
    return result;
  }

  Future<ScoreSubmitResult> _submit({
    required String title,
    required Future<ScoreSubmitResult> Function() action,
  }) async {
    final remaining = cooldownRemaining;
    if (remaining != null) {
      return ScoreSubmitResult(
        success: false,
        message: '操作过于频繁，请 ${remaining.inSeconds + 1} 秒后再试',
      );
    }
    if (_uid.isEmpty) {
      return const ScoreSubmitResult(success: false, message: '账号信息未就绪，请先刷新');
    }

    _submitting = true;
    notifyListeners();
    ScoreSubmitResult result;
    try {
      result = await action();
    } catch (e) {
      result = ScoreSubmitResult(success: false, message: _describeError(e));
    }
    _lastSubmitAt = DateTime.now();
    _submitting = false;
    _logs.insert(
      0,
      ScoreLogEntry(
        time: DateTime.now(),
        title: title,
        success: result.success,
        gained: result.gained,
      ),
    );
    if (_logs.length > 100) _logs.removeLast();
    notifyListeners();

    if (result.success) {
      await refresh();
    }
    return result;
  }

  /// 加载下一页积分明细（追加）
  Future<void> loadMoreRecords() async {
    if (_isLoadingMoreRecords || _loading || !hasMoreRecords) return;
    _isLoadingMoreRecords = true;
    notifyListeners();
    try {
      final nextPage = _recordPage + 1;
      final page = await _service.fetchRecords(
        page: nextPage,
        size: recordPageSize,
      );
      // 明细没有唯一 id，用「时间+标题+分值+adId」做去重键
      String keyOf(ScoreRecord r) =>
          '${r.time?.millisecondsSinceEpoch}|${r.title}|${r.score}|${r.adId}';
      final existing = _records.map(keyOf).toSet();
      _records = [
        ..._records,
        ...page.items.where((r) => !existing.contains(keyOf(r))),
      ];
      _recordTotal = page.total;
      _recordPage = nextPage;
    } catch (e) {
      _recordError('加载更多积分明细失败: $e');
    } finally {
      _isLoadingMoreRecords = false;
      notifyListeners();
    }
  }

  void _recordError(String message) {
    _error = message;
  }

  String _describeError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Connection')) {
      return '网络连接失败，请检查网络';
    }
    if (text.contains('timeout') || text.contains('Timeout')) {
      return '请求超时，请稍后重试';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
