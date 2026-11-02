package uno.skkk.oasis.widget

import android.util.Log

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import uno.skkk.oasis.MainActivity
import uno.skkk.oasis.R

/**
 * 接水控制桌面小部件。
 *
 * 交互只有两种：
 *   - 还没在 App 里选设备：整张卡片 + 按钮都打开 App 去设置；
 *   - 已经选好设备：按钮直接启动接水，点击后立刻回写状态文字。
 *
 * 状态文字由 [refreshAll] / [updateStatus] 从任意线程回写，所以用 RemoteViews 而不是绑定数据。
 */
class OasisWidgetProvider : AppWidgetProvider() {

    companion object {
        /** 小部件按钮广播 */
        const val ACTION_START = "uno.skkk.oasis.widget.ACTION_WIDGET_START"

        /**
         * 刷新所有已添加的小部件。
         *
         * Dart 侧改了默认设备或估算设置后通过 MethodChannel 调到这里，
         * 保证桌面卡片立刻反映最新状态。
         */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, OasisWidgetProvider::class.java),
            ) ?: return
            if (ids.isEmpty()) return
            val views = buildViews(context)
            manager.updateAppWidget(ids, views)
        }

        /** 只更新状态文字（不重建整个布局）。 */
        fun updateStatus(context: Context, status: String) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, OasisWidgetProvider::class.java),
            ) ?: return
            if (ids.isEmpty()) return
            val views = buildViews(context, status)
            manager.updateAppWidget(ids, views)
        }

        /** 构建小部件视图。 */
        fun buildViews(context: Context, status: String? = null): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_water)
            val ready = WidgetPrefs.isReady(context)

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPending = PendingIntent.getActivity(
                context,
                100,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            // HyperOS 会按 @android:id/background 裁圆角，点击也挂在这上面
            views.setOnClickPendingIntent(android.R.id.background, openAppPending)

            if (!ready) {
                views.setTextViewText(R.id.btn_start, context.getString(R.string.widget_action_configure))
                views.setTextViewText(
                    R.id.widget_status,
                    status ?: context.getString(R.string.widget_status_unconfigured),
                )
                views.setOnClickPendingIntent(R.id.btn_start, openAppPending)
                return views
            }

            val startIntent = Intent(context, OasisWidgetProvider::class.java).apply {
                action = ACTION_START
            }
            val startPending = PendingIntent.getBroadcast(
                context,
                200,
                startIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            views.setTextViewText(R.id.btn_start, context.getString(R.string.widget_action_start))
            views.setTextViewText(
                R.id.widget_status,
                status ?: "${WidgetPrefs.deviceName(context)} · " +
                    context.getString(R.string.widget_status_ready),
            )
            views.setOnClickPendingIntent(R.id.btn_start, startPending)
            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        if (appWidgetIds.isEmpty()) return
        appWidgetManager.updateAppWidget(appWidgetIds, buildViews(context))
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i("OasisWater", "widget onReceive action=${intent.action}")
        if (intent.action != ACTION_START) {
            super.onReceive(context, intent)
            return
        }

        val deviceId = WidgetPrefs.deviceId(context)
        if (deviceId.isEmpty()) {
            updateStatus(context, context.getString(R.string.widget_status_unconfigured))
            return
        }

        when (WaterMonitorService.start(context, deviceId)) {
            WaterMonitorService.RESULT_STARTED ->
                updateStatus(context, "设备启动中…")
            WaterMonitorService.RESULT_ALREADY_RUNNING ->
                updateStatus(context, "已有接水会话正在监测")
            WaterMonitorService.RESULT_NOT_READY ->
                updateStatus(context, context.getString(R.string.widget_status_unconfigured))
            else ->
                updateStatus(context, "启动失败，请稍后重试")
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        refreshAll(context)
    }
}