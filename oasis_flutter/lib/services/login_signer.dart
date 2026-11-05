import 'dart:convert';

import 'blake3_keyed.dart';

/// 短信登录签名（服务端协议 3.1.10）
///
/// 服务端对 `POST /api/v1/acc/login` 校验 URL 上的 `?sign=` 查询参数。
/// 算法与积分提交同源（OctUtil keyed BLAKE3），区别只在 key 的第三段：
/// 积分用「token 中间 8 位」，登录用「手机号中间 8 位」；payload 也不同。
///
///   bucket  = (服务器时间ms / 30000) * 30          // 注意结果是「秒」，不是毫秒
///   payload = "authCode=" + 短信码 + "&un=" + 手机号
///   key     = "Ys3yx=j7" + 8位bucket + 手机号中间8位 + 路径token
///   sign    = hex(keyedBlake3(key, payload))[0..32]
///
/// 其中：
/// - 路径 token：`/api/v1/acc/login` 去掉非字母数字后取末 8 位 = `acclogin`
/// - 手机号中间 8 位：从 `(phone.length - 8) / 2` 起取 8 个字符
///   （`13800138000` → `38001380`）
/// - 时间必须用服务器时间（调用方用响应 Date 头校正），30 秒为一个时间窗
///
/// 注意：登录请求**不带** `authorization` 头，body 只有 `{authCode, un}`。
/// 3.1.9 及更早的 `md5("authCode=..&un=.." + salt)` 算法已失效。
class LoginSigner {
  LoginSigner._();

  /// 时间窗口：30 秒
  static const int windowMs = 30000;

  /// OctUtil 的 key 前缀（3.1.10 协议固定值）
  static const String _octKeyPrefix = 'Ys3yx=j7';

  /// 登录路径常量（参与 key 计算）
  static const String _loginPath = '/api/v1/acc/login';

  /// 时间戳取值：(t / 30000) * 30，单位秒
  static int windowValue(int nowMs) => (nowMs ~/ windowMs) * 30;

  /// 路径 token：路径去非字母数字 → 左补 `0` 到 8 位 → 取末 8 位
  static String pathToken([String path = _loginPath]) {
    final digits = path.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final padded = digits.padLeft(8, '0');
    return padded.substring(padded.length - 8);
  }

  static String _pad8TakeLast8(String value) {
    final padded = value.padLeft(8, '0');
    return padded.substring(padded.length - 8);
  }

  static String _middle8(String value) {
    final start = ((value.length - 8) ~/ 2).clamp(0, value.length);
    final end = (start + 8).clamp(0, value.length);
    return value.substring(start, end);
  }

  /// 计算 `sign` 参数值（32 位小写 hex）
  static String sign({
    required String phone,
    required String smsCode,
    required int nowMs,
  }) {
    final bucket = windowValue(nowMs);
    final payload = 'authCode=$smsCode&un=$phone';
    final key = '$_octKeyPrefix${_pad8TakeLast8('$bucket')}'
        '${_middle8(phone)}${pathToken()}';
    final digest = Blake3Keyed.keyedHashHex(
      utf8.encode(key),
      utf8.encode(payload),
    );
    return digest.substring(0, 32);
  }
}
