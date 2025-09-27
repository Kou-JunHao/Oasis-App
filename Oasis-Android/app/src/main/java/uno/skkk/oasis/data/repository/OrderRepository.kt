package uno.skkk.oasis.data.repository

import uno.skkk.oasis.data.api.ApiService
import uno.skkk.oasis.data.model.Order
import uno.skkk.oasis.data.model.OrderListResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 订单数据仓库
 */
@Singleton
class OrderRepository @Inject constructor(
    private val apiService: ApiService
) {
    
    /**
     * 获取订单列表
     */
    suspend fun getOrderList(
        token: String,
        page: Int = 0,
        size: Int = 20,
        status: String? = null
    ): Result<List<Order>> {
        return withContext(Dispatchers.IO) {
            try {
                val response = apiService.getOrderList(token, page, size, status)
                if (response.isSuccessful) {
                    val orderResponse = response.body()
                    if (orderResponse?.isSuccess() == true) {
                        // API直接返回订单列表数组
                        val orders = orderResponse.data ?: emptyList()
                        android.util.Log.d("OrderRepository", "获取到${orders.size}条订单")
                        Result.success(orders)
                    } else {
                        android.util.Log.e("OrderRepository", "订单查询失败: code=${orderResponse?.code}")
                        Result.failure(Exception("获取订单列表失败"))
                    }
                } else {
                    val errorMsg = when (response.code()) {
                        400 -> "请求参数错误"
                        401 -> "用户未登录或登录已过期"
                        403 -> "没有权限执行此操作"
                        404 -> "订单信息不存在"
                        500 -> "服务器内部错误"
                        else -> "网络请求失败 (${response.code()})"
                    }
                    Result.failure(Exception(errorMsg))
                }
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }
    
    /**
     * 获取所有订单
     */
    suspend fun getAllOrders(token: String): Result<List<Order>> {
        return withContext(Dispatchers.IO) {
            try {
                getOrderList(token, 0, 100) // 获取100条订单，page从0开始
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }
    
    /**
     * 根据状态获取订单
     */
    suspend fun getOrdersByStatus(token: String, status: String): Result<List<Order>> {
        return withContext(Dispatchers.IO) {
            try {
                getOrderList(token, 0, 100, status) // page从0开始
            } catch (e: Exception) {
                Result.failure(e)
            }
        }
    }
}
