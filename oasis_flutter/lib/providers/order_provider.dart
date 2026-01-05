import 'package:flutter/foundation.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

/// 订单状态管理
class OrderProvider with ChangeNotifier {
  final ApiService _apiService;

  List<OrderData> _orders = [];
  bool _isLoading = false;
  String? _error;
  int? _filterStatus; // 筛选状态: null=全部, 1=未付款, 2=待确认, 3=已付款, 4=失败, 9=已取消

  OrderProvider(this._apiService);

  List<OrderData> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get filterStatus => _filterStatus;

  /// 获取订单列表
  Future<void> fetchOrders({int? status}) async {
    try {
      _isLoading = true;
      _error = null;
      _filterStatus = status;
      notifyListeners();

      final response = await _apiService.getOrders(status: status);

      if (response.isSuccess && response.data != null) {
        _orders = response.data!;
        _error = null;
      } else {
        _error = response.message ?? '获取订单列表失败';
      }
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

  /// 刷新订单列表
  Future<void> refreshOrders() async {
    await fetchOrders(status: _filterStatus);
  }

  /// 取消订单
  Future<bool> cancelOrder(String orderId) async {
    try {
      _error = null;
      
      final response = await _apiService.cancelOrder(orderId);
      
      if (response.isSuccess) {
        // 刷新订单列表
        await refreshOrders();
        return true;
      } else {
        _error = response.message ?? '取消订单失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('取消订单失败: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// 获取订单状态文本
  String getOrderStatusText(int status) {
    switch (status) {
      case 1:
        return '未付款';
      case 2:
        return '待确认';
      case 3:
        return '已付款';
      case 4:
        return '订单失败';
      case 9:
        return '已取消';
      default:
        return '未知状态';
    }
  }

  /// 清除错误信息
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
