/// 用户模型
class User {
  final String id;
  final String username;
  final String? phone;
  final String? email;
  final String? avatar;
  final double balance;
  final DateTime createdAt;
  final String token;
  final String userId;
  final String phoneNumber;
  final String? eid;

  User({
    required this.id,
    required this.username,
    this.phone,
    this.email,
    this.avatar,
    this.balance = 0.0,
    required this.createdAt,
    required this.token,
    required this.userId,
    required this.phoneNumber,
    this.eid,
  });

  /// 从 JSON 创建用户对象
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      token: json['token'] as String? ?? '',
      userId: json['userId'] as String? ?? json['id'] as String,
      phoneNumber: json['phoneNumber'] as String? ?? json['phone'] as String? ?? '',
      eid: json['eid'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'phone': phone,
      'email': email,
      'avatar': avatar,
      'balance': balance,
      'created_at': createdAt.toIso8601String(),
      'token': token,
      'userId': userId,
      'phoneNumber': phoneNumber,
      'eid': eid,
    };
  }
  
  /// 创建副本
  User copyWith({
    String? id,
    String? username,
    String? phone,
    String? email,
    String? avatar,
    double? balance,
    DateTime? createdAt,
    String? token,
    String? userId,
    String? phoneNumber,
    String? eid,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      eid: eid ?? this.eid,
    );
  }
}
