import 'dart:convert';

import 'blake3_keyed.dart';

/// 积分奖励提交签名（服务端协议 3.1.10）
///
/// 服务端只对 `POST /acc/score/score-send` 校验签名。3.1.10 起算法已从
/// 「MD5(adId + 时间桶 + token后8位 + uid后8位 + 固定盐)」改为 **keyed BLAKE3**：
///
///   bucket  = (服务器时间ms / 30000) * 30          // 注意结果是「秒」，不是毫秒
///   payload = 规范化adId + bucket + token后8位 + uid后8位
///   key     = "Ys3yx=j7" + 8位bucket + token中间8位 + 路径token
///   sign    = hex(keyedBlake3(key, payload))[0..32]
///
/// 其中：
/// - 规范化 adId：按 `&` 拆分后按 `=` 前的 key **稳定**排序再拼回（同 key 保留原顺序）
/// - 路径 token：`/api/v1/acc/score/score-send` 去掉非字母数字后取末 8 位 = `coresend`
/// - token 中间 8 位：从 `(token.length - 8) / 2` 起取 8 个字符
/// - 时间必须用服务器时间（调用方用响应 Date 头校正），30 秒为一个时间窗
///
/// 旧协议的固定盐已移除：服务端在 2026-10 中旬停用该算法，
/// 继续携带旧盐只会得到 `{"code":-1,"msg":"验签失败"}`。
class ScoreSigner {
  ScoreSigner._();

  /// 服务端协议版本（决定签名算法，与客户端版本号无关）
  static const String protocolVersion = '3.1.10';

  /// 时间窗口：30 秒
  static const int windowMs = 30000;

  /// OctUtil 的 key 前缀（3.1.10 协议固定值）
  static const String _octKeyPrefix = 'Ys3yx=j7';

  /// score-send 路径常量（参与 key 计算）
  static const String _scoreSendPath = '/api/v1/acc/score/score-send';

  /// 时间戳取值：(t / 30000) * 30，单位秒
  static int windowValue(int nowMs) => (nowMs ~/ windowMs) * 30;

  static String tail8(String value) =>
      value.length <= 8 ? value : value.substring(value.length - 8);

  /// 规范化 adId：按 `=` 前的 key 稳定排序（对齐 Kotlin `sortedBy` 语义）
  static String normalizeAdId(String adId) {
    final parts = adId.split('&');
    final order = List<int>.generate(parts.length, (i) => i);
    order.sort((a, b) {
      final byKey =
          parts[a].split('=').first.compareTo(parts[b].split('=').first);
      return byKey != 0 ? byKey : a.compareTo(b);
    });
    return order.map((i) => parts[i]).join('&');
  }

  /// 路径 token：路径去非字母数字 → 左补 `0` 到 8 位 → 取末 8 位
  static String pathToken([String path = _scoreSendPath]) {
    final digits = path.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final padded = digits.padLeft(8, '0');
    return padded.substring(padded.length - 8);
  }

  static String _pad8TakeLast8(String value) {
    final padded = value.padLeft(8, '0');
    return padded.substring(padded.length - 8);
  }

  static String _middle8(String token) {
    final start = ((token.length - 8) ~/ 2).clamp(0, token.length);
    final end = (start + 8).clamp(0, token.length);
    return token.substring(start, end);
  }

  /// 计算 `sign` 参数值（32 位小写 hex）
  static String sign({
    required String adId,
    required String token,
    required String uid,
    required int nowMs,
  }) {
    final bucket = windowValue(nowMs);
    final payload =
        '${normalizeAdId(adId)}$bucket${tail8(token)}${tail8(uid)}';
    final key = '$_octKeyPrefix${_pad8TakeLast8('$bucket')}'
        '${_middle8(token)}${pathToken()}';
    final digest = Blake3Keyed.keyedHashHex(
      utf8.encode(key),
      utf8.encode(payload),
    );
    return digest.substring(0, 32);
  }
}
