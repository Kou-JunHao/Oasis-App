import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart';
import '../models/score_models.dart';
import '../providers/score_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/api_service.dart';
import '../widgets/wallet_highlight.dart';

/// 积分任务页面：每日签到、积分任务、任务执行记录
class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 冷却倒计时需要每秒刷新
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScoreProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScoreProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final padding = width > 720 ? (width - 720) / 2 : 16.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverAppBar.medium(
              title: Text('积分任务'),
              pinned: true,
              floating: false,
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (provider.isLoading && provider.overview.missions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _buildScoreCard(context, provider),
                    const SizedBox(height: 20),
                    _buildMissions(context, provider),
                    const SizedBox(height: 20),
                    _buildLogs(context, provider),
                    const SizedBox(height: 20),
                    _buildRecords(context, provider),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 积分 + 签到 ====================

  Widget _buildScoreCard(BuildContext context, ScoreProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final daily = provider.overview.daily;
    final signed = provider.signedInToday;
    final cooldown = provider.cooldownRemaining;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前积分',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${provider.overview.validScore}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '≈¥${(provider.overview.validScore / 1000).toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.error != null) ...[
              Text(
                provider.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (daily == null || signed || cooldown != null || provider.isSubmitting)
                        ? null
                        : () => _handleSignIn(provider),
                    icon: Icon(signed
                        ? Icons.check_circle_rounded
                        : Icons.event_available_rounded),
                    label: Text(
                      signed
                          ? '今日已签到'
                          : cooldown != null
                              ? '${cooldown.inSeconds + 1}s 后可签到'
                              : daily == null
                                  ? '签到信息不可用'
                                  : '立即签到 +${daily.baseScore}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: provider.isSubmitting
                  ? null
                  : () => _showExchangeSheet(context, provider),
              icon: const Icon(Icons.redeem_rounded, size: 18),
              label: const Text('积分兑换'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: colorScheme.onPrimaryContainer,
                side: BorderSide(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (daily != null && daily.rules.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '连续签到奖励',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final rule in daily.rules)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${_ruleLabel(rule)} +${rule.score}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _ruleLabel(SignInRule rule) {
    final days = <String>[];
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    for (var i = 0; i < 7; i++) {
      if (rule.weekMask & (1 << i) != 0) days.add(names[i]);
    }
    if (days.length == 7) return '连续 7 天';
    if (days.isEmpty) return rule.message.isEmpty ? '奖励' : rule.message;
    return '周${days.first}-${days.last}';
  }

  /// 打开积分兑换面板
  Future<void> _showExchangeSheet(
    BuildContext context,
    ScoreProvider provider,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScoreExchangeSheet(
        availableScore: provider.overview.validScore,
        provider: provider,
      ),
    );
  }

  Future<void> _handleSignIn(ScoreProvider provider) async {
    final result = await provider.signIn();
    if (!mounted) return;
    _toast(result.success
        ? '签到成功${result.gained > 0 ? ' +${result.gained} 分' : ''}'
        : result.message);
  }

  // ==================== 任务列表 ====================

  Widget _buildMissions(BuildContext context, ScoreProvider provider) {
    final theme = Theme.of(context);
    final missions = provider.executableMissions;
    final cooldown = provider.cooldownRemaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '积分任务（${missions.length}）',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (missions.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.inbox_rounded),
              title: const Text('暂无可执行任务'),
              subtitle: Text(provider.isLoading ? '正在加载…' : '稍后下拉刷新试试'),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < missions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  _buildMissionTile(context, provider, missions[i], cooldown),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '服务端限制同一账号 30 秒内只能提交一次；提交即视为完成任务，'
            '接口不核验是否真的观看过广告，请注意账号风险',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMissionTile(
    BuildContext context,
    ScoreProvider provider,
    ScoreMission mission,
    Duration? cooldown,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remaining = provider.remainingCount(mission);
    final disabled = cooldown != null || provider.isSubmitting || remaining <= 0;

    return ListTile(
      leading: Icon(
        remaining > 0 ? Icons.play_circle_outline_rounded : Icons.task_alt_rounded,
        color: remaining > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(mission.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '剩余 $remaining/${mission.limit} 次 · +${mission.score} 分/次',
      ),
      trailing: FilledButton.tonal(
        onPressed: disabled ? null : () => _handleMission(provider, mission),
        child: Text(remaining <= 0 ? '已完成' : '执行'),
      ),
    );
  }

  Future<void> _handleMission(ScoreProvider provider, ScoreMission mission) async {
    final result = await provider.runMission(mission);
    if (!mounted) return;
    _toast(result.success
        ? '${mission.name} 完成${result.gained > 0 ? ' +${result.gained} 分' : ''}'
        : result.message);
  }

  // ==================== 本地执行记录 ====================

  Widget _buildLogs(BuildContext context, ScoreProvider provider) {
    final theme = Theme.of(context);
    final logs = provider.logs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '本次执行记录',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: logs.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.history_toggle_off_rounded),
                  title: Text('暂无执行记录'),
                  subtitle: Text('签到或执行任务后会记录在这里'),
                )
              : Column(
                  children: [
                    for (var i = 0; i < logs.length && i < 20; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      _buildLogTile(context, logs[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLogTile(BuildContext context, ScoreLogEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListTile(
      leading: Icon(
        entry.success ? Icons.check_circle_rounded : Icons.error_rounded,
        color: entry.success ? Colors.green : colorScheme.error,
      ),
      title: Text(entry.title),
      subtitle: Text(_formatTime(entry.time)),
      trailing: Text(
        entry.success
            ? (entry.gained > 0 ? '+${entry.gained}' : '成功')
            : '失败',
        style: theme.textTheme.titleMedium?.copyWith(
          color: entry.success ? Colors.green : colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==================== 服务端积分明细 ====================

  Widget _buildRecords(BuildContext context, ScoreProvider provider) {
    final theme = Theme.of(context);
    final records = provider.records;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '积分明细',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: records.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.receipt_long_rounded),
                  title: Text('暂无积分明细'),
                )
              : Column(
                  children: [
                    for (var i = 0; i < records.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      _buildRecordTile(context, records[i]),
                    ],
                  ],
                ),
        ),
        if (provider.hasMoreRecords)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: provider.isLoadingMoreRecords
                  ? null
                  : provider.loadMoreRecords,
              icon: provider.isLoadingMoreRecords
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                provider.isLoadingMoreRecords
                    ? '加载中…'
                    : '加载更多（已显示 ${records.length}/${provider.recordTotal}）',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordTile(BuildContext context, ScoreRecord record) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        record.isIncome
            ? Icons.add_circle_outline_rounded
            : Icons.remove_circle_outline_rounded,
        color: record.isIncome
            ? Colors.green
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(record.time == null ? '' : _formatTime(record.time!)),
      trailing: Text(
        record.scoreText,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: record.isIncome ? Colors.green : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 积分兑换面板：选择钱包、档位与份数后兑换
class _ScoreExchangeSheet extends StatefulWidget {
  final int availableScore;
  final ScoreProvider provider;

  const _ScoreExchangeSheet({
    required this.availableScore,
    required this.provider,
  });

  @override
  State<_ScoreExchangeSheet> createState() => _ScoreExchangeSheetState();
}

class _ScoreExchangeSheetState extends State<_ScoreExchangeSheet> {
  bool _loadingWallets = true;
  String? _walletError;
  List<({String id, String name})> _wallets = const [];
  String? _selectedWalletId;
  int _unitScore = scoreExchangeAmounts.first;
  int _quantity = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallets());
  }

  Future<void> _loadWallets() async {
    setState(() {
      _loadingWallets = true;
      _walletError = null;
    });
    try {
      final response = await context.read<ApiService>().getWalletBalance();
      final wallets = response.data?.allWallets ?? const <WalletData>[];
      final options = <({String id, String name})>[];
      for (final wallet in wallets) {
        final id = wallet.ep?.id ?? '';
        if (id.isEmpty) continue;
        options.add((id: id, name: wallet.ep?.name ?? wallet.name ?? '未命名钱包'));
      }
      if (!mounted) return;
      setState(() {
        _wallets = options;
        _selectedWalletId = options.isNotEmpty ? options.first.id : null;
        _loadingWallets = false;
        _walletError = options.isEmpty ? '未找到可兑换的钱包' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingWallets = false;
        _walletError = '钱包列表获取失败，请稍后重试';
      });
    }
  }

  int get _totalScore => _unitScore * _quantity;

  int get _maxQuantity =>
      _unitScore <= 0 ? 0 : widget.availableScore ~/ _unitScore;

  String _money(int score) => '¥${(score / 1000).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '积分兑换',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '可用 ${widget.availableScore} 积分',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingWallets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_walletError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_walletError!, style: TextStyle(color: colorScheme.error)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _loadWallets, child: const Text('重试')),
                ],
              )
            else ...[
              Text('兑换到', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              RadioGroup<String>(
                groupValue: _selectedWalletId,
                onChanged: _submitting
                    ? (_) {}
                    : (value) => setState(() => _selectedWalletId = value),
                child: Column(
                  children: [
                    for (final wallet in _wallets)
                      RadioListTile<String>(
                        value: wallet.id,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          wallet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('每份', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final amount in scoreExchangeAmounts)
                    ChoiceChip(
                      label: Text('$amount 积分 = ${_money(amount)}'),
                      selected: _unitScore == amount,
                      onSelected: _submitting || amount > widget.availableScore
                          ? null
                          : (_) => setState(() {
                                _unitScore = amount;
                                if (_quantity > _maxQuantity) _quantity = 1;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('份数', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: _submitting || _quantity <= 1
                        ? null
                        : () => setState(() => _quantity -= 1),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text(
                    '$_quantity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting || _quantity >= _maxQuantity
                        ? null
                        : () => setState(() => _quantity += 1),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              Text(
                '合计消耗 $_totalScore 积分，兑换 ${_money(_totalScore)}'
                '（最多 $_maxQuantity 份）',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _submitting || _maxQuantity <= 0 ? null : _confirm,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('确认兑换'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '兑换后不可撤销；若结果提示「待确认」，请先到官方记录核对，不要重复兑换。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final walletId = _selectedWalletId;
    if (walletId == null) return;
    if (!isValidExchangeQuantity(
      unitScore: _unitScore,
      quantity: _quantity,
      available: widget.availableScore,
    )) {
      _toast('份数无效或积分不足');
      return;
    }

    final walletName =
        _wallets.firstWhere((w) => w.id == walletId).name;
    final score = _totalScore;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认兑换'),
        content: Text.rich(
          TextSpan(
            style: Theme.of(dialogContext).textTheme.bodyMedium,
            children: [
              TextSpan(text: '将 $score 积分兑换 ${_money(score)} 到'),
              highlightedWalletSpan(
                walletName,
                baseStyle: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const TextSpan(text: '？\n\n请核对钱包名称，兑换后不可撤销。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认兑换'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);

    final result = await widget.provider.exchange(
      endpointId: walletId,
      score: score,
      walletName: walletName,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.success) {
      // 兑换成功：同步刷新钱包余额
      context.read<WalletProvider>().fetchWalletBalance();
    }
    navigator.pop();

    if (result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('兑换已完成，${_money(score)} 已兑换至「$walletName」'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result.pending) {
      showDialog<void>(
        context: navigator.context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('兑换结果待确认'),
          content: Text('${result.message}\n\n请先到官方记录核对积分与账单，确认无误前不要重复兑换。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
