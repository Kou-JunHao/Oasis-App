package uno.skkk.oasis

import android.app.Application
import android.content.Context
import android.os.Build
import androidx.appcompat.app.AppCompatDelegate
import com.google.android.material.color.DynamicColors
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class LifeWaterApplication : Application() {
    
    companion object {
        private const val PREFS_NAME = "app_settings"
        private const val KEY_MONET_ENABLED = "monet_enabled"
        private const val KEY_FOLLOW_SYSTEM = "follow_system_theme"
        
        /**
         * 检查是否启用了莫奈取色
         */
        fun isMonetEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_MONET_ENABLED, true) && 
                   Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
        }
        
        /**
         * 检查是否启用了跟随系统主题
         */
        fun isFollowSystemEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_FOLLOW_SYSTEM, true)
        }
        
        /**
         * 设置跟随系统主题
         */
        fun setFollowSystemEnabled(context: Context, enabled: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_FOLLOW_SYSTEM, enabled).apply()
            
            // 应用主题设置
            applyThemeMode(enabled)
        }
        
        /**
         * 应用主题模式
         */
        fun applyThemeMode(followSystem: Boolean) {
            if (followSystem) {
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
            } else {
                // 如果不跟随系统，可以设置为其他模式，这里默认设置为浅色模式
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // 应用跟随系统主题设置
        val followSystem = isFollowSystemEnabled(this)
        applyThemeMode(followSystem)
        
        // 应用动态颜色（如果启用且支持）
        if (isMonetEnabled(this)) {
            DynamicColors.applyToActivitiesIfAvailable(this)
        }
    }
}
