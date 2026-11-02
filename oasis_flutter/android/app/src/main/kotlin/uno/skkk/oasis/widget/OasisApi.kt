package uno.skkk.oasis.widget

import android.content.Context
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import org.json.JSONObject

/**
 * 原生侧的最小 HTTP 客户端。
 *
 * 小部件、快捷开关和接水监测服务都可能在 Flutter 引擎没有运行时被触发，
 * 所以原生层必须能自己发请求，不能依赖 MethodChannel 回到 Dart。
 *
 * 这些接口（dev/start、dev/end、bill 列表、acc/score/score-lst、ui/app/dev/status）
 * 都不校验 sign，只需要 Authorization + ApplicationType + versioncode 头，
 * 与 Dart 侧 ApiService 的默认头保持一致。
 */
object OasisApi {
    private const val BASE_URL = "https://i.ilife798.com/api/v1/"
    private const val CONNECT_TIMEOUT_MILLIS = 10_000
    private const val READ_TIMEOUT_MILLIS = 20_000

    /** 统一结果：成功时带 data 对象，失败时带可读原因。 */
    class Result(val ok: Boolean, val code: Int, val message: String, val body: JSONObject?) {
        val data: JSONObject? get() = body?.optJSONObject("data")
        val dataArray: org.json.JSONArray? get() = body?.optJSONArray("data")

        companion object {
            fun fail(code: Int, message: String) = Result(false, code, message, null)
            fun httpError(code: Int) = Result(false, code, "网络请求失败（$code）", null)
        }
    }

    /**
     * 发起一次 GET 请求。
     *
     * 服务端约定：HTTP 200 + body.code == 0 才算成功；
     * code == -99 表示登录态失效，调用方应提示用户重新登录。
     */
    fun get(context: Context, path: String): Result {
        val token = WidgetPrefs.token(context)
        if (token.isEmpty()) return Result.fail(-99, "登录状态已过期")

        val url = URL(BASE_URL + path.trimStart('/'))
        var connection: HttpURLConnection? = null
        return try {
            connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT_MILLIS
                readTimeout = READ_TIMEOUT_MILLIS
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("ApplicationType", "1,1")
                setRequestProperty("versioncode", WidgetPrefs.clientVersion(context))
                setRequestProperty("User-Agent", "Android_ilife798_${WidgetPrefs.clientVersion(context)}")
                setRequestProperty("Accept", "*/*")
                setRequestProperty("Authorization", token)
            }

            val status = connection.responseCode
            if (status !in 200..299) return Result.httpError(status)

            val text = connection.inputStream.bufferedReader().use(BufferedReader::readText)
            val json = runCatching { JSONObject(text) }.getOrNull()
                ?: return Result.fail(-1, "响应解析失败")

            val code = json.optInt("code", -1)
            val message = json.optString("msg", "")
            Result(code == 0, code, message, json)
        } catch (e: Exception) {
            Result.fail(-1, e.message ?: "网络异常")
        } finally {
            connection?.disconnect()
        }
    }

    // ==================== 设备 ====================

    /**
     * 启动设备出水。
     *
     * 注意：URL 里**不能**带 sign 参数，否则服务端会返回 -1 验签失败；
     * 这几个接口本来就不校验签名。
     */
    fun startDevice(context: Context, deviceId: String): Result =
        get(context, "dev/start?did=$deviceId&upgrade=true&ptype=91&rcp=false")

    /** 停止出水。 */
    fun stopDevice(context: Context, deviceId: String): Result =
        get(context, "dev/end?did=$deviceId&rcp=false")

    /** 设备运行状态，含累计出水量 gene.out（升）。 */
    fun deviceStatus(context: Context, deviceId: String): Result =
        get(context, "ui/app/dev/status?did=$deviceId")

    // ==================== 账单 / 积分 ====================

    /** 账单列表（接水记录 type=91）。 */
    fun billList(context: Context, page: Int = 0, size: Int = 20): Result =
        get(context, "bill/lst-owner?page=$page&size=$size&hasCount=1")

    /** 账单详情。 */
    fun billDetail(context: Context, id: String): Result =
        get(context, "bill/view-full?id=$id")

    /** 积分流水（消费记录在这里，type=105/107）。 */
    fun scoreList(context: Context, page: Int = 0, size: Int = 50): Result =
        get(context, "acc/score/score-lst?page=$page&size=$size&hasCount=1")
}
