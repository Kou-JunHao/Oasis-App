package uno.skkk.oasis.data.repository

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import dagger.hilt.android.qualifiers.ApplicationContext
import uno.skkk.oasis.data.model.DeviceCustomIcon
import uno.skkk.oasis.data.model.DeviceIconType
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeviceIconRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val sharedPreferences: SharedPreferences = 
        context.getSharedPreferences("device_icons", Context.MODE_PRIVATE)
    
    private val gson = Gson()
    
    companion object {
        private const val KEY_DEVICE_ICONS = "device_custom_icons"
    }
    
    /**
     * 保存设备自定义图标
     */
    fun saveDeviceIcon(deviceId: String, iconType: DeviceIconType) {
        val customIcons = getDeviceIcons().toMutableMap()
        customIcons[deviceId] = iconType
        
        val iconsJson = gson.toJson(customIcons.map { (id, type) -> 
            DeviceCustomIcon(id, type) 
        })
        
        sharedPreferences.edit {
            putString(KEY_DEVICE_ICONS, iconsJson)
        }
    }
    
    /**
     * 获取设备图标
     */
    fun getDeviceIcon(deviceId: String): DeviceIconType {
        val customIcons = getDeviceIcons()
        return customIcons[deviceId] ?: DeviceIconType.WATER_DISPENSER
    }
    
    /**
     * 获取所有设备自定义图标
     */
    fun getDeviceIcons(): Map<String, DeviceIconType> {
        val iconsJson = sharedPreferences.getString(KEY_DEVICE_ICONS, null)
        
        if (iconsJson.isNullOrEmpty()) {
            return emptyMap()
        }
        
        return try {
            val type = object : TypeToken<List<DeviceCustomIcon>>() {}.type
            val customIcons: List<DeviceCustomIcon> = gson.fromJson(iconsJson, type)
            customIcons.associate { it.deviceId to it.iconType }
        } catch (e: Exception) {
            emptyMap()
        }
    }
    
    /**
     * 删除设备图标设置
     */
    fun removeDeviceIcon(deviceId: String) {
        val customIcons = getDeviceIcons().toMutableMap()
        customIcons.remove(deviceId)
        
        val iconsJson = gson.toJson(customIcons.map { (id, type) -> 
            DeviceCustomIcon(id, type) 
        })
        
        sharedPreferences.edit {
            putString(KEY_DEVICE_ICONS, iconsJson)
        }
    }
    
    /**
     * 智能设置设备图标（基于设备名称）
     */
    fun smartSetDeviceIcon(deviceId: String, deviceName: String): DeviceIconType {
        val matchedIcon = DeviceIconType.matchByDeviceName(deviceName)
        saveDeviceIcon(deviceId, matchedIcon)
        return matchedIcon
    }
    
    /**
     * 清除所有设备图标设置
     */
    fun clearAllDeviceIcons() {
        sharedPreferences.edit {
            remove(KEY_DEVICE_ICONS)
        }
    }
}