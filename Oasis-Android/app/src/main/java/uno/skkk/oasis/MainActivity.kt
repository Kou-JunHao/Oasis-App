package uno.skkk.oasis

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.ui.base.BaseActivity
import uno.skkk.oasis.ui.main.MainNavigationActivity
import uno.skkk.oasis.ui.login.LoginActivity
import uno.skkk.oasis.utils.GitHubUpdateChecker

class MainActivity : BaseActivity() {
    
    private var disclaimerDialog: DisclaimerDialog? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 首先检查是否已接受免责声明
        if (!DisclaimerDialog.isDisclaimerAccepted(this)) {
            showDisclaimerDialog()
        } else {
            proceedToNextActivity()
        }
    }
    
    private fun showDisclaimerDialog() {
        disclaimerDialog = DisclaimerDialog(this, object : DisclaimerDialog.OnDisclaimerActionListener {
            override fun onAccepted() {
                disclaimerDialog = null
                proceedToNextActivity()
            }
            
            override fun onCancelled() {
                disclaimerDialog = null
                // 用户取消，退出应用
                finishAffinity()
            }
        })
        disclaimerDialog?.show()
    }
    
    private fun proceedToNextActivity() {
        // 检查登录状态
        val repository = AppRepository.getInstance(this)
        val isLoggedIn = repository.isLoggedIn()
        
        // 直接导航到下一个Activity，不再在启动时检查更新
        navigateToNextActivity(isLoggedIn)
    }
    
    /**
     * 导航到下一个Activity
     */
    private fun navigateToNextActivity(isLoggedIn: Boolean) {
        if (isLoggedIn) {
            // 已登录，跳转到主导航页面
            startActivity(Intent(this, MainNavigationActivity::class.java))
        } else {
            // 未登录，跳转到登录页面
            startActivity(Intent(this, LoginActivity::class.java))
        }
        
        finish()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        disclaimerDialog?.dismiss()
    }
}
