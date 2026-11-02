package uno.skkk.oasis.widget

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast
import uno.skkk.oasis.MainActivity
import uno.skkk.oasis.R

/**
 * 快捷设置磁贴：下拉通知栏点一下就启动默认设备。
 *
 * 与 life798 的 WaterTileService 行为一致：
 *   - 未登录/未选设备：提示先去 App 设置；
 *   - 正在监测：提示已在运行；
 *   - 启动成功：磁贴短暂变成「启动中…」，1.2 秒后恢复。
 */
class OasisTileService : TileService() {

    companion object {
        private const val LABEL = "启动设备"
        private const val RESET_DELAY_MILLIS = 1_200L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onStartListening() {
        super.onStartListening()
        updateTile(Tile.STATE_INACTIVE, LABEL)
    }

    override fun onTileAdded() {
        super.onTileAdded()
        updateTile(Tile.STATE_INACTIVE, LABEL)
    }

    override fun onClick() {
        super.onClick()

        if (!WidgetPrefs.isReady(this)) {
            Toast.makeText(this, "请先在 App 中登录并选择设备", Toast.LENGTH_SHORT).show()
            openApp()
            return
        }

        when (WaterMonitorService.startDefaultDevice(this)) {
            WaterMonitorService.RESULT_STARTED -> {
                updateTile(Tile.STATE_ACTIVE, "启动中…")
                mainHandler.postDelayed(
                    { updateTile(Tile.STATE_INACTIVE, LABEL) },
                    RESET_DELAY_MILLIS,
                )
            }
            WaterMonitorService.RESULT_ALREADY_RUNNING ->
                Toast.makeText(this, "已有接水会话正在监测", Toast.LENGTH_SHORT).show()
            WaterMonitorService.RESULT_NOT_READY -> {
                Toast.makeText(this, "请先在 App 中登录并选择设备", Toast.LENGTH_SHORT).show()
                openApp()
            }
            else ->
                Toast.makeText(this, "启动失败，请稍后重试", Toast.LENGTH_SHORT).show()
        }
    }

    /** 更新磁贴状态与文案。 */
    private fun updateTile(state: Int, label: String) {
        val tile = qsTile ?: return
        tile.state = state
        tile.label = label
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.icon = Icon.createWithResource(this, R.drawable.ic_water_drop)
        }
        tile.updateTile()
    }

    /** 折叠通知栏并打开 App。 */
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending = PendingIntent.getActivity(
                this,
                300,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
