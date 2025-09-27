package uno.skkk.oasis.ui.wallet

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import uno.skkk.oasis.data.model.AlipayPaymentData
import uno.skkk.oasis.data.model.PaymentChannelsResponse
import uno.skkk.oasis.data.model.Product
import uno.skkk.oasis.data.model.RechargeAmount
import uno.skkk.oasis.data.model.RechargeOrder
import uno.skkk.oasis.data.repository.WalletRepository
import uno.skkk.oasis.data.TokenManager
import javax.inject.Inject
import kotlin.Result

@HiltViewModel
class RechargeViewModel @Inject constructor(
    private val walletRepository: WalletRepository,
    private val tokenManager: TokenManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(RechargeUiState())
    val uiState: StateFlow<RechargeUiState> = _uiState.asStateFlow()



    private val _rechargeProducts = MutableStateFlow<List<Product>>(emptyList())
    val rechargeProducts: StateFlow<List<Product>> = _rechargeProducts.asStateFlow()

    private val _paymentChannels = MutableStateFlow<PaymentChannelsResponse?>(null)
    val paymentChannels: StateFlow<PaymentChannelsResponse?> = _paymentChannels.asStateFlow()

    private val _alipayPaymentData = MutableStateFlow<AlipayPaymentData?>(null)
    val alipayPaymentData: StateFlow<AlipayPaymentData?> = _alipayPaymentData.asStateFlow()

    init {
        loadRechargeProducts()
    }

    /**
     * 加载充值产品列表（新版本，包含优惠信息）
     */
    private fun loadRechargeProducts() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            
            val token = tokenManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = "请先登录"
                )
                return@launch
            }

            // 获取用户信息以获取eid
            val user = tokenManager.getSavedUser()
            val eid = user?.eid ?: "fd94e5502003000" // 使用默认的企业ID
            if (eid.isEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = "无法获取用户企业信息"
                )
                return@launch
            }

            walletRepository.getRechargeProducts(
                token = token,
                eid = eid,
                type = 1, // 产品类型
                status = 1, // 产品状态
                all = false,
                did = "",
                page = 0,
                size = 100,
                hasCount = false
            ).fold(
                onSuccess = { products ->
                    _rechargeProducts.value = products
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = null
                    )
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = exception.message ?: "加载充值产品失败"
                    )
                }
            )
        }
    }



    /**
     * 创建充值订单
     */
    fun createRechargeOrder(productId: String, count: Int = 1) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)

            walletRepository.createRechargeOrder(productId, count).fold(
                onSuccess = { rechargeOrder: RechargeOrder ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = null
                    )
                    // 创建订单成功后，获取支付渠道
                    getPaymentChannels(rechargeOrder.id)
                },
                onFailure = { exception: Throwable ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = exception.message ?: "创建充值订单失败"
                    )
                }
            )
        }
    }

    /**
     * 获取支付渠道
     */
    private fun getPaymentChannels(id: String) {
        viewModelScope.launch {
            val token = tokenManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(
                    errorMessage = "请先登录"
                )
                return@launch
            }

            walletRepository.getPaymentChannels(token, id).fold(
                onSuccess = { channels: PaymentChannelsResponse ->
                    _paymentChannels.value = channels
                },
                onFailure = { exception: Throwable ->
                    _uiState.value = _uiState.value.copy(
                        errorMessage = exception.message ?: "获取支付渠道失败"
                    )
                }
            )
        }
    }

    /**
     * 一键充值 - 整合创建订单、获取支付渠道、发起支付宝支付的完整流程
     */
    fun oneClickRecharge(productId: String, count: Int = 1) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
            
            val token = tokenManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = "请先登录"
                )
                return@launch
            }

            try {
                // 第一步：创建充值订单
                Log.d("RechargeViewModel", "开始创建充值订单，产品ID: $productId")
                val orderResult = walletRepository.createRechargeOrder(productId, count)
                
                orderResult.fold(
                    onSuccess = { rechargeOrder ->
                        Log.d("RechargeViewModel", "订单创建成功，订单ID: ${rechargeOrder.id}")
                        _uiState.value = _uiState.value.copy(currentOrder = rechargeOrder)
                        
                        // 第二步：获取支付渠道
                        Log.d("RechargeViewModel", "开始获取支付渠道")
                        val channelsResult = walletRepository.getPaymentChannels(token, rechargeOrder.id)
                        
                        channelsResult.fold(
                            onSuccess = { channels ->
                                Log.d("RechargeViewModel", "支付渠道获取成功，渠道数量: ${channels.channels.size}")
                                _paymentChannels.value = channels
                                
                                // 第三步：自动选择支付宝支付（渠道类型21）
                                val alipayChannel = channels.channels.find { it.type == 21 }
                                if (alipayChannel != null) {
                                    Log.d("RechargeViewModel", "找到支付宝渠道，开始发起支付")
                                    
                                    // 第四步：发起支付宝支付
                                    val paymentResult = walletRepository.initiateAlipayPayment(token, rechargeOrder.id)
                                    
                                    paymentResult.fold(
                                        onSuccess = { paymentData ->
                                            Log.d("RechargeViewModel", "支付宝支付发起成功")
                                            _alipayPaymentData.value = paymentData
                                            _uiState.value = _uiState.value.copy(
                                                isLoading = false,
                                                errorMessage = null
                                            )
                                        },
                                        onFailure = { exception ->
                                            Log.e("RechargeViewModel", "发起支付宝支付失败", exception)
                                            _uiState.value = _uiState.value.copy(
                                                isLoading = false,
                                                errorMessage = exception.message ?: "发起支付宝支付失败"
                                            )
                                        }
                                    )
                                } else {
                                    Log.e("RechargeViewModel", "未找到支付宝支付渠道")
                                    _uiState.value = _uiState.value.copy(
                                        isLoading = false,
                                        errorMessage = "暂不支持支付宝支付"
                                    )
                                }
                            },
                            onFailure = { exception ->
                                Log.e("RechargeViewModel", "获取支付渠道失败", exception)
                                _uiState.value = _uiState.value.copy(
                                    isLoading = false,
                                    errorMessage = exception.message ?: "获取支付渠道失败"
                                )
                            }
                        )
                    },
                    onFailure = { exception ->
                        Log.e("RechargeViewModel", "创建充值订单失败", exception)
                        _uiState.value = _uiState.value.copy(
                            isLoading = false,
                            errorMessage = exception.message ?: "创建充值订单失败"
                        )
                    }
                )
            } catch (e: Exception) {
                Log.e("RechargeViewModel", "一键充值过程中发生异常", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = "充值过程中发生错误：${e.message}"
                )
            }
        }
    }

    /**
     * 发起支付宝支付
     */
    fun initiateAlipayPayment() {
        viewModelScope.launch {
            val currentOrder = _uiState.value.currentOrder
            if (currentOrder == null) {
                _uiState.value = _uiState.value.copy(
                    errorMessage = "请先创建充值订单"
                )
                return@launch
            }

            _uiState.value = _uiState.value.copy(isLoading = true)
            
            val token = tokenManager.getToken()
            if (token.isNullOrEmpty()) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = "请先登录"
                )
                return@launch
            }

            walletRepository.initiateAlipayPayment(token, currentOrder.id).fold(
                onSuccess = { paymentData: AlipayPaymentData ->
                    _alipayPaymentData.value = paymentData
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = null
                    )
                },
                onFailure = { exception: Throwable ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = exception.message ?: "发起支付宝支付失败"
                    )
                }
            )
        }
    }

    /**
     * 清除错误信息
     */
    fun clearError() {
        _uiState.value = _uiState.value.copy(errorMessage = null)
    }

    /**
     * 重置支付数据
     */
    fun resetPaymentData() {
        _alipayPaymentData.value = null
        _paymentChannels.value = null
        _uiState.value = _uiState.value.copy(currentOrder = null)
    }



    /**
     * 刷新充值产品列表
     */
    fun refreshRechargeProducts() {
        loadRechargeProducts()
    }

    /**
     * 刷新所有数据
     */
    fun refreshAll() {
        loadRechargeProducts()
    }
}

/**
 * 充值页面UI状态
 */
data class RechargeUiState(
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val currentOrder: RechargeOrder? = null
)