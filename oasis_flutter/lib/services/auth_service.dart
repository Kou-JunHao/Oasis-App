import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../models/api_models.dart';
import 'api_service.dart';

/// 认证服务类
class AuthService {
  final ApiService _apiService;

  AuthService(this._apiService);

  /// 获取图形验证码
  Future<Response> getCaptcha() async {
    return await _apiService.get(
      '/api/v1/captcha/',
      queryParameters: {
        's': DateTime.now().millisecondsSinceEpoch,
        'r': (DateTime.now().millisecondsSinceEpoch * 1000).toInt(),
      },
    );
  }

  /// 获取短信验证码
  Future<void> getSmsCode(GetCodeRequest request) async {
    try {
      final response = await _apiService.post(
        '/api/v1/acc/login/code',
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Connection': 'keep-alive',
            'applicationtype': '1,1',
            'Accept': '*/*',
            'User-Agent': 'Android_ilife798_2.0.11',
            'Accept-Language': 'zh-TW,zh-Hant;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'versioncode': '2.0.11',
          },
        ),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(response.data, null);
        if (apiResponse.isSuccess) {
          return; // 成功
        } else {
          // 根据错误码返回相应错误信息
          final errorMsg = _getErrorMessage(apiResponse.code);
          throw Exception(errorMsg);
        }
      } else {
        throw Exception('获取验证码失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('获取验证码失败: $e');
    }
  }

  /// 根据错误码获取错误信息
  String _getErrorMessage(int code) {
    switch (code) {
      case -2:
        return '图形验证码错误';
      case -1:
        return '参数错误';
      case -3:
        return '手机号格式错误';
      case -4:
        return '发送频率过快';
      case 1:
        return '系统错误';
      default:
        return '获取验证码失败(错误码: $code)';
    }
  }

  /// 用户登录
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _apiService.post(
        '/api/v1/acc/login',
        data: request.toJson(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Connection': 'keep-alive',
            'applicationtype': '1,1',
            'Accept': '*/*',
            'User-Agent': 'Android_ilife798_2.0.11',
            'Accept-Language': 'zh-TW,zh-Hant;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'versioncode': '2.0.11',
          },
        ),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data,
          (json) => LoginData.fromJson(json as Map<String, dynamic>),
        );
        
        if (apiResponse.isSuccess && apiResponse.data != null) {
          final loginData = apiResponse.data!;
          // 将LoginData转换为LoginResponse
          // 从请求中获取手机号
          final phoneNumber = request.un;
          return LoginResponse(
            token: loginData.al.token,
            user: User(
              id: loginData.al.uid,  // 使用uid而不是oid
              username: phoneNumber,  // 使用手机号作为初始用户名，后续从Master API更新
              phone: phoneNumber,
              createdAt: DateTime.now(),
              token: loginData.al.token,
              userId: loginData.al.uid,  // 使用uid
              phoneNumber: phoneNumber,
              eid: loginData.al.eid,
            ),
          );
        } else {
          // 错误码映射
          final errorMsg = switch (apiResponse.code) {
            -2 => '验证码错误',
            -1 => '参数错误',
            _ => '登录失败，请重试(错误码: ${apiResponse.code})',
          };
          throw Exception(errorMsg);
        }
      } else {
        throw Exception('登录失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('登录失败: $e');
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _apiService.post('/api/v1/acc/logout');
    } catch (e) {
      if (AppConfig.isDebugMode) {
        // ignore: avoid_print
        print('退出登录请求失败: $e');
      }
    }
  }
}
