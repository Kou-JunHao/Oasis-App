package uno.skkk.oasis.ui.device

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.color.MaterialColors
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import uno.skkk.oasis.ui.qrcode.QRCodeScanActivityNew
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.DialogAddDeviceBinding
import uno.skkk.oasis.databinding.FragmentDeviceListBinding
import uno.skkk.oasis.databinding.DialogFabMenuBinding
import uno.skkk.oasis.databinding.DialogDeleteDeviceBinding
import uno.skkk.oasis.databinding.ItemDeleteDeviceBinding
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.data.repository.DeviceIconRepository
import uno.skkk.oasis.ui.components.UnifiedTopBar
import uno.skkk.oasis.ui.dialog.DeviceIconSelectorDialog
import java.util.regex.Pattern
import javax.inject.Inject

@AndroidEntryPoint
class DeviceListFragment : Fragment() {
    
    private var _binding: FragmentDeviceListBinding? = null
    private val binding get() = _binding!!
    
    private val viewModel: DeviceListViewModel by viewModels()
    private lateinit var deviceAdapter: DeviceAdapter
    
    @Inject
    lateinit var deviceIconRepository: DeviceIconRepository
    private var allDevices: List<Device> = emptyList()
    private var filteredDevices: List<Device> = emptyList()
    private var isFirstLoad = true
    
