/// 设备实时状态与钱包明细模型
///
/// 接口（实测）：
///   GET /ui/app/dev/status?did=<设备id>
///     data.device {id, status, gene{out,status,mode,vel,pluse,err,offcnt,thirdDevNid},
///                  subs:[{out,status}]}
///     data.prepay
///   GET /acc/wallet/detail?id=<钱包id>
///     data {id, ep{id,name,status}, owner{id,name,pn},
///           ofCash, ofGift, olCash, olGift, total, rtime, utime}
library;

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

/// 设备运行信息（gene）
class DeviceGeneStatus {
  /// 累计出水量（升）
  final double totalOut;

  /// 99 表示未运行，其它值表示运行中
  final int status;
  final int mode;

  /// 实时流速
  final int velocity;

  /// 脉冲计数
  final int pulse;

  /// 错误码，0 表示正常
  final int error;
  final int offCount;

  const DeviceGeneStatus({
    required this.totalOut,
    required this.status,
    required this.mode,
    required this.velocity,
    required this.pulse,
    required this.error,
    required this.offCount,
  });

  bool get running => status != 99;
  bool get hasError => error != 0;

  factory DeviceGeneStatus.fromJson(Map<String, dynamic> json) =>
      DeviceGeneStatus(
        totalOut: _double(json['out']),
        status: _int(json['status']),
        mode: _int(json['mode']),
        velocity: _int(json['vel']),
        pulse: _int(json['pluse']),
        error: _int(json['err']),
        offCount: _int(json['offcnt']),
      );
}

/// 分路（出水口）状态
class DeviceSubStatus {
  final double out;
  final int status;

  const DeviceSubStatus({required this.out, required this.status});

  factory DeviceSubStatus.fromJson(Map<String, dynamic> json) =>
      DeviceSubStatus(out: _double(json['out']), status: _int(json['status']));

  bool get active => status != 0;
}

/// 设备实时状态
class DeviceRuntimeStatus {
  final String id;

  /// 1 表示设备在线
  final int status;
  final DeviceGeneStatus? gene;
  final List<DeviceSubStatus> subs;

  /// 是否预付费设备
  final bool prepay;

  const DeviceRuntimeStatus({
    required this.id,
    required this.status,
    this.gene,
    this.subs = const [],
    this.prepay = false,
  });

  bool get online => status == 1;
  bool get running => gene?.running ?? false;

  /// 累计出水量（升）
  double get totalOut => gene?.totalOut ?? 0;

  factory DeviceRuntimeStatus.fromJson(Map<String, dynamic> json) {
    final deviceJson = json['device'];
    if (deviceJson is! Map) {
      return DeviceRuntimeStatus(id: '', status: 0, prepay: json['prepay'] == true);
    }
    final geneJson = deviceJson['gene'];
    final subsJson = deviceJson['subs'];
    return DeviceRuntimeStatus(
      id: (deviceJson['id'] ?? '').toString(),
      status: _int(deviceJson['status']),
      gene: geneJson is Map<String, dynamic>
          ? DeviceGeneStatus.fromJson(geneJson)
          : null,
      subs: subsJson is List
          ? subsJson
              .whereType<Map<String, dynamic>>()
              .map(DeviceSubStatus.fromJson)
              .toList()
          : const [],
      prepay: json['prepay'] == true,
    );
  }
}

/// 钱包明细（余额构成）
class WalletDetail {
  final String id;
  final String endpointName;
  final String ownerName;
  final String ownerPhone;

  /// 线上现金 / 线上赠送 / 线下现金 / 线下赠送
  final double onlineCash;
  final double onlineGift;
  final double offlineCash;
  final double offlineGift;
  final double total;
  final DateTime? updateTime;

  const WalletDetail({
    required this.id,
    required this.endpointName,
    required this.ownerName,
    required this.ownerPhone,
    required this.onlineCash,
    required this.onlineGift,
    required this.offlineCash,
    required this.offlineGift,
    required this.total,
    this.updateTime,
  });

  /// 赠送余额合计
  double get giftTotal => onlineGift + offlineGift;

  /// 现金余额合计
  double get cashTotal => onlineCash + offlineCash;

  factory WalletDetail.fromJson(Map<String, dynamic> json) {
    final ep = json['ep'];
    final owner = json['owner'];
    final utime = _int(json['utime']);
    return WalletDetail(
      id: (json['id'] ?? '').toString(),
      endpointName: ep is Map ? (ep['name'] ?? '').toString() : '',
      ownerName: owner is Map ? (owner['name'] ?? '').toString() : '',
      ownerPhone: owner is Map ? (owner['pn'] ?? '').toString() : '',
      onlineCash: _double(json['olCash']),
      onlineGift: _double(json['olGift']),
      offlineCash: _double(json['ofCash']),
      offlineGift: _double(json['ofGift']),
      total: _double(json['total']),
      updateTime:
          utime > 0 ? DateTime.fromMillisecondsSinceEpoch(utime) : null,
    );
  }
}
