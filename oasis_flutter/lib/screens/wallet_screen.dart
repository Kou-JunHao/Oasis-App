import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../models/device_detail_models.dart';
import '../providers/score_provider.dart';
import '../providers/wallet_provider.dart';
import 'recharge_screen.dart';
import 'score_screen.dart';

/// 钱包页面
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // 加载钱包余额
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadWalletOrder();
      context.read<WalletProvider>().fetchWalletBalance();
      // 钱包卡片上要显示积分，顺带取一次
      context.read<ScoreProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (walletProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (walletProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 64, color: colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      walletProvider.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        walletProvider.fetchWalletBalance();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Material 3中等标题AppBar
              SliverAppBar.medium(
                title: const Text('我的钱包'),
                floating: false,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.reorder_rounded),
                    onPressed: () => _showWalletOrderSheet(context),
                    tooltip: '钱包排序',
                  ),
                  IconButton(
                    icon: const Icon(Icons.history_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrderHistoryScreen(),
                        ),
                      );
                    },
                    tooltip: '交易记录',
                  ),
                ],
              ),
              
              // 内容
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 余额卡片
                    _buildBalanceCard(context, walletProvider),
                    const SizedBox(height: 24),
                    // 充值按钮
                    _buildRechargeButton(context),
                    const SizedBox(height: 24),
                    // 积分任务入口
                    _buildScoreEntry(context),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 余额构成明细（线下/线上 × 现金/赠送），并补充账号与结算端点信息
  Future<void> _showBalanceDetail(BuildContext context, WalletData wallet) async {
    final api = context.read<ApiService>();
    WalletDetail? remote;
    if (wallet.id != null && wallet.id!.isNotEmpty) {
      try {
        final response = await api.getWalletDetail(wallet.id!);
        if (response.isSuccess) remote = response.data;
      } catch (_) {
        // 明细补充失败不影响本地余额展示
      }
    }

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final endpointName =
            remote?.endpointName ?? wallet.ep?.name ?? wallet.name ?? '钱包';
        final owner = remote?.ownerName ??
            wallet.owner?.id ??
            '';

        Widget row(String label, double value) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  Text(
                    '¥${value.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '余额明细',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  endpointName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (remote != null && remote.ownerPhone.isNotEmpty)
                  Text(
                    '账号 $owner · ${remote.ownerPhone}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Divider(height: 24),
                row('线上现金', wallet.olCash ?? 0),
                row('线上赠送', wallet.olGift ?? 0),
                row('线下现金', wallet.ofCash ?? 0),
                row('线下赠送', wallet.ofGift ?? 0),
                const Divider(height: 24),
                Row(
                  children: [
                    Text(
                      '合计',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '¥${wallet.totalBalance.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (_formatUtime(wallet.utime) != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '更新时间 ${_formatUtime(wallet.utime)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 后端 utime 可能是毫秒时间戳字符串
  String? _formatUtime(String? raw) {
    final ms = int.tryParse(raw ?? '');
    if (ms == null || ms <= 0) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  /// 卡片上的积分胶囊：显示积分数量与折算金额
  Widget _buildScorePill(
    BuildContext context,
    ScoreProvider provider,
    ColorScheme colorScheme,
  ) {
    final overview = provider.overview;
    final text = overview.validScore > 0
        ? '积分 ${overview.validScore} · ${overview.moneyText}'
        : '积分 --';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 14,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// 积分任务入口
  Widget _buildScoreEntry(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.workspace_premium_rounded, color: colorScheme.primary),
        title: const Text('积分任务'),
        subtitle: const Text('每日签到、做任务赚积分'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScoreScreen()),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletProvider provider) {    final totalBalance = provider.totalBalance;  // 使用总余额
    final allWallets = provider.allWallets;
    final colorScheme = Theme.of(context).colorScheme;

    if (allWallets.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: const Center(
            child: Text('暂无钱包数据'),
          ),
        ),
      );
    }

    // 使用PageView支持左右滑动
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          provider.switchWallet(index);
        },
        itemCount: allWallets.length,
        itemBuilder: (context, index) {
          final wallet = allWallets[index];
          
          return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showBalanceDetail(context, wallet),
                child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部：钱包图标 + 页码指示
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        if (allWallets.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chevron_left,
                                  size: 16,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                                Text(
                                  '${index + 1}/${allWallets.length}',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 钱包名称（单行，避免长名称撑破卡片）
                    Text(
                      wallet.ep?.name ?? wallet.name ?? '未命名钱包',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 余额与积分胶囊同一行：余额占主位，积分贴右下
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '¥',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    wallet.displayBalance.toStringAsFixed(2),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onPrimaryContainer,
                                          letterSpacing: -1,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildScorePill(
                          context,
                          context.watch<ScoreProvider>(),
                          colorScheme,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 底部：多钱包时显示总余额
                    if (allWallets.length > 1)
                      Text(
                        '总余额 ¥${totalBalance.toStringAsFixed(2)} · '
                        '点卡片查看余额构成',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      )
                    else
                      Text(
                        '点卡片查看余额构成',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
                ),
              ),
            );
        },
      ),
    );
  }

  /// 钱包排序：拖拽调整卡片顺序并保存到本地
  Future<void> _showWalletOrderSheet(BuildContext context) async {
    final provider = context.read<WalletProvider>();
    final wallets = provider.allWallets;
    if (wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前只有一个钱包，无需排序'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ids = wallets.map((w) => w.id ?? '').toList();
    final names = {
      for (final w in wallets)
        (w.id ?? ''): (w.ep?.name ?? w.name ?? '未命名钱包'),
    };

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '钱包排序',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '拖动调整顺序',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: ids.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setSheetState(() {
                      final moved = ids.removeAt(oldIndex);
                      ids.insert(newIndex, moved);
                    });
                  },
                  itemBuilder: (context, i) => ListTile(
                    key: ValueKey('wallet-order-${ids[i]}-$i'),
                    leading: const Icon(Icons.drag_indicator_rounded),
                    title: Text(
                      names[ids[i]] ?? '未命名钱包',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: i == 0 ? const Text('默认展示') : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, const <String>[]),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('恢复默认'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, ids),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('保存顺序'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = result.isEmpty ? '已恢复默认排序（按余额）' : '钱包顺序已保存';
    if (result.isEmpty) {
      await provider.resetWalletOrder();
    } else {
      await provider.saveWalletOrder(result);
    }
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildRechargeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RechargeScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_card_rounded, size: 24),
        label: const Text('立即充值'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 显示钱包选择器
  void _showWalletSelector(BuildContext context, WalletProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final allWallets = provider.allWallets;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择钱包',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 钱包列表
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allWallets.length,
                itemBuilder: (context, index) {
                  final wallet = allWallets[index];
                  final isSelected = provider.currentWalletIndex == index;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? colorScheme.primaryContainer 
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: isSelected 
                            ? colorScheme.onPrimaryContainer 
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      wallet.ep?.name ?? wallet.name ?? '钱包 ${index + 1}',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '¥${wallet.displayBalance.toStringAsFixed(2)}',
                    ),
                    trailing: isSelected 
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : null,
                    onTap: () {
                      provider.switchWallet(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 订单历史页面
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // 加载订单列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('交易记录'),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          if (walletProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (walletProvider.orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无交易记录', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await walletProvider.fetchOrders();
            },
            child: ListView.builder(
              itemCount: walletProvider.orders.length,
              itemBuilder: (context, index) {
                final order = walletProvider.orders[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      order.cata == '1'
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                    ),
                  ),
                  title: Text(order.message),
                  subtitle: Text(order.createTime),
                  trailing: Text(
                    order.formattedAmount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: order.cata == '1' ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
