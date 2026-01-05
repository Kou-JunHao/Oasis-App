import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/order_provider.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/disclaimer_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

  const OasisApp({
    super.key,
    required this.apiService,
  });

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
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, authProvider, _) {
        // 等待AuthProvider初始化完成
        if (!authProvider.isInitialized) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        // 同步token到ApiService（仅在Token变化时）
        _syncTokenIfNeeded(authProvider.token);

        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            // 更新动态颜色方案
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (themeProvider.useDynamicColor) {
                themeProvider.updateDynamicColorScheme(lightDynamic, darkDynamic);
              }
            });

            return MaterialApp(
              title: 'Oasis',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.getLightTheme(),
              darkTheme: themeProvider.getDarkTheme(),
              themeMode: themeProvider.themeMode,
              home: authProvider.isLoggedIn 
                  ? const HomeScreen()  // 已登录直接进入主页
                  : const LoginScreen(), // 未登录显示登录界面
            );
          },
        );
      },
    );
  }
}
