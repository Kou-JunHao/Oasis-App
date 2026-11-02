package uno.skkk.oasis.widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.util.concurrent.atomic.AtomicLong
import org.json.JSONObject
import uno.skkk.oasis.MainActivity
import uno.skkk.oasis.R

/**
 * 接水监测服务。
 *
 * 小部件/快捷开关点「启动设备」后，这里负责：
 *   1. 先记下当前积分流水的 baseline，避免把历史消费算成这一次的；
 *   2. 调用 dev/start 启动出水；
 *   3. 前台通知里持续显示已出水量（设备 gene.out 的增量，是真实水量）；
 *   4. 轮询积分流水，出现新的消费记录就结算并弹出结果通知。
 *
 * 全程不依赖 Flutter 引擎 —— 原生自己发 HTTP，所以从桌面直接点也能用。
 */
class WaterMonitorService : Service() {

    companion object {
        private const val TAG = "OasisWater"

        private const val ACTION_START = "uno.skkk.oasis.widget.ACTION_MONITOR_START"

        private const val EXTRA_DEVICE_ID = "extra_device_id"

        private const val CHANNEL_ID = "oasis_water_monitor"
        private const val ONGOING_NOTIFICATION_ID = 4201
        private const val RESULT_NOTIFICATION_ID = 4202

        /** 启动后先等 8 秒再开始轮询，给设备留出出水时间 */
        private const val FIRST_POLL_DELAY_MILLIS = 8_000L

        /** 设备状态轮询间隔（看实时水量） */
        private const val STATUS_POLL_INTERVAL_MILLIS = 10_000L

        /** 积分流水轮询间隔（看是否产生了消费记录），比状态慢一些，减少服务端压力 */
        private const val SCORE_POLL_INTERVAL_MILLIS = 30_000L

        /** 单次监测最长时长，超过就按已拿到的数据结算 */
        private const val MAX_MONITOR_MILLIS = 10 * 60_000L

        /** 抓 baseline 时最多等多久 */
        private const val BASELINE_TIMEOUT_MILLIS = 5_000L

        /** 启动结果 */
        const val RESULT_STARTED = 0
        const val RESULT_ALREADY_RUNNING = 1
        const val RESULT_NOT_READY = 2
        const val RESULT_FAILED = 3

        /** 同一时间只允许一个监测会话，用小部件/磁贴并发点击时做互斥。 */
        private val activeSession = AtomicLong(0)
        private val startingSession = AtomicLong(0)

        /**
         * 启动一次接水监测。
         *
         * 返回的只是「是否成功把服务拉起来」，真正的出水结果异步出。
         */
        fun start(context: Context, deviceId: String): Int {
            if (!WidgetPrefs.isReady(context)) return RESULT_NOT_READY
            if (activeSession.get() != 0L || !startingSession.compareAndSet(0, 1)) {
                return RESULT_ALREADY_RUNNING
            }
            return try {
                val intent = Intent(context, WaterMonitorService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_DEVICE_ID, deviceId)
                }
                ContextCompat.startForegroundService(context, intent)
                RESULT_STARTED
            } catch (e: Exception) {
                startingSession.set(0)
                RESULT_FAILED
            }
        }

        /** 小部件直接启动（用偏好里保存的默认设备）。 */
        fun startDefaultDevice(context: Context): Int =
            start(context, WidgetPrefs.deviceId(context))

        /** 当前是否正在监测，供界面显示状态用。 */
        fun isMonitoring(): Boolean = activeSession.get() != 0L

