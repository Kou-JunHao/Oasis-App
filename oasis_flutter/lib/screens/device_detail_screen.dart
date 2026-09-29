import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_models.dart';
import '../models/device_detail_models.dart';
import '../services/api_service.dart';

/// 设备详情：实时运行状态与用水统计
class DeviceDetailScreen extends StatefulWidget {
  final DeviceDetail device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  static const Duration _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  DeviceRuntimeStatus? _status;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(_pollInterval, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final response = await api.getDeviceStatus(widget.device.id);
      if (!mounted) return;
      setState(() {
        if (response.isSuccess && response.data != null) {
          _status = response.data;
          _error = null;
        } else {
          _error = response.message ?? '获取设备状态失败';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '网络错误: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = width > 720 ? (width - 720) / 2 : 16.0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = _status;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.medium(
              title: Text(widget.device.name ?? '设备详情'),
              pinned: true,
              floating: false,
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && status == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null && status == null)
                    _buildErrorCard(context, colorScheme)
                  else ...[
                    _buildHeaderCard(context, status, colorScheme, theme),
                    const SizedBox(height: 16),
                    _buildUsageCard(context, status, colorScheme, theme),
                    const SizedBox(height: 16),
                    _buildRuntimeCard(context, status, colorScheme, theme),
                    if (status != null && status.subs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSubsCard(context, status, colorScheme, theme),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        '每 ${_pollInterval.inSeconds} 秒自动刷新 · 下拉可手动刷新',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.error_outline_rounded, color: colorScheme.error),
        title: Text(_error!),
        trailing: TextButton(
          onPressed: () => _load(),
          child: const Text('重试'),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    DeviceRuntimeStatus? status,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final online = status?.online ?? widget.device.isOnline;
    final running = status?.running ?? widget.device.isRunning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.water_drop_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.name ?? '未命名设备',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '编号 ${widget.device.id}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(
                  label: online ? '在线' : '离线',
                  color: online ? Colors.green : colorScheme.outline,
                ),
                const SizedBox(height: 6),
                _StatusChip(
                  label: running ? '运行中' : '已停止',
                  color: running ? colorScheme.primary : colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(
    BuildContext context,
    DeviceRuntimeStatus? status,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final liters = status?.totalOut ?? 0;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '累计出水量',
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
                  liters.toStringAsFixed(1),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '升',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                if (liters >= 1000)
                  Text(
                    '≈ ${(liters / 1000).toStringAsFixed(2)} 吨',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuntimeCard(
    BuildContext context,
    DeviceRuntimeStatus? status,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final gene = status?.gene;
    final rows = <(IconData, String, String)>[
      (
        Icons.speed_rounded,
        '实时流速',
        gene == null ? '—' : '${gene.velocity}',
      ),
      (
        Icons.timeline_rounded,
        '脉冲计数',
        gene == null ? '—' : '${gene.pulse}',
      ),
      (
        Icons.tune_rounded,
        '工作模式',
        gene == null ? '—' : _modeText(gene.mode),
      ),
      (
        Icons.power_settings_new_rounded,
        '开关机次数',
        gene == null ? '—' : '${gene.offCount}',
      ),
      (
        Icons.warning_amber_rounded,
        '错误码',
        gene == null ? '—' : (gene.hasError ? '${gene.error}' : '正常'),
      ),
      (
        Icons.credit_card_rounded,
        '付费方式',
        status == null ? '—' : (status.prepay ? '预付费' : '后付费'),
      ),
    ];

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            ListTile(
              leading: Icon(rows[i].$1, color: colorScheme.primary),
              title: Text(rows[i].$2),
              trailing: Text(
                rows[i].$3,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: rows[i].$2 == '错误码' && (gene?.hasError ?? false)
                      ? colorScheme.error
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubsCard(
    BuildContext context,
    DeviceRuntimeStatus status,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '分路出水（${status.subs.length}）',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < status.subs.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    status.subs[i].active
                        ? Icons.play_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: status.subs[i].active
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  title: Text('分路 ${i + 1}'),
                  subtitle: Text(status.subs[i].active ? '出水中' : '空闲'),
                  trailing: Text(
                    '${status.subs[i].out.toStringAsFixed(2)} 升',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _modeText(int mode) {
    switch (mode) {
      case 0:
        return '待机';
      case 1:
        return '计费';
      case 2:
        return '免费';
      default:
        return '$mode';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
