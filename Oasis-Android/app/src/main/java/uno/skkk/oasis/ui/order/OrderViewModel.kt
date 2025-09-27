package uno.skkk.oasis.ui.order

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import uno.skkk.oasis.data.model.Order
import uno.skkk.oasis.data.repository.OrderRepository
import uno.skkk.oasis.ui.base.UserManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * 订单ViewModel
 */
@HiltViewModel
class OrderViewModel @Inject constructor(
    private val orderRepository: OrderRepository,
    private val userManager: UserManager
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(OrderUiState())
    val uiState: StateFlow<OrderUiState> = _uiState.asStateFlow()
    
    private val _orders = MutableStateFlow<List<Order>>(emptyList())
    val orders: StateFlow<List<Order>> = _orders.asStateFlow()
    
    // 保存全部订单用于统计
    private val _allOrders = MutableStateFlow<List<Order>>(emptyList())
    val allOrders: StateFlow<List<Order>> = _allOrders.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _errorMessage = MutableStateFlow("")
    val errorMessage: StateFlow<String> = _errorMessage.asStateFlow()
    
    init {
        loadAllOrders()
    }
    
    /**
     * 加载所有订单
     */
    fun loadAllOrders(showLoading: Boolean = true) {
        val token = userManager.getToken()
        if (token.isNullOrEmpty()) {
            _errorMessage.value = "用户未登录"
            return
        }
        
        viewModelScope.launch {
            if (showLoading) {
                _isLoading.value = true
            }
            try {
                val result = orderRepository.getAllOrders(token)
                result.fold(
                    onSuccess = { orders ->
                        _allOrders.value = orders // 保存全部订单
                        _orders.value = orders    // 显示全部订单
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessage = null
                        )
                    },
                    onFailure = { exception ->
                        _errorMessage.value = exception.message ?: "获取订单列表失败"
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessage = exception.message
                        )
                    }
                )
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "网络错误"
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = e.message
                )
            } finally {
                if (showLoading) {
                    _isLoading.value = false
                }
            }
        }
    }
    
    /**
     * 根据状态加载订单
     */
    fun loadOrdersByStatus(status: Int?) {
        val token = userManager.getToken()
        if (token.isNullOrEmpty()) {
            _errorMessage.value = "用户未登录"
            return
        }
        
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val result = if (status == null) {
                    orderRepository.getAllOrders(token)
                } else {
                    orderRepository.getOrdersByStatus(token, status.toString())
                }
                
                result.fold(
                    onSuccess = { orders ->
                        if (status == null) {
                            // 如果是加载全部订单，更新allOrders
                            _allOrders.value = orders
                        }
                        _orders.value = orders // 更新显示的订单
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessage = null
                        )
                    },
                    onFailure = { exception ->
                        _errorMessage.value = exception.message ?: "获取订单列表失败"
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessage = exception.message
                        )
                    }
                )
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "网络错误"
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = e.message
                )
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    /**
     * 清除错误信息
     */
    fun clearError() {
        _errorMessage.value = ""
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
}

/**
 * 订单UI状态
 */
data class OrderUiState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val orders: List<Order> = emptyList()
)
