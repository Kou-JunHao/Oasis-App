import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/api_models.dart';
import '../models/auth_models.dart';
import '../models/device_detail_models.dart';
import 'client_version_service.dart';

/// 宽松解析整数：服务端的总数可能是字符串（如 "6"）
int _parseIntLenient(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
}

/// API 服务类
class ApiService {
  late final Dio _dio;
  String? _token;

  /// 服务端表示「登录状态已过期」的业务码（HTTP 200 + code=-99 + msg=登录状态已过期）
  static const int codeSessionExpired = -99;

  /// 会话失效回调：由 AuthProvider 注册，用于清理登录态并回到登录页
  void Function()? onSessionExpired;

  /// 防止并发请求同时触发多次登出
  bool _sessionExpiredNotified = false;

  /// 判断响应体是否表示登录态已失效（纯函数，便于测试）
  @visibleForTesting
  static bool isSessionExpiredPayload(dynamic data) {
    if (data is Map) {
      final code = data['code'];
      return code is num && code.toInt() == codeSessionExpired;
    }
    return false;
  }

  void _notifySessionExpired(String reason) {
    if (_sessionExpiredNotified) return;
    _sessionExpiredNotified = true;
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print('检测到登录状态失效（$reason），触发自动登出');
    }
    onSessionExpired?.call();
  }

  Map<String, dynamic> _maskedHeaders(Map<String, dynamic> headers) {
    final masked = Map<String, dynamic>.from(headers);
    final auth = masked['authorization'];
    if (auth is String && auth.isNotEmpty) {
      if (auth.length <= 8) {
        masked['authorization'] = '***';
      } else {
        masked['authorization'] =
            '${auth.substring(0, 4)}***${auth.substring(auth.length - 4)}';
      }
    }
    return masked;
  }

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          // 这里的版本号只是初始值，实际每次请求由拦截器按当前生效值覆盖
          ...AppConfig.commonHeadersFor(ClientVersionService.current),
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.add(_createInterceptor());
  }

  /// 创建拦截器
  Interceptor _createInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 伪装版本号：动态获取（用户自定义 > 线上最新 > 缓存 > 基线），
        // 带超时等待，超时则先用当前已知值，不阻塞请求。
        // 个别接口需要固定版本号（如积分主平台要求 2.0.178），
        // 可通过 options.extra['skipVersionHeaders'] = true 跳过自动注入。
        final skipVersionHeaders = options.extra['skipVersionHeaders'] == true;
        final String clientVersion;
        if (skipVersionHeaders) {
          clientVersion = '${options.headers['versioncode'] ?? ''}';
        } else {
          clientVersion = await ClientVersionService.resolveBounded();
          options.headers['versioncode'] = clientVersion;
          options.headers['User-Agent'] = 'Android_ilife798_$clientVersion';
        }

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
          print(
            '伪装版本号: $clientVersion (来源: ${ClientVersionService.statusNotifier.value.sourceLabel})',
          );
          // ignore: avoid_print
          print('请求头: ${_maskedHeaders(options.headers)}');
          if (options.data != null) {
            // ignore: avoid_print
            print('请求体: ${options.data}');
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // 登录态失效时服务端返回 HTTP 200 + code=-99，必须主动识别并登出
        if (isSessionExpiredPayload(response.data)) {
          _notifySessionExpired('code=$codeSessionExpired');
        }
        if (AppConfig.isDebugMode) {
          // ignore: avoid_print
          print('响应: ${response.statusCode} ${response.requestOptions.uri}');
          // ignore: avoid_print
          print('响应数据: ${response.data}');
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        // 部分接口可能直接返回 401/403
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          _notifySessionExpired('HTTP $status');
        }
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

  /// 当前 Token（积分奖励签名等场景需要）
  String? get token => _token;

  /// 设置 Token
  void setToken(String token) {
    _token = token;
    // 重新登录后重新武装会话失效检测
    _sessionExpiredNotified = false;
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
      data: {'s': s, 'authCode': authCode, 'un': phoneNumber},
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
    final body = response.data;

    // 该接口在 token 失效时不会返回 -99，而是返回 code=0 + 匿名数据（仅含广告位，
    // 没有 account/favos）。这里显式识别，否则会被当成成功响应，
    // 表现为设备页解析出 null 账号后抛类型转换错误且不会退回登录页。
    if (body is Map && body['code'] == 0) {
      final data = body['data'];
      final authenticated = data is Map && data['account'] != null;
      if (!authenticated) {
        _notifySessionExpired('master 返回匿名数据');
      }
    }

    return ApiResponse.fromJson(
      body,
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
    AddDeviceRequest request,
  ) async {
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
      queryParameters: {'did': deviceId, 'remove': remove ? 1 : 0},
    );
    return ApiResponse.fromJson(response.data, null);
  }

  // ==================== 钱包相关 API ====================

  /// 获取钱包余额
  Future<ApiResponse<WalletResponseData>> getWalletBalance() async {
    if (AppConfig.isDebugMode) {
      // ignore: avoid_print
      print(
        '开始获取钱包余额, Token状态: ${_token != null ? "已设置(${_token!.substring(0, 10)}...)" : "未设置"}',
      );
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
        'hasCount': 1,
        if (status != null) 'status': status,
      },
    );
    return OrderListResponse.fromJson(response.data);
  }

  /// 获取订单列表 (新版API - 返回ApiResponse)
  /// 订单分页：返回当页数据与服务端总数
  ///
  /// 服务端在 `hasCount=1` 时会在响应里带上 `size` 字段（总数）。
  Future<({List<OrderData> items, int total})> getOrdersPage({
    int page = 0,
    int size = 20,
    int? status,
  }) async {
    final response = await _dio.get(
      'api/v1/bill/lst-owner',
      queryParameters: {
        'page': page,
        'size': size,
        'hasCount': 1,
        if (status != null) 'status': status,
      },
    );
    final body = response.data;
    final items = <OrderData>[];
    if (body is Map && body['data'] is List) {
      for (final item in body['data'] as List) {
        if (item is Map<String, dynamic>) {
          items.add(OrderData.fromJson(item));
        }
      }
    }
    // 注意：服务端返回的 size 是字符串（如 "6"），需要宽松解析
    final total = body is Map
        ? _parseIntLenient(body['size'], items.length)
        : items.length;
    return (items: items, total: total);
  }

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
    BillSaveRequest request,
  ) async {
    final response = await _dio.post(
      'api/v1/bill/save',
      data: request.toJson(),
    );
    return ApiResponse.fromJson(response.data, (json) => json as String);
  }

  /// 获取支付渠道
  Future<ApiResponse<PaymentChannelsResponse>> getPaymentChannels(
    String orderId,
  ) async {
    final response = await _dio.get(
      'api/v1/bill/pay/channels',
      queryParameters: {'id': orderId},
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => PaymentChannelsResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 发起支付宝支付
  Future<ApiResponse<String>> initiateAlipayPayment(String orderId) async {
    final response = await _dio.get(
      'api/v1/trans/prepay/21',
      queryParameters: {'id': orderId},
    );
    return ApiResponse.fromJson(response.data, (json) => json as String);
  }

  // ==================== 设备详情相关 API ====================

  /// 设备实时状态（运行状态、累计出水量、流速、分路等）
  Future<ApiResponse<DeviceRuntimeStatus>> getDeviceStatus(String deviceId) async {
    final response = await _dio.get(
      'api/v1/ui/app/dev/status',
      queryParameters: {'did': deviceId},
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => DeviceRuntimeStatus.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 钱包明细（余额构成、归属账号与结算端点）
  Future<ApiResponse<WalletDetail>> getWalletDetail(String walletId) async {
    final response = await _dio.get(
      'api/v1/acc/wallet/detail',
      queryParameters: {'id': walletId},
    );
    return ApiResponse.fromJson(
      response.data,
      (json) => WalletDetail.fromJson(json as Map<String, dynamic>),
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
