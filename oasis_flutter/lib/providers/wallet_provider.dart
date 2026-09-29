import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tobias/tobias.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

/// 钱包状态管理
class WalletProvider with ChangeNotifier {
  final ApiService _apiService;

  WalletData? _walletData;
  WalletResponseData? _walletResponseData; // 保存完整的响应数据
  WalletEndpointInfo? _endpointInfo;
  List<Product> _products = [];
  List<OrderData> _orders = [];
  int _ordersPage = 0;
  int _ordersTotal = 0;
  bool _isLoadingMoreOrders = false;
  bool _isLoading = false;
  String? _error;
  int _currentWalletIndex = 0; // 当前选中的钱包索引
  List<String> _walletOrder = []; // 用户自定义的钱包顺序（存钱包 id）

  /// 自定义顺序的存储键
  static const String prefsKeyWalletOrder = 'wallet_order';

  /// 交易记录每页条数
  static const int ordersPageSize = 20;

  WalletProvider(this._apiService);

  WalletData? get walletData => _walletData;
  WalletResponseData? get walletResponseData => _walletResponseData;
  WalletEndpointInfo? get endpointInfo => _endpointInfo;
  List<Product> get products => _products;
  List<OrderData> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentWalletIndex => _currentWalletIndex;

  // 获取所有可用钱包
  //
  // 默认按「有余额优先、余额从大到小」排序；
  // 用户在钱包页自定义过顺序后，优先采用自定义顺序（未列入的钱包排在末尾）。
  List<WalletData> get allWallets {
    if (_walletResponseData == null) return [];
    final wallets = List<WalletData>.from(_walletResponseData!.allWallets);
    wallets.sort((a, b) {
      // 先按是否有余额排序
      if (a.displayBalance > 0 && b.displayBalance <= 0) return -1;
      if (a.displayBalance <= 0 && b.displayBalance > 0) return 1;
      // 再按余额从大到小排序
      return b.displayBalance.compareTo(a.displayBalance);
    });
    return applyWalletOrder(wallets, _walletOrder);
  }

  /// 是否已自定义过钱包顺序
  bool get hasCustomWalletOrder => _walletOrder.isNotEmpty;

  /// 当前自定义顺序（钱包 id 列表）
  List<String> get walletOrder => List.unmodifiable(_walletOrder);

