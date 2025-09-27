package uno.skkk.oasis.ui.device

import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.data.model.DeviceIconType
import uno.skkk.oasis.data.model.DeviceStatus
import uno.skkk.oasis.data.repository.DeviceIconRepository
import uno.skkk.oasis.databinding.ItemDeviceCardBinding
import java.text.SimpleDateFormat
import java.util.*

class DeviceAdapter(
    private val onStartClick: (Device) -> Unit,
    private val onStopClick: (Device) -> Unit,
    private val onIconClick: (Device) -> Unit,
    private val deviceIconRepository: DeviceIconRepository
) : ListAdapter<Device, DeviceAdapter.DeviceViewHolder>(DeviceDiffCallback()) {
    
    private var disabledStopButtons: Set<String> = emptySet()
    // 存储正在操作中的设备ID
    private var operatingDevices: Set<String> = emptySet()
    // 存储设备状态信息
    private var deviceStatuses: Map<String, DeviceStatus> = emptyMap()
    
    fun updateDevices(devices: List<Device>) {
        submitList(devices)
    }
    
    fun updateDisabledStopButtons(disabledButtons: Set<String>) {
        disabledStopButtons = disabledButtons
        notifyDataSetChanged() // 刷新所有项目以更新按钮状态
    }
    
    fun updateOperatingDevices(operatingDevices: Set<String>) {
        Log.d("DeviceAdapter", "更新操作中设备列表: $operatingDevices")
        this.operatingDevices = operatingDevices
        notifyDataSetChanged() // 刷新所有项目以更新按钮状态
    }
    
    fun updateDeviceStatuses(statuses: List<DeviceStatus>) {
        deviceStatuses = statuses.associateBy { it.id }
        notifyDataSetChanged() // 刷新所有项目以更新按钮状态
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): DeviceViewHolder {
        val binding = ItemDeviceCardBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return DeviceViewHolder(binding)
    }

    override fun onBindViewHolder(holder: DeviceViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    inner class DeviceViewHolder(
        private val binding: ItemDeviceCardBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(device: Device) {
            binding.apply {
                tvDeviceName.text = device.name
                tvDeviceId.text = "ID: ${device.id}"
                
                // 设置设备状态
                val isOnline = device.status == 1
                tvDeviceLocation.text = device.addr?.detail ?: "未知位置"
                
                // 设置状态指示器
                if (isOnline) {
                    statusIndicator.text = "在线"
                    statusIndicator.setBackgroundResource(uno.skkk.oasis.R.drawable.status_indicator_online)
                } else {
                    statusIndicator.text = "离线"
                    statusIndicator.setBackgroundResource(uno.skkk.oasis.R.drawable.status_indicator_offline)
                }
                
                // 设置设备图标
                val deviceIcon = deviceIconRepository.getDeviceIcon(device.id)
                ivDeviceIcon.setImageResource(deviceIcon.iconRes)
                
                // 设置图标点击事件
                ivDeviceIcon.setOnClickListener {
                    onIconClick(device)
                }
                
                // 设置设备类型图标
                val deviceTypeText = when (device.btype) {
                    1 -> "Android设备"
                    2 -> "iOS设备"
                    3 -> "Windows设备"
                    4 -> "Mac设备"
                    5 -> "Linux设备"
                    6 -> "智能电视"
                    7 -> "路由器"
                    8 -> "其他设备"
                    else -> "未知设备"
                }
                
                // 设置操作按钮
                // 优先使用DeviceStatus中的状态信息，如果没有则回退到Device.isRunning()
                val deviceStatus = deviceStatuses[device.id]
                val isRunning = if (deviceStatus != null) {
                    deviceStatus.status == 1 // DeviceStatus中1表示运行中，0表示停止
                } else {
                    device.isRunning() // 回退到原来的逻辑
                }
                val isOperating = operatingDevices.contains(device.id)
                
                Log.d("DeviceAdapter", "设备 ${device.id}: isRunning=$isRunning (来源: ${if (deviceStatus != null) "DeviceStatus" else "Device.gene"}), isOnline=$isOnline, isOperating=$isOperating")
                
                // 启动按钮 - 设备未运行、在线且不在操作中时可用
                btnStartDevice.isEnabled = !isRunning && isOnline && !isOperating
                
                // 为禁用状态添加视觉反馈
                if (!btnStartDevice.isEnabled) {
                    btnStartDevice.alpha = 0.5f // 禁用时半透明
                } else {
                    btnStartDevice.alpha = 1.0f // 启用时完全不透明
                }
                
                btnStartDevice.setOnClickListener {
                    onStartClick(device)
                }
                
                // 停止按钮 - 设备运行、在线、不在操作中且不在禁用列表中时可用
                val isStopButtonDisabled = disabledStopButtons.contains(device.id)
                btnStopDevice.isEnabled = isRunning && isOnline && !isOperating && !isStopButtonDisabled
                
                // 为禁用状态添加视觉反馈
                if (!btnStopDevice.isEnabled) {
                    btnStopDevice.alpha = 0.5f // 禁用时半透明
                } else {
                    btnStopDevice.alpha = 1.0f // 启用时完全不透明
                }
                
                btnStopDevice.setOnClickListener {
                    onStopClick(device)
                }
                
                // 设置卡片点击事件
                root.setOnClickListener {
                    // 可以添加设备详情页面导航
                }
            }
        }
        
        private fun formatLastOnlineTime(timestamp: Long?): String {
            if (timestamp == null || timestamp == 0L) {
                return "从未在线"
            }
            
            val now = System.currentTimeMillis()
            val diff = now - timestamp
            
            return when {
                diff < 60 * 1000 -> "刚刚"
                diff < 60 * 60 * 1000 -> "${diff / (60 * 1000)}分钟前"
                diff < 24 * 60 * 60 * 1000 -> "${diff / (60 * 60 * 1000)}小时前"
                diff < 7 * 24 * 60 * 60 * 1000 -> "${diff / (24 * 60 * 60 * 1000)}天前"
                else -> {
                    val sdf = SimpleDateFormat("MM-dd HH:mm", Locale.getDefault())
                    sdf.format(Date(timestamp))
                }
            }
        }
    }

    class DeviceDiffCallback : DiffUtil.ItemCallback<Device>() {
        override fun areItemsTheSame(oldItem: Device, newItem: Device): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(oldItem: Device, newItem: Device): Boolean {
            return oldItem == newItem
        }
    }
}
