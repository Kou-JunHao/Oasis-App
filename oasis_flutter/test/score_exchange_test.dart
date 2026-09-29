import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/models/score_models.dart';

void main() {
  group('兑换参数校验', () {
    test('积分必须为正且是 100 的整数倍', () {
      expect(isValidExchangeScore(100), isTrue);
      expect(isValidExchangeScore(1000), isTrue);
      expect(isValidExchangeScore(150), isFalse);
      expect(isValidExchangeScore(0), isFalse);
      expect(isValidExchangeScore(-100), isFalse);
    });

    test('档位只允许 100 / 1000', () {
      expect(scoreExchangeAmounts, [100, 1000]);
    });

    test('份数不得超过可用积分', () {
      expect(
        isValidExchangeQuantity(unitScore: 100, quantity: 1, available: 100),
        isTrue,
      );
      expect(
        isValidExchangeQuantity(unitScore: 100, quantity: 2, available: 100),
        isFalse,
      );
      expect(
        isValidExchangeQuantity(unitScore: 1000, quantity: 1, available: 1000),
        isTrue,
      );
      expect(
        isValidExchangeQuantity(unitScore: 1000, quantity: 1, available: 80),
        isFalse,
      );
      expect(
        isValidExchangeQuantity(unitScore: 500, quantity: 1, available: 1000),
        isFalse,
      );
      expect(
        isValidExchangeQuantity(unitScore: 100, quantity: 0, available: 100),
        isFalse,
      );
    });
  });

  group('兑换响应解析', () {
    test('账单号取 data.sn，空值与 "null" 视为缺失', () {
      expect(exchangeBillIdOf({'code': 0, 'data': {'sn': 'B123'}}), 'B123');
      expect(exchangeBillIdOf({'code': 0, 'data': {'sn': ''}}), isNull);
      expect(exchangeBillIdOf({'code': 0, 'data': {'sn': 'null'}}), isNull);
      expect(exchangeBillIdOf({'code': 0, 'data': {}}), isNull);
      expect(exchangeBillIdOf({'code': 0}), isNull);
      expect(exchangeBillIdOf(null), isNull);
    });

    test('账单完成校验：id 必须匹配且 status == 3', () {
      expect(
        exchangeCompletedOf({'data': {'bill': {'id': 'B1', 'status': 3}}}, 'B1'),
        isTrue,
      );
      expect(
        exchangeCompletedOf({'data': {'bill': {'id': 'B1', 'status': 1}}}, 'B1'),
        isFalse,
      );
      // id 不匹配 → 待确认（null），避免误判为成功
      expect(
        exchangeCompletedOf({'data': {'bill': {'id': 'B2', 'status': 3}}}, 'B1'),
        isNull,
      );
      expect(exchangeCompletedOf({'data': {}}, 'B1'), isNull);
    });
  });
}
