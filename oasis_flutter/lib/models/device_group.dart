/// 设备分组数据模型
class DeviceGroup {
  final String id;
  final String name;
  final List<String> deviceIds;
  final int sortOrder;
  final bool isDefault; // 是否为默认分组（未分组的设备）

  DeviceGroup({
    required this.id,
    required this.name,
    this.deviceIds = const [],
    this.sortOrder = 0,
    this.isDefault = false,
  });

  /// 从JSON创建DeviceGroup
  factory DeviceGroup.fromJson(Map<String, dynamic> json) {
    return DeviceGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceIds: (json['deviceIds'] as List<dynamic>?)?.cast<String>() ?? [],
      sortOrder: json['sortOrder'] as int? ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceIds': deviceIds,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
    };
  }

  /// 创建副本
  DeviceGroup copyWith({
    String? id,
    String? name,
    List<String>? deviceIds,
    int? sortOrder,
    bool? isDefault,
  }) {
    return DeviceGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceIds: deviceIds ?? this.deviceIds,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          deviceIds == other.deviceIds &&
          sortOrder == other.sortOrder &&
          isDefault == other.isDefault;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      deviceIds.hashCode ^
      sortOrder.hashCode ^
      isDefault.hashCode;

  @override
  String toString() {
    return 'DeviceGroup{id: $id, name: $name, deviceIds: $deviceIds, sortOrder: $sortOrder, isDefault: $isDefault}';
  }
}
