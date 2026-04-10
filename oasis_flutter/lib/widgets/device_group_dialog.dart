import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/device_group.dart';

/// 设备分组管理对话框
class DeviceGroupDialog extends StatefulWidget {
  final String? deviceId; // 可选，用于单个设备的分组操作

  const DeviceGroupDialog({super.key, this.deviceId});

  @override
  State<DeviceGroupDialog> createState() => _DeviceGroupDialogState();
}

class _DeviceGroupDialogState extends State<DeviceGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    if (widget.deviceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
        _selectedGroupId = deviceProvider.getDeviceGroupId(widget.deviceId!);
      });
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  /// 显示创建分组对话框
  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新分组'),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(
            hintText: '输入分组名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
                final name = _groupNameController.text.trim();
                if (name.isNotEmpty && context.mounted) {
                  final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
                  await deviceProvider.createGroup(name);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  /// 显示重命名分组对话框
  void _showRenameGroupDialog(BuildContext context, DeviceGroup group) {
    _groupNameController.text = group.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(
            hintText: '输入新分组名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
                final newName = _groupNameController.text.trim();
                if (newName.isNotEmpty && newName != group.name && context.mounted) {
                  final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
                  await deviceProvider.renameGroup(group.id, newName);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 显示删除分组确认对话框
  void _showDeleteGroupDialog(BuildContext context, DeviceGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除分组 "${group.name}" 吗？该分组下的设备将移动到 "未分组"。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
                if (context.mounted) {
                  final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
                  await deviceProvider.deleteGroup(group.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        return AlertDialog(
          title: widget.deviceId != null
              ? const Text('移动设备到分组')
              : const Text('设备分组管理'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: deviceProvider.deviceGroups.length,
              itemBuilder: (context, index) {
                final group = deviceProvider.deviceGroups[index];
                final isSelected = _selectedGroupId == group.id;

                return ListTile(
                  selected: isSelected,
                  leading: widget.deviceId != null
                      ? Radio<String>(
                          value: group.id,
                          groupValue: _selectedGroupId,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (value) {
                            setState(() {
                              _selectedGroupId = value;
                            });
                          },
                        )
                      : null,
                  title: Text(group.name),
                  trailing: widget.deviceId == null
                      ? PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('重命名'),
                            ),
                            if (!group.isDefault)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('删除'),
                              ),
                          ],
                          onSelected: (value) {
                            if (value == 'rename') {
                              _showRenameGroupDialog(context, group);
                            } else if (value == 'delete') {
                              _showDeleteGroupDialog(context, group);
                            }
                          },
                        )
                      : null,
                  onTap: widget.deviceId != null
                      ? () {
                          setState(() {
                            _selectedGroupId = group.id;
                          });
                        }
                      : null,
                );
              },
            ),
          ),
          actions: [
            if (widget.deviceId == null)
              TextButton(
                onPressed: () => _showCreateGroupDialog(context),
                child: const Text('创建分组'),
              ),
            if (widget.deviceId != null)
              TextButton(
                onPressed: () async {
                if (_selectedGroupId != null && context.mounted) {
                  await deviceProvider.addDeviceToGroup(widget.deviceId!, _selectedGroupId!);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
                child: const Text('确定'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
}

/// 分组选择下拉菜单
class GroupSelectorDropdown extends StatelessWidget {
  const GroupSelectorDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        return DropdownButton<String>(
          value: deviceProvider.activeGroupId,
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('所有设备'),
            ),
            ...deviceProvider.deviceGroups.map((group) {
              return DropdownMenuItem(
                value: group.id,
                child: Text(group.name),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null) {
              deviceProvider.setActiveGroup(value);
            }
          },
        );
      },
    );
  }
}
