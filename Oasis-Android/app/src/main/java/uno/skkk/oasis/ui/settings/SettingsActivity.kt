package uno.skkk.oasis.ui.settings

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import com.google.android.material.color.DynamicColors
import uno.skkk.oasis.LifeWaterApplication
import uno.skkk.oasis.databinding.ActivitySettingsBinding
import uno.skkk.oasis.ui.base.BaseActivity

class SettingsActivity : BaseActivity() {
    
    private lateinit var binding: ActivitySettingsBinding
    private lateinit var sharedPreferences: SharedPreferences
    
    companion object {
        private const val PREFS_NAME = "app_settings"
        private const val KEY_MONET_ENABLED = "monet_enabled"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        sharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        setupToolbar()
        setupSettings()
    }
    
    private fun setupToolbar() {
        binding.toolbar.setNavigationOnClickListener {
            finish()
        }
    }
    
    private fun setupSettings() {
        // 读取莫奈取色设置
        val isMonetEnabled = LifeWaterApplication.isMonetEnabled(this)
        binding.switchMonet.isChecked = isMonetEnabled
        
        // 如果不支持Android 12+，禁用开关
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            binding.switchMonet.isEnabled = false
        }
        
        // 设置莫奈取色开关监听器
        binding.switchMonet.setOnCheckedChangeListener { _, isChecked ->
            sharedPreferences.edit()
                .putBoolean(KEY_MONET_ENABLED, isChecked)
                .apply()
            
            // 应用莫奈取色设置
            applyMonetTheme(isChecked)
        }
    }
    
    private fun applyMonetTheme(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (enabled) {
                // 应用动态颜�?
                DynamicColors.applyToActivityIfAvailable(this)
            }
            
            // 重启应用以完全应用新主题
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            finishAffinity()
        }
    }
    

}
