import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/api_models.dart';
import '../widgets/bottom_sheet_helper.dart';
import '../widgets/qr_scanner_screen.dart';
import '../widgets/device_group_dialog.dart';

/// 设备列表页面 - 参考Kotlin的DeviceListFragment
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<DeviceDetail> _allDevices = [];
  List<DeviceDetail> _filteredDevices = [];
  int _lastDevicesVersion = -1;
  int _lastNotesVersion = -1;
  int _lastGroupsVersion = -1;
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deviceProvider = Provider.of<DeviceProvider>(
        context,
        listen: false,
      );
      deviceProvider.startDevicePolling();
      deviceProvider.fetchDevices();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    switch (state) {
      case AppLifecycleState.resumed:
        deviceProvider.startDevicePolling();
        deviceProvider.fetchDevices(silent: true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        deviceProvider.stopDevicePolling();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Provider.of<DeviceProvider>(context, listen: false).stopDevicePolling();
    _searchController.dispose();
    super.dispose();
  }

  void _filterDevices(
    String query,
    List<DeviceDetail> devices, [
    DeviceProvider? deviceProvider,
  ]) {
    final normalizedQuery = query.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredDevices = devices;
      });
    } else {
      setState(() {
        _filteredDevices = devices.where((device) {
          // 模糊搜索：备注、设备名称、ID、地址
          final note = deviceProvider?.getDeviceNote(device.id) ?? '';
          final noteMatch = note.toLowerCase().contains(normalizedQuery);
          final nameMatch =
              device.name?.toLowerCase().contains(normalizedQuery) ?? false;
          final idMatch = device.id.toLowerCase().contains(normalizedQuery);
          final addressMatch =
              device.address?.detail?.toLowerCase().contains(normalizedQuery) ??
              false;

          return noteMatch || nameMatch || idMatch || addressMatch;
        }).toList();
      });
    }
  }

  /// 显示设备操作菜单（简化版）
  void _showSimpleDeviceActionMenu(BuildContext context, DeviceDetail device) {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    _showDeviceActionMenu(context, device, deviceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Consumer<DeviceProvider>(
        builder: (context, deviceProvider, child) {
          final currentDevices = deviceProvider.filteredDevices;

          // 同步更新设备列表，避免延迟
          if (_lastDevicesVersion != deviceProvider.devicesVersion ||
              _lastGroupsVersion != deviceProvider.groupsVersion) {
            _allDevices = currentDevices;
            _lastDevicesVersion = deviceProvider.devicesVersion;
            _lastNotesVersion = deviceProvider.notesVersion;
            _lastGroupsVersion = deviceProvider.groupsVersion;
            // 只在必要时进行过滤
            if (_searchController.text.isNotEmpty) {
              _filterDevices(
                _searchController.text,
                _allDevices,
                deviceProvider,
              );
            } else {
              _filteredDevices = _allDevices;
            }
          }

          if (deviceProvider.isLoading && currentDevices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (deviceProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      deviceProvider.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => deviceProvider.fetchDevices(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          // 使用过滤后的设备列表
          final displayDevices = _filteredDevices;

          return CustomScrollView(
            slivers: [
              // Material 3中等标题AppBar
              SliverAppBar.medium(
                title: const Text('设备管理'),
                floating: false,
                pinned: true,
                actions: [
                  const GroupSelectorDropdown(),
                  IconButton(
                    icon: const Icon(Icons.group_rounded),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => const DeviceGroupDialog(),
                    ),
                    tooltip: '分组管理',
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _showDeviceManagementMenu(context),
                    tooltip: '添加设备',
                  ),
                ],
              ),

              // 搜索栏
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: '搜索备注、设备名称、ID或地址',
                    leading: const Icon(Icons.search_rounded),
                    elevation: const WidgetStatePropertyAll(0),
                    trailing: _searchController.text.isNotEmpty
                        ? [
                            IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _filterDevices('', _allDevices, deviceProvider);
                              },
                            ),
                          ]
                        : null,
                    onChanged: (value) =>
                        _filterDevices(value, _allDevices, deviceProvider),
                  ),
                ),
              ),

              // 设备列表或空状态
              if (displayDevices.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.devices_other_rounded,
                          size: 64,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? '未找到匹配的设备'
                              : '暂无设备',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () {
                              _searchController.clear();
                              _filterDevices('', _allDevices, deviceProvider);
                            },
                            child: const Text('清除搜索'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final device = displayDevices[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDeviceCard(
                          context,
                          device,
                          deviceProvider,
                        ),
                      );
                    }, childCount: displayDevices.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showDeviceManagementMenu(BuildContext context) async {
    final result = await showMenuBottomSheet<String>(
      context: context,
      title: '设备管理',
      options: [
        MenuOption(
          title: '添加设备',
          subtitle: '输入设备ID添加',
          icon: Icons.add_rounded,
          value: 'add',
        ),
        MenuOption(
          title: '扫码添加',
          subtitle: '扫描设备二维码快速添加',
          icon: Icons.qr_code_scanner_rounded,
          color: Colors.blue,
          value: 'scan',
        ),
      ],
    );

    if (result != null && context.mounted) {
      if (result == 'add') {
        _showAddDeviceDialog(context);
      } else if (result == 'scan') {
        _showScanQRCode(context);
      }
    }
  }

  /// 显示设备操作菜单
  void _showDeviceActionMenu(
    BuildContext context,
    DeviceDetail device,
    DeviceProvider deviceProvider,
  ) async {
    final note = deviceProvider.getDeviceNote(device.id);
    final isPinned = deviceProvider.isDevicePinned(device.id);
    final title = note.isNotEmpty ? note : (device.name ?? device.id);

    final result = await showMenuBottomSheet<String>(
      context: context,
      title: title,
      options: [
        MenuOption(
          title: '复制设备ID',
          subtitle: device.id,
          icon: Icons.copy_rounded,
          value: 'copy',
        ),
        MenuOption(
          title: '编辑备注',
          subtitle: note.isNotEmpty ? '当前: $note' : '设置设备备注，便于识别',
          icon: Icons.edit_note_rounded,
          value: 'note',
        ),
        MenuOption(
          title: isPinned ? '取消置顶' : '置顶设备',
          subtitle: '在列表顶部显示',
          icon: Icons.push_pin_outlined,
          color: Theme.of(context).colorScheme.primary,
          value: 'pin',
        ),
        MenuOption(
          title: '移动到分组',
          subtitle: '将设备归类到指定分组',
          icon: Icons.group_rounded,
          value: 'group',
        ),
        MenuOption(
          title: '删除设备',
          subtitle: '从收藏列表移除',
          icon: Icons.delete_outline_rounded,
          color: Colors.red,
          value: 'delete',
        ),
      ],
    );

    if (result != null && context.mounted) {
      switch (result) {
        case 'copy':
          await _copyDeviceId(context, device.id);
          break;
        case 'note':
          await _editDeviceNote(context, device, deviceProvider);
          break;
        case 'pin':
          await _pinDevice(context, device, deviceProvider);
          break;
        case 'group':
          showDialog(
            context: context,
            builder: (context) => DeviceGroupDialog(deviceId: device.id),
          );
          break;
        case 'delete':
          await _deleteDeviceFromCard(context, device, deviceProvider);
          break;
      }
    }
  }

  /// 编辑设备备注
  Future<void> _editDeviceNote(
    BuildContext context,
    DeviceDetail device,
    DeviceProvider deviceProvider,
  ) async {
    final currentNote = deviceProvider.getDeviceNote(device.id);
    final originalName = device.name ?? device.id;

    final result = await showInputBottomSheet(
      context: context,
      title: '编辑设备备注',
      icon: Icons.edit_note_rounded,
      fields: [
        InputField(
          key: 'note',
          label: '设备备注',
          hint: '例如：客厅主机 / 二楼备用机',
          helper: '留空并确认可清除备注',
          icon: Icons.notes_rounded,
          initialValue: currentNote,
          validator: (value) {
            if ((value ?? '').trim().length > 30) {
              return '备注最多30个字符';
            }
            return null;
          },
        ),
      ],
      confirmText: '保存',
    );

    if (result != null && context.mounted) {
      final note = (result['note'] ?? '').trim();
      await deviceProvider.setDeviceNote(device.id, note);
      _filterDevices(_searchController.text, _allDevices, deviceProvider);

      if (context.mounted) {
        final hasNote = note.isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  hasNote ? Icons.check_circle : Icons.clear,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasNote ? '备注已更新：$note' : '已清除“$originalName”的备注',
                  ),
                ),
              ],
            ),
            backgroundColor: hasNote ? Colors.green : Colors.grey,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 复制设备ID到剪贴板
  Future<void> _copyDeviceId(BuildContext context, String deviceId) async {
    try {
      await Clipboard.setData(ClipboardData(text: deviceId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('已复制设备ID: $deviceId'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复制失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 置顶设备
  Future<void> _pinDevice(
    BuildContext context,
    DeviceDetail device,
    DeviceProvider deviceProvider,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final isPinned = deviceProvider.isDevicePinned(device.id);
    await deviceProvider.togglePinDevice(device.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(isPinned ? '已取消置顶' : '已置顶到顶部'),
            ],
          ),
          backgroundColor: isPinned
              ? colorScheme.secondary
              : colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 从卡片删除设备（带确认）
  Future<void> _deleteDeviceFromCard(
    BuildContext context,
    DeviceDetail device,
    DeviceProvider deviceProvider,
  ) async {
    final confirmed = await showConfirmBottomSheet(
      context: context,
      title: '确认删除',
      message: '确定要删除设备 "${device.name ?? device.id}" 吗？\n设备ID: ${device.id}',
      icon: Icons.warning_rounded,
      isDangerous: true,
    );

    if (confirmed == true && context.mounted) {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在删除设备...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await deviceProvider.removeDevice(device.id);

        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭加载指示器
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('设备删除成功'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭加载指示器
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('删除失败: $e')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showAddDeviceDialog(BuildContext context) async {
    final result = await showInputBottomSheet(
      context: context,
      title: '添加设备',
      icon: Icons.devices_rounded,
      fields: [
        InputField(
          key: 'deviceId',
          label: '设备ID',
          hint: '请输入设备ID',
          icon: Icons.devices_rounded,
          helper: '可以通过扫码或手动输入设备ID',
        ),
      ],
      confirmText: '添加',
    );

    if (result != null && context.mounted) {
      final deviceId = (result['deviceId'] ?? '').trim();

      if (deviceId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入设备ID')));
        return;
      }

      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在添加设备...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final deviceProvider = Provider.of<DeviceProvider>(
          context,
          listen: false,
        );
        final success = await deviceProvider.addDevice(deviceId);

        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭加载指示器
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('设备添加成功'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(deviceProvider.error ?? '设备添加失败')),
                  ],
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭加载指示器
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('添加失败: $e')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _extractDeviceIdFromQr(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      const queryKeys = ['did', 'deviceId', 'device_id', 'id'];
      for (final key in queryKeys) {
        final value = uri.queryParameters[key]?.trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }

      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last.trim();
        if (last.isNotEmpty && !last.contains('.')) {
          return last;
        }
      }
    }

    final keyValueMatch = RegExp(
      r'(?:did|deviceId|device_id|id)\s*[:=]\s*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (keyValueMatch != null) {
      return keyValueMatch.group(1) ?? trimmed;
    }

    return trimmed;
  }

  void _showScanQRCode(BuildContext context) async {
    // 使用真实的二维码扫描器
    final String? qrCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (qrCode != null && qrCode.isNotEmpty && context.mounted) {
      final deviceId = _extractDeviceIdFromQr(qrCode);
      if (deviceId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未识别到有效设备ID，请尝试手动输入'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在添加设备...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final deviceProvider = Provider.of<DeviceProvider>(
          context,
          listen: false,
        );
        final success = await deviceProvider.addDevice(deviceId);

        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭加载指示器
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('设备添加成功'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(deviceProvider.error ?? '设备添加失败')),
                  ],
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭加载指示器
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('添加失败: $e')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildDeviceCard(
    BuildContext context,
    DeviceDetail device,
    DeviceProvider deviceProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOnline = device.isOnline; // device.status == 1 表示在线
    final isRunning = device.isRunning; // gene.status != 99 表示运行中
    final isPinned = deviceProvider.isDevicePinned(device.id);
    final note = deviceProvider.getDeviceNote(device.id);
    final displayName = note.isNotEmpty ? note : (device.name ?? device.id);
    final secondaryName = note.isNotEmpty ? (device.name ?? device.id) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: 跳转到设备详情页
        },
        onLongPress: () => _showSimpleDeviceActionMenu(context, device),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 设备信息头部
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.water_drop_rounded,
                        color: isOnline
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (secondaryName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            secondaryName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? '在线' : '离线',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (isOnline) ...[
                              const SizedBox(width: 12),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isRunning
                                      ? Colors.blue
                                      : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRunning ? '运行中' : '已停止',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        if (isPinned) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '置顶',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 设备状态芯片
                  _DeviceStatusChip(device: device),
                ],
              ),
              // 设备地址(如果有)
              if (device.address?.detail != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        device.address!.detail!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // 控制按钮
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (isOnline && !isRunning)
                          ? () =>
                                _startDevice(context, device.id, deviceProvider)
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('启动'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: (isOnline && isRunning)
                          ? () =>
                                _stopDevice(context, device.id, deviceProvider)
                          : null,
                      icon: const Icon(Icons.stop, size: 20),
                      label: const Text('停止'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startDevice(
    BuildContext context,
    String deviceId,
    DeviceProvider provider,
  ) async {
    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在启动设备...'),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await provider.startDevice(deviceId);

    if (context.mounted) {
      // 关闭加载指示器
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(success ? '设备启动成功' : provider.error ?? '启动失败'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success
              ? Colors.green.shade700
              : Colors.red.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopDevice(
    BuildContext context,
    String deviceId,
    DeviceProvider provider,
  ) async {
    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在停止设备...'),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await provider.stopDevice(deviceId);

    if (context.mounted) {
      // 关闭加载指示器
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(success ? '设备停止成功' : provider.error ?? '停止失败'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success
              ? Colors.green.shade700
              : Colors.red.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _DeviceStatusChip extends StatelessWidget {
  final DeviceDetail device;

  const _DeviceStatusChip({required this.device});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOnline = device.isOnline; // 使用device.status判断在线

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isOnline ? '在线' : '离线',
        style: TextStyle(
          color: isOnline
              ? colorScheme.onPrimaryContainer
              : colorScheme.onErrorContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
