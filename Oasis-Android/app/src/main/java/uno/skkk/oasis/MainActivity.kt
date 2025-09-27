package uno.skkk.oasis

import android.content.Intent
import android.os.Bundle
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.ui.base.BaseActivity
import uno.skkk.oasis.ui.main.MainNavigationActivity
import uno.skkk.oasis.ui.login.LoginActivity

class MainActivity : BaseActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 检查登录状�?
        val repository = AppRepository.getInstance(this)
        val isLoggedIn = repository.isLoggedIn()
        
        if (isLoggedIn) {
            // 已登录，跳转到主导航页面
            startActivity(Intent(this, MainNavigationActivity::class.java))
        } else {
            // 未登录，跳转到登录页面
            startActivity(Intent(this, LoginActivity::class.java))
        }
        
        finish()
    }
}
