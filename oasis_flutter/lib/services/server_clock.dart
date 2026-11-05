import 'dart:io';

/// 服务器时钟校正。
///
/// 3.1.10 协议下多个接口的 `sign` 参数都带「30 秒时间桶」，桶值必须与服务端
/// 一致，否则签名校验失败。设备时钟偏差超过 30 秒时本地时间会算错桶，因此
/// 这里用响应头里的 `Date` 推算偏差，供签名逻辑取「服务器当前时间」。
///
/// 偏差是全局共享的：任意一次响应都能刷新它，登录前抓图形验证码/发短信码
/// 的响应就足以把时钟校准到秒级。
class ServerClock {
  ServerClock._();

  /// 服务器时间 - 本地时间（毫秒）。未校准时为 0。
  static int _offsetMs = 0;

  /// 当前偏差（毫秒），便于调试与测试。
  static int get offsetMs => _offsetMs;

  /// 是否已经用响应头校准过。
  static bool get isSynced => _offsetMs != 0;

  /// 服务器当前时间（毫秒）。
  static int get nowMs => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  /// 用响应头里的 `Date` 校准；解析失败时沿用上次偏差。
  static void syncFromDateHeader(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return;
    try {
      final serverMs = HttpDate.parse(rawDate).millisecondsSinceEpoch;
      _offsetMs = serverMs - DateTime.now().millisecondsSinceEpoch;
    } catch (_) {
      // 解析失败就沿用上次的偏差
    }
  }

  /// 仅供测试：重置偏差。
  static void resetForTest() {
    _offsetMs = 0;
  }
}
