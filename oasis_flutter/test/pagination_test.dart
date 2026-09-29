import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/models/api_models.dart';

void main() {
  group('分页总数解析', () {
    test('订单列表：hasCount 返回的 size 字段即总数', () {
      final response = OrderListResponse.fromJson({
        'code': 0,
        'size': 6,
        'data': [
          {
            'id': '1001',
            'cata': '1',
            'status': 2,
            'payment': 10.0,
            'msg': '钱包充值',
            'ctime': 1790677339838,
          },
        ],
      });
      expect(response.totalElements, 6);
      expect(response.orders.length, 1);
      expect(response.orders.first.id, '1001');
    });

    test('缺少总数时退化为当页条数（避免误判还有下一页）', () {
      final response = OrderListResponse.fromJson({'code': 0, 'data': []});
      expect(response.totalElements, 0);
      expect(response.orders, isEmpty);
    });

    test('totalElements 为字符串时也能解析', () {
      final response = OrderListResponse.fromJson({
        'code': 0,
        'totalElements': '12',
        'data': [],
      });
      expect(response.totalElements, 12);
    });
  });
}
