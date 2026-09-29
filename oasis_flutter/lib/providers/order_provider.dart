import 'package:flutter/foundation.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

/// 订单状态管理
class OrderProvider with ChangeNotifier {
  final ApiService _apiService;

  /// 每页条数
  static const int pageSize = 20;

  List<OrderData> _orders = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _page = 0;
  int _total = 0;
  String? _error;
  int? _filterStatus; // 筛选状态: null=全部, 1=未付款, 2=待确认, 3=已付款, 4=失败, 9=已取消

  OrderProvider(this._apiService);

  List<OrderData> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  int? get filterStatus => _filterStatus;

  /// 服务端返回的订单总数
  int get total => _total;

  /// 是否还有下一页
  bool get hasMore => _orders.length < _total;

  /// 获取订单列表
  Future<void> fetchOrders({int? status}) async {
    try {
      _isLoading = true;
      _error = null;
      _filterStatus = status;
      notifyListeners();

      final result = await _apiService.getOrdersPage(
        page: 0,
        size: pageSize,
        status: status,
      );
      _orders = result.items;
      _total = result.total;
      _page = 0;
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

  /// 刷新订单列表
  Future<void> refreshOrders() async {
    await fetchOrders(status: _filterStatus);
  }

  /// 加载下一页订单（追加）
  Future<void> loadMoreOrders() async {
    if (_isLoadingMore || _isLoading || !hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final nextPage = _page + 1;
      final result = await _apiService.getOrdersPage(
        page: nextPage,
        size: pageSize,
        status: _filterStatus,
      );
      // 按 id 去重后追加，避免服务端分页边界导致重复
      final existing = _orders.map((o) => o.id).toSet();
      _orders.addAll(result.items.where((o) => !existing.contains(o.id)));
      _total = result.total;
      _page = nextPage;
      _error = null;
    } catch (e) {
      _error = '加载更多失败: $e';
      if (kDebugMode) {
        print('加载更多订单失败: $e');
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
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
