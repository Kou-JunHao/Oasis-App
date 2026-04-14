import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_models.dart';
import '../models/device_group.dart';
import '../services/api_service.dart';

/// 设备状态管理
class DeviceProvider with ChangeNotifier {
  final ApiService _apiService;

  List<DeviceDetail> _devices = [];
  List<DeviceDetail> _sortedDevicesCache = [];
  bool _isDeviceOrderDirty = true;
  int _devicesVersion = 0;
  bool _isLoading = false;
  String? _error;
  List<String> _pinnedDeviceIds = []; // 置顶设备ID列表
  Map<String, String> _deviceNotes = {}; // 设备备注（key: deviceId）
  int _notesVersion = 0;
  Timer? _pollingTimer;
  bool _isPollingEnabled = false;
  bool _isFetchingDevices = false;
  static const Duration _defaultPollingInterval = Duration(seconds: 15);

  // 设备分组管理
  List<DeviceGroup> _deviceGroups = [];
  Map<String, String> _deviceGroupMap = {}; // deviceId -> groupId
  int _groupsVersion = 0;
  String _activeGroupId = 'all'; // 显示的分组（'all'表示所有设备）

  // 分组过滤缓存
  List<DeviceDetail> _filteredDevicesCache = [];
  String _cachedFilterGroupId = '';
  int _cachedDevicesVersion = -1;

  DeviceProvider(this._apiService) {
    _loadPinnedDevices();
    _loadDeviceNotes();
    _loadDeviceGroups();
  }

  void _markDeviceOrderDirty() {
    _isDeviceOrderDirty = true;
    _devicesVersion++;
  }

  List<DeviceDetail> get devices {
    if (!_isDeviceOrderDirty) {
      return _sortedDevicesCache;
    }

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

    _sortedDevicesCache = [...pinnedDevices, ...unpinnedDevices];
    _isDeviceOrderDirty = false;
    return _sortedDevicesCache;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get devicesVersion => _devicesVersion;
  int get notesVersion => _notesVersion;
  bool get isPollingEnabled => _isPollingEnabled;
  List<DeviceGroup> get deviceGroups => _deviceGroups;
  int get groupsVersion => _groupsVersion;
  String get activeGroupId => _activeGroupId;

  bool _hasGroup(String groupId) {
    return _deviceGroups.any((g) => g.id == groupId);
  }

  String _normalizeGroupName(String name) {
    return name.trim().toLowerCase();
  }

  bool isGroupNameTaken(String name, {String? excludeGroupId}) {
    final normalized = _normalizeGroupName(name);
    if (normalized.isEmpty) return false;
    return _deviceGroups.any(
      (group) =>
          group.id != excludeGroupId &&
          _normalizeGroupName(group.name) == normalized,
    );
  }

  void _ensureDefaultGroup() {
    if (_hasGroup('default')) {
      return;
    }
    _deviceGroups.insert(
      0,
      DeviceGroup(id: 'default', name: '未分组', isDefault: true),
    );
  }

  String _normalizeGroupId(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      return 'default';
    }
    return _hasGroup(groupId) ? groupId : 'default';
  }

  /// 获取当前分组的设备列表（带缓存）
  List<DeviceDetail> get filteredDevices {
    // 检查缓存是否有效
    if (_cachedFilterGroupId == _activeGroupId &&
        _cachedDevicesVersion == _devicesVersion &&
        _filteredDevicesCache.isNotEmpty) {
      return _filteredDevicesCache;
    }

    // 计算过滤后的设备列表
    List<DeviceDetail> result;
    if (_activeGroupId == 'all') {
      result = devices;
    } else {
      result = devices
          .where((device) => getDeviceGroupId(device.id) == _activeGroupId)
          .toList();
    }

    // 更新缓存
    _filteredDevicesCache = result;
    _cachedFilterGroupId = _activeGroupId;
    _cachedDevicesVersion = _devicesVersion;

    return result;
  }

