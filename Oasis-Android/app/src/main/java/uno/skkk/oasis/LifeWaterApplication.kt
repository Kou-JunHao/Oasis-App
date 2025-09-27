package uno.skkk.oasis

import android.app.Application
import android.content.Context
import android.os.Build
import com.google.android.material.color.DynamicColors
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class LifeWaterApplication : Application() {
    
    companion object {
        private const val PREFS_NAME = "app_settings"
        private const val KEY_MONET_ENABLED = "monet_enabled"
        
        /**
         * 检查是否启用了莫奈取色
         */
        fun isMonetEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_MONET_ENABLED, true) && 
                   Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // 应用动态颜色（如果启用且支持）
        if (isMonetEnabled(this)) {
            DynamicColors.applyToActivitiesIfAvailable(this)
        }
    }
}
