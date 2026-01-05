// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:oasis_flutter/main.dart';
import 'package:oasis_flutter/theme/theme_provider.dart';
import 'package:oasis_flutter/providers/auth_provider.dart';
import 'package:oasis_flutter/providers/device_provider.dart';
import 'package:oasis_flutter/providers/order_provider.dart';
import 'package:oasis_flutter/providers/wallet_provider.dart';
import 'package:oasis_flutter/services/api_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 创建API服务
    final apiService = ApiService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => DeviceProvider(apiService)),
          ChangeNotifierProvider(create: (_) => OrderProvider(apiService)),
          ChangeNotifierProvider(create: (_) => WalletProvider(apiService)),
        ],
        child: OasisApp(
          apiService: apiService,
        ),
      ),
    );

    // 等待widget构建完成
    await tester.pumpAndSettle();

    // 由于没有登录,应该显示登录界面
    expect(find.text('欢迎使用 Oasis'), findsWidgets);
  });
}
