import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 桌面小部件 / 快捷设置磁贴的桥。
///
/// 原生侧的小部件和磁贴不依赖 Flutter 引擎，它们直接从
/// `FlutterSharedPreferences` 里读 token 与默认设备，所以这里的职责只有两个：
///   1. 把 App 内选中的默认设备写进同一个 SharedPreferences；
///   2. 写完通知原生刷新小部件。
///
/// 原生读取用的键名必须与 `WidgetPrefs.kt` 保持一致。
class WidgetService {
  static const MethodChannel _channel = MethodChannel('uno.skkk.oasis/widget');

  static const String keyDeviceId = 'widget_device_id';
  static const String keyDeviceName = 'widget_device_name';

  /// 启动结果码，与原生 WaterMonitorService 的常量对应。
  static const int resultStarted = 0;
  static const int resultAlreadyRunning = 1;
  static const int resultNotReady = 2;
  static const int resultFailed = 3;

  /// 当前小部件绑定的设备 id，未设置返回空串。
  static Future<String> readDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(keyDeviceId) ?? '').trim();
  }

  /// 当前小部件绑定的设备名称，未设置返回空串。
  static Future<String> readDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(keyDeviceName) ?? '').trim();
  }

  /// 把设备设为小部件/磁贴的默认设备。
  static Future<void> setDefaultDevice({
    required String deviceId,
    required String deviceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDeviceId, deviceId);
    await prefs.setString(keyDeviceName, deviceName);
    await _invoke('syncDevice', {
      'deviceId': deviceId,
      'deviceName': deviceName,
    });
  }

  /// 清除默认设备（小部件回到「未配置」状态）。
  static Future<void> clearDefaultDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyDeviceId);
    await prefs.remove(keyDeviceName);
    await _invoke('clearDevice');
  }

  /// 通知原生刷新小部件（例如换了主题或改了估算设置）。
  static Future<void> refreshWidgets() async {
    await _invoke('refreshWidgets');
  }

  /// 直接从 App 触发一次默认设备的接水监测。
  static Future<int> startDefaultDevice() async {
    final code = await _invoke('startDefaultDevice');
    return code is int ? code : resultFailed;
  }

  /// 当前是否有监测会话在跑。
  static Future<bool> isMonitoring() async {
    final running = await _invoke('isMonitoring');
    return running == true;
  }

  /// 停止监测。
  static Future<void> stopMonitoring() async {
    await _invoke('stopMonitoring');
  }

  /// 统一的桥调用；平台通道不可用时静默降级（例如桌面端调试）。
  static Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