        /** 停止监测（不结束出水，只是不再记录）。 */
        fun requestStop(context: Context) {
            context.startService(
                Intent(context, WaterMonitorService::class.java).apply {
                    action = "uno.skkk.oasis.widget.ACTION_MONITOR_STOP"
                }
            )
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.water_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.getString(R.string.water_channel_description)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var cancelled = false

    @Volatile
    private var worker: Thread? = null

    private var sessionToken = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 服务由 startForegroundService() 拉起，系统要求 5 秒内必须 startForeground()，
        // 否则抛 ForegroundServiceDidNotStartInTimeException 直接把进程杀掉。
        // 所以先无条件转前台，再做其它判断。
        sessionToken = System.currentTimeMillis()
        activeSession.set(sessionToken)
        startingSession.set(0)
        startForegroundCompat(
            buildNotification(
                title = getString(R.string.water_notification_title),
                text = getString(R.string.water_notification_starting),
                ongoing = true,
            ),
        )

        val action = intent?.action
        if (action == "uno.skkk.oasis.widget.ACTION_MONITOR_STOP") {
            cancelled = true
            finishSilently()
            return START_NOT_STICKY
        }

        val deviceId = intent?.getStringExtra(EXTRA_DEVICE_ID)?.trim().orEmpty()
        if (deviceId.isEmpty()) {
            startingSession.set(0)
            finishSilently()
            return START_NOT_STICKY
        }

        worker?.interrupt()
        worker = Thread({ runMonitor(deviceId) }, "oasis-water-monitor").apply {
            isDaemon = true
            start()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        cancelled = true
        activeSession.compareAndSet(sessionToken, 0)
        startingSession.set(0)
        super.onDestroy()
    }

    // ==================== 监测主流程 ====================

    private fun runMonitor(deviceId: String) {
        Log.i(TAG, "monitor start did=$deviceId")
        try {
            val startedAt = System.currentTimeMillis()
            val baselineKeys = captureBaselineKeys()
            val baselineOut = readTotalOut(deviceId)

            val startResult = OasisApi.startDevice(this, deviceId)
            Log.i(TAG, "dev/start code=${startResult.code} msg=${startResult.message}")
            if (!startResult.ok) {
                // -2 / 设备正在使用中之类的状态不算失败，继续监测；
                // 其余（登录失效、余额不足等）直接结束并提示。
                val friendly = startResult.message
                if (!isBenignStartFailure(startResult.code, friendly)) {
                    finishWithMessage(
                        title = getString(R.string.water_notification_done),
                        text = friendly.ifEmpty { "启动失败，请稍后重试" },
                    )
                    return
                }
            }

            updateNotification(
                getString(R.string.water_notification_title),
                getString(R.string.water_notification_monitoring),
            )

            var elapsed = 0L
            var sinceScorePoll = 0L
            var lastOut = baselineOut

            while (!cancelled && elapsed < MAX_MONITOR_MILLIS) {
                sleep(STATUS_POLL_INTERVAL_MILLIS)
                if (cancelled) break
                elapsed += STATUS_POLL_INTERVAL_MILLIS
                sinceScorePoll += STATUS_POLL_INTERVAL_MILLIS

                // 实时水量：设备状态里的 gene.out 是累计升数，取增量最准
                val currentOut = readTotalOut(deviceId)
                if (currentOut > lastOut) {
                    val delta = currentOut - lastOut
                    lastOut = currentOut
                    updateNotification(
                        getString(R.string.water_notification_title),
                        "已出水 ${formatLitres(delta)}，结束后自动结算",
                    )
                }

                if (sinceScorePoll >= SCORE_POLL_INTERVAL_MILLIS) {
                    sinceScorePoll = 0L
                    val consumption = detectConsumption(baselineKeys, startedAt, deviceId)
                    if (consumption != null) {
                        finishWithConsumption(consumption, lastOut - baselineOut)
                        return
                    }
                }
            }

            // 到点或被打断：用已拿到的数据结算
            val consumption = detectConsumption(baselineKeys, startedAt, deviceId)
            if (consumption != null) {
                finishWithConsumption(consumption, lastOut - baselineOut)
            } else {
                finishSilently()
            }
        } catch (e: Exception) {
            finishWithMessage(
                title = getString(R.string.water_notification_done),
                text = "监测中断：${e.message ?: "未知错误"}",
            )
        }
    }

    /** 记录开始前的积分流水，结算时用来排除历史记录。 */
    private fun captureBaselineKeys(): Set<String> {
        val keys = mutableSetOf<String>()
        val deadline = System.currentTimeMillis() + BASELINE_TIMEOUT_MILLIS
        while (System.currentTimeMillis() < deadline) {
            val result = OasisApi.scoreList(this, page = 0, size = 50)
            if (result.ok) {
                val array = result.dataArray
                if (array != null) {
                    for (i in 0 until array.length()) {
                        val record = array.optJSONObject(i) ?: continue
                        val key = WaterConsumptionParser.recordKey(record)
                        if (key.isNotEmpty()) keys.add(key)
                    }
                    return keys
                }
            }
            sleep(1_000L)
        }
        return keys
    }

    /** 设备累计出水量（升），读不到返回 0。 */
    private fun readTotalOut(deviceId: String): Double {
        val result = OasisApi.deviceStatus(this, deviceId)
        if (result.ok) {
            val device = result.data?.optJSONObject("device") ?: return 0.0
            val gene = device.optJSONObject("gene") ?: return 0.0
            return gene.optDouble("out", 0.0).takeIf { it.isFinite() && it > 0 } ?: 0.0
        }
        return 0.0
    }

    /** 找本次接水产生的消费记录。 */
    private fun detectConsumption(
        baselineKeys: Set<String>,
        startedAt: Long,
        deviceId: String,
    ): WaterConsumption? {
        val result = OasisApi.scoreList(this, page = 0, size = 50)
        if (!result.ok) return null
        val array = result.dataArray ?: return null
        val records = mutableListOf<JSONObject>()
        for (i in 0 until array.length()) {
            array.optJSONObject(i)?.let { records.add(it) }
        }
        val record = WaterConsumptionParser.newestConsumption(records, baselineKeys, startedAt)
            ?: return null
        return WaterConsumptionParser.toConsumption(record, deviceId)
    }

    /** 启动接口返回这些码时不算真正失败（设备本来就在用）。 */
    private fun isBenignStartFailure(code: Int, message: String): Boolean {
        if (code == -2) return true
        return message.contains("正在使用") || message.contains("使用中") || message.contains("-2")
    }

    // ==================== 通知 / 收尾 ====================

    private fun finishWithConsumption(consumption: WaterConsumption, realLiters: Double) {
        val ratio = WidgetPrefs.millilitresPerYuan(this)
        val visible = WidgetPrefs.estimateVisible(this)
        val prefix = if (realLiters >= 0.1) "已出水 ${formatLitres(realLiters)} · " else ""
        val text = prefix + consumption.completionText(ratio, visible)
        finishWithMessage(getString(R.string.water_notification_done), text)
    }

    private fun finishWithMessage(title: String, text: String) {
        if (cancelled) {
            finishSilently()
            return
        }
        notifyResult(title, text)
        finishSilently()
    }

    private fun finishSilently() {
        activeSession.compareAndSet(sessionToken, 0)
        startingSession.set(0)
        stopForegroundCompat()
        stopSelf()
    }

    private fun notifyResult(title: String, text: String) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.notify(RESULT_NOTIFICATION_ID, buildNotification(title, text, ongoing = false))
    }

    private fun updateNotification(title: String, text: String) {
        if (cancelled) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.notify(ONGOING_NOTIFICATION_ID, buildNotification(title, text, ongoing = true))
    }

    private fun buildNotification(title: String, text: String, ongoing: Boolean): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_water_drop)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(contentIntent)
            .setAutoCancel(!ongoing)
            .setOngoing(ongoing)
            .setOnlyAlertOnce(ongoing)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (ongoing) builder.setSilent(true)
        return builder.build()
    }

    private fun startForegroundCompat(notification: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    ONGOING_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(ONGOING_NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // 转前台失败（缺权限、通知被禁用等）时不能让进程崩掉，
            // 退化成后台服务继续跑完这一轮监测。
            Log.w(TAG, "startForeground failed: ${e.message}")
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun sleep(millis: Long) {
        try {
            Thread.sleep(millis)
        } catch (_: InterruptedException) {
            cancelled = true
        }
    }

    private fun formatLitres(litres: Double): String =
        if (litres >= 1) String.format(java.util.Locale.CHINA, "%.2f L", litres)
        else String.format(java.util.Locale.CHINA, "%.0f ml", litres * 1000)
}