import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../models/api_models.dart';

/// 订单页面 - 参考Kotlin的OrderFragment
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          return CustomScrollView(
            slivers: [
              // Material 3中等标题AppBar
              SliverAppBar.medium(
                title: const Text('订单记录'),
                floating: false,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list_rounded),
                    onPressed: () => _showFilterDialog(context),
                    tooltip: '筛选',
                  ),
                ],
              ),
              
              // 筛选提示
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Card(
                    color: colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, 
                            color: colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '当前筛选: ${_getFilterText(orderProvider.filterStatus)}',
                              style: TextStyle(
                                color: colorScheme.onSecondaryContainer,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 订单列表
              _buildOrderList(context, orderProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, OrderProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (provider.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => provider.refreshOrders(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.orders.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 64, color: colorScheme.outlineVariant),
              const SizedBox(height: 16),
              Text(
                '暂无订单',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final order = provider.orders[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrderCard(order: order),
            );
          },
          childCount: provider.orders.length,
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选订单'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterOption(
              label: '全部',
              value: null,
              currentValue: provider.filterStatus,
              onTap: () {
                Navigator.pop(context);
                provider.fetchOrders(status: null);
              },
            ),
            _FilterOption(
              label: '未付款',
              value: 1,
              currentValue: provider.filterStatus,
              onTap: () {
                Navigator.pop(context);
                provider.fetchOrders(status: 1);
              },
            ),
            _FilterOption(
              label: '待确认',
              value: 2,
              currentValue: provider.filterStatus,
              onTap: () {
                Navigator.pop(context);
                provider.fetchOrders(status: 2);
              },
            ),
            _FilterOption(
              label: '已付款',
              value: 3,
              currentValue: provider.filterStatus,
              onTap: () {
                Navigator.pop(context);
                provider.fetchOrders(status: 3);
              },
            ),
            _FilterOption(
              label: '订单失败',
              value: 4,
              currentValue: provider.filterStatus,
              onTap: () {
                Navigator.pop(context);
                provider.fetchOrders(status: 4);
              },
            ),
            _FilterOption(
              label: '已取消',
              value: 9,
              currentValue: provider.filterStatus,
              onTap: () {
                Navigator.pop(context);
                provider.fetchOrders(status: 9);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterText(int? status) {
    if (status == null) return '全部订单';
    final provider = Provider.of<OrderProvider>(context, listen: false);
    return provider.getOrderStatusText(status);
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final int? value;
  final int? currentValue;
  final VoidCallback onTap;

  const _FilterOption({
    required this.label,
    required this.value,
    required this.currentValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == currentValue;
    
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: onTap,
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderData order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 订单状态图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(order.status),
                  color: _getStatusColor(order.status),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // 订单信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.message.isNotEmpty ? order.message : '订单 #${order.id}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '¥${order.payment.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusText(order.status),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(order.status),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.createTime,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 箭头
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 订单状态映射：与Kotlin保持一致
  // 1=未付款, 2=待确认, 3=已付款, 4=订单失败, 9=已取消
  Color _getStatusColor(int status) {
    switch (status) {
      case 1: // 未付款
        return Colors.orange;
      case 2: // 待确认
        return Colors.blue;
      case 3: // 已付款
        return Colors.green;
      case 4: // 订单失败
        return Colors.red;
      case 9: // 已取消
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(int status) {
    switch (status) {
      case 1: // 未付款
        return Icons.pending_rounded;
      case 2: // 待确认
        return Icons.hourglass_empty_rounded;
      case 3: // 已付款
        return Icons.check_circle_rounded;
      case 4: // 订单失败
        return Icons.error_rounded;
      case 9: // 已取消
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return '未付款';
      case 2:
        return '待确认';
      case 3:
        return '已付款';
      case 4:
        return '订单失败';
      case 9:
        return '已取消';
      default:
        return '未知状态';
    }
  }

  void _showOrderDetails(BuildContext context) {
    // TODO: 实现订单详情页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订单详情功能待实现')),
    );
  }
}



