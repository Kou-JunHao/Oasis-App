/// 登录请求模型
class LoginRequest {
  final String openCode;
  final String un;
  final String authCode;
  final String cid;

  LoginRequest({
    this.openCode = '',
    required this.un,
    required this.authCode,
    this.cid = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'openCode': openCode,
      'un': un,
      'authCode': authCode,
      'cid': cid,
    };
  }
}

/// 登录响应数据模型（对应后端API）
class LoginData {
  final AuthLoginData al;
  final AuthRoleData ar;
  final int showAd;

  LoginData({
    required this.al,
    required this.ar,
    required this.showAd,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      al: AuthLoginData.fromJson(json['al'] as Map<String, dynamic>),
      ar: AuthRoleData.fromJson(json['ar'] as Map<String, dynamic>),
      showAd: json['showAd'] as int? ?? 0,
    );
  }
}

/// 认证登录数据
class AuthLoginData {
  final int atype;
  final int dtype;
  final String eid;
  final String oid;
  final int stype;
  final String token;
  final String uid;  // 实际的用户ID

  AuthLoginData({
    required this.atype,
    required this.dtype,
    required this.eid,
    required this.oid,
    required this.stype,
    required this.token,
    required this.uid,
  });

  factory AuthLoginData.fromJson(Map<String, dynamic> json) {
    return AuthLoginData(
      atype: json['atype'] as int,
      dtype: json['dtype'] as int,
      eid: json['eid'] as String,
      oid: json['oid'] as String,
      stype: json['stype'] as int,
      token: json['token'] as String,
      uid: json['uid'] as String,  // 使用uid而不是oid
    );
  }
}

/// 认证角色数据
class AuthRoleData {
  final List<String> rids;
  final List<String> types;

  AuthRoleData({
    required this.rids,
    required this.types,
  });

  factory AuthRoleData.fromJson(Map<String, dynamic> json) {
    return AuthRoleData(
      rids: (json['rids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      types: (json['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
  
  // 为了向后兼容，提供name getter
  String get name => rids.isNotEmpty ? rids.first : '';
}

/// 获取验证码请求模型
class GetCodeRequest {
  final int s;
  final String authCode;
  final String un;

  GetCodeRequest({
    required this.s,
    required this.authCode,
    required this.un,
  });

  Map<String, dynamic> toJson() {
    return {
      's': s,
      'authCode': authCode,
      'un': un,
    };
  }
}

/// 登录响应模型
class LoginResponse {
  final String token;
  final User user;

  LoginResponse({
    required this.token,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// 用户信息扩展
class User {
  final String id;
  final String username;
  final String? phone;
  final String? email;
  final String? avatar;
  final double balance;
  final DateTime createdAt;
  final String? token;
  final String? userId;
  final String? phoneNumber;
  final String? eid;

  User({
    required this.id,
    required this.username,
    this.phone,
    this.email,
    this.avatar,
    this.balance = 0.0,
    required this.createdAt,
    this.token,
    this.userId,
    this.phoneNumber,
    this.eid,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // 支持多种字段名格式
    final phone = json['phone'] as String? ?? json['phoneNumber'] as String? ?? json['pn'] as String?;
    final id = json['id'] as String? ?? json['userId'] as String? ?? '';
    return User(
      id: id,
      username: json['username'] as String? ?? json['name'] as String? ?? '',
      phone: phone,
      email: json['email'] as String?,
      avatar: json['avatar'] as String? ?? json['img'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      token: json['token'] as String?,
      userId: json['userId'] as String? ?? id,
      phoneNumber: phone,
      eid: json['eid'] as String?,
    );
  }

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
