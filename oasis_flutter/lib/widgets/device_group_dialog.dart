import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/device_group.dart';
import 'bottom_sheet_helper.dart';

/// 设备分组管理对话框
class DeviceGroupDialog extends StatefulWidget {
  final String? deviceId; // 可选，用于单个设备的分组操作

  const DeviceGroupDialog({super.key, this.deviceId});

  @override
  State<DeviceGroupDialog> createState() => _DeviceGroupDialogState();
}

class _DeviceGroupDialogState extends State<DeviceGroupDialog> {
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    if (widget.deviceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final deviceProvider = Provider.of<DeviceProvider>(
          context,
          listen: false,
        );
        setState(() {
          _selectedGroupId = deviceProvider.getDeviceGroupId(widget.deviceId!);
        });
      });
    }
  }

  /// 显示创建分组对话框
  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final result = await showInputBottomSheet(
      context: context,
      title: '创建新分组',
      icon: Icons.create_new_folder_rounded,
      confirmText: '创建',
      fields: [
        InputField(
          key: 'groupName',
          label: '分组名称',
          hint: '输入分组名称',
          icon: Icons.group_rounded,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return '分组名称不能为空';
            }
            return null;
          },
        ),
      ],
    );

    if (result == null || !context.mounted) return;
    final name = (result['groupName'] ?? '').trim();
    if (name.isEmpty) return;

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    await deviceProvider.createGroup(name);
  }

  /// 显示重命名分组对话框
  Future<void> _showRenameGroupDialog(
    BuildContext context,
    DeviceGroup group,
  ) async {
    final result = await showInputBottomSheet(
      context: context,
      title: '重命名分组',
      icon: Icons.drive_file_rename_outline_rounded,
      confirmText: '保存',
      fields: [
        InputField(
          key: 'groupName',
          label: '新分组名称',
          hint: '输入新分组名称',
          icon: Icons.group_rounded,
          initialValue: group.name,
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return '分组名称不能为空';
            }
            return null;
          },
        ),
      ],
    );

    if (result == null || !context.mounted) return;
    final newName = (result['groupName'] ?? '').trim();
    if (newName.isEmpty || newName == group.name) return;

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    await deviceProvider.renameGroup(group.id, newName);
  }

  /// 显示删除分组确认对话框
  Future<void> _showDeleteGroupDialog(
    BuildContext context,
    DeviceGroup group,
  ) async {
    final confirmed = await showConfirmBottomSheet(
      context: context,
      title: '删除分组',
      message: '确定要删除分组 "${group.name}" 吗？该分组下的设备将移动到“未分组”。',
      icon: Icons.delete_outline_rounded,
      confirmText: '删除',
      isDangerous: true,
    );

    if (confirmed != true || !context.mounted) return;
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    await deviceProvider.deleteGroup(group.id);
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
                onPressed: () async => _showCreateGroupDialog(context),
                child: const Text('创建分组'),
              ),
            if (widget.deviceId != null)
              TextButton(
                onPressed: () async {
                  if (_selectedGroupId != null && context.mounted) {
                    await deviceProvider.addDeviceToGroup(
                      widget.deviceId!,
                      _selectedGroupId!,
                    );
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
        final validValues = {
          'all',
          ...deviceProvider.deviceGroups.map((group) => group.id),
        };
        final safeValue = validValues.contains(deviceProvider.activeGroupId)
            ? deviceProvider.activeGroupId
            : 'all';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('所有设备')),
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
            ),
          ),
        );
      },
    );
  }
}
