package uno.skkk.oasis.ui.dialog

import android.app.Dialog
import android.content.Context
import android.os.Bundle
import androidx.recyclerview.widget.GridLayoutManager
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.data.model.DeviceIconType
import uno.skkk.oasis.data.repository.DeviceIconRepository
import uno.skkk.oasis.databinding.DialogDeviceIconSelectorBinding
import uno.skkk.oasis.ui.adapter.DeviceIconSelectorAdapter

class DeviceIconSelectorDialog(
    context: Context,
    private val device: Device,
    private val deviceIconRepository: DeviceIconRepository,
    private val onIconSelected: (DeviceIconType) -> Unit
) : Dialog(context) {

    private lateinit var binding: DialogDeviceIconSelectorBinding
    private lateinit var iconAdapter: DeviceIconSelectorAdapter
    private var selectedIconType: DeviceIconType = DeviceIconType.WATER_DISPENSER

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        binding = DialogDeviceIconSelectorBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupDialog()
        setupViews()
        setupRecyclerView()
        setupClickListeners()
    }

    private fun setupDialog() {
        window?.setLayout(
            (context.resources.displayMetrics.widthPixels * 0.9).toInt(),
            android.view.ViewGroup.LayoutParams.WRAP_CONTENT
        )
        setCancelable(true)
    }

    private fun setupViews() {
        // 获取当前设备图标
        selectedIconType = deviceIconRepository.getDeviceIcon(device.id)
        
        binding.apply {
            // 设置设备信息
            tvDeviceName.text = device.name
            ivCurrentIcon.setImageResource(selectedIconType.iconRes)
        }
    }

    private fun setupRecyclerView() {
        val iconTypes = DeviceIconType.getSelectableIcons()
        
        iconAdapter = DeviceIconSelectorAdapter(iconTypes) { iconType ->
            selectedIconType = iconType
            binding.ivCurrentIcon.setImageResource(iconType.iconRes)
        }
        
        binding.rvIconGrid.apply {
            layoutManager = GridLayoutManager(context, 4)
            adapter = iconAdapter
        }
        
        // 设置当前选中的图标
        iconAdapter.setSelectedIcon(selectedIconType)
    }

    private fun setupClickListeners() {
        binding.apply {
            // 智能匹配按钮
            btnSmartMatch.setOnClickListener {
                val matchedIcon = DeviceIconType.matchByDeviceName(device.name)
                selectedIconType = matchedIcon
                iconAdapter.setSelectedIcon(matchedIcon)
                ivCurrentIcon.setImageResource(matchedIcon.iconRes)
            }
            
            // 取消按钮
            btnCancel.setOnClickListener {
                dismiss()
            }
            
            // 确定按钮
            btnConfirm.setOnClickListener {
                // 保存选择的图标
                deviceIconRepository.saveDeviceIcon(device.id, selectedIconType)
                onIconSelected(selectedIconType)
                dismiss()
            }
        }
    }

    companion object {
        fun show(
            context: Context,
            device: Device,
            deviceIconRepository: DeviceIconRepository,
            onIconSelected: (DeviceIconType) -> Unit
        ) {
            DeviceIconSelectorDialog(context, device, deviceIconRepository, onIconSelected).show()
        }
    }
}