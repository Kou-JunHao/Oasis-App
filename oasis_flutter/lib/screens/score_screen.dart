import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/score_models.dart';
import '../providers/score_provider.dart';

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
                    for (var i = 0; i < records.length && i < 30; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 72),
                      _buildRecordTile(context, records[i]),
                    ],
                  ],
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
