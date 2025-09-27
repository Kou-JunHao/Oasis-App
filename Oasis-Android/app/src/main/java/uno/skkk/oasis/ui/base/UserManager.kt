package uno.skkk.oasis.ui.base

import android.content.Context
import android.content.SharedPreferences
import uno.skkk.oasis.data.model.User
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 用户管理�? */
@Singleton
class UserManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    
    private val sharedPreferences: SharedPreferences = 
        context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
    
    companion object {
        private const val KEY_TOKEN = "token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_USERNAME = "username"
        private const val KEY_PHONE = "phone"
    }
    
    /**
     * 保存用户信息
     */
    fun saveUser(user: User) {
        sharedPreferences.edit().apply {
            putString(KEY_TOKEN, user.token)
            putString(KEY_USER_ID, user.userId)
            putString(KEY_USERNAME, user.username)
            putString(KEY_PHONE, user.phoneNumber)
            apply()
        }
    }
    
    /**
     * 获取保存的用户信�?     */
    fun getSavedUser(): User? {
        val token = sharedPreferences.getString(KEY_TOKEN, null)
        val userId = sharedPreferences.getString(KEY_USER_ID, null)
        val username = sharedPreferences.getString(KEY_USERNAME, null)
        val phone = sharedPreferences.getString(KEY_PHONE, null)
        
        return if (token != null && userId != null && username != null && phone != null) {
            User(token, userId, username, phone)
        } else {
            null
        }
    }
    
    /**
     * 获取Token
     */
    fun getToken(): String? {
        return sharedPreferences.getString(KEY_TOKEN, null)
    }
    
    /**
     * 获取用户ID
     */
    fun getUserId(): String? {
        return sharedPreferences.getString(KEY_USER_ID, null)
    }
    
    /**
     * 获取用户�?     */
    fun getUsername(): String? {
        return sharedPreferences.getString(KEY_USERNAME, null)
    }
    
    /**
     * 获取用户手机�?     */
    fun getUserPhone(): String? {
        return sharedPreferences.getString(KEY_PHONE, null)
    }
    
    /**
     * 清除用户信息
     */
    fun clearUser() {
        sharedPreferences.edit().clear().apply()
    }
    
    /**
     * 检查是否已登录
     */
    fun isLoggedIn(): Boolean {
        return !getToken().isNullOrEmpty()
    }
}
