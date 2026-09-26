import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/services/api_service.dart';

void main() {
  group('登录状态失效识别', () {
    test('服务端实际的失效响应（HTTP 200 + code=-99）能被识别', () {
      // 实测：失效 token 请求 /api/v1/acc/wallet/owner 的真实响应
      expect(
        ApiService.isSessionExpiredPayload({
          'code': -99,
          'msg': '登录状态已过期',
        }),
        isTrue,
      );
    });

    test('只有 code 字段也能识别', () {
      expect(ApiService.isSessionExpiredPayload({'code': -99}), isTrue);
    });

    test('成功响应不会被误判', () {
      expect(
        ApiService.isSessionExpiredPayload({
          'code': 0,
          'data': {'ads': []},
          'time': 1790400871389,
        }),
        isFalse,
      );
    });

    test('其它业务错误码不会被当成登录失效', () {
      expect(ApiService.isSessionExpiredPayload({'code': -1, 'msg': '参数错误'}), isFalse);
      expect(ApiService.isSessionExpiredPayload({'code': -2, 'msg': '验证码错误'}), isFalse);
    });

    test('非 JSON 结构的响应体（验证码图片字节流等）不会误判', () {
      expect(ApiService.isSessionExpiredPayload(null), isFalse);
      expect(ApiService.isSessionExpiredPayload('plain text'), isFalse);
      expect(ApiService.isSessionExpiredPayload([1, 2, 3]), isFalse);
      expect(ApiService.isSessionExpiredPayload({'code': '-99'}), isFalse);
    });
  });
}
