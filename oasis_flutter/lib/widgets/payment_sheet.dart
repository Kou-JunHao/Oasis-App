import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 显示支付方式底部弹窗（充值使用）
Future<void> showPaymentSheet({
  required BuildContext context,
  required double amount,
  required Function(String paymentType) onPaymentSelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RechargePaymentSheet(
      amount: amount,
      onPaymentSelected: onPaymentSelected,
    ),
  );
}

/// 显示支付方式底部弹窗（旧版本兼容）
void showPaymentSheetLegacy(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const PaymentBottomSheet(),
  );
}

/// 支付方式底部弹窗
class PaymentBottomSheet extends StatelessWidget {
  const PaymentBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: Colors.pink.shade400,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '支持作者',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 支付方式选项
            _PaymentOption(
              title: '支付宝',
              subtitle: '推荐使用支付宝扫码',
              icon: Icons.qr_code_rounded,
              color: Colors.blue,
              imagePath: 'assets/images/alipay_qr.png',
              onTap: () {
                Navigator.pop(context);
                _showQRCode(context, '支付宝', 'assets/images/alipay_qr.png', Colors.blue);
              },
            ),
            
            const Divider(height: 1),
            
            _PaymentOption(
              title: '微信',
              subtitle: '推荐使用微信支付',
              icon: Icons.qr_code_rounded,
              color: Colors.green,
              imagePath: 'assets/images/wechat_qr.png',
              onTap: () {
                Navigator.pop(context);
                _showQRCode(context, '微信', 'assets/images/wechat_qr.png', Colors.green);
              },
            ),
            
            const Divider(height: 1),
            
            _PaymentOption(
              title: 'Buy Me a Coffee',
              subtitle: 'Support via Buymeacoffee',
              icon: Icons.coffee_rounded,
              color: Colors.amber.shade700,
              imagePath: '',
              onTap: () {
                Navigator.pop(context);
                _launchBuyMeACoffee();
              },
            ),
            
            const SizedBox(height: 24),
            
            // 提示文字
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '您的支持是我持续更新的动力 ❤️',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  static void _showQRCode(BuildContext context, String title, String imagePath, Color color) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$title 收款码',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // 二维码图片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Image.asset(
                  imagePath,
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '二维码图片未找到',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '请将二维码图片放入\nassets/images/',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 提示文字
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '长按二维码保存或截图使用',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                        ),
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
  }

  static void _launchBuyMeACoffee() async {
    final url = Uri.parse('https://buymeacoffee.com/skkk');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

/// 支付选项组件
class _PaymentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String imagePath;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// 充值支付选择弹窗
class _RechargePaymentSheet extends StatefulWidget {
  final double amount;
  final Function(String paymentType) onPaymentSelected;

  const _RechargePaymentSheet({
    required this.amount,
    required this.onPaymentSelected,
  });

  @override
  State<_RechargePaymentSheet> createState() => _RechargePaymentSheetState();
}

class _RechargePaymentSheetState extends State<_RechargePaymentSheet> {
  String? _selectedPaymentType;

  final List<_PaymentOptionData> _paymentOptions = [
    _PaymentOptionData(
      type: 'alipay',
      name: '支付宝',
      icon: Icons.payment,
      color: Colors.blue,
    ),
    _PaymentOptionData(
      type: 'wechat',
      name: '微信支付',
      icon: Icons.chat_bubble,
      color: Colors.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                    '选择支付方式',
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

          // 支付金额
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '支付金额',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '¥${widget.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 支付方式列表
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _paymentOptions.length,
            itemBuilder: (context, index) {
              final option = _paymentOptions[index];

              return RadioListTile<String>(
                value: option.type,
                groupValue: _selectedPaymentType,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentType = value;
                  });
                },
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: option.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        option.icon,
                        color: option.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(option.name),
                  ],
                ),
                activeColor: colorScheme.primary,
              );
            },
          ),

          // 确认按钮
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: FilledButton(
              onPressed: _selectedPaymentType != null
                  ? () => widget.onPaymentSelected(_selectedPaymentType!)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '确认支付',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 支付选项数据模型
class _PaymentOptionData {
  final String type;
  final String name;
  final IconData icon;
  final Color color;

  _PaymentOptionData({
    required this.type,
    required this.name,
    required this.icon,
    required this.color,
  });
}
