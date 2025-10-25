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
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.data.model.WalletInfo
import uno.skkk.oasis.data.repository.WalletRepository
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.data.TokenManager
import javax.inject.Inject
import kotlin.Result

@HiltViewModel
class RechargeViewModel @Inject constructor(
    private val walletRepository: WalletRepository,
    private val appRepository: AppRepository,
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

    private val _deviceList = MutableStateFlow<List<Device>>(emptyList())
    val deviceList: StateFlow<List<Device>> = _deviceList.asStateFlow()

    private val _walletList = MutableStateFlow<List<WalletInfo>>(emptyList())
    val walletList: StateFlow<List<WalletInfo>> = _walletList.asStateFlow()

    init {
        loadRechargeProducts()
        loadDeviceList()
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

            walletRepository.createRechargeOrder(productId, count, "").fold(
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
     * 加载设备列表
     */
    fun loadDeviceList() {
        viewModelScope.launch {
            val token = tokenManager.getToken()
            if (token.isNullOrEmpty()) {
                Log.e("RechargeViewModel", "Token为空，无法加载设备列表")
                return@launch
            }

            try {
                val result = appRepository.getDeviceList()
                result.fold(
                    onSuccess = { deviceListData ->
                        _deviceList.value = deviceListData.devices
                        // 从设备列表中提取钱包信息
                        extractWalletsFromDevices(deviceListData.devices)
                        Log.d("RechargeViewModel", "设备列表加载成功，设备数量: ${deviceListData.devices.size}")
                    },
                    onFailure = { exception ->
                        Log.e("RechargeViewModel", "设备列表加载失败", exception)
                        _deviceList.value = emptyList()
                        _walletList.value = emptyList()
                    }
                )
            } catch (e: Exception) {
                Log.e("RechargeViewModel", "设备列表加载异常", e)
                _deviceList.value = emptyList()
                _walletList.value = emptyList()
            }
        }
    }

    /**
     * 从设备列表中提取钱包信息并去重
     */
    private fun extractWalletsFromDevices(devices: List<Device>) {
        val walletMap = mutableMapOf<String, WalletInfo>()
        
        devices.forEach { device ->
            device.ep?.let { endpoint ->
                val walletId = endpoint.id
                val walletName = endpoint.name ?: "未知钱包"
                
                if (walletId.isNotEmpty()) {
                    if (walletMap.containsKey(walletId)) {
                        // 如果钱包已存在，增加设备计数
                        val existingWallet = walletMap[walletId]!!
                        walletMap[walletId] = existingWallet.copy(
                            deviceCount = existingWallet.deviceCount + 1
                        )
                    } else {
                        // 新钱包
                        walletMap[walletId] = WalletInfo(
                            id = walletId,
                            name = walletName,
                            deviceCount = 1,
                            balance = 0.0 // 初始余额为0，后续通过API获取
                        )
                    }
                }
            }
        }
        
        val walletList = walletMap.values.toList()
        
        // 为每个钱包获取余额
        loadWalletBalances(walletList)
        
        Log.d("RechargeViewModel", "提取到 ${walletList.size} 个不同的钱包")
        walletList.forEach { wallet ->
            Log.d("RechargeViewModel", "钱包: ${wallet.name} (ID: ${wallet.id}), 设备数量: ${wallet.deviceCount}")
        }
    }
    
    /**
     * 为钱包列表加载余额信息
     */
    private fun loadWalletBalances(wallets: List<WalletInfo>) {
        viewModelScope.launch {
            val token = tokenManager.getToken()
            if (token.isNullOrEmpty()) {
                // 如果没有token，直接设置钱包列表（余额为0）
                _walletList.value = wallets
                return@launch
            }
            
            try {
                // 获取完整的钱包响应数据
                val result = walletRepository.getWalletResponseData(token)
                result.fold(
                    onSuccess = { walletResponseData ->
                        val epsWalletData = walletResponseData.eps ?: emptyList()
                        
                        Log.d("RechargeViewModel", "获取到钱包数据: ${epsWalletData.size} 个钱包")
                        
                        // 更新钱包余额，根据ep.id匹配对应的钱包数据
                        val updatedWallets = wallets.map { wallet ->
                            // 在eps数组中查找匹配的钱包数据
                            val matchingWalletData = epsWalletData.find { walletData ->
                                walletData.ep?.id == wallet.id
                            }
                            
                            val balance = matchingWalletData?.getDisplayBalance() ?: 0.0
                            Log.d("RechargeViewModel", "钱包 ${wallet.id} (${wallet.name}) 余额: $balance")
                            
                            wallet.copy(balance = balance)
                        }
                        
                        _walletList.value = updatedWallets
                        Log.d("RechargeViewModel", "钱包余额更新完成")
                    },
                    onFailure = { exception ->
                        Log.e("RechargeViewModel", "获取钱包数据失败: ${exception.message}")
                        // 失败时将所有钱包余额设为0
                        _walletList.value = wallets
                    }
                )
            } catch (e: Exception) {
                Log.e("RechargeViewModel", "钱包余额加载异常", e)
                // 异常时将所有钱包余额设为0
                _walletList.value = wallets
            }
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
    fun oneClickRecharge(productId: String, count: Int = 1, walletId: String) {
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
                Log.d("RechargeViewModel", "开始创建充值订单，产品ID: $productId, 钱包ID: $walletId")
                val orderResult = walletRepository.createRechargeOrder(productId, count, walletId)
                
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