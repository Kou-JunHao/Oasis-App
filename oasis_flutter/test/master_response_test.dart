import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/models/api_models.dart';

void main() {
  group('Master 响应解析', () {
    test('登录态失效时服务端只回广告位数据，不应抛类型转换错误', () {
      // 实测：token 失效时 /ui/app/master 返回 code=0 + {"ads":[]}
      final data = MasterResponseData.fromJson({'ads': <dynamic>[]});
      expect(data.authenticated, isFalse);
      expect(data.account, isNull);
      expect(data.devices, isEmpty);
    });

    test('正常响应能解析账号与设备列表', () {
      final data = MasterResponseData.fromJson({
        'account': {'id': 123, 'name': '测试用户', 'pn': '13800000000'},
        'favos': [
          {'id': 'dev-1', 'name': '一号机'},
        ],
        'pltTotalScore': '120',
      });
      expect(data.authenticated, isTrue);
      expect(data.account!.name, '测试用户');
      expect(data.devices.length, 1);
      expect(data.pltTotalScore, '120');
    });

    test('字段缺失或类型异常时不抛异常', () {
      expect(MasterResponseData.fromJson(const {}).authenticated, isFalse);
      expect(MasterResponseData.fromJson(const {'favos': 'oops'}).devices, isEmpty);
      expect(
        MasterResponseData.fromJson(const {'account': 'oops'}).authenticated,
        isFalse,
      );
      // 设备列表里混入非法项时跳过而不是崩溃
      final data = MasterResponseData.fromJson({
        'account': {'id': 1},
        'favos': [
          'not-a-map',
          {'id': 'dev-2', 'name': '二号机'},
        ],
      });
      expect(data.devices.length, 1);
      expect(data.devices.first.id, 'dev-2');
    });
  });
}
