import 'package:flutter/material.dart';

/// 颜色选择器对话框
class ColorPickerDialog extends StatefulWidget {
  final Color? initialColor;
  
  const ColorPickerDialog({
    super.key,
    this.initialColor,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;

  // 预设颜色列表
  static const List<Color> _presetColors = [
    Color(0xFF2196F3), // 蓝色
    Color(0xFF4CAF50), // 绿色
    Color(0xFFF44336), // 红色
    Color(0xFFFF9800), // 橙色
    Color(0xFF9C27B0), // 紫色
    Color(0xFFE91E63), // 粉色
    Color(0xFF00BCD4), // 青色
    Color(0xFFFFEB3B), // 黄色
    Color(0xFF795548), // 棕色
    Color(0xFF607D8B), // 蓝灰色
    Color(0xFF3F51B5), // 靛蓝色
    Color(0xFF009688), // 蓝绿色
    Color(0xFFFF5722), // 深橙色
    Color(0xFF8BC34A), // 浅绿色
    Color(0xFFCDDC39), // 酸橙色
    Color(0xFFFFC107), // 琥珀色
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor ?? _presetColors[0];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('选择主题颜色'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前选中的颜色预览
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '预览效果',
                  style: TextStyle(
                    color: _selectedColor.computeLuminance() > 0.5 
                        ? Colors.black 
                        : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 颜色选项
            Text(
              '选择预设颜色',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 颜色网格
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _presetColors.length,
              itemBuilder: (context, index) {
                final color = _presetColors[index];
                // ignore: deprecated_member_use
                final isSelected = color.value == _selectedColor.value;
                
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5 
                                ? Colors.black 
                                : Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 显示颜色选择器对话框
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  Color? initialColor,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => ColorPickerDialog(initialColor: initialColor),
  );
}
