package uno.skkk.oasis.data.model

import androidx.annotation.DrawableRes
import uno.skkk.oasis.R

/**
 * 设备图标枚举类
 */
enum class DeviceIconType(
    val iconName: String,
    val displayName: String,
    @DrawableRes val iconRes: Int,
    val keywords: List<String> // 用于智能匹配的关键词
) {
    WATER_DISPENSER("water_dispenser", "饮水机", R.drawable.ic_device_water_dispenser, 
        listOf("饮水机", "饮水", "水机", "water", "dispenser", "drink")),
    WASHING_MACHINE("washing_machine", "洗衣机", R.drawable.ic_device_washing_machine, 
        listOf("洗衣机", "洗衣", "washing", "machine", "laundry")),
    CHARGING_STATION("charging_station", "充电桩", R.drawable.ic_device_charging_station, 
        listOf("充电桩", "充电", "charging", "station", "charge", "电桩")),
    HAIR_DRYER("hair_dryer", "吹风机", R.drawable.ic_device_hair_dryer, 
        listOf("电吹风", "吹风机", "吹风", "hair", "dryer", "blow", "风扇", "fan"));

    companion object {
        /**
         * 根据设备名称智能匹配图标
         */
        fun matchByDeviceName(deviceName: String): DeviceIconType {
            val lowerCaseName = deviceName.lowercase()
            
            // 遍历所有图标类型，查找匹配的关键词
            for (iconType in values()) {
                for (keyword in iconType.keywords) {
                    if (lowerCaseName.contains(keyword.lowercase())) {
                        return iconType
                    }
                }
            }
            
            return WATER_DISPENSER // 如果没有匹配到，返回饮水机图标作为默认值
        }
        
        /**
         * 根据图标名称获取图标类型
         */
        fun fromIconName(iconName: String): DeviceIconType {
            return values().find { it.iconName == iconName } ?: WATER_DISPENSER
        }
        
        /**
         * 获取所有可选的图标类型（排除默认图标）
         */
        fun getSelectableIcons(): List<DeviceIconType> {
            return values().toList()
        }
    }
}

/**
 * 设备自定义图标数据类
 */
data class DeviceCustomIcon(
    val deviceId: String,
    val iconType: DeviceIconType
)