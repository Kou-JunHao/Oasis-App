/// 扩展的API数据模型
library;

/// 通用API响应
class ApiResponse<T> {
  final int code;
  final String? message;
  final T? data;

  ApiResponse({
    required this.code,
    this.message,
    this.data,
  });

  bool get isSuccess => code == 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int,
      message: json['msg'] as String?,
      data: fromJsonT != null && json['data'] != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
    );
  }
}

/// Master响应数据（包含用户信息和设备列表）
class MasterResponseData {
  final UserAccount account;
  final List<DeviceDetail> devices;
  final String? pltTotalScore;

  MasterResponseData({
    required this.account,
    required this.devices,
    this.pltTotalScore,
  });

  factory MasterResponseData.fromJson(Map<String, dynamic> json) {
    return MasterResponseData(
      account: UserAccount.fromJson(json['account'] as Map<String, dynamic>),
      devices: (json['favos'] as List<dynamic>)
          .map((e) => DeviceDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      pltTotalScore: json['pltTotalScore'] as String?,
    );
  }
}

/// 用户账户信息
class UserAccount {
  final String id;
  final String? name;
  final String? phoneNumber;
  final String? avatarUrl;

  UserAccount({
    required this.id,
    this.name,
    this.phoneNumber,
    this.avatarUrl,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'].toString(),  // 处理int和String
      name: json['name'] as String?,
      phoneNumber: json['pn']?.toString(),  // 处理int和String
      avatarUrl: json['img'] as String?,  // 使用img字段，不是avatar
    );
  }
}

/// 设备详细信息
class DeviceDetail {
  final String id;
  final String? name;
  final int status; // 设备在线状态：1=在线, 0=离线
  final DeviceOwner owner;
  final DeviceGene? gene;
  final DeviceAddress? address;
  final DeviceEndpoint? endpoint;

  DeviceDetail({
    required this.id,
    this.name,
    required this.status,
    required this.owner,
    this.gene,
    this.address,
    this.endpoint,
  });

  // device.status == 1 表示设备在线（网络连接）
  bool get isOnline => status == 1;
  // gene.status != 99 表示设备正在运行（工作状态）
  bool get isRunning => gene != null && gene!.status != 99;
  String get statusText => isOnline ? '在线' : '离线';
  String get runningText => isRunning ? '运行中' : '已停止';

