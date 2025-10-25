package uno.skkk.oasis.utils

import android.content.Context
import android.content.SharedPreferences

/**
 * SharedPreferences管理器
 */
class SharedPreferencesManager(context: Context) {
    
    companion object {
        private const val PREF_NAME = "oasis_preferences"
        private const val KEY_SKIPPED_VERSION = "skipped_version"
        private const val KEY_LAST_UPDATE_CHECK = "last_update_check"
    }
    
    private val sharedPreferences: SharedPreferences = 
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    
    /**
     * 跳过指定版本
     */
    fun skipVersion(version: String) {
        setSkippedVersion(version)
    }
    
    /**
     * 保存跳过的版本号
     */
    fun setSkippedVersion(version: String) {
        sharedPreferences.edit()
            .putString(KEY_SKIPPED_VERSION, version)
            .apply()
    }
    
    /**
     * 获取跳过的版本号
     */
    fun getSkippedVersion(): String? {
        return sharedPreferences.getString(KEY_SKIPPED_VERSION, null)
    }
    
    /**
     * 清除跳过的版本号
     */
    fun clearSkippedVersion() {
        sharedPreferences.edit()
            .remove(KEY_SKIPPED_VERSION)
            .apply()
    }
    
    /**
     * 检查版本是否被跳过
     */
    fun isVersionSkipped(version: String): Boolean {
        return getSkippedVersion() == version
    }
    
    /**
     * 保存最后检查更新的时间
     */
    fun setLastUpdateCheckTime(timestamp: Long) {
        sharedPreferences.edit()
            .putLong(KEY_LAST_UPDATE_CHECK, timestamp)
            .apply()
    }
    
    /**
     * 获取最后检查更新的时间
     */
    fun getLastUpdateCheckTime(): Long {
        return sharedPreferences.getLong(KEY_LAST_UPDATE_CHECK, 0)
    }
}