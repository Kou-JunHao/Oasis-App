package uno.skkk.oasis.data

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import uno.skkk.oasis.data.repository.AppRepository
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Token管理器
 * 负责管理用户认证token
 */
@Singleton
class TokenManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val appRepository by lazy { AppRepository.getInstance(context) }
    
    /**
     * 获取当前用户的token
     */
    fun getToken(): String? {
        return appRepository.getSavedUser()?.token
    }
    
    /**
     * 获取保存的用户信息
     */
    fun getSavedUser(): uno.skkk.oasis.data.model.User? {
        return appRepository.getSavedUser()
    }
    
    /**
     * 检查用户是否已登录
     */
    fun isLoggedIn(): Boolean {
        return appRepository.isLoggedIn()
    }
    
    /**
     * 清除用户信息
     */
    fun clearUser() {
        appRepository.clearUser()
    }
}