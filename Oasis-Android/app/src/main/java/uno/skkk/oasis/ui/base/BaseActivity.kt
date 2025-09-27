package uno.skkk.oasis.ui.base

import android.os.Build
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import uno.skkk.oasis.LifeWaterApplication
import uno.skkk.oasis.R

abstract class BaseActivity : AppCompatActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        // 应用主题
        applyTheme()
        
        super.onCreate(savedInstanceState)
    }
    
    private fun applyTheme() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!LifeWaterApplication.isMonetEnabled(this)) {
                setTheme(R.style.Theme_LifeWater_NoMonet_NoActionBar)
            } else {
                setTheme(R.style.Theme_LifeWater_NoActionBar)
            }
        } else {
            setTheme(R.style.Theme_LifeWater_NoActionBar)
        }
    }
}
