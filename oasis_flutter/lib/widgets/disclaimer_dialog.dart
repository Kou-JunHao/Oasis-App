import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// 免责声明对话框 - 对应Kotlin的DisclaimerDialog
class DisclaimerDialog extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onCancelled;

  const DisclaimerDialog({
    super.key,
    required this.onAccepted,
    required this.onCancelled,
  });

  /// 检查是否已接受免责声明
  static Future<bool> isDisclaimerAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('disclaimer_accepted') ?? false;
  }

  /// 重置免责声明状态
  static Future<void> resetDisclaimerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('disclaimer_accepted');
  }

  @override
  State<DisclaimerDialog> createState() => _DisclaimerDialogState();
}

class _DisclaimerDialogState extends State<DisclaimerDialog> {
  static const int _countdownSeconds = 5;
  int _secondsLeft = _countdownSeconds;
  Timer? _countdownTimer;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _isButtonEnabled = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _saveDisclaimerAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disclaimer_accepted', true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 8),
          const Text('免责声明'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '重要提示',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              '本应用仅供学习和研究使用，使用本应用前请仔细阅读以下内容：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildDisclaimerItem('1. 本应用为非官方应用，与官方无任何关联。'),
            _buildDisclaimerItem('2. 使用本应用产生的任何后果由用户自行承担。'),
            _buildDisclaimerItem('3. 本应用不收集、存储或传输您的任何个人敏感信息。'),
            _buildDisclaimerItem('4. 请妥善保管您的账号信息，不要与他人分享。'),
            _buildDisclaimerItem('5. 如有任何问题，请立即停止使用本应用。'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '继续使用即表示您已阅读并同意以上所有条款',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            _countdownTimer?.cancel();
            Navigator.of(context).pop();
            widget.onCancelled();
          },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isButtonEnabled
              ? () async {
                  _countdownTimer?.cancel();
                  await _saveDisclaimerAccepted();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    widget.onAccepted();
                  }
                }
              : null,
          child: Text(
            _isButtonEnabled ? '同意并继续' : '同意并继续 ($_secondsLeft)',
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
