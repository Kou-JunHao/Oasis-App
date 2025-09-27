package uno.skkk.oasis.ui.wallet

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import uno.skkk.oasis.data.model.WalletData
import uno.skkk.oasis.data.model.RechargeAmount
import uno.skkk.oasis.data.model.RechargeOrder
import uno.skkk.oasis.data.model.PaymentChannel
import uno.skkk.oasis.data.model.PaymentChannelsResponse
import uno.skkk.oasis.data.model.AlipayPaymentData
import uno.skkk.oasis.data.model.RechargeRequest
import uno.skkk.oasis.data.repository.WalletRepository
import uno.skkk.oasis.ui.base.UserManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * 钱包ViewModel
 */
@HiltViewModel
class WalletViewModel @Inject constructor(
    private val walletRepository: WalletRepository,
    private val userManager: UserManager
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(WalletUiState())
    val uiState: StateFlow<WalletUiState> = _uiState.asStateFlow()
    
    private val _walletData = MutableStateFlow<WalletData?>(null)
    val walletData: StateFlow<WalletData?> = _walletData.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _errorMessage = MutableStateFlow("")
    val errorMessage: StateFlow<String> = _errorMessage.asStateFlow()
    
    init {
        loadWalletBalance()
    }
    
    /**
     * 加载钱包余额
     */
    fun loadWalletBalance(showLoading: Boolean = true) {
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
                val result = walletRepository.getWalletBalance(token)
                result.fold(
                    onSuccess = { walletData ->
                        _walletData.value = walletData
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessage = null
                        )
                    },
                    onFailure = { exception ->
                        _errorMessage.value = exception.message ?: "获取钱包信息失败"
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
     * 清除错误信息
     */
    fun clearError() {
        _errorMessage.value = ""
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }
    
    /**
     * 获取充值金额选项
     */
    fun getRechargeAmounts(): List<RechargeAmount> {
        return listOf(
            RechargeAmount(amount = 10.0, description = "10元"),
            RechargeAmount(amount = 20.0, description = "20元"),
            RechargeAmount(amount = 50.0, description = "50元"),
            RechargeAmount(amount = 100.0, description = "100元+5元赠送"),
            RechargeAmount(amount = 200.0, description = "200元+15元赠送"),
            RechargeAmount(amount = 500.0, description = "500元+50元赠送")
        )
    }
    
    /**
     * 创建充值订单
     */
    fun createRechargeOrder(productId: String, count: Int = 1, callback: (Result<RechargeOrder>) -> Unit) {
        val token = userManager.getToken()
        if (token.isNullOrEmpty()) {
            callback(Result.failure(Exception("用户未登录")))
            return
        }
        
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val result = walletRepository.createRechargeOrder(productId, count)
                callback(result)
            } catch (e: Exception) {
                callback(Result.failure(e))
            } finally {
                _isLoading.value = false
            }
        }
    }
    
    /**
     * 获取支付渠道
     */
    fun getPaymentChannels(id: String, callback: (Result<PaymentChannelsResponse>) -> Unit) {
        val token = userManager.getToken()
        if (token.isNullOrEmpty()) {
            callback(Result.failure(Exception("用户未登录")))
            return
        }
        
        viewModelScope.launch {
            try {
                val result = walletRepository.getPaymentChannels(token, id)
                callback(result)
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }
    
    /**
     * 发起支付宝支付
     */
    fun initiateAlipayPayment(id: String, callback: (Result<AlipayPaymentData>) -> Unit) {
        val token = userManager.getToken()
        if (token.isNullOrEmpty()) {
            callback(Result.failure(Exception("用户未登录")))
            return
        }
        
        viewModelScope.launch {
            try {
                val result = walletRepository.initiateAlipayPayment(token, id)
                callback(result)
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }
}

/**
 * 钱包UI状态
 */
data class WalletUiState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val walletData: WalletData? = null
)
