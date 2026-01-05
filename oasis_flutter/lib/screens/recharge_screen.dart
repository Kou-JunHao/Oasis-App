import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../models/api_models.dart';

/// 充值页面
class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  int? _selectedWalletIndex;
  String? _selectedProductId;
  double? _selectedAmount;
  List<Product> _products = [];  // 从服务器加载的产品列表
  bool _isLoadingProducts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 加载钱包列表
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      walletProvider.fetchWalletBalance();
    });
  }

  /// 加载充值产品列表
  Future<void> _loadRechargeProducts(String endpointId) async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      await walletProvider.fetchRechargeProducts(endpointId);
      
      setState(() {
        _products = walletProvider.products;
        _isLoadingProducts = false;
      });

      // 如果没有产品，显示提示
      if (_products.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该钱包暂无可用充值产品')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingProducts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载产品失败: $e')),
        );
      }
    }
  }

  /// 过滤掉测试钱包，只显示可充值的钱包
  List<WalletData> _filterRechargeableWallets(List<WalletData> wallets) {
    // 过滤掉测试钱包
    final excludeNames = ['测试默认值', '硬件测试'];
    
    return wallets.where((wallet) {
      final walletName = wallet.ep?.name ?? wallet.name ?? '';
      return !excludeNames.any((exclude) => walletName.contains(exclude));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final walletProvider = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('钱包充值'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 钱包选择区域
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, 
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '选择充值钱包',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildWalletSelector(walletProvider, colorScheme),
                ],
              ),
            ),

            const Divider(height: 1),

            // 充值金额选择
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments_rounded, 
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '选择充值金额',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAmountGrid(colorScheme),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          child: FilledButton(
            onPressed: _selectedWalletIndex != null && 
                      _selectedProductId != null &&
                      _selectedAmount != null
                ? () => _handleRecharge(context, walletProvider)
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _selectedAmount != null && _selectedProductId != null
                ? _buildRechargeButtonText()
                : const Text(
                    '请选择充值金额',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSelector(WalletProvider walletProvider, ColorScheme colorScheme) {
    final allWallets = walletProvider.allWallets;
    final wallets = _filterRechargeableWallets(allWallets);  // 过滤测试钱包

    if (wallets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('暂无可用钱包'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 提示信息
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_rounded,
                size: 20,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '请选择正确的钱包进行充值，充值后余额将到账至选中的钱包',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 钱包列表
        ...List.generate(wallets.length, (index) {
          final wallet = wallets[index];
          // 需要找到该钱包在全部钱包中的索引
          final originalIndex = allWallets.indexOf(wallet);
          final isSelected = _selectedWalletIndex == originalIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: isSelected ? 2 : 0,
            color: isSelected 
                ? colorScheme.primaryContainer 
                : colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected 
                    ? colorScheme.primary 
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _selectedWalletIndex = originalIndex;  // 使用原始索引
                  _selectedProductId = null;  // 重置产品选择
                  _selectedAmount = null;
                });
                // 加载该钱包的产品列表
                final endpointId = wallet.ep?.id;
                if (endpointId != null && endpointId.isNotEmpty) {
                  _loadRechargeProducts(endpointId);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: isSelected 
                          ? colorScheme.onPrimaryContainer 
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wallet.ep?.name ?? wallet.name ?? '钱包 ${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? colorScheme.onPrimaryContainer 
                                  : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '余额: ¥${wallet.displayBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected 
                                  ? colorScheme.onPrimaryContainer 
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        }),
      ],
    );
  }

  Widget _buildAmountGrid(ColorScheme colorScheme) {
    if (_isLoadingProducts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '请先选择钱包',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final isSelected = _selectedProductId == product.id;

        return Card(
          elevation: isSelected ? 2 : 0,
          color: isSelected 
              ? colorScheme.primaryContainer 
              : colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected 
                  ? colorScheme.primary 
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _selectedProductId = product.id;
                _selectedAmount = product.price;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 优惠标签
                  if (product.hasDiscount)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      margin: const EdgeInsets.only(bottom: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        '活动',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // 显示逻辑：
                  // 有优惠：显示充值金额 + 赠送提示
                  // 无优惠：只显示充值金额
                  if (product.hasDiscount) ...[
                    const SizedBox(height: 1),
                    // 充值金额
                    Text(
                      '¥${product.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? colorScheme.onPrimaryContainer 
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // 赠送金额提示
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '+¥${product.discountAmount!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    // 普通充值，只显示金额
                    Text(
                      '¥${product.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? colorScheme.onPrimaryContainer 
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRechargeButtonText() {
    // 查找当前选中的产品
    final product = _products.firstWhere(
      (p) => p.id == _selectedProductId,
      orElse: () => _products.first,
    );

    if (product.hasDiscount) {
      // 有优惠：显示 "50+5¥" 效果
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          children: [
            const TextSpan(text: '充值 '),
            TextSpan(text: '${product.price.toStringAsFixed(0)}'),
            TextSpan(
              text: '+${product.discountAmount!.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.red.shade300,
                fontWeight: FontWeight.bold,
              ),
            ),
            const TextSpan(text: '¥'),
          ],
        ),
      );
    } else {
      // 无优惠：显示 "充值 ¥50"
      return Text(
        '充值 ¥${_selectedAmount!.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );
    }
  }

  void _handleRecharge(BuildContext context, WalletProvider walletProvider) async {
    if (_selectedWalletIndex == null || _selectedAmount == null || _selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择钱包和充值金额')),
      );
      return;
    }

    final wallet = walletProvider.allWallets[_selectedWalletIndex!];
    final endpointId = wallet.ep?.id;
    final ownerId = wallet.owner?.id;
    
    if (endpointId == null || endpointId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('钱包端点ID无效')),
      );
      return;
    }

    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户ID无效')),
      );
      return;
    }

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在处理充值...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 一键充值流程
      final success = await walletProvider.oneClickRecharge(
        productId: _selectedProductId!,
        endpointId: endpointId,
        ownerId: ownerId,
      );

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框

      if (success) {
        // 充值成功，返回并刷新
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('充值成功！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // 返回钱包页面
      } else {
        // 显示错误信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.error ?? '充值失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载对话框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('充值出错: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
