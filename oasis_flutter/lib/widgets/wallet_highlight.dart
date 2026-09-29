import 'package:flutter/material.dart';

/// 确认弹窗中钱包名称的高亮色（橙色）
const Color kWalletNameColor = Color(0xFFE65100);

/// 生成「钱包名」高亮文本片段
///
/// 充值与积分兑换前都需要用户二次确认，钱包名加粗橙色显示，
/// 便于一眼核对，避免充错/兑换错钱包。
TextSpan highlightedWalletSpan(String name, {TextStyle? baseStyle}) {
  final style = (baseStyle ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.bold,
    color: kWalletNameColor,
  );
  return TextSpan(
    children: [
      TextSpan(text: '「', style: baseStyle),
      TextSpan(text: name, style: style),
      TextSpan(text: '」', style: baseStyle),
    ],
  );
}
