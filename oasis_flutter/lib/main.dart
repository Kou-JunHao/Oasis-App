import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/order_provider.dart';
import 'services/api_service.dart';
import 'services/client_version_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/disclaimer_dialog.dart';

/// 全局 SnackBar 载体：会话失效时无论当前在哪个页面都能提示
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启动即异步解析伪装版本号（用户自定义 > 线上最新 > 缓存 > 基线）。
  // 不 await：网络慢或离线时也不阻塞启动，首个请求会按超时取当前已知值。
  unawaited(ClientVersionService.resolve());

  // 创建API服务单例
  final apiService = ApiService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DeviceProvider(apiService)),
        ChangeNotifierProvider(create: (_) => OrderProvider(apiService)),
        ChangeNotifierProvider(create: (_) => WalletProvider(apiService)),
      ],
      child: OasisApp(apiService: apiService),
    ),
  );
}

class OasisApp extends StatefulWidget {
  final ApiService apiService;

  const OasisApp({super.key, required this.apiService});

  @override
  State<OasisApp> createState() => _OasisAppState();
}

class _OasisAppState extends State<OasisApp> {
  bool? _disclaimerAccepted;
  String? _lastSyncedToken;

  @override
  void initState() {
    super.initState();
    _checkDisclaimerStatus();
  }

  /// 同步Token到ApiService（仅在Token变化时）
  void _syncTokenIfNeeded(String? token) {
    if (token != _lastSyncedToken) {
      _lastSyncedToken = token;
      if (token != null && token.isNotEmpty) {
        widget.apiService.setToken(token);
      } else {
        widget.apiService.clearToken();
      }
    }
  }

  /// 检查免责声明状态
  Future<void> _checkDisclaimerStatus() async {
    final accepted = await DisclaimerDialog.isDisclaimerAccepted();
    if (mounted) {
      setState(() {
        _disclaimerAccepted = accepted;
      });

      // 如果未接受,显示对话框
      if (!accepted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showDisclaimerDialog();
        });
      }
    }
  }

  void _showDisclaimerDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DisclaimerDialog(
        onAccepted: () async {
          Navigator.of(context).pop();
          if (mounted) {
            setState(() {
              _disclaimerAccepted = true;
            });
          }
        },
        onCancelled: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 等待免责声明状态加载
    if (_disclaimerAccepted == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, authProvider, _) {
        // 等待AuthProvider初始化完成
        if (!authProvider.isInitialized) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        // 同步token到ApiService（仅在Token变化时）
        _syncTokenIfNeeded(authProvider.token);

        // 服务端会话失效：已自动登出并回到登录页，这里给出提示
        if (authProvider.sessionExpired) {
          authProvider.acknowledgeSessionExpired();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appScaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text('登录状态已过期，请重新登录')),
            );
          });
        }

        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            // 更新动态颜色方案
            if (themeProvider.useDynamicColor &&
                !themeProvider.isDynamicColorSchemeSame(
                  lightDynamic,
                  darkDynamic,
                )) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                themeProvider.updateDynamicColorScheme(
                  lightDynamic,
                  darkDynamic,
                );
              });
            }

            return MaterialApp(
              title: 'Oasis',
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: appScaffoldMessengerKey,
              theme: themeProvider.getLightTheme(),
              darkTheme: themeProvider.getDarkTheme(),
              themeMode: themeProvider.themeMode,
              home: authProvider.isLoggedIn
                  ? const HomeScreen() // 已登录直接进入主页
                  : const LoginScreen(), // 未登录显示登录界面
            );
          },
        );
      },
    );
  }
}
