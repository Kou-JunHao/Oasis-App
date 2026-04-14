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

  bool get _isMoveMode => widget.deviceId != null;

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
            final name = (value ?? '').trim();
            if (name.isEmpty) {
              return '分组名称不能为空';
            }
            final deviceProvider = Provider.of<DeviceProvider>(
              context,
              listen: false,
            );
            if (deviceProvider.isGroupNameTaken(name)) {
              return '分组名称已存在';
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
    final success = await deviceProvider.createGroup(name);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分组名称已存在，请使用其他名称'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            final name = (value ?? '').trim();
            if (name.isEmpty) {
              return '分组名称不能为空';
            }
            final deviceProvider = Provider.of<DeviceProvider>(
              context,
              listen: false,
            );
            if (deviceProvider.isGroupNameTaken(
              name,
              excludeGroupId: group.id,
            )) {
              return '分组名称已存在';
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
    final success = await deviceProvider.renameGroup(group.id, newName);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分组名称已存在，请使用其他名称'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Future<void> _showGroupActionMenu(DeviceGroup group) async {
    final result = await showMenuBottomSheet<String>(
      context: context,
      title: group.name,
      options: [
        const MenuOption(
          title: '重命名',
          subtitle: '修改分组名称',
          icon: Icons.drive_file_rename_outline_rounded,
          value: 'rename',
        ),
        if (!group.isDefault)
          MenuOption(
            title: '删除',
            subtitle: '将设备移到未分组',
            icon: Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.error,
            value: 'delete',
          ),
      ],
    );

    if (!mounted || result == null) return;
    if (result == 'rename') {
      await _showRenameGroupDialog(context, group);
    } else if (result == 'delete') {
      await _showDeleteGroupDialog(context, group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, child) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isMoveMode
                              ? Icons.drive_file_move_rounded
                              : Icons.group_rounded,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isMoveMode ? '移动设备到分组' : '设备分组管理',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: deviceProvider.deviceGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final group = deviceProvider.deviceGroups[index];
                        final isSelected = _selectedGroupId == group.id;

                        return Material(
                          color: isSelected
                              ? colorScheme.secondaryContainer
                              : colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _isMoveMode
                                ? () {
                                    setState(() {
                                      _selectedGroupId = group.id;
                                    });
                                  }
                                : null,
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              leading: _isMoveMode
                                  ? Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? colorScheme.onSecondaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    )
                                  : Icon(
                                      group.isDefault
                                          ? Icons.folder_open_rounded
                                          : Icons.folder_rounded,
                                      color: colorScheme.primary,
                                    ),
                              title: Text(
                                group.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              trailing: !_isMoveMode
                                  ? IconButton(
                                      tooltip: '分组选项',
                                      icon: const Icon(
                                        Icons.more_horiz_rounded,
                                      ),
                                      onPressed: () =>
                                          _showGroupActionMenu(group),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!_isMoveMode)
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () async =>
                                _showCreateGroupDialog(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('创建分组'),
                          ),
                        )
                      else
                        Expanded(
                          child: FilledButton(
                            onPressed: _selectedGroupId == null
                                ? null
                                : () async {
                                    await deviceProvider.addDeviceToGroup(
                                      widget.deviceId!,
                                      _selectedGroupId!,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: const Text('确定'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final validValues = {
          'all',
          ...deviceProvider.deviceGroups.map((group) => group.id),
        };
        final safeValue = validValues.contains(deviceProvider.activeGroupId)
            ? deviceProvider.activeGroupId
            : 'all';
        final currentGroupName = safeValue == 'all'
            ? '所有设备'
            : deviceProvider.getGroupName(safeValue);

        Future<void> showGroupSelectorMenu() async {
          final result = await showMenuBottomSheet<String>(
            context: context,
            title: '筛选分组',
            options: [
              MenuOption(
                title: '所有设备',
                subtitle: safeValue == 'all' ? '当前分组' : null,
                icon: Icons.apps_rounded,
                value: 'all',
                color: safeValue == 'all' ? colorScheme.primary : null,
              ),
              ...deviceProvider.deviceGroups.map(
                (group) => MenuOption<String>(
                  title: group.name,
                  subtitle: safeValue == group.id ? '当前分组' : null,
                  icon: group.isDefault
                      ? Icons.folder_open_rounded
                      : Icons.folder_rounded,
                  value: group.id,
                  color: safeValue == group.id ? colorScheme.primary : null,
                ),
              ),
            ],
          );

          if (result != null) {
            deviceProvider.setActiveGroup(result);
          }
        }

        return Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: showGroupSelectorMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_work_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(
                      currentGroupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