  /// 按自定义顺序重排钱包（纯函数，便于测试）
  ///
  /// [order] 为空时原样返回；不在 [order] 中的钱包保持原有相对顺序排在末尾。
  @visibleForTesting
  static List<WalletData> applyWalletOrder(
    List<WalletData> wallets,
    List<String> order,
  ) {
    if (order.isEmpty || wallets.isEmpty) return wallets;
    final rank = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      rank[order[i]] = i;
    }
    final ordered = <WalletData>[];
    final rest = <WalletData>[];
    for (final wallet in wallets) {
      final id = wallet.id ?? '';
      if (id.isNotEmpty && rank.containsKey(id)) {
        ordered.add(wallet);
      } else {
        rest.add(wallet);
      }
    }
    ordered.sort((a, b) => rank[a.id]!.compareTo(rank[b.id]!));
    return [...ordered, ...rest];
  }

  /// 读取自定义顺序
  Future<void> loadWalletOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(prefsKeyWalletOrder);
      if (saved != null) {
        _walletOrder = saved;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('读取钱包顺序失败: $e');
    }
  }

  /// 保存自定义顺序
  Future<void> saveWalletOrder(List<String> ids) async {
    _walletOrder = List<String>.from(ids);
    _currentWalletIndex = 0;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKeyWalletOrder, _walletOrder);
    } catch (e) {
      debugPrint('保存钱包顺序失败: $e');
    }
  }

  /// 恢复默认（按余额）排序
  Future<void> resetWalletOrder() async {
    _walletOrder = [];
    _currentWalletIndex = 0;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKeyWalletOrder);
    } catch (e) {
      debugPrint('清除钱包顺序失败: $e');
    }
  }

  // 当前选中的钱包
  WalletData? get currentWallet {
    final wallets = allWallets;
    if (wallets.isEmpty || _currentWalletIndex >= wallets.length) return null;
    return wallets[_currentWalletIndex];
  }

  // 单个钱包的余额
  double get balance => _walletData?.displayBalance ?? 0.0;

  // 所有钱包的总余额（所有余额字段相加）
  double get totalBalance {
    if (_walletResponseData == null) return 0.0;
    final allWallets = _walletResponseData!.allWallets;
    return allWallets.fold(0.0, (sum, wallet) => sum + wallet.totalBalance);
  }

  String? get eid => _endpointInfo?.id;

  /// 获取钱包余额
  Future<void> fetchWalletBalance() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getWalletBalance();

      if (kDebugMode) {
        print('钱包响应: code=${response.code}, data=${response.data != null}');
      }

      if (response.isSuccess && response.data != null) {
        _walletResponseData = response.data; // 保存完整响应
        _walletData = response.data!.primaryWallet; // 使用primaryWallet
        _endpointInfo = response.data!.endpoint;

        if (kDebugMode) {
          print('===== 钱包数据详情 =====');
          print('主钱包(aw): ${response.data!.wallet != null ? "存在" : "不存在"}');
          print('多钱包(eps): ${response.data!.wallets?.length ?? 0}个');
          if (_walletData != null) {
            print('选中钱包余额:');
            print('  - total: ${_walletData!.total}');
            print('  - olCash: ${_walletData!.olCash}');
            print('  - olGift: ${_walletData!.olGift}');
            print('  - ofCash: ${_walletData!.ofCash}');
            print('  - ofGift: ${_walletData!.ofGift}');
            print('  - balance: ${_walletData!.balance}');
            print('  - displayBalance: ${_walletData!.displayBalance}');
            print('  - totalBalance: ${_walletData!.totalBalance}');
          }
          print('所有钱包总余额: ${totalBalance}');
          print('endpoint id: ${_endpointInfo?.id}');
          print('=======================');
        }

        // 自动选择余额最多的钱包（排序后的第一个）
        _currentWalletIndex = 0;

        _error = null;
      } else {
        _error = response.message ?? '获取钱包余额失败';
        if (kDebugMode) {
          print('钱包响应失败: ${_error}');
        }
      }
    } catch (e, stackTrace) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('获取钱包余额失败: $e');
        print('堆栈跟踪: $stackTrace');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取充值产品列表
  Future<void> fetchRechargeProducts(String eid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getRechargeProducts(eid: eid);

      if (response.isSuccess && response.data != null) {
        _products = response.data!;
        _error = null;
      } else {
        _error = response.message ?? '获取充值产品失败';
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('获取充值产品失败: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建充值订单
  Future<String?> createRechargeOrder({
    required String eid,
    required String productId,
    required String contactName,
    required String contactPhone,
    required String note,
    required String ownerId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final request = BillSaveRequest(
        cata: 1, // 充值类别
        contact: BillContact(id: ownerId), // 只需要id
        ep: BillEndpointRef(id: eid),
        note: note,
        owner: BillOwnerRef(id: ownerId),
        prds: [BillProduct(id: productId, count: 1)], // 使用prds数组和count
      );

      final response = await _apiService.createRechargeOrder(request);

      if (response.isSuccess && response.data != null) {
        _error = null;
        notifyListeners();
        return response.data; // 返回订单ID
      } else {
        _error = response.message ?? '创建订单失败';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('创建充值订单失败: $e');
      }
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取订单列表
  /// 是否还有更多交易记录
  bool get hasMoreOrders => _orders.length < _ordersTotal;

  bool get isLoadingMoreOrders => _isLoadingMoreOrders;

  /// 服务端返回的交易记录总数
  int get ordersTotal => _ordersTotal;

  /// 加载下一页交易记录（追加）
  Future<void> loadMoreOrders() async {
    if (_isLoadingMoreOrders || !hasMoreOrders) return;
    _isLoadingMoreOrders = true;
    notifyListeners();
    try {
      final nextPage = _ordersPage + 1;
      final response = await _apiService.getOrderList(
        page: nextPage,
        size: ordersPageSize,
      );
      final existing = _orders.map((o) => o.id).toSet();
      _orders.addAll(response.orders.where((o) => !existing.contains(o.id)));
      _ordersTotal = response.totalElements;
      _ordersPage = nextPage;
    } catch (e) {
      debugPrint('加载更多交易记录失败: $e');
    } finally {
      _isLoadingMoreOrders = false;
      notifyListeners();
    }
  }

  Future<void> fetchOrders({int page = 0, int size = 20}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getOrderList(page: page, size: size);

      _orders = response.orders;
      _error = null;
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('获取订单列表失败: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取支付渠道
  Future<PaymentChannelsResponse?> getPaymentChannels(String orderId) async {
    try {
      final response = await _apiService.getPaymentChannels(orderId);

      if (response.isSuccess && response.data != null) {
        return response.data;
      } else {
        _error = response.message ?? '获取支付渠道失败';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('获取支付渠道失败: $e');
      }
      notifyListeners();
      return null;
    }
  }

  /// 发起支付宝支付
  Future<String?> initiateAlipayPayment(String orderId) async {
    try {
      final response = await _apiService.initiateAlipayPayment(orderId);

      if (response.isSuccess && response.data != null) {
        return response.data; // 返回支付宝SDK调用字符串
      } else {
        _error = response.message ?? '发起支付失败';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('发起支付失败: $e');
      }
      notifyListeners();
      return null;
    }
  }

  /// 清空错误
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 切换钱包
  void switchWallet(int index) {
    final wallets = allWallets;
    if (index >= 0 && index < wallets.length) {
      _currentWalletIndex = index;
      _walletData = wallets[index];
      notifyListeners();
    }
  }

  /// 一键充值 - 整合创建订单和发起支付宝支付的完整流程
  Future<bool> oneClickRecharge({
    required String productId,
    required String endpointId,
    required String ownerId,
    int count = 1,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (kDebugMode) {
        print('===== 开始一键充值流程 =====');
        print('产品ID: $productId');
        print('端点ID: $endpointId');
        print('用户ID: $ownerId');
        print('数量: $count');
      }

      // 第一步：创建充值订单
      final request = BillSaveRequest(
        cata: 1, // 充值类别
        contact: BillContact(id: ownerId), // 使用用户ID作为联系人
        ep: BillEndpointRef(id: endpointId), // 使用端点ID
        note: '钱包充值',
        owner: BillOwnerRef(id: ownerId), // 使用用户ID作为订单拥有者
        prds: [BillProduct(id: productId, count: count)],
      );

      if (kDebugMode) {
        print('第1步：创建充值订单...');
      }

      final orderResponse = await _apiService.createRechargeOrder(request);

      if (!orderResponse.isSuccess || orderResponse.data == null) {
        _error = orderResponse.message ?? '创建订单失败';
        if (kDebugMode) {
          print('创建订单失败: $_error');
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final orderId = orderResponse.data!;
      if (kDebugMode) {
        print('订单创建成功，订单ID: $orderId');
        print('第2步：发起支付宝支付...');
      }

      // 第二步：直接发起支付宝支付（跳过获取支付渠道，因为只支持支付宝）
      final paymentResponse = await _apiService.initiateAlipayPayment(orderId);

      if (!paymentResponse.isSuccess || paymentResponse.data == null) {
        _error = paymentResponse.message ?? '发起支付失败';
        if (kDebugMode) {
          print('发起支付失败: $_error');
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final paymentString = paymentResponse.data!;
      if (kDebugMode) {
        print('支付宝支付发起成功');
        print('支付字符串长度: ${paymentString.length}');
      }

      // 第三步：调用支付宝SDK进行支付
      final paymentSuccess = await _launchAlipayPayment(paymentString);

      if (paymentSuccess) {
        if (kDebugMode) {
          print('支付成功，刷新钱包余额...');
        }
        // 支付成功后刷新余额
        await fetchWalletBalance();
      }

      _isLoading = false;
      notifyListeners();

      if (kDebugMode) {
        print('===== 充值流程结束 =====');
      }

      return paymentSuccess;
    } catch (e, stackTrace) {
      _error = '充值出错: $e';
      if (kDebugMode) {
        print('一键充值失败: $e');
        print('堆栈跟踪: $stackTrace');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 调用支付宝支付
  Future<bool> _launchAlipayPayment(String paymentString) async {
    try {
      if (kDebugMode) {
        print('准备启动支付宝SDK...');
        print(
          '支付参数: ${paymentString.substring(0, paymentString.length > 100 ? 100 : paymentString.length)}...',
        );
      }

      // 调用tobias支付宝SDK (新版本API)
      final tobias = Tobias();
      final payResult = await tobias.pay(paymentString);

      if (kDebugMode) {
        print('支付宝返回结果: $payResult');
      }

      // 解析支付结果
      if (payResult.isNotEmpty) {
        final resultStatus = payResult['resultStatus'] as String?;
        final memo = payResult['memo'] as String?;

        if (kDebugMode) {
          print('resultStatus: $resultStatus');
          print('memo: $memo');
        }

        // 9000 表示支付成功
        // 8000 表示正在处理中（可能支付成功）
        // 6001 表示用户取消
        // 6002 表示网络错误
        // 其他表示支付失败
        if (resultStatus == '9000') {
          if (kDebugMode) {
            print('支付成功');
          }
          return true;
        } else if (resultStatus == '8000') {
          if (kDebugMode) {
            print('支付结果确认中，建议查询订单状态');
          }
          // 对于处理中的订单，可以返回true让用户知道已提交
          return true;
        } else if (resultStatus == '6001') {
          _error = '用户取消支付';
          if (kDebugMode) {
            print(_error);
          }
          return false;
        } else if (resultStatus == '6002') {
          _error = '网络连接出错';
          if (kDebugMode) {
            print(_error);
          }
          return false;
        } else {
          _error = '支付失败: ${memo ?? "未知错误"}';
          if (kDebugMode) {
            print(_error);
          }
          return false;
        }
      } else {
        _error = '支付返回结果为空';
        if (kDebugMode) {
          print(_error);
        }
        return false;
      }
    } catch (e) {
      _error = '支付出错: $e';
      if (kDebugMode) {
        print('支付宝支付失败: $e');
      }
      return false;
    }
  }
}