  /// 开启设备状态轮询（前台使用）
  void startDevicePolling({Duration interval = _defaultPollingInterval}) {
    _isPollingEnabled = true;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) {
      fetchDevices(silent: true);
    });
  }

  /// 停止设备状态轮询（后台或页面销毁时）
  void stopDevicePolling() {
    _isPollingEnabled = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// 检查设备是否置顶
  bool isDevicePinned(String deviceId) {
    return _pinnedDeviceIds.contains(deviceId);
  }

  /// 获取设备备注
  String getDeviceNote(String deviceId) {
    return _deviceNotes[deviceId] ?? '';
  }

  /// 设置设备备注（空字符串表示清空）
  Future<void> setDeviceNote(String deviceId, String note) async {
    final normalizedNote = note.trim();
    if (normalizedNote.isEmpty) {
      _deviceNotes.remove(deviceId);
    } else {
      _deviceNotes[deviceId] = normalizedNote;
    }
    _notesVersion++;
    await _saveDeviceNotes();
    notifyListeners();
  }

  /// 清空设备备注
  Future<void> clearDeviceNote(String deviceId) async {
    _deviceNotes.remove(deviceId);
    _notesVersion++;
    await _saveDeviceNotes();
    notifyListeners();
  }

  /// 加载置顶设备列表
  Future<void> _loadPinnedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pinnedDeviceIds = prefs.getStringList('pinned_devices') ?? [];
      _markDeviceOrderDirty();
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

  /// 加载设备备注
  Future<void> _loadDeviceNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawNotes = prefs.getString('device_notes');
      if (rawNotes != null && rawNotes.isNotEmpty) {
        final decoded = jsonDecode(rawNotes);
        if (decoded is Map<String, dynamic>) {
          _deviceNotes = decoded.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          )..removeWhere((key, value) => value.trim().isEmpty);
        }
      }
      _notesVersion++;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('加载设备备注失败: $e');
      }
    }
  }

  /// 保存设备备注
  Future<void> _saveDeviceNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_notes', jsonEncode(_deviceNotes));
    } catch (e) {
      if (kDebugMode) {
        print('保存设备备注失败: $e');
      }
    }
  }

  /// 加载设备分组
  Future<void> _loadDeviceGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawGroups = prefs.getString('device_groups');
      final rawGroupMap = prefs.getString('device_group_map');

      if (rawGroups != null && rawGroups.isNotEmpty) {
        final decodedGroups = jsonDecode(rawGroups) as List<dynamic>;
        _deviceGroups = decodedGroups
            .map((e) => DeviceGroup.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // 初始化默认分组
        _deviceGroups = [
          DeviceGroup(id: 'default', name: '未分组', isDefault: true),
        ];
      }

      // 脏数据修复：确保默认分组始终存在
      _ensureDefaultGroup();

      if (rawGroupMap != null && rawGroupMap.isNotEmpty) {
        final decodedMap = jsonDecode(rawGroupMap) as Map<String, dynamic>;
        _deviceGroupMap = decodedMap.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      }

      // 脏数据修复：将无效分组映射回退到 default
      _deviceGroupMap = _deviceGroupMap.map(
        (key, value) => MapEntry(key, _normalizeGroupId(value)),
      );

      // 当前筛选分组无效时，回退到 all
      if (_activeGroupId != 'all' && !_hasGroup(_activeGroupId)) {
        _activeGroupId = 'all';
      }

      _groupsVersion++;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('加载设备分组失败: $e');
      }
    }
  }

  /// 保存设备分组
  Future<void> _saveDeviceGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_groups', jsonEncode(_deviceGroups));
      await prefs.setString('device_group_map', jsonEncode(_deviceGroupMap));
    } catch (e) {
      if (kDebugMode) {
        print('保存设备分组失败: $e');
      }
    }
  }

  /// 创建新分组
  Future<bool> createGroup(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || isGroupNameTaken(normalizedName)) {
      return false;
    }

    final newGroup = DeviceGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: normalizedName,
      sortOrder: _deviceGroups.length,
    );

    _deviceGroups.add(newGroup);
    _groupsVersion++;
    await _saveDeviceGroups();
    notifyListeners();
    return true;
  }

  /// 重命名分组
  Future<bool> renameGroup(String groupId, String newName) async {
    final normalizedName = newName.trim();
    if (normalizedName.isEmpty ||
        isGroupNameTaken(normalizedName, excludeGroupId: groupId)) {
      return false;
    }

    final groupIndex = _deviceGroups.indexWhere((g) => g.id == groupId);
    if (groupIndex != -1) {
      _deviceGroups[groupIndex] = _deviceGroups[groupIndex].copyWith(
        name: normalizedName,
      );
      _groupsVersion++;
      await _saveDeviceGroups();
      notifyListeners();
      return true;
    }

    return false;
  }

  /// 删除分组（设备会移动到默认分组）
  Future<void> deleteGroup(String groupId) async {
    // 不能删除默认分组
    if (groupId == 'default') return;

    _ensureDefaultGroup();

    // 将该分组的设备移动到默认分组
    _deviceGroupMap.forEach((deviceId, currentGroupId) {
      if (currentGroupId == groupId) {
        _deviceGroupMap[deviceId] = 'default';
      }
    });

    // 删除分组
    _deviceGroups.removeWhere((g) => g.id == groupId);

    // 如果删除的是当前筛选分组，回退到 all
    if (_activeGroupId == groupId) {
      _activeGroupId = 'all';
    }

    _groupsVersion++;
    await _saveDeviceGroups();
    notifyListeners();
  }

  /// 将设备添加到分组
  Future<void> addDeviceToGroup(String deviceId, String groupId) async {
    _deviceGroupMap[deviceId] = _normalizeGroupId(groupId);
    _groupsVersion++;
    await _saveDeviceGroups();
    notifyListeners();
  }

  /// 将设备从分组中移除（移动到默认分组）
  Future<void> removeDeviceFromGroup(String deviceId) async {
    _deviceGroupMap[deviceId] = 'default';
    _groupsVersion++;
    await _saveDeviceGroups();
    notifyListeners();
  }

  /// 切换当前显示的分组
  void setActiveGroup(String groupId) {
    final targetGroupId = (groupId == 'all' || _hasGroup(groupId))
        ? groupId
        : 'all';
    if (_activeGroupId != targetGroupId) {
      _activeGroupId = targetGroupId;
      _groupsVersion++;
      notifyListeners();
    }
  }

  /// 获取设备所在的分组
  String getDeviceGroupId(String deviceId) {
    return _normalizeGroupId(_deviceGroupMap[deviceId]);
  }

  /// 获取分组名称
  String getGroupName(String groupId) {
    final group = _deviceGroups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => DeviceGroup(id: groupId, name: '未知分组'),
    );
    return group.name;
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
    _markDeviceOrderDirty();
    await _savePinnedDevices();
    notifyListeners();
  }

  /// 获取设备列表（从Master数据）
  Future<void> fetchDevices({bool silent = false}) async {
    if (_isFetchingDevices) {
      return;
    }

    _isFetchingDevices = true;
    try {
      if (!silent) {
        _isLoading = true;
        _error = null;
        notifyListeners();
      }

      final response = await _apiService.getMasterData();

      if (response.isSuccess && response.data != null) {
        _devices = response.data!.devices;
        _markDeviceOrderDirty();
        _error = null;
      } else if (!silent) {
        _error = response.message ?? '获取设备列表失败';
      }
    } catch (e) {
      if (!silent) {
        _error = '网络错误: $e';
      }
      if (kDebugMode) {
        print('获取设备列表失败: $e');
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      _isFetchingDevices = false;
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
        // 启动请求成功后先立即拉取一次最新状态，减少“正在启动”感知时长
        await fetchDevices(silent: true);
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
        // 停止后必须立即刷新一次，尽快以服务端状态覆盖本地乐观状态
        await fetchDevices(silent: true);
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
  Future<void> _waitForDeviceStatusChange(
    String deviceId, {
    required bool expectedRunning,
  }) async {
    const maxAttempts = 6; // 最多检查6次
    const delayBetweenAttempts = Duration(milliseconds: 800); // 每次间隔800ms

    for (int i = 0; i < maxAttempts; i++) {
      // 首次立即检查一次，后续再按间隔轮询
      if (i > 0) {
        await Future.delayed(delayBetweenAttempts);
      }
      await fetchDevices(silent: true);

      // 检查设备状态是否已经改变
      final device = _devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => DeviceDetail(
          id: deviceId,
          name: null,
          status: 0,
          owner: DeviceOwner(id: ''),
          gene: DeviceGene(status: 99),
        ),
      );

      // 与DeviceDetail.isRunning保持一致：gene.status != 99 即运行中
      final isRunning = device.isRunning;

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
  void _optimisticUpdateDeviceStatus(
    String deviceId, {
    required bool isStarting,
  }) {
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
      _markDeviceOrderDirty();
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
        _deviceNotes.remove(deviceId);
        _pinnedDeviceIds.remove(deviceId);
        _markDeviceOrderDirty();
        _notesVersion++;
        await _saveDeviceNotes();
        await _savePinnedDevices();
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

  @override
  void dispose() {
    stopDevicePolling();
    super.dispose();
  }
}