    // QR Code scanning
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            startQRCodeScan()
        } else {
            Toast.makeText(requireContext(), "需要相机权限才能扫描二维码", Toast.LENGTH_SHORT).show()
        }
    }
    
    private val scanLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val qrResult = result.data?.getStringExtra("SCAN_RESULT")
            if (qrResult != null) {
                handleQRCodeResult(qrResult)
            }
        }
    }
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDeviceListBinding.inflate(inflater, container, false)
        return binding.root
    }
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        setupTopBar()
        setupRecyclerView()
        setupSearchBar()
        setupSwipeRefresh()
        setupFab()
        observeViewModel()
        loadDevices() // 首次加载，显示LoadingIndicator
        isFirstLoad = false
    }
    
    override fun onResume() {
        super.onResume()
        // 只在非首次加载时静默刷新数据（不显示LoadingIndicator）
        if (!isFirstLoad) {
            loadDevices(showLoading = false)
        }
    }
    
    private fun setupTopBar() {
        binding.simpleTitle.setTitle("设备列表")
    }
    
    private fun observeViewModel() {
        lifecycleScope.launch {
            viewModel.devices.collect { devices ->
                allDevices = devices
                filteredDevices = devices
                deviceAdapter.updateDevices(filteredDevices)
                updateEmptyState(filteredDevices.isEmpty())
            }
        }
        
        lifecycleScope.launch {
            viewModel.uiState.collect { uiState ->
                // 处理下拉刷新状态
                binding.swipeRefreshLayout.isRefreshing = uiState.isLoading
                
                // 只在非下拉刷新时显示进度条
                binding.progressBar.visibility = if (uiState.isLoading && !binding.swipeRefreshLayout.isRefreshing) View.VISIBLE else View.GONE
                
                // 更新禁用的停止按钮状态
                deviceAdapter.updateDisabledStopButtons(uiState.disabledStopButtons)
                
                // 更新操作中设备状态
                deviceAdapter.updateOperatingDevices(uiState.operatingDevices)
                
                // 更新设备状态信息
                deviceAdapter.updateDeviceStatuses(uiState.deviceStatuses)
                
                uiState.errorMessage?.let { errorMessage ->
                    // 只在非加载状态下显示错误消息，避免与空状态混淆
                    if (!uiState.isLoading) {
                        Toast.makeText(requireContext(), errorMessage, Toast.LENGTH_LONG).show()
                        viewModel.clearError()
                    }
                }
                
                uiState.successMessage?.let { successMessage ->
                    Toast.makeText(requireContext(), successMessage, Toast.LENGTH_SHORT).show()
                    viewModel.clearSuccess()
                }
            }
        }
    }
    
    private fun setupRecyclerView() {
        deviceAdapter = DeviceAdapter(
            onStartClick = { device -> 
                viewModel.startDevice(device.id)
            },
            onStopClick = { device -> 
                viewModel.stopDevice(device.id)
            },
            onIconClick = { device ->
                showDeviceIconSelector(device)
            },
            deviceIconRepository = deviceIconRepository
        )
        
        binding.recyclerViewDevices.apply {
            layoutManager = LinearLayoutManager(requireContext())
            adapter = deviceAdapter
        }
    }
    
    private fun showDeviceIconSelector(device: Device) {
        DeviceIconSelectorDialog.show(
            context = requireContext(),
            device = device,
            deviceIconRepository = deviceIconRepository
        ) { selectedIcon ->
            // 图标选择完成后刷新设备列表
            deviceAdapter.notifyDataSetChanged()
            Toast.makeText(
                requireContext(), 
                "已为设备 ${device.name} 设置图标: ${selectedIcon.displayName}", 
                Toast.LENGTH_SHORT
            ).show()
        }
    }
    
    private fun setupSearchBar() {
        binding.etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            
            override fun afterTextChanged(s: Editable?) {
                val query = s?.toString()?.trim() ?: ""
                filterDevices(query)
                updateClearButtonVisibility(query.isNotEmpty())
            }
        })
        
        binding.ivClearSearch.setOnClickListener {
            binding.etSearch.text?.clear()
        }
    }
    
    private fun setupSwipeRefresh() {
        binding.swipeRefreshLayout.setOnRefreshListener {
            loadDevices()
        }
        
        // 设置MD3E动态颜色主题
        val context = requireContext()
        
        // 使用MaterialColors获取MD3E颜色
        val colorPrimary = MaterialColors.getColor(context, android.R.attr.colorPrimary, 0)
        val colorAccent = MaterialColors.getColor(context, android.R.attr.colorAccent, 0)
        val colorBackground = MaterialColors.getColor(context, android.R.attr.colorBackground, 0)
        
        binding.swipeRefreshLayout.setColorSchemeColors(
            colorPrimary,
            colorAccent
        )
        
        binding.swipeRefreshLayout.setProgressBackgroundColorSchemeColor(colorBackground)
    }
    
    private fun filterDevices(query: String) {
        filteredDevices = if (query.isEmpty()) {
            allDevices
        } else {
            allDevices.filter { device ->
                // 模糊搜索：设备名称包含查询字符串（忽略大小写）
                val nameMatch = device.name.contains(query, ignoreCase = true)
                // ID搜索：设备ID包含查询字符串
                val idMatch = device.id.contains(query, ignoreCase = true)
                // 地址搜索：设备地址包含查询字符串
                val addressMatch = device.addr?.detail?.contains(query, ignoreCase = true) ?: false
                
                nameMatch || idMatch || addressMatch
            }
        }
        
        deviceAdapter.updateDevices(filteredDevices)
        updateEmptyState(filteredDevices.isEmpty())
    }
    
    private fun updateClearButtonVisibility(isVisible: Boolean) {
        binding.ivClearSearch.visibility = if (isVisible) View.VISIBLE else View.GONE
    }
    
    private fun setupFab() {
        binding.fabAddDevice.setOnClickListener {
            showFabMenu()
        }
    }
    
    private fun showFabMenu() {
        val dialogBinding = DialogFabMenuBinding.inflate(layoutInflater)
        
        val dialog = AlertDialog.Builder(requireContext())
            .setView(dialogBinding.root)
            .create()
        
        dialogBinding.btnAddDevice.setOnClickListener {
            dialog.dismiss()
            showAddDeviceDialog()
        }
        
        dialogBinding.btnDeleteDevice.setOnClickListener {
            dialog.dismiss()
            showDeleteDeviceDialog()
        }
        
        dialog.show()
    }
    
    private fun showDeleteDeviceDialog() {
        val devices = filteredDevices
        val dialogBinding = DialogDeleteDeviceBinding.inflate(layoutInflater)
        
        val dialog = AlertDialog.Builder(requireContext())
            .setView(dialogBinding.root)
            .create()
        
        // 设置对话框背景透明
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
        
        if (devices.isEmpty()) {
            // 显示空状态
            dialogBinding.rvDeviceList.visibility = View.GONE
            dialogBinding.llEmptyState.visibility = View.VISIBLE
            dialogBinding.btnDelete.isEnabled = false
        } else {
            // 设置设备列表
            dialogBinding.rvDeviceList.visibility = View.VISIBLE
            dialogBinding.llEmptyState.visibility = View.GONE
            
            val selectedDevices = mutableSetOf<Device>()
            val adapter = DeleteDeviceAdapter(devices) { device, isSelected ->
                if (isSelected) {
                    selectedDevices.add(device)
                } else {
                    selectedDevices.remove(device)
                }
                dialogBinding.btnDelete.isEnabled = selectedDevices.isNotEmpty()
                dialogBinding.btnDelete.text = if (selectedDevices.isEmpty()) {
                    "删除设备"
                } else {
                    "删除设备 (${selectedDevices.size})"
                }
            }
            
            dialogBinding.rvDeviceList.layoutManager = LinearLayoutManager(requireContext())
            dialogBinding.rvDeviceList.adapter = adapter
        }
        
        // 取消按钮
        dialogBinding.btnCancel.setOnClickListener {
            dialog.dismiss()
        }
        
        // 删除按钮
        dialogBinding.btnDelete.setOnClickListener {
            val adapter = dialogBinding.rvDeviceList.adapter as? DeleteDeviceAdapter
            val selectedDevices = adapter?.getSelectedDevices() ?: emptyList()
            if (selectedDevices.isNotEmpty()) {
                deleteDevices(selectedDevices)
                dialog.dismiss()
            }
        }
        
        dialog.show()
    }
    
    // 删除设备适配器内部类
    private inner class DeleteDeviceAdapter(
        private val devices: List<Device>,
        private val onSelectionChanged: (Device, Boolean) -> Unit
    ) : androidx.recyclerview.widget.RecyclerView.Adapter<DeleteDeviceAdapter.ViewHolder>() {
        
        private val selectedDevices = mutableSetOf<Device>()
        
        inner class ViewHolder(private val binding: ItemDeleteDeviceBinding) : 
            androidx.recyclerview.widget.RecyclerView.ViewHolder(binding.root) {
            
            fun bind(device: Device) {
                binding.apply {
                    tvDeviceName.text = device.name
                    tvDeviceLocation.text = "${device.addr?.detail ?: "未知位置"} · 设备ID: ${device.id}"
                    
                    // 设置设备图标
                    val iconType = deviceIconRepository.getDeviceIcon(device.id)
                    ivDeviceIcon.setImageResource(iconType.iconRes)
                    
                    // 设置复选框状态
                    cbSelected.isChecked = selectedDevices.contains(device)
                    
                    // 点击事件
                    root.setOnClickListener {
                        cbSelected.isChecked = !cbSelected.isChecked
                        updateSelection(device, cbSelected.isChecked)
                    }
                    
                    cbSelected.setOnCheckedChangeListener { _, isChecked ->
                        updateSelection(device, isChecked)
                    }
                }
            }
            
            private fun updateSelection(device: Device, isSelected: Boolean) {
                if (isSelected) {
                    selectedDevices.add(device)
                } else {
                    selectedDevices.remove(device)
                }
                onSelectionChanged(device, isSelected)
            }
        }
        
        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemDeleteDeviceBinding.inflate(
                LayoutInflater.from(parent.context), parent, false
            )
            return ViewHolder(binding)
        }
        
        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(devices[position])
        }
        
        override fun getItemCount() = devices.size
        
        fun getSelectedDevices(): List<Device> = selectedDevices.toList()
    }
    
    private fun deleteDevices(devices: List<Device>) {
        devices.forEach { device ->
            viewModel.removeFavoriteDevice(device.id)
        }
        Toast.makeText(requireContext(), "已删除 ${devices.size} 个设备", Toast.LENGTH_SHORT).show()
    }
    
    private fun loadDevices(showLoading: Boolean = true) {
        viewModel.loadDevices(showLoading = showLoading)
    }
    
    private fun updateEmptyState(isEmpty: Boolean) {
        binding.emptyStateLayout.visibility = if (isEmpty) View.VISIBLE else View.GONE
        binding.recyclerViewDevices.visibility = if (isEmpty) View.GONE else View.VISIBLE
    }
    

    
    private fun showAddDeviceDialog() {
        val dialogBinding = DialogAddDeviceBinding.inflate(layoutInflater)
        
        val dialog = MaterialAlertDialogBuilder(requireContext())
            .setView(dialogBinding.root)
            .create()
        
        // 设置输入监听，实时验证
        dialogBinding.etDeviceId.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val deviceId = s?.toString()?.trim() ?: ""
                val isValid = isValidDeviceId(deviceId)
                dialogBinding.btnAddDevice.isEnabled = isValid
                
                if (deviceId.isNotEmpty() && !isValid) {
                    dialogBinding.tilDeviceId.error = "设备ID格式不正确"
                } else {
                    dialogBinding.tilDeviceId.error = null
                }
            }
        })
        
        // 扫码按钮点击事件
        dialogBinding.btnScanQR.setOnClickListener {
            dialog.dismiss()
            checkCameraPermissionAndScan()
        }
        
        // 手动输入按钮点击事件
        dialogBinding.btnManualInput.setOnClickListener {
            dialogBinding.etDeviceId.requestFocus()
        }
        
        // 输入框末尾图标点击事件（扫码）
        dialogBinding.tilDeviceId.setEndIconOnClickListener {
            dialog.dismiss()
            checkCameraPermissionAndScan()
        }
        
        // 取消按钮
        dialogBinding.btnCancel.setOnClickListener {
            dialog.dismiss()
        }
        
        // 添加设备按钮
        dialogBinding.btnAddDevice.setOnClickListener {
            val deviceId = dialogBinding.etDeviceId.text.toString().trim()
            if (isValidDeviceId(deviceId)) {
                viewModel.addDevice(deviceId)
                dialog.dismiss()
            } else {
                Toast.makeText(requireContext(), "请输入正确的设备ID", Toast.LENGTH_SHORT).show()
            }
        }
        
        dialog.show()
    }
    
    private fun checkCameraPermissionAndScan() {
        when {
            ContextCompat.checkSelfPermission(
                requireContext(),
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED -> {
                startQRCodeScan()
            }
            else -> {
                requestPermissionLauncher.launch(Manifest.permission.CAMERA)
            }
        }
    }
    
    private fun startQRCodeScan() {
        val intent = Intent(requireContext(), QRCodeScanActivityNew::class.java)
        scanLauncher.launch(intent)
    }
    
    private fun handleQRCodeResult(qrContent: String) {
        val deviceId = extractDeviceIdFromQR(qrContent)
        if (deviceId != null) {
            if (isValidDeviceId(deviceId)) {
                viewModel.addDevice(deviceId)
                Toast.makeText(requireContext(), "已添加$deviceId", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(requireContext(), "二维码中的设备ID格式不正确", Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(requireContext(), "无法从二维码中提取设备ID", Toast.LENGTH_SHORT).show()
        }
    }
    
    private fun extractDeviceIdFromQR(qrContent: String): String? {
        // 根据用户提供的信息，从类似 https://i.hnkzy.com/q/1/862551058539692 的链接中提取设备号
        val pattern = Pattern.compile(".*/(\\d{12,15})/?$")
        val matcher = pattern.matcher(qrContent)
        
        return if (matcher.find()) {
            matcher.group(1)
        } else {
            // 如果不是链接格式，检查是否直接是数字
            if (qrContent.matches(Regex("\\d{12,15}"))) {
                qrContent
            } else {
                null
            }
        }
    }
    
    private fun isValidDeviceId(deviceId: String): Boolean {
        // 验证设备ID格式：12-15位数字
        return deviceId.matches(Regex("\\d{12,15}"))
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
    
    companion object {
        fun newInstance() = DeviceListFragment()
    }
}
