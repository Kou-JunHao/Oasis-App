import 'package:flutter_test/flutter_test.dart';
import 'package:oasis_flutter/services/login_signer.dart';

void main() {
  group('LoginSigner', () {
    test('时间桶按 30 秒取整，单位是秒', () {
      expect(LoginSigner.windowValue(1793849886000), 1793849880);
      expect(LoginSigner.windowValue(1793849880000), 1793849880);
      expect(LoginSigner.windowValue(1793849879999), 1793849850);
    });

    test('路径 token 取去符号后的末 8 位', () {
      expect(LoginSigner.pathToken(), 'acclogin');
      expect(LoginSigner.pathToken('/api/v1/acc/login/code'), 'ogincode');
    });

    test('固定向量：key 由前缀 + 8位桶 + 手机号中间8位 + 路径token 组成', () {
      // 该向量由独立实现（Python + blake3 库）算出，用于锁死算法细节；
      // 算法本身已用官方 App 3.1.10 的真实抓包逐字节验证过。
      final sign = LoginSigner.sign(
        phone: '13800138000',
        smsCode: '123456',
        nowMs: 1793849886000,
      );
      expect(sign, '1e8502705cab835610587ecddbf5600e');
    });

    test('相邻时间桶的签名不同', () {
      final current = LoginSigner.sign(
        phone: '13800138000',
        smsCode: '123456',
        nowMs: 1793849886000,
      );
      final previous = LoginSigner.sign(
        phone: '13800138000',
        smsCode: '123456',
        nowMs: 1793849886000 - 30000,
      );
      expect(current, isNot(previous));
    });

    test('签名固定 32 位小写 hex', () {
      final sign = LoginSigner.sign(
        phone: '13900000000',
        smsCode: '654321',
        nowMs: 1793849886000,
      );
      expect(sign, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });
}
