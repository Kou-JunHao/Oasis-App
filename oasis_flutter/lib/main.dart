import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/order_provider.dart';
import 'providers/score_provider.dart';
import 'app_globals.dart';
import 'services/api_service.dart';
import 'services/client_version_service.dart';
import 'services/update_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/disclaimer_dialog.dart';


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
        // 页面可直接读取 ApiService（如设备详情页查询实时状态）
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DeviceProvider(apiService)),
        ChangeNotifierProvider(create: (_) => OrderProvider(apiService)),
        ChangeNotifierProvider(create: (_) => WalletProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ScoreProvider(apiService)),
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
    _autoCheckUpdate();
  }

  /// 启动后按「自动检查更新」开关检查一次
  ///
  /// 更新面板挂在根导航器上，因此只要开关开启，任何页面都能收到更新提示，
  /// 不再依赖用户是否停留在登录页。
  void _autoCheckUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 稍作延迟，避免与首屏数据加载抢占网络与界面
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await UpdateService.autoCheckOnStartup();
    });
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

        // 服务端会话失效：已自动登出，这里弹出所有二级页面并提示
        if (authProvider.sessionExpired) {
          authProvider.acknowledgeSessionExpired();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 处在二级页面（如积分任务、订单详情）时，home 切换不足以回到登录页，
            // 需要把压栈的路由全部弹出
            appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
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
              navigatorKey: appNavigatorKey,
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
