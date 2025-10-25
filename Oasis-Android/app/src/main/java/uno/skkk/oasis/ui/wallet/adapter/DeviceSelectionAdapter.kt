package uno.skkk.oasis.ui.wallet.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.databinding.ItemDeviceSelectionBinding

/**
 * 设备选择适配器 - 用于充值页面的设备选择
 */
class DeviceSelectionAdapter(
    private val onDeviceSelected: (Device) -> Unit
) : ListAdapter<Device, DeviceSelectionAdapter.DeviceSelectionViewHolder>(DeviceDiffCallback()) {

    private var selectedDeviceId: String? = null

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): DeviceSelectionViewHolder {
        val binding = ItemDeviceSelectionBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return DeviceSelectionViewHolder(binding)
    }

    override fun onBindViewHolder(holder: DeviceSelectionViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    fun updateSelectedDevice(deviceId: String?) {
        val oldSelectedId = selectedDeviceId
        selectedDeviceId = deviceId
        
        // 刷新之前选中的项目
        oldSelectedId?.let { oldId ->
            val oldIndex = currentList.indexOfFirst { it.id == oldId }
            if (oldIndex >= 0) {
                notifyItemChanged(oldIndex)
            }
        }
        
        // 刷新新选中的项目
        deviceId?.let { newId ->
            val newIndex = currentList.indexOfFirst { it.id == newId }
            if (newIndex >= 0) {
                notifyItemChanged(newIndex)
            }
        }
    }

    inner class DeviceSelectionViewHolder(
        private val binding: ItemDeviceSelectionBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(device: Device) {
            binding.apply {
                // 设置设备名称
                textDeviceName.text = device.name
                
                // 设置设备位置信息
                val location = device.ep?.name ?: device.addr?.let { addr ->
                    listOfNotNull(addr.prov, addr.city, addr.detail).joinToString(" ")
                } ?: "未知位置"
                textDeviceLocation.text = location
                
                // 设置选择状态
                radioDeviceSelected.isChecked = device.id == selectedDeviceId
                
                // 设置点击事件
                root.setOnClickListener {
                    onDeviceSelected(device)
                }
                
                // 设置设备图标（根据设备类型）
                val iconRes = when (device.btype) {
                    3 -> uno.skkk.oasis.R.drawable.ic_device_water_dispenser // 饮水机
                    4 -> uno.skkk.oasis.R.drawable.ic_device_washing_machine // 洗衣机
                    5 -> uno.skkk.oasis.R.drawable.ic_device_charging_station // 充电桩
                    6 -> uno.skkk.oasis.R.drawable.ic_device_hair_dryer // 吹风机
                    else -> uno.skkk.oasis.R.drawable.ic_device_water_dispenser // 默认图标
                }
                imageDeviceIcon.setImageResource(iconRes)
            }
        }
    }

    private class DeviceDiffCallback : DiffUtil.ItemCallback<Device>() {
        override fun areItemsTheSame(oldItem: Device, newItem: Device): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(oldItem: Device, newItem: Device): Boolean {
            return oldItem == newItem
        }
    }
}