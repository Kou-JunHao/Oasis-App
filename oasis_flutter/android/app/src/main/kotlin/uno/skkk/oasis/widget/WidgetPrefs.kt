package uno.skkk.oasis.widget

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * 原生层读取 Dart 侧状态。
 *
 * Flutter 的 shared_preferences 插件在 Android 上就是一个名为
 * `FlutterSharedPreferences` 的 SharedPreferences 文件，键名统一带 `flutter.` 前缀，
 * 所以原生可以直接读，不需要 MethodChannel 往返。
 *
 * 约定与 Dart 侧 `lib/services/widget_service.dart` 保持一致：
 *   flutter.user_token          登录 token
 *   flutter.user_data           JSON（取 id 作为 uid）
 *   flutter.widget_device_id    小部件/磁贴使用的默认设备 did
 *   flutter.widget_device_name  默认设备名称（仅用于界面显示）
 *   flutter.water_estimate_*    预估水量设置
 */
object WidgetPrefs {
    private const val PREFS_NAME = "FlutterSharedPreferences"

    private const val KEY_TOKEN = "flutter.user_token"
    private const val KEY_USER_DATA = "flutter.user_data"
    private const val KEY_DEVICE_ID = "flutter.widget_device_id"
    private const val KEY_DEVICE_NAME = "flutter.widget_device_name"
    private const val KEY_CLIENT_VERSION = "flutter.spoof_client_version"
    private const val DEFAULT_CLIENT_VERSION = "3.1.10"
    private const val KEY_ESTIMATE_VISIBLE = "flutter.water_estimate_visible"
    private const val KEY_ESTIMATE_AMOUNT = "flutter.water_estimate_amount_yuan"
    private const val KEY_ESTIMATE_VOLUME = "flutter.water_estimate_volume_ml"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** 登录 token，空串表示未登录。 */
    fun token(context: Context): String =
        prefs(context).getString(KEY_TOKEN, null)?.trim().orEmpty()

    /** 用户 uid，取不到返回空串。 */
    fun uid(context: Context): String {
        val raw = prefs(context).getString(KEY_USER_DATA, null) ?: return ""
        return try {
            JSONObject(raw).optString("id", "")
        } catch (_: Exception) {
            ""
        }
    }

    /** 小部件/磁贴使用的默认设备 id。 */
    fun deviceId(context: Context): String =
        prefs(context).getString(KEY_DEVICE_ID, null)?.trim().orEmpty()

    /** 默认设备名称（仅界面显示用，可能为空，此时显示 did 后 6 位）。 */
    fun deviceName(context: Context): String {
        val name = prefs(context).getString(KEY_DEVICE_NAME, null)?.trim().orEmpty()
        if (name.isNotEmpty()) return name
        val id = deviceId(context)
        return if (id.length > 6) "设备 ${id.takeLast(6)}" else "已选设备"
    }

    /** 是否已登录且已选择设备，可以执行启动。 */
    fun isReady(context: Context): Boolean =
        token(context).isNotEmpty() && deviceId(context).isNotEmpty()

    /** 伪装客户端版本号，与 Dart 侧 ClientVersionService 的缓存保持同一来源。 */
    fun clientVersion(context: Context): String {
        val cached = prefs(context).getString(KEY_CLIENT_VERSION, null)?.trim().orEmpty()
        return if (cached.isEmpty()) DEFAULT_CLIENT_VERSION else cached
    }

    /** 预估水量是否开启显示。 */
    fun estimateVisible(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ESTIMATE_VISIBLE, true)

    /**
     * shared_preferences 插件把 Dart 的 double 存成**带前缀的字符串**而不是 `<float>`，
     * 见 shared_preferences_android 的 LegacySharedPreferencesPlugin：
     *   putString(key, DOUBLE_PREFIX + value.toString())
     * 所以这里必须按字符串解析，`getFloat` 永远读不到。
     */
    private const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    private fun readDouble(p: SharedPreferences, key: String, fallback: Double): Double {
        val raw = p.getString(key, null) ?: return fallback
        val text = if (raw.startsWith(DOUBLE_PREFIX)) raw.substring(DOUBLE_PREFIX.length) else raw
        return text.toDoubleOrNull()?.takeIf { it.isFinite() && it > 0 } ?: fallback
    }

    /** 「每元多少毫升」的换算比例，非法时回退到 500/0.16。 */
    fun millilitresPerYuan(context: Context): Double {
        val p = prefs(context)
        val amount = readDouble(p, KEY_ESTIMATE_AMOUNT, 0.16)
        val volume = readDouble(p, KEY_ESTIMATE_VOLUME, 500.0)
        return volume / amount
    }

    /** 通知原生侧刷新所有小部件。 */
    fun notifyWidgets(context: Context) {
        OasisWidgetProvider.refreshAll(context)
    }
}
