import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

/// 设备状态管理
class DeviceProvider with ChangeNotifier {
  final ApiService _apiService;

  List<DeviceDetail> _devices = [];
  bool _isLoading = false;
  String? _error;
  List<String> _pinnedDeviceIds = []; // 置顶设备ID列表

  DeviceProvider(this._apiService) {
    _loadPinnedDevices();
  }

  List<DeviceDetail> get devices {
    // 返回排序后的设备列表：置顶设备在前，最后置顶的在最上方
    final pinnedDevices = <DeviceDetail>[];
    final unpinnedDevices = <DeviceDetail>[];

    for (var device in _devices) {
      if (_pinnedDeviceIds.contains(device.id)) {
        pinnedDevices.add(device);
      } else {
        unpinnedDevices.add(device);
      }
    }

    // 按置顶顺序排列（后置顶的在前）
    pinnedDevices.sort((a, b) {
      final aIndex = _pinnedDeviceIds.indexOf(a.id);
      final bIndex = _pinnedDeviceIds.indexOf(b.id);
      return bIndex.compareTo(aIndex); // 逆序排列
    });

    return [...pinnedDevices, ...unpinnedDevices];
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 检查设备是否置顶
  bool isDevicePinned(String deviceId) {
    return _pinnedDeviceIds.contains(deviceId);
  }

  /// 加载置顶设备列表
  Future<void> _loadPinnedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pinnedDeviceIds = prefs.getStringList('pinned_devices') ?? [];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('加载置顶设备列表失败: $e');
      }
    }
  }

  /// 保存置顶设备列表
  Future<void> _savePinnedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pinned_devices', _pinnedDeviceIds);
    } catch (e) {
      if (kDebugMode) {
        print('保存置顶设备列表失败: $e');
      }
    }
  }

  /// 置顶/取消置顶设备
  Future<void> togglePinDevice(String deviceId) async {
    if (_pinnedDeviceIds.contains(deviceId)) {
      // 取消置顶
      _pinnedDeviceIds.remove(deviceId);
    } else {
      // 置顶（添加到列表末尾，因为显示时会逆序）
      _pinnedDeviceIds.add(deviceId);
    }
    await _savePinnedDevices();
    notifyListeners();
  }

  /// 获取设备列表（从Master数据）
  Future<void> fetchDevices() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.getMasterData();

      if (response.isSuccess && response.data != null) {
        _devices = response.data!.devices;
        _error = null;
      } else {
        _error = response.message ?? '获取设备列表失败';
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('获取设备列表失败: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 启动设备
  Future<bool> startDevice(String deviceId) async {
    try {
      _error = null;
      
      // 先乐观更新UI - 假设启动成功,立即更新本地状态
      _optimisticUpdateDeviceStatus(deviceId, isStarting: true);
      
      final response = await _apiService.startDevice(deviceId: deviceId);

      if (response.isSuccess) {
        // 延迟并轮询检查设备状态，直到状态真正改变
        await _waitForDeviceStatusChange(deviceId, expectedRunning: true);
        return true;
      } else {
        // 失败时回滚状态
        await fetchDevices();
        _error = response.message ?? '启动设备失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      // 失败时回滚状态
      await fetchDevices();
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('启动设备失败: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// 停止设备
  Future<bool> stopDevice(String deviceId) async {
    try {
      _error = null;
      
      // 先乐观更新UI - 假设停止成功,立即更新本地状态
      _optimisticUpdateDeviceStatus(deviceId, isStarting: false);
      
      final response = await _apiService.stopDevice(deviceId);

      if (response.isSuccess) {
        // 延迟并轮询检查设备状态，直到状态真正改变
        await _waitForDeviceStatusChange(deviceId, expectedRunning: false);
        return true;
      } else {
        // 失败时回滚状态
        await fetchDevices();
        _error = response.message ?? '停止设备失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      // 失败时回滚状态
      await fetchDevices();
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('停止设备失败: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// 等待设备状态改变（轮询检查）
  Future<void> _waitForDeviceStatusChange(String deviceId, {required bool expectedRunning}) async {
    const maxAttempts = 6; // 最多检查6次
    const delayBetweenAttempts = Duration(milliseconds: 800); // 每次间隔800ms
    
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(delayBetweenAttempts);
      await fetchDevices();
      
      // 检查设备状态是否已经改变
      final device = _devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => _devices.first,
      );
      
      final isRunning = device.gene?.status == 1;
      
      if (isRunning == expectedRunning) {
        // 状态已改变，成功
        if (kDebugMode) {
          print('设备状态已更新: $deviceId, 运行中: $isRunning');
        }
        return;
      }
    }
    
    // 超时，但仍然显示乐观更新的状态
    if (kDebugMode) {
      print('等待设备状态改变超时: $deviceId');
    }
  }

  /// 乐观更新设备状态（用于即时UI反馈）
  void _optimisticUpdateDeviceStatus(String deviceId, {required bool isStarting}) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final device = _devices[index];
      // 创建新的gene对象,更新status
      final updatedGene = DeviceGene(
        status: isStarting ? 1 : 99, // 1表示运行中,99表示已停止
      );
      
      final updatedDevice = DeviceDetail(
        id: device.id,
        name: device.name,
        status: device.status,
        owner: device.owner,
        gene: updatedGene,
        address: device.address,
        endpoint: device.endpoint,
      );
      
      _devices[index] = updatedDevice;
      notifyListeners();
    }
  }

  /// 添加设备（绑定设备）
  Future<bool> addDevice(String deviceId, {String? password}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final request = AddDeviceRequest(did: deviceId, password: password);
      final response = await _apiService.addDevice(request);

      if (response.isSuccess) {
        // 刷新设备列表
        await fetchDevices();
        return true;
      } else {
        _error = response.message ?? '添加设备失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('添加设备失败: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 删除设备（从收藏列表移除）
  Future<bool> removeDevice(String deviceId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.manageFavoriteDevice(
        deviceId: deviceId,
        remove: true, // true表示取消收藏/删除
      );

      if (response.isSuccess) {
        // 刷新设备列表
        await fetchDevices();
        return true;
      } else {
        _error = response.message ?? '删除设备失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('删除设备失败: $e');
      }
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 收藏/取消收藏设备
  Future<bool> toggleFavorite(String deviceId, bool isFavorite) async {
    try {
      final response = await _apiService.manageFavoriteDevice(
        deviceId: deviceId,
        remove: isFavorite, // true表示取消收藏
      );

      if (response.isSuccess) {
        // 刷新设备列表
        await fetchDevices();
        return true;
      } else {
        _error = response.message ?? '操作失败';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = '网络错误: $e';
      if (kDebugMode) {
        print('操作失败: $e');
      }
      notifyListeners();
      return false;
    }
  }



  /// 清空错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
