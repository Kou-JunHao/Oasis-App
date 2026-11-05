import 'package:flutter_test/flutter_test.dart';
import 'package:oasis_flutter/models/auth_models.dart';

/// 官方 3.1.10 登录成功响应的**真实结构**（值已替换为假数据）。
///
/// 关键点：`al` 里只有 `{atype, dtype, eid, ltime, stype, token, uid}`，
/// **没有 `oid`**。早期 `AuthLoginData.fromJson` 用 `json['oid'] as String`
/// 直接强转，遇到 null 会抛
/// `type 'Null' is not a subtype of type 'String' in type cast`，
/// 把已经成功的登录当成失败（issue #15 的「登录失败」就是这个）。
const _officialLoginResponse = <String, dynamic>{
  'code': 0,
  'data': <String, dynamic>{
    'adPlt': 1,
    'al': <String, dynamic>{
      'atype': 1,
      'dtype': 1,
      'eid': '0000000000000000',
      'ltime': 1793849887080,
      'stype': 1,
      'token': '00000000000000000000000000000000',
      'uid': '0000000000000000',
    },
    'ar': <String, dynamic>{
      'rids': <dynamic>[],
      'types': <dynamic>[],
    },
    'poll': <dynamic>[3, 4, 6, 20],
    'showAd': 2,
  },
  'time': 1793849887086,
};

void main() {
  group('LoginData.fromJson', () {
    test('解析官方登录响应（al 里没有 oid）不抛异常', () {
      final data = LoginData.fromJson(
        _officialLoginResponse['data'] as Map<String, dynamic>,
      );

      expect(data.al.token, '00000000000000000000000000000000');
      expect(data.al.uid, '0000000000000000');
      expect(data.al.eid, '0000000000000000');
      expect(data.al.atype, 1);
      expect(data.al.dtype, 1);
      expect(data.al.stype, 1);
      // 官方响应没有 oid，必须降级成空串而不是抛异常
      expect(data.al.oid, '');
      expect(data.ar.rids, isEmpty);
      expect(data.ar.types, isEmpty);
      expect(data.showAd, 2);
    });

    test('al / ar 缺失时也不抛异常', () {
      final data = LoginData.fromJson(const <String, dynamic>{});
      expect(data.al.token, '');
      expect(data.al.uid, '');
      expect(data.ar.rids, isEmpty);
      expect(data.showAd, 0);
    });

    test('字段类型异常时降级而不是崩溃', () {
      final data = LoginData.fromJson(<String, dynamic>{
        'al': <String, dynamic>{
          'atype': null,
          'dtype': '1',
          'eid': null,
          'oid': null,
          'stype': null,
          'token': null,
          'uid': null,
        },
        'ar': null,
        'showAd': null,
      });
      expect(data.al.atype, 0);
      // 数字字符串会被解析成数字，而不是直接丢弃
      expect(data.al.dtype, 1);
      expect(data.al.eid, '');
      expect(data.al.oid, '');
      expect(data.al.stype, 0);
      expect(data.al.token, '');
      expect(data.al.uid, '');
      expect(data.ar.rids, isEmpty);
      expect(data.showAd, 0);
    });
  });

  group('LoginRequest.toJson', () {
    test('只发 authCode 与 un，不带 cid', () {
      final json = LoginRequest(un: '13800138000', authCode: '123456').toJson();
      expect(json.keys.toList(), <String>['authCode', 'un']);
      expect(json['authCode'], '123456');
      expect(json['un'], '13800138000');
      expect(json.containsKey('cid'), isFalse);
    });

    test('openCode 非空时才带上', () {
      final json = LoginRequest(
        un: '13800138000',
        authCode: '123456',
        openCode: 'abc',
      ).toJson();
      expect(json['openCode'], 'abc');
    });
  });

  group('GetCodeRequest.toJson', () {
    test('s 是 double 且原样序列化', () {
      final json = GetCodeRequest(
        s: 0.5017482238831142,
        authCode: '83315',
        un: '13800138000',
      ).toJson();
      expect(json['s'], isA<double>());
      expect(json['s'], 0.5017482238831142);
      expect(json['authCode'], '83315');
      expect(json['un'], '13800138000');
    });
  });
}
