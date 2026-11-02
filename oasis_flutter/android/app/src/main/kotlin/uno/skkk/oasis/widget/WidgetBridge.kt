package uno.skkk.oasis.widget

import android.content.Context
import android.content.SharedPreferences
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart ↔ 原生 的桥。
 *
 * 只用来「写」：把 App 里选中的默认设备、估算设置同步到 SharedPreferences，
 * 再让原生刷新小部件与磁贴。读取方向不需要桥 —— 原生直接读 SP 就够了。
 */
class WidgetBridge(private val context: Context, private val channel: MethodChannel) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "uno.skkk.oasis/widget"
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncDevice" -> {
                val deviceId = call.argument<String>("deviceId").orEmpty()
                val deviceName = call.argument<String>("deviceName").orEmpty()
                prefs.edit()
                    .putString("flutter.widget_device_id", deviceId)
                    .putString("flutter.widget_device_name", deviceName)
                    .apply()
                OasisWidgetProvider.refreshAll(context)
                result.success(true)
            }
            "clearDevice" -> {
                prefs.edit()
                    .remove("flutter.widget_device_id")
                    .remove("flutter.widget_device_name")
                    .apply()
                OasisWidgetProvider.refreshAll(context)
                result.success(true)
            }
            "refreshWidgets" -> {
                OasisWidgetProvider.refreshAll(context)
                result.success(true)
            }
            "startDefaultDevice" -> {
                val code = WaterMonitorService.startDefaultDevice(context)
                result.success(code)
            }
            "isMonitoring" -> result.success(WaterMonitorService.isMonitoring())
            "stopMonitoring" -> {
                WaterMonitorService.requestStop(context)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