  factory DeviceDetail.fromJson(Map<String, dynamic> json) {
    return DeviceDetail(
      id: json['id'].toString(),  // 处理int和String类型
      name: json['name'] as String?,
      status: json['status'] as int? ?? 0, // 默认为离线
      owner: DeviceOwner.fromJson(json['owner'] as Map<String, dynamic>),
      gene: json['gene'] != null
          ? DeviceGene.fromJson(json['gene'] as Map<String, dynamic>)
          : null,
      address: json['addr'] != null
          ? DeviceAddress.fromJson(json['addr'] as Map<String, dynamic>)
          : null,
      endpoint: json['ep'] != null
          ? DeviceEndpoint.fromJson(json['ep'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 设备所有者信息
class DeviceOwner {
  final String id;

  DeviceOwner({required this.id});

  factory DeviceOwner.fromJson(Map<String, dynamic> json) {
    return DeviceOwner(id: json['id'].toString());  // 处理int和String
  }
}

/// 设备基因信息
class DeviceGene {
  final int status; // 99表示设备未开启/离线，其他值表示在线

  DeviceGene({required this.status});

  factory DeviceGene.fromJson(Map<String, dynamic> json) {
    return DeviceGene(status: json['status'] as int? ?? 99);
  }
}

/// 设备地址信息
class DeviceAddress {
  final String? detail;
  final String? prov;
  final String? city;
  final String? dist;

  DeviceAddress({
    this.detail,
    this.prov,
    this.city,
    this.dist,
  });

  factory DeviceAddress.fromJson(Map<String, dynamic> json) {
    return DeviceAddress(
      detail: json['detail'] as String?,
      prov: json['prov'] as String?,
      city: json['city'] as String?,
      dist: json['dist'] as String?,
    );
  }
}

/// 设备端点信息
class DeviceEndpoint {
  final String id;
  final String name;

  DeviceEndpoint({
    required this.id,
    required this.name,
  });

  factory DeviceEndpoint.fromJson(Map<String, dynamic> json) {
    return DeviceEndpoint(
      id: json['id'].toString(),  // 处理int和String
      name: json['name'] as String,
    );
  }
}

/// 钱包响应数据
class WalletResponseData {
  final WalletData? wallet;  // aw - 主钱包
  final List<WalletData>? wallets;  // eps - 多个钱包
  final int charge;
  final int vip;
  final int refund;
  final WalletEndpointInfo? endpoint;

  WalletResponseData({
    this.wallet,
    this.wallets,
    this.charge = 0,
    this.vip = 0,
    this.refund = 0,
    this.endpoint,
  });

  // 获取主要的钱包数据 - 优先使用aw，与Kotlin版本一致
  WalletData? get primaryWallet {
    // 优先返回aw（主钱包），只有在aw为null且eps不为空时才使用eps中余额最高的
    if (wallet != null) return wallet;
    if (wallets == null || wallets!.isEmpty) return null;
    
    // 从eps中选择余额最高的钱包（与Kotlin版本一致）
    return wallets!.reduce((curr, next) => 
      curr.displayBalance > next.displayBalance ? curr : next
    );
  }
  
  // 获取所有可用的钱包数据
  List<WalletData> get allWallets {
    final result = <WalletData>[];
    if (wallet != null) result.add(wallet!);
    if (wallets != null) result.addAll(wallets!);
    return result;
  }

  factory WalletResponseData.fromJson(Map<String, dynamic> json) {
    // API返回的是{aw: {...}, eps: [...], ...}格式
    final awData = json['aw'] as Map<String, dynamic>?;
    final epsData = json['eps'] as List<dynamic>?;
    
    // 从 aw.ep 中获取 endpoint，而不是从 awData 直接获取
    WalletEndpointInfo? endpoint;
    if (awData != null && awData['ep'] != null) {
      endpoint = WalletEndpointInfo.fromJson(awData['ep'] as Map<String, dynamic>);
    }
    
    return WalletResponseData(
      wallet: awData != null ? WalletData.fromJson(awData) : null,
      wallets: epsData?.map((e) => WalletData.fromJson(e as Map<String, dynamic>)).toList(),
      charge: json['charge'] as int? ?? 0,
      vip: json['vip'] as int? ?? 0,
      refund: json['refund'] as int? ?? 0,
      endpoint: endpoint,
    );
  }
}

/// 钱包数据
class WalletData {
  final String? id;
  final String? name;
  final double balance;  // 兼容旧版本
  final double total;    // 实际余额
  final double? olCash;  // 在线现金余额
  final double? olGift;  // 在线礼品余额
  final double? ofCash;  // 离线现金余额
  final double? ofGift;  // 离线礼品余额
  final String currency; // 货币类型
  final double frozen;   // 冻结金额
  final WalletEndpointInfo? ep;
  final WalletOwner? owner;
  final String? rtime;   // 创建时间
  final String? utime;   // 更新时间

  WalletData({
    this.id,
    this.name,
    this.balance = 0.0,
    required this.total,
    this.olCash,
    this.olGift,
    this.ofCash,
    this.ofGift,
    this.currency = 'CNY',
    this.frozen = 0.0,
    this.ep,
    this.owner,
    this.rtime,
    this.utime,
  });

  // 获取实际显示的余额，优先使用olCash字段
  double get displayBalance => olCash ?? (total > 0.0 ? total : balance);
  
  // 获取总余额（所有余额字段相加）
  double get totalBalance {
    return (olCash ?? 0.0) + (olGift ?? 0.0) + (ofCash ?? 0.0) + (ofGift ?? 0.0);
  }

  factory WalletData.fromJson(Map<String, dynamic> json) {
    return WalletData(
      id: json['id']?.toString(),  // 处理int和String
      name: json['name'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      olCash: (json['olCash'] as num?)?.toDouble(),
      olGift: (json['olGift'] as num?)?.toDouble(),
      ofCash: (json['ofCash'] as num?)?.toDouble(),
      ofGift: (json['ofGift'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      frozen: (json['frozen'] as num?)?.toDouble() ?? 0.0,
      ep: json['ep'] != null 
          ? WalletEndpointInfo.fromJson(json['ep'] as Map<String, dynamic>)
          : null,
      owner: json['owner'] != null
          ? WalletOwner.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      rtime: json['rtime']?.toString(),  // 处理int和String
      utime: json['utime']?.toString(),  // 处理int和String
    );
  }
}

/// 钱包端点信息
class WalletEndpointInfo {
  final String id;
  final String name;
  final WalletContact? contact;
  final WalletSetting? setting;

  WalletEndpointInfo({
    required this.id,
    required this.name,
    this.contact,
    this.setting,
  });

  factory WalletEndpointInfo.fromJson(Map<String, dynamic> json) {
    return WalletEndpointInfo(
      id: json['id'].toString(),  // 处理int和String
      name: json['name'] as String,
      contact: json['contact'] != null
          ? WalletContact.fromJson(json['contact'] as Map<String, dynamic>)
          : null,
      setting: json['setting'] != null
          ? WalletSetting.fromJson(json['setting'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 钱包联系人信息
class WalletContact {
  final String name;
  final String pn;

  WalletContact({
    required this.name,
    required this.pn,
  });

  factory WalletContact.fromJson(Map<String, dynamic> json) {
    return WalletContact(
      name: json['name'] as String,
      pn: json['pn'].toString(),  // 处理int和String
    );
  }
}

/// 钱包设置信息
class WalletSetting {
  final int olcharge;
  final int olrefund;
  final int thirdPay;

  WalletSetting({
    this.olcharge = 0,
    this.olrefund = 0,
    this.thirdPay = 0,
  });

  factory WalletSetting.fromJson(Map<String, dynamic> json) {
    return WalletSetting(
      olcharge: json['olcharge'] as int? ?? 0,
      olrefund: json['olrefund'] as int? ?? 0,
      thirdPay: json['thirdPay'] as int? ?? 0,
    );
  }
}

/// 钱包所有者信息
class WalletOwner {
  final String id;
  final String name;
  final String pn;

  WalletOwner({
    required this.id,
    required this.name,
    required this.pn,
  });

  factory WalletOwner.fromJson(Map<String, dynamic> json) {
    return WalletOwner(
      id: json['id'].toString(),  // 处理int和String
      name: json['name'] as String,
      pn: json['pn'].toString(),  // 处理int和String
    );
  }
}

/// 订单列表响应
class OrderListResponse {
  final List<OrderData> orders;
  final int totalElements;

  OrderListResponse({
    required this.orders,
    required this.totalElements,
  });

  factory OrderListResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] ?? json['content'];
    return OrderListResponse(
      orders: dataList != null && dataList is List
          ? dataList.map((e) => OrderData.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      totalElements: (json['totalElements'] ?? json['total'] ?? 0) as int,
    );
  }
}

/// 订单数据
class OrderData {
  final String id;
  final String cata;  // 订单分类
  final int status;   // 订单状态: 1=待支付, 2=已支付, 3=失败, 4=已取消
  final double payment;
  final String message;
  final String createTime;
  final String? updateTime;

  OrderData({
    required this.id,
    required this.cata,
    required this.status,
    required this.payment,
    required this.message,
    required this.createTime,
    this.updateTime,
  });

  String get formattedAmount => '¥${payment.toStringAsFixed(2)}';

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      id: json['id'].toString(), // 支持int和String
      cata: json['cata'].toString(), // 订单分类
      status: (json['status'] as num?)?.toInt() ?? 1, // 订单状态
      payment: (json['payment'] as num?)?.toDouble() ?? 0.0,
      message: json['msg'] as String? ?? '',
      createTime: _parseTimestamp(json['ctime']),
      updateTime: json['utime'] != null ? _parseTimestamp(json['utime']) : null,
    );
  }

  static String _parseTimestamp(dynamic value) {
    if (value is int) {
      // 毫秒时间戳转换为日期字符串
      final date = DateTime.fromMillisecondsSinceEpoch(value);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return value.toString();
  }
}

/// 充值产品
class Product {
  final String id;
  final String name;
  final double price;
  final double? originPrice;
  final String? description;
  final ProductPromotion? promotion;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.originPrice,
    this.description,
    this.promotion,
  });

  bool get hasDiscount => originPrice != null && originPrice! > price;
  double? get discountAmount => hasDiscount ? originPrice! - price : null;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      price: (json['curPrice'] as num?)?.toDouble() ?? 0.0,
      originPrice: (json['ogiPrice'] as num?)?.toDouble(),
      description: json['desc'] as String?,
      promotion: json['promo'] != null && json['promo'] is Map
          ? ProductPromotion.fromJson(json['promo'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 产品优惠信息
class ProductPromotion {
  final String? title;
  final String? description;

  ProductPromotion({
    this.title,
    this.description,
  });

  factory ProductPromotion.fromJson(Map<String, dynamic> json) {
    return ProductPromotion(
      title: json['title'] as String?,
      description: json['desc'] as String?,
    );
  }
}

/// 支付渠道响应
class PaymentChannelsResponse {
  final BillInfo bill;
  final List<PaymentChannel> channels;

  PaymentChannelsResponse({
    required this.bill,
    required this.channels,
  });

  factory PaymentChannelsResponse.fromJson(Map<String, dynamic> json) {
    return PaymentChannelsResponse(
      bill: BillInfo.fromJson(json['bill'] as Map<String, dynamic>),
      channels: (json['channels'] as List<dynamic>)
          .map((e) => PaymentChannel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 账单信息
class BillInfo {
  final int cata;
  final String id;
  final double payment;

  BillInfo({
    required this.cata,
    required this.id,
    required this.payment,
  });

  factory BillInfo.fromJson(Map<String, dynamic> json) {
    return BillInfo(
      cata: json['cata'] as int,
      id: json['id'] as String,
      payment: (json['payment'] as num).toDouble(),
    );
  }
}

/// 支付渠道
class PaymentChannel {
  final int type;
  final String name;
  final String? icon;

  PaymentChannel({
    required this.type,
    required this.name,
    this.icon,
  });

  factory PaymentChannel.fromJson(Map<String, dynamic> json) {
    return PaymentChannel(
      type: json['type'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
    );
  }
}

/// 添加设备请求
class AddDeviceRequest {
  final String did;
  final String? password;

  AddDeviceRequest({
    required this.did,
    this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'did': did,
      if (password != null) 'password': password,
    };
  }
}

/// 添加设备响应
class AddDeviceResponse {
  final String deviceId;
  final String message;

  AddDeviceResponse({
    required this.deviceId,
    required this.message,
  });

  factory AddDeviceResponse.fromJson(Map<String, dynamic> json) {
    return AddDeviceResponse(
      deviceId: json['did'] as String,
      message: json['msg'] as String? ?? '设备添加成功',
    );
  }
}

/// 创建充值订单请求（与Kotlin版本一致）
class BillSaveRequest {
  final int cata;
  final BillContact contact;
  final BillEndpointRef ep;
  final String note;
  final BillOwnerRef owner;
  final List<BillProduct> prds;  // 改为prds数组

  BillSaveRequest({
    required this.cata,
    required this.contact,
    required this.ep,
    required this.note,
    required this.owner,
    required this.prds,  // 改为prds
  });

  Map<String, dynamic> toJson() {
    return {
      'cata': cata,
      'contact': contact.toJson(),
      'ep': ep.toJson(),
      'note': note,
      'owner': owner.toJson(),
      'prds': prds.map((p) => p.toJson()).toList(),  // 改为prds数组
    };
  }
}

/// 账单联系人（仅包含id）
class BillContact {
  final String id;  // 只有id字段

  BillContact({required this.id});

  Map<String, dynamic> toJson() {
    return {'id': id};  // 只有id
  }
}

/// 账单端点引用
class BillEndpointRef {
  final String id;

  BillEndpointRef({required this.id});

  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}

/// 账单所有者引用
class BillOwnerRef {
  final String id;

  BillOwnerRef({required this.id});

  Map<String, dynamic> toJson() {
    return {'id': id};
  }
}

/// 账单产品
class BillProduct {
  final String id;
  final int count;  // 改为count

  BillProduct({
    required this.id,
    required this.count,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'count': count,  // 改为count
    };
  }
}
