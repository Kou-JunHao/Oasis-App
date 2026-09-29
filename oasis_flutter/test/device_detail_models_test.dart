import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/models/device_detail_models.dart';

void main() {
  group('设备实时状态', () {
    // 实测响应（ui/app/dev/status?did=...）
    const realResponse = {
      'device': {
        'gene': {
          'out': 17148.782,
          'status': 99,
          'offcnt': 0,
          'mode': 0,
          'err': 0,
          'vel': 3,
          'pluse': 386,
          'thirdDevNid': '',
        },
        'id': 'test-device-id',
        'status': 1,
        'subs': [
          {'out': 0.57, 'status': 0},
          {'out': 0.0, 'status': 0},
        ],
      },
      'prepay': false,
    };

    test('解析在线状态、累计出水量与运行参数', () {
      final status = DeviceRuntimeStatus.fromJson(realResponse);
      expect(status.id, 'test-device-id');
      expect(status.online, isTrue);
      expect(status.running, isFalse); // gene.status == 99 表示未运行
      expect(status.totalOut, closeTo(17148.782, 0.001));
      expect(status.gene!.velocity, 3);
      expect(status.gene!.pulse, 386);
      expect(status.gene!.hasError, isFalse);
      expect(status.subs.length, 2);
      expect(status.subs.first.out, closeTo(0.57, 0.001));
      expect(status.prepay, isFalse);
    });

    test('缺少 device 字段时返回空状态而不是抛异常', () {
      final status = DeviceRuntimeStatus.fromJson(const {'prepay': true});
      expect(status.id, isEmpty);
      expect(status.online, isFalse);
      expect(status.totalOut, 0);
      expect(status.prepay, isTrue);
    });

    test('数值以字符串下发时也能解析', () {
      final status = DeviceRuntimeStatus.fromJson(const {
        'device': {
          'id': 123,
          'status': '1',
          'gene': {'out': '12.5', 'status': '0', 'vel': '7', 'err': '2'},
        },
      });
      expect(status.id, '123');
      expect(status.online, isTrue);
      expect(status.running, isTrue);
      expect(status.totalOut, closeTo(12.5, 0.001));
      expect(status.gene!.hasError, isTrue);
    });
  });

  group('钱包明细', () {
    // 实测响应（acc/wallet/detail?id=...）
    const realResponse = {
      'auth': false,
      'ep': {'id': 'test-endpoint-id', 'name': '支付宝第三方结算平台', 'status': 1},
      'id': 'test-account-idtest-endpoint-id',
      'ofCash': 0.0,
      'ofGift': 1.5,
      'olCash': 0.01,
      'olGift': 2.5,
      'owner': {'id': 'test-account-id', 'name': '测试用户', 'pn': '13800000000'},
      'rtime': 1759112548161,
      'total': 4.01,
      'utime': 1762330593682,
    };

    test('解析余额构成与归属信息', () {
      final detail = WalletDetail.fromJson(realResponse);
      expect(detail.endpointName, '支付宝第三方结算平台');
      expect(detail.ownerName, '测试用户');
      expect(detail.ownerPhone, '13800000000');
      expect(detail.onlineCash, closeTo(0.01, 1e-9));
      expect(detail.onlineGift, closeTo(2.5, 1e-9));
      expect(detail.offlineGift, closeTo(1.5, 1e-9));
      expect(detail.cashTotal, closeTo(0.01, 1e-9));
      expect(detail.giftTotal, closeTo(4.0, 1e-9));
      expect(detail.total, closeTo(4.01, 1e-9));
      expect(detail.updateTime, isNotNull);
    });

    test('字段缺失时返回零值而不是抛异常', () {
      final detail = WalletDetail.fromJson(const {});
      expect(detail.id, isEmpty);
      expect(detail.total, 0);
      expect(detail.updateTime, isNull);
      expect(detail.giftTotal, 0);
    });
  });
}
