import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

/// 认证状态提供者
class AuthProvider extends ChangeNotifier {
  late final AuthService _authService;
  final ApiService _apiService;
  SharedPreferences? _prefs;
  
  User? _user;
  String? _token;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  AuthProvider(this._apiService) {
    _authService = AuthService(_apiService);
    _initFuture = _initPreferences();
  }

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  /// 初始化 SharedPreferences
  Future<void> _initPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadUserData();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (AppConfig.isDebugMode) {
        // ignore: avoid_print
        print('初始化SharedPreferences失败: $e');
      }
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 等待初始化完成
  Future<void> ensureInitialized() async {
    if (_initFuture != null) {
      await _initFuture;
    }
  }

  /// 加载用户数据
  Future<void> _loadUserData() async {
    if (_prefs == null) return;
    
    final token = _prefs!.getString(AppConfig.keyUserToken);
    final userJson = _prefs!.getString('user_data');

    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('=== 加载用户数据 ===');
      // ignore: avoid_print
      print('Token: ${token != null ? "存在(${token.substring(0, 10)}...)" : "不存在"}');
      // ignore: avoid_print
      print('UserData: ${userJson != null ? "存在" : "不存在"}');
    }

    if (token != null && userJson != null) {
      try {
        _token = token;
        _user = User.fromJson(jsonDecode(userJson));
        _isLoggedIn = true;
        
        if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('✅ 登录状态加载成功: user=${_user?.username}, phone=${_user?.phone}');
        }
        
        notifyListeners();
      } catch (e) {
        if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('❌ 加载用户数据失败: $e');
          // ignore: avoid_print
          print('UserJson内容: $userJson');
        }
        await _clearUserData();
      }
    } else {
      if (AppConfig.isDebugMode) {
        // ignore: avoid_print
        print('ℹ️ 没有保存的登录信息');
      }
    }
  }

  /// 保存用户数据
  Future<void> _saveUserData() async {
    if (_prefs == null) {
      if (AppConfig.isDebugMode) {
        // ignore: avoid_print
        print('❌ SharedPreferences未初始化，无法保存用户数据');
      }
      return;
    }
    
    if (_token != null && _user != null) {
      final userJson = jsonEncode(_user!.toJson());
      await _prefs!.setString(AppConfig.keyUserToken, _token!);
      await _prefs!.setString('user_data', userJson);
      
      if (AppConfig.isDebugMode) {
        // ignore: avoid_print
        print('=== 保存用户数据 ===');
        // ignore: avoid_print
        print('Token: ${_token!.substring(0, 10)}...');
        // ignore: avoid_print
        print('User: ${_user?.username}, Phone: ${_user?.phone}');
        // ignore: avoid_print
        print('UserJson: $userJson');
        // ignore: avoid_print
        print('✅ 保存成功');
      }
    }
  }

  /// 清除用户数据
  Future<void> _clearUserData() async {
    if (_prefs == null) return;
    
    await _prefs!.remove(AppConfig.keyUserToken);
    await _prefs!.remove('user_data');
  }

  /// 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 设置错误消息
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// 获取短信验证码
  Future<bool> getSmsCode(String phone, String captcha, int s) async {
    try {
      _setLoading(true);
      _setError(null);

      final request = GetCodeRequest(
        s: s,
        authCode: captcha,
        un: phone,
      );

      await _authService.getSmsCode(request);
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('获取验证码失败: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 登录
  Future<bool> login(String phone, String code, String captcha) async {
    try {
      await ensureInitialized();
      _setLoading(true);
      _setError(null);

      final request = LoginRequest(
        un: phone,
        authCode: code,
        openCode: '',
        cid: '',
      );

      final response = await _authService.login(request);
      
      _user = response.user;
      _token = response.user.token; // token在User对象中
      _isLoggedIn = true;

      await _saveUserData();
      
      // 登录成功后获取完整用户信息（头像、昵称）
      try {
        await _fetchUserInfo();
      } catch (e) {
        // 获取用户信息失败不影响登录成功
        if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('⚠️ 获取用户信息失败: $e');
        }
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('登录失败: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 获取用户信息（头像、昵称）
  Future<void> _fetchUserInfo() async {
    if (_token == null) return;
    
    try {
      // 获取Master数据
      _apiService.setToken(_token!);
      final response = await _apiService.get('/api/v1/ui/app/master');  // 使用正确的API路径
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final account = data?['account'] as Map<String, dynamic>?;
        
        if (account != null && _user != null) {
          final avatarUrl = account['img'] as String?;
          final userName = account['name'] as String?;
          
          if (AppConfig.isDebugMode) {
            // ignore: avoid_print
            print('获取到用户信息 - 昵称: $userName, 头像: $avatarUrl');
          }
          
          // 更新用户信息
          _user = _user!.copyWith(
            username: userName ?? _user!.username,
            avatar: avatarUrl,
          );
          
          // 保存更新后的用户信息
          await _saveUserData();
          notifyListeners();
        }
      }
    } catch (e) {
      if (AppConfig.isDebugMode) {
        // ignore: avoid_print
        print('获取用户信息异常: $e');
      }
      rethrow;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      if (AppConfig.isDebugMode) {
        // ignore: avoid_print
        print('退出登录失败: $e');
      }
    } finally {
      _token = null;
      _user = null;
      _isLoggedIn = false;
      await _clearUserData();
      notifyListeners();
    }
  }

  /// 更新用户信息
  void updateUser(User user) {
    _user = user;
    _saveUserData();
    notifyListeners();
  }
}
