import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/api_models.dart';
import '../models/auth_models.dart';

/// API 服务类
class ApiService {
  late final Dio _dio;
  String? _token;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          ...AppConfig.commonHeaders,
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.add(_createInterceptor());
  }

  /// 创建拦截器
  Interceptor _createInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // 添加 token
        if (_token != null && _token!.isNotEmpty) {
          options.headers['authorization'] = _token;
          if (AppConfig.isDebugMode) {
            // ignore: avoid_print
            print('添加Token到请求: ${_token!.substring(0, 10)}...');
          }
        } else if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('请求时Token为空!');
        }

        if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('请求: ${options.method} ${options.uri}');
          // ignore: avoid_print
          print('请求头: ${options.headers}');
          if (options.data != null) {
            // ignore: avoid_print
            print('请求体: ${options.data}');
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('响应: ${response.statusCode} ${response.requestOptions.uri}');
          // ignore: avoid_print
          print('响应数据: ${response.data}');
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('错误: ${error.message}');
          // ignore: avoid_print
          print('错误响应: ${error.response?.data}');
        }
        return handler.next(error);
      },
    );
  }

  /// 设置 Token
  void setToken(String token) {
    _token = token;
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('ApiService Token已设置: ${token.substring(0, 10)}...');
    }
  }

  /// 清除 Token
  void clearToken() {
    _token = null;
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('ApiService Token已清除');
    }
  }

  // ==================== 认证相关 API ====================

  /// 获取图形验证码
  Future<Response<List<int>>> getCaptcha(int s, int r) async {
    return await _dio.get(
      'api/v1/captcha/',
      queryParameters: {'s': s, 'r': r},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// 获取短信验证码
  Future<ApiResponse<dynamic>> getSmsCode({
    required int s,
    required String authCode,
    required String phoneNumber,
  }) async {
    final response = await _dio.post(
      'api/v1/acc/login/code',
      data: {
        's': s,
        'authCode': authCode,
        'un': phoneNumber,
      },
    );
    return ApiResponse.fromJson(response.data, null);
  }

  /// 用户登录
  Future<ApiResponse<LoginData>> login({
    required String phoneNumber,
    required String smsCode,
    String openCode = '',
    String cid = '',
  }) async {
    final response = await _dio.post(
      'api/v1/acc/login',
      data: {
        'openCode': openCode,
        'un': phoneNumber,
        'authCode': smsCode,
        'cid': cid,
      },
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => LoginData.fromJson(json as Map<String, dynamic>),
    );
  }

  // ==================== 设备相关 API ====================

  /// 获取完整的Master响应（包含用户信息和设备列表）
  Future<ApiResponse<MasterResponseData>> getMasterData() async {
    final response = await _dio.get('api/v1/ui/app/master');
    return ApiResponse.fromJson(
      response.data,
      (json) => MasterResponseData.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 启动设备
  Future<ApiResponse<dynamic>> startDevice({
    required String deviceId,
    bool upgrade = true,
    int ptype = 91,
    bool rcp = false,
  }) async {
    final response = await _dio.get(
      'api/v1/dev/start',
      queryParameters: {
        'did': deviceId,
        'upgrade': upgrade,
        'ptype': ptype,
        'rcp': rcp,
      },
    );
    return ApiResponse.fromJson(response.data, null);
  }

  /// 停止设备
  Future<ApiResponse<dynamic>> stopDevice(String deviceId) async {
    final response = await _dio.get(
      'api/v1/dev/end',
      queryParameters: {'did': deviceId},
    );
    return ApiResponse.fromJson(response.data, null);
  }

  /// 添加设备（绑定设备）
  Future<ApiResponse<AddDeviceResponse>> addDevice(
      AddDeviceRequest request) async {
    final response = await _dio.get(
      'api/v1/dev/favo',
      queryParameters: {
        'did': request.did,
        'remove': 0, // 0为添加，1为删除
      },
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => AddDeviceResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 设备收藏管理
  Future<ApiResponse<dynamic>> manageFavoriteDevice({
    required String deviceId,
    required bool remove,
  }) async {
    final response = await _dio.get(
      'api/v1/dev/favo',
      queryParameters: {
        'did': deviceId,
        'remove': remove ? 1 : 0,
      },
    );
    return ApiResponse.fromJson(response.data, null);
  }

  // ==================== 钱包相关 API ====================

  /// 获取钱包余额
  Future<ApiResponse<WalletResponseData>> getWalletBalance() async {
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('开始获取钱包余额, Token状态: ${_token != null ? "已设置(${_token!.substring(0, 10)}...)" : "未设置"}');
    }
    final response = await _dio.get('api/v1/acc/wallet/owner');
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('钱包余额响应: ${response.statusCode}, data=${response.data}');
    }
    return ApiResponse.fromJson(
      response.data,
      (json) => WalletResponseData.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 获取订单列表
  Future<OrderListResponse> getOrderList({
    int page = 0,
    int size = 20,
    String? status,
  }) async {
    final response = await _dio.get(
      'api/v1/bill/lst-owner',
      queryParameters: {
        'page': page,
        'size': size,
        if (status != null) 'status': status,
      },
    );
    return OrderListResponse.fromJson(response.data);
  }

  /// 获取订单列表 (新版API - 返回ApiResponse)
  Future<ApiResponse<List<OrderData>>> getOrders({int? status}) async {
    final response = await _dio.get(
      'api/v1/bill/lst-owner',
      queryParameters: {
        'page': 0,
        'size': 100,
        if (status != null) 'status': status,
      },
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => (json as List<dynamic>)
          .map((e) => OrderData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 取消订单
  Future<ApiResponse<dynamic>> cancelOrder(String orderId) async {
    final response = await _dio.post(
      'api/v1/bill/cancel',
      data: {'id': orderId},
    );
    return ApiResponse.fromJson(response.data, null);
  }

  /// 获取充值产品列表
  Future<ApiResponse<List<Product>>> getRechargeProducts({
    required String eid,
    int type = 1,
    int status = 1,
    bool all = false,
    String did = '',
    int page = 0,
    int size = 100,
    bool hasCount = false,
  }) async {
    final response = await _dio.get(
      'api/v1/prd/lst',
      queryParameters: {
        'eid': eid,
        'type': type,
        'status': status,
        'all': all,
        'did': did,
        'page': page,
        'size': size,
        'hasCount': hasCount,
      },
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => (json as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 创建充值订单
  Future<ApiResponse<String>> createRechargeOrder(
      BillSaveRequest request) async {
    final response = await _dio.post(
      'api/v1/bill/save',
      data: request.toJson(),
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => json as String,
    );
  }

  /// 获取支付渠道
  Future<ApiResponse<PaymentChannelsResponse>> getPaymentChannels(
      String orderId) async {
    final response = await _dio.get(
      'api/v1/bill/pay/channels',
      queryParameters: {'id': orderId},
    );
    return ApiResponse.fromJson(
      response.data,
      (json) =>
          PaymentChannelsResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 发起支付宝支付
  Future<ApiResponse<String>> initiateAlipayPayment(String orderId) async {
    final response = await _dio.get(
      'api/v1/trans/prepay/21',
      queryParameters: {'id': orderId},
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => json as String,
    );
  }

  // ==================== 通用方法 ====================

  /// GET 请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST 请求
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT 请求
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE 请求
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

