import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'recharge_screen.dart';

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
      context.read<WalletProvider>().fetchWalletBalance();
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
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, WalletProvider provider) {
    final totalBalance = provider.totalBalance;  // 使用总余额
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
      height: 220,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          provider.switchWallet(index);
        },
        itemCount: allWallets.length,
        itemBuilder: (context, index) {
          final wallet = allWallets[index];
          final isCurrentPage = provider.currentWalletIndex == index;
          
          return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
                        // 滑动提示（横向箭头）
                        if (allWallets.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    const SizedBox(height: 16),
                    // 钱包名称
                    if (wallet.ep?.name != null || wallet.name != null) ...[
                      Text(
                        wallet.ep?.name ?? wallet.name!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    // 钱包余额
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '¥',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wallet.displayBalance.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    // 总余额提示
                    if (allWallets.length > 1) ...[
                      const SizedBox(height: 8),
                      Text(
                        '总余额: ¥${totalBalance.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
        },
      ),
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
