import 'package:flutter/material.dart';

/// 显示确认底部弹窗
Future<bool?> showConfirmBottomSheet({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = '确定',
  String cancelText = '取消',
  IconData? icon,
  Color? iconColor,
  bool isDangerous = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动条
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 图标
              if (icon != null) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: (iconColor ?? (isDangerous 
                      ? Theme.of(context).colorScheme.error 
                      : Theme.of(context).colorScheme.primary)).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: iconColor ?? (isDangerous 
                      ? Theme.of(context).colorScheme.error 
                      : Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // 标题
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // 消息
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // 按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isDangerous 
                          ? Theme.of(context).colorScheme.error 
                          : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 显示选项菜单底部弹窗
Future<T?> showMenuBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<MenuOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // 选项列表
            ...options.map((option) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: option.color?.withOpacity(0.1) ?? 
                    Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  option.icon,
                  color: option.color ?? Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(option.title),
              subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => Navigator.pop(context, option.value),
            )),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

/// 菜单选项
class MenuOption<T> {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final T value;

  const MenuOption({
    required this.title,
    this.subtitle,
    required this.icon,
    this.color,
    required this.value,
  });
}

/// 显示输入表单底部弹窗
Future<Map<String, String>?> showInputBottomSheet({
  required BuildContext context,
  required String title,
  required List<InputField> fields,
  String confirmText = '确定',
  String cancelText = '取消',
  IconData? icon,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => _InputBottomSheetContent(
      title: title,
      fields: fields,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
    ),
  );
}

/// 输入底部弹窗内容组件
class _InputBottomSheetContent extends StatefulWidget {
  final String title;
  final List<InputField> fields;
  final String confirmText;
  final String cancelText;
  final IconData? icon;

  const _InputBottomSheetContent({
    required this.title,
    required this.fields,
    required this.confirmText,
    required this.cancelText,
    this.icon,
  });

  @override
  State<_InputBottomSheetContent> createState() => _InputBottomSheetContentState();
}

class _InputBottomSheetContentState extends State<_InputBottomSheetContent> {
  late final Map<String, TextEditingController> _controllers;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (var field in widget.fields)
        field.key: TextEditingController(text: field.initialValue)
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // 拖动条
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // 标题
                  Row(
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 28),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 输入字段
                  ...widget.fields.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _controllers[field.key],
                      decoration: InputDecoration(
                        labelText: field.label,
                        hintText: field.hint,
                        helperText: field.helper,
                        prefixIcon: field.icon != null ? Icon(field.icon) : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: field.isPassword,
                      keyboardType: field.keyboardType,
                      maxLines: field.maxLines ?? 1,
                      validator: field.validator,
                    ),
                  )),
                  
                  const SizedBox(height: 8),
                  
                  // 按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(widget.cancelText),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              final result = {
                                for (var field in widget.fields)
                                  field.key: _controllers[field.key]!.text.trim()
                              };
                              Navigator.pop(context, result);
                            }
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(widget.confirmText),
                        ),
                      ),
                    ],
                  ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 输入字段
class InputField {
  final String key;
  final String label;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? initialValue;
  final String? Function(String?)? validator;
  final int? maxLines;

  const InputField({
    required this.key,
    required this.label,
    this.hint,
    this.helper,
    this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.initialValue,
    this.validator,
    this.maxLines,
  });
}
