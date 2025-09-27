package uno.skkk.oasis.data.repository

import android.util.Log
import uno.skkk.oasis.data.api.ApiService
import uno.skkk.oasis.data.model.WalletData
import uno.skkk.oasis.data.model.WalletResponseData
import uno.skkk.oasis.data.model.AlipayPaymentData
import uno.skkk.oasis.data.model.PaymentChannelsResponse
import uno.skkk.oasis.data.model.RechargeAmount
import uno.skkk.oasis.data.model.RechargeOrder
import uno.skkk.oasis.data.model.RechargeRequest
import uno.skkk.oasis.data.model.Product
import uno.skkk.oasis.data.model.BillSaveRequest
import uno.skkk.oasis.data.model.BillContact
import uno.skkk.oasis.data.model.BillEndpointRef
import uno.skkk.oasis.data.model.BillOwnerRef
import uno.skkk.oasis.data.model.BillProduct
import uno.skkk.oasis.data.TokenManager
import uno.skkk.oasis.data.model.User
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.Result

/**
 * 钱包数据仓库
 */
@Singleton
class WalletRepository @Inject constructor(
    private val apiService: ApiService,
    private val tokenManager: TokenManager
) {
    
    /**
     * 获取钱包余额
     */
    suspend fun getWalletBalance(token: String): Result<WalletData> {
        return try {
            val response = apiService.getWalletBalance(token)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.code == 0 && apiResponse.data != null) {
                    // 从响应数据中提取主要的钱包数据
                    val walletData = apiResponse.data.getPrimaryWalletData()
                    if (walletData != null) {
                        // 添加调试日志
                        Log.d("WalletRepository", "API返回的钱包数据: ${apiResponse.data}")
                        Log.d("WalletRepository", "total=${walletData.total}, olCash=${walletData.olCash}, balance=${walletData.balance}")
                        Log.d("WalletRepository", "显示余额: ${walletData.getDisplayBalance()}")
                        Result.success(walletData)
                    } else {
                        Result.failure(Exception("钱包数据为空"))
                    }
                } else {
                    Result.failure(Exception(apiResponse?.message ?: "获取钱包余额失败"))
                }
            } else {
                val errorMessage = when (response.code()) {
                    401 -> "登录已过期，请重新登录"
                    403 -> "没有权限访问钱包信息"
                    404 -> "钱包信息不存在"
                    500 -> "服务器内部错误"
                    else -> "网络请求失败: ${response.code()}"
                }
                Result.failure(Exception(errorMessage))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 获取充值产品列表（新版本，包含优惠信息）
     */
    suspend fun getRechargeProducts(
        token: String,
        eid: String,
        type: Int = 1,
        status: Int = 1,
        all: Boolean = false,
        did: String = "",
        page: Int = 0,
        size: Int = 100,
        hasCount: Boolean = false
    ): Result<List<Product>> {
        return try {
            val response = apiService.getRechargeProducts(
                token = token,
                eid = eid,
                type = type,
                status = status,
                all = all,
                did = did,
                page = page,
                size = size,
                hasCount = hasCount
            )
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.code == 0 && apiResponse.data != null) {
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception(apiResponse?.message ?: "获取充值产品失败"))
                }
            } else {
                val errorMessage = when (response.code()) {
                    401 -> "登录已过期，请重新登录"
                    403 -> "没有权限访问充值产品"
                    404 -> "充值产品不存在"
                    500 -> "服务器内部错误"
                    else -> "网络请求失败: ${response.code()}"
                }
                Result.failure(Exception(errorMessage))
            }
        } catch (e: Exception) {
            Log.e("WalletRepository", "获取充值产品异常", e)
            Result.failure(e)
        }
    }

    /**
     * 获取充值档位（已弃用，保留兼容性）
     */
    @Deprecated("使用 getRechargeProducts 替代")
    suspend fun getRechargeAmounts(token: String): Result<List<RechargeAmount>> {
        return try {
            val response = apiService.getRechargeAmounts(token)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.code == 0 && apiResponse.data != null) {
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception(apiResponse?.message ?: "获取充值金额列表失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 创建充值订单
     */
    suspend fun createRechargeOrder(
        productId: String,
        count: Int = 1
    ): Result<RechargeOrder> = withContext(Dispatchers.IO) {
        try {
            val token = tokenManager.getToken()
            val user = tokenManager.getSavedUser()
            
            if (token.isNullOrEmpty() || user == null) {
                return@withContext Result.failure(Exception("用户未登录"))
            }

            val request = BillSaveRequest(
                cata = 1, // 充值订单分类
                contact = BillContact(
                    id = user.userId
                ),
                ep = BillEndpointRef(
                    id = user.eid ?: "fd94e5502003000"
                ),
                note = "充值订单",
                owner = BillOwnerRef(
                    id = user.userId
                ),
                prds = listOf(
                    BillProduct(
                        count = count,
                        id = productId
                    )
                )
            )
            
            val response = apiService.createRechargeOrder(token, request)
            
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                    // API返回的是订单ID字符串，我们需要创建RechargeOrder对象
                    val rechargeOrder = RechargeOrder(
                        id = apiResponse.data,
                        amount = 0.0, // 这里需要根据产品信息计算金额
                        status = "pending",
                        createTime = System.currentTimeMillis().toString()
                    )
                    Result.success(rechargeOrder)
                } else {
                    Result.failure(Exception(apiResponse?.message ?: "创建充值订单失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 获取支付渠道
     */
    suspend fun getPaymentChannels(token: String, id: String): Result<PaymentChannelsResponse> {
        return try {
            val response = apiService.getPaymentChannels(token, id)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.code == 0 && apiResponse.data != null) {
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception(apiResponse?.message ?: "获取支付渠道失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 发起支付宝支付
     */
    suspend fun initiateAlipayPayment(token: String, id: String): Result<AlipayPaymentData> {
        return try {
            val response = apiService.initiateAlipayPayment(token, id)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.code == 0 && apiResponse.data != null) {
                    // API返回的data字段包含支付宝SDK调用字符串
                    val paymentData = AlipayPaymentData.fromApiResponse(apiResponse.data)
                    Result.success(paymentData)
                } else {
                    Result.failure(Exception(apiResponse?.message ?: "获取支付宝支付参数失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
