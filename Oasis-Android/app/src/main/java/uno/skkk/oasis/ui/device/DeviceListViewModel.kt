package uno.skkk.oasis.ui.device

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.data.model.DeviceStatus
import uno.skkk.oasis.data.repository.DeviceRepository
import uno.skkk.oasis.data.repository.DeviceIconRepository
import uno.skkk.oasis.ui.base.UserManager
import uno.skkk.oasis.data.model.DeviceIconType
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import javax.inject.Inject

/**
 * 设备列表ViewModel
 */
@HiltViewModel
class DeviceListViewModel @Inject constructor(
    private val deviceRepository: DeviceRepository,
    private val userManager: UserManager,
    private val deviceIconRepository: DeviceIconRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(DeviceListUiState())
    val uiState: StateFlow<DeviceListUiState> = _uiState.asStateFlow()
    
    private val _devices = MutableStateFlow<List<Device>>(emptyList())
    val devices: StateFlow<List<Device>> = _devices.asStateFlow()
    
    // 状态缓存相关
    private var lastStatusCheckTime = 0L
    private val statusCacheValidDuration = 30_000L // 30秒缓存有效期
    private var isStatusLoading = false
    
    init {
        loadDevices()
    }
    
    /**
     * 加载设备列表
     */
    fun loadDevices(forceRefreshStatus: Boolean = false, showLoading: Boolean = true) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = showLoading, errorMessage = null)
            
            val token = userManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = "用户未登录"
                )
                return@launch
            }
            
            deviceRepository.getDeviceList(token)
                .onSuccess { deviceList ->
                    _devices.value = deviceList
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = null
                    )
                    // 智能匹配设备图标
                    smartMatchDeviceIcons(deviceList)
                    // 智能加载设备状态
                    loadDeviceStatusesIfNeeded(deviceList.map { it.id }, forceRefreshStatus)
                }
                .onFailure { exception ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = exception.message ?: "加载设备列表失败"
                    )
                }
        }
    }
    
    /**
     * 智能加载设备状态（带缓存机制）
     */
    private fun loadDeviceStatusesIfNeeded(deviceIds: List<String>, forceRefresh: Boolean = false) {
        if (deviceIds.isEmpty()) return
        
        val currentTime = System.currentTimeMillis()
        val isCacheValid = (currentTime - lastStatusCheckTime) < statusCacheValidDuration
        
        // 如果缓存有效且不强制刷新，则跳过
        if (isCacheValid && !forceRefresh && _uiState.value.deviceStatuses.isNotEmpty()) {
            return
        }
        
        // 防止重复请求
        if (isStatusLoading) return
        
        loadDeviceStatuses(deviceIds)
    }
    
    /**
     * 加载设备状态
     */
    private fun loadDeviceStatuses(deviceIds: List<String>) {
        if (deviceIds.isEmpty()) return
        
        viewModelScope.launch {
            isStatusLoading = true
            val token = userManager.getToken() ?: return@launch
            
            deviceRepository.checkDeviceStatus(token, deviceIds)
                .onSuccess { statusList ->
                    _uiState.value = _uiState.value.copy(deviceStatuses = statusList)
                    lastStatusCheckTime = System.currentTimeMillis()
                }
                .onFailure { exception ->
                    // 状态加载失败不影响主要功能，只记录日志，不显示错误消息
                    // Log.w("DeviceListViewModel", "加载设备状态失败: ${exception.message}")
                }
                .also {
                    isStatusLoading = false
                }
        }
    }
    
    /**
     * 加载单个设备状态（用于操作后的状态更新）
     */
    private fun loadSingleDeviceStatus(deviceId: String) {
        viewModelScope.launch {
            val token = userManager.getToken() ?: return@launch
            
            deviceRepository.getSingleDeviceStatus(token, deviceId)
                .onSuccess { singleStatusData ->
                    // 更新单个设备的状态
            val currentStatuses = _uiState.value.deviceStatuses.toMutableList()
                    val existingIndex = currentStatuses.indexOfFirst { it.id == deviceId }
                    
                    val newStatus = DeviceStatus(
                        id = deviceId,
                        status = singleStatusData.status,
                        online = singleStatusData.online
                    )
                    
                    if (existingIndex >= 0) {
                        currentStatuses[existingIndex] = newStatus
                    } else {
                        currentStatuses.add(newStatus)
                    }
                    
                    _uiState.value = _uiState.value.copy(deviceStatuses = currentStatuses)
                }
                .onFailure { exception ->
                    // 单个设备状态加载失败，不影响整体功能
                    // Log.w("DeviceListViewModel", "加载单个设备状态失败: ${exception.message}")
                }
        }
    }
    
    /**
     * 启动设备（乐观更新策略）
     */
    fun startDevice(deviceId: String) {
        viewModelScope.launch {
            val token = userManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(errorMessage = "用户未登录")
                return@launch
            }
            
            // 1. 立即乐观更新前端状态
            val currentOperatingDevices = _uiState.value.operatingDevices.toMutableSet()
            currentOperatingDevices.add(deviceId)
            
            // 立即更新设备状态为运行中
            val currentStatuses = _uiState.value.deviceStatuses.toMutableList()
            val existingIndex = currentStatuses.indexOfFirst { it.id == deviceId }
            val optimisticStatus = DeviceStatus(
                id = deviceId,
                status = 1, // 乐观设置为运行状态
                online = true
            )
            
            if (existingIndex >= 0) {
                currentStatuses[existingIndex] = optimisticStatus
            } else {
                currentStatuses.add(optimisticStatus)
            }
            
            Log.d("DeviceListViewModel", "乐观更新：启动设备$deviceId - 立即更新前端状态")
            _uiState.value = _uiState.value.copy(
                isOperating = true,
                errorMessage = null,
                operatingDevices = currentOperatingDevices,
                deviceStatuses = currentStatuses // 立即更新状态
            )
            
            // 2. 调用API并根据结果决定是否回滚
            deviceRepository.startDevice(token, deviceId)
                .onSuccess {
                    // API成功，保持前端状态，移除操作中标记
                    val updatedOperatingDevices = _uiState.value.operatingDevices.toMutableSet()
                    updatedOperatingDevices.remove(deviceId)
                    
                    Log.d("DeviceListViewModel", "API成功：启动设备$deviceId - 保持前端状态")
                    _uiState.value = _uiState.value.copy(
                        isOperating = false,
                        successMessage = "设备启动成功",
                        operatingDevices = updatedOperatingDevices
                    )
                    
                    // 启动成功后，禁用停止按钮2秒，防止用户立即停止
                    launch {
                        val currentDisabledButtons = _uiState.value.disabledStopButtons.toMutableSet()
                        currentDisabledButtons.add(deviceId)
                        _uiState.value = _uiState.value.copy(
                            disabledStopButtons = currentDisabledButtons
                        )
                        
                        delay(2000)
                        
                        val finalDisabledButtons = _uiState.value.disabledStopButtons.toMutableSet()
                        finalDisabledButtons.remove(deviceId)
                        _uiState.value = _uiState.value.copy(
                            disabledStopButtons = finalDisabledButtons
                        )
                    }
                }
                .onFailure { exception ->
                    // API失败，回滚前端状态
                    val updatedOperatingDevices = _uiState.value.operatingDevices.toMutableSet()
                    updatedOperatingDevices.remove(deviceId)
                    
                    // 回滚设备状态
                    val rollbackStatuses = _uiState.value.deviceStatuses.toMutableList()
                    val rollbackIndex = rollbackStatuses.indexOfFirst { it.id == deviceId }
                    if (rollbackIndex >= 0) {
                        val rollbackStatus = rollbackStatuses[rollbackIndex].copy(status = 0) // 回滚为停止状态
                        rollbackStatuses[rollbackIndex] = rollbackStatus
                    }
                    
                    Log.d("DeviceListViewModel", "API失败：启动设备$deviceId - 回滚前端状态")
                    _uiState.value = _uiState.value.copy(
                        isOperating = false,
                        errorMessage = "设备启动失败: ${exception.message}",
                        operatingDevices = updatedOperatingDevices,
                        deviceStatuses = rollbackStatuses // 回滚状态
                    )
                }
        }
    }
    
    /**
     * 停止设备（乐观更新策略）
     */
    fun stopDevice(deviceId: String) {
        viewModelScope.launch {
            val token = userManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(errorMessage = "用户未登录")
                return@launch
            }
            
            // 1. 立即乐观更新前端状态
            val currentOperatingDevices = _uiState.value.operatingDevices.toMutableSet()
            currentOperatingDevices.add(deviceId)
            
            // 立即更新设备状态为停止
            val currentStatuses = _uiState.value.deviceStatuses.toMutableList()
            val existingIndex = currentStatuses.indexOfFirst { it.id == deviceId }
            val optimisticStatus = DeviceStatus(
                id = deviceId,
                status = 0, // 乐观设置为停止状态
                online = true
            )
            
            if (existingIndex >= 0) {
                currentStatuses[existingIndex] = optimisticStatus
            } else {
                currentStatuses.add(optimisticStatus)
            }
            
            Log.d("DeviceListViewModel", "乐观更新：停止设备$deviceId - 立即更新前端状态")
            _uiState.value = _uiState.value.copy(
                isOperating = true,
                errorMessage = null,
                operatingDevices = currentOperatingDevices,
                deviceStatuses = currentStatuses // 立即更新状态
            )
            
            // 2. 调用API并根据结果决定是否回滚
            deviceRepository.stopDevice(token, deviceId)
                .onSuccess {
                    // API成功，保持前端状态，移除操作中标记
                    val updatedOperatingDevices = _uiState.value.operatingDevices.toMutableSet()
                    updatedOperatingDevices.remove(deviceId)
                    
                    Log.d("DeviceListViewModel", "API成功：停止设备$deviceId - 保持前端状态")
                    _uiState.value = _uiState.value.copy(
                        isOperating = false,
                        successMessage = "设备停止成功",
                        operatingDevices = updatedOperatingDevices
                    )
                }
                .onFailure { exception ->
                    // API失败，回滚前端状态
                    val updatedOperatingDevices = _uiState.value.operatingDevices.toMutableSet()
                    updatedOperatingDevices.remove(deviceId)
                    
                    // 回滚设备状态
                    val rollbackStatuses = _uiState.value.deviceStatuses.toMutableList()
                    val rollbackIndex = rollbackStatuses.indexOfFirst { it.id == deviceId }
                    if (rollbackIndex >= 0) {
                        val rollbackStatus = rollbackStatuses[rollbackIndex].copy(status = 1) // 回滚为运行状态
                        rollbackStatuses[rollbackIndex] = rollbackStatus
                    }
                    
                    Log.d("DeviceListViewModel", "API失败：停止设备$deviceId - 回滚前端状态")
                    _uiState.value = _uiState.value.copy(
                        isOperating = false,
                        errorMessage = "设备停止失败: ${exception.message}",
                        operatingDevices = updatedOperatingDevices,
                        deviceStatuses = rollbackStatuses // 回滚状态
                    )
                }
        }
    }
    
    /**
     * 添加设备到收藏
     */
    fun addFavoriteDevice(deviceId: String) {
        viewModelScope.launch {
            val token = userManager.getToken() ?: return@launch
            
            deviceRepository.addFavoriteDevice(token, deviceId)
                .onSuccess {
                    // 重新加载设备列表
                    loadDevices()
                }
                .onFailure { exception ->
                    _uiState.value = _uiState.value.copy(
                        errorMessage = exception.message ?: "添加收藏失败"
                    )
                }
        }
    }
    
    /**
     * 从收藏中移除设备
     */
    fun removeFavoriteDevice(deviceId: String) {
        viewModelScope.launch {
            val token = userManager.getToken() ?: return@launch
            
            deviceRepository.removeFavoriteDevice(token, deviceId)
                .onSuccess {
                    // 重新加载设备列表
                    loadDevices()
                }
                .onFailure { exception ->
                    _uiState.value = _uiState.value.copy(
                        errorMessage = exception.message ?: "移除收藏失败"
                    )
                }
        }
    }
    
    /**
     * 添加新设备
     */
    fun addDevice(deviceId: String, deviceName: String? = null) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isOperating = true, errorMessage = null)
            
            val token = userManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isOperating = false,
                    errorMessage = "用户未登录"
                )
                return@launch
            }
            
            deviceRepository.addDevice(token, deviceId, deviceName)
                .onSuccess { device ->
                    _uiState.value = _uiState.value.copy(isOperating = false)
                    // 重新加载设备列表
                    loadDevices()
                }
                .onFailure { exception ->
                    _uiState.value = _uiState.value.copy(
                        isOperating = false,
                        errorMessage = exception.message ?: "添加设备失败"
                    )
                }
        }
    }
    
    /**
     * 清除错误消息
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
    
    /**
     * 清除成功消息
     */
    fun clearSuccess() {
        _uiState.value = _uiState.value.copy(successMessage = null)
    }
    
    /**
     * 手动刷新设备状态
     */
    fun refreshDeviceStatuses() {
        val deviceIds = _devices.value.map { it.id }
        if (deviceIds.isNotEmpty()) {
            loadDeviceStatuses(deviceIds)
        }
    }
    
    /**
     * 获取设备状态
     */
    fun getDeviceStatus(deviceId: String): DeviceStatus? {
        return _uiState.value.deviceStatuses.find { it.id == deviceId }
    }
    
    /**
     * 智能匹配设备图标
     * 为没有自定义图标的设备自动匹配合适的图标
     */
    private fun smartMatchDeviceIcons(devices: List<Device>) {
        viewModelScope.launch {
            devices.forEach { device ->
                // 检查设备是否已有自定义图标
                val existingIcon = deviceIconRepository.getDeviceIcon(device.id)
                if (existingIcon == null) {
                    // 使用智能匹配算法为设备匹配图标
                    val matchedIcon = DeviceIconType.matchByDeviceName(device.name)
                    if (matchedIcon != DeviceIconType.WATER_DISPENSER) {
                        // 如果匹配到非默认图标，则保存
                        deviceIconRepository.smartSetDeviceIcon(device.id, device.name)
                    }
                }
            }
        }
    }
}

/**
 * 设备列表UI状态
 */
data class DeviceListUiState(
    val isLoading: Boolean = false,
    val isOperating: Boolean = false,
    val errorMessage: String? = null,
    val successMessage: String? = null,
    val deviceStatuses: List<DeviceStatus> = emptyList(),
    val disabledStopButtons: Set<String> = emptySet(), // 存储禁用停止按钮的设备ID
    val operatingDevices: Set<String> = emptySet() // 存储正在操作中的设备ID
)
