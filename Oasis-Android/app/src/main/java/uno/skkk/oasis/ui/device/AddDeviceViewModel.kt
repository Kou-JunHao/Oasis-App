package uno.skkk.oasis.ui.device

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.data.repository.AppRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 添加设备ViewModel
 */
class AddDeviceViewModel(private val repository: AppRepository) : ViewModel() {
    
    // UI状�?
    private val _uiState = MutableStateFlow(AddDeviceUiState())
    val uiState: StateFlow<AddDeviceUiState> = _uiState.asStateFlow()
    
    // 设备ID输入
    private val _deviceId = MutableStateFlow("")
    val deviceId: StateFlow<String> = _deviceId.asStateFlow()
    
    // 设备名称输入
    private val _deviceName = MutableStateFlow("")
    val deviceName: StateFlow<String> = _deviceName.asStateFlow()
    
    // 设备类型输入
    private val _deviceType = MutableStateFlow("")
    val deviceType: StateFlow<String> = _deviceType.asStateFlow()
    
    /**
     * 更新设备ID
     */
    fun updateDeviceId(id: String) {
        _deviceId.value = id
        validateInput()
    }
    
    /**
     * 更新设备名称
     */
    fun updateDeviceName(name: String) {
        _deviceName.value = name
    }
    
    /**
     * 更新设备类型
     */
    fun updateDeviceType(type: String) {
        _deviceType.value = type
    }
    
    /**
     * 验证输入
     */
    private fun validateInput() {
        val isValid = _deviceId.value.isNotBlank()
        _uiState.value = _uiState.value.copy(isInputValid = isValid)
    }
    
    /**
     * 添加设备
     */
    fun addDevice() {
        if (_deviceId.value.isBlank()) {
            _uiState.value = _uiState.value.copy(
                errorMessage = "请输入设备ID"
            )
            return
        }
        
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null
            )
            
            try {
                val result = repository.addDevice(
                    deviceId = _deviceId.value.trim(),
                    deviceName = _deviceName.value.trim().takeIf { it.isNotBlank() },
                    deviceType = _deviceType.value.trim().takeIf { it.isNotBlank() }
                )
                
                result.fold(
                    onSuccess = { device ->
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            isSuccess = true,
                            addedDevice = device,
                            successMessage = "设备添加成功"
                        )
                    },
                    onFailure = { exception ->
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessage = exception.message ?: "添加设备失败"
                        )
                    }
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = e.message ?: "添加设备失败"
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
        _uiState.value = _uiState.value.copy(
            isSuccess = false,
            successMessage = null,
            addedDevice = null
        )
    }
    
    /**
     * 重置表单
     */
    fun resetForm() {
        _deviceId.value = ""
        _deviceName.value = ""
        _deviceType.value = ""
        _uiState.value = AddDeviceUiState()
    }
}

/**
 * 添加设备UI状�?
 */
data class AddDeviceUiState(
    val isLoading: Boolean = false,
    val isInputValid: Boolean = false,
    val isSuccess: Boolean = false,
    val errorMessage: String? = null,
    val successMessage: String? = null,
    val addedDevice: Device? = null
)

/**
 * ViewModel工厂
 */
class AddDeviceViewModelFactory(private val repository: AppRepository) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(AddDeviceViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return AddDeviceViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
