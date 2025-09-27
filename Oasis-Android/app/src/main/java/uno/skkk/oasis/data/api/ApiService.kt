package uno.skkk.oasis.data.api

import uno.skkk.oasis.data.model.*
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.*

/**
 * API服务接口
 */
interface ApiService {
    
    /**
     * 获取图形验证�?
     */
    @GET("api/v1/captcha/")
    suspend fun getCaptcha(
        @Query("s") s: Int,
        @Query("r") r: Int
    ): Response<ResponseBody>
    
    /**
     * 获取短信验证�?
     */
    @Headers(
        "Content-Type: application/json",
        "Connection: keep-alive",
        "applicationtype: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @POST("api/v1/acc/login/code")
    suspend fun getSmsCode(
        @Body request: GetCodeRequest
    ): Response<ApiResponse<Any>>
    
    /**
     * 用户登录
     */
    @Headers(
        "Content-Type: application/json",
        "Connection: keep-alive",
        "applicationtype: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @POST("api/v1/acc/login")
    suspend fun login(
        @Body request: LoginRequest
    ): Response<ApiResponse<LoginData>>
    
    /**
     * 获取设备列表
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/ui/app/master")
    suspend fun getDeviceList(
        @Header("authorization") token: String
    ): Response<ApiResponse<DeviceListData>>
    
    /**
     * 获取完整的Master响应（包含用户信息和设备列表）
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/ui/app/master")
    suspend fun getMasterData(
        @Header("authorization") token: String
    ): Response<ApiResponse<MasterResponseData>>
    
    /**
     * 启动设备
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/dev/start")
    suspend fun startDevice(
        @Header("authorization") token: String,
        @Query("did") deviceId: String,
        @Query("upgrade") upgrade: Boolean = true,
        @Query("ptype") ptype: Int = 91,
        @Query("rcp") rcp: Boolean = false
    ): Response<ApiResponse<Any>>
    
    /**
     * 停止设备
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/dev/end")
    suspend fun stopDevice(
        @Header("authorization") token: String,
        @Query("did") deviceId: String
    ): Response<ApiResponse<Any>>
    
    /**
     * 添加设备（绑定设备）
     */
    @Headers(
        "Content-Type: application/json",
        "Connection: keep-alive",
        "applicationtype: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @POST("api/v1/dev/bind")
    suspend fun addDevice(
        @Header("authorization") token: String,
        @Body request: AddDeviceRequest
    ): Response<ApiResponse<AddDeviceResponse>>
    
    /**
     * 检查设备状�?
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/ui/app/dev/status")
    suspend fun checkDeviceStatus(
        @Header("authorization") token: String,
        @Query("ids") deviceIds: String // 设备ID列表，逗号分隔
    ): Response<ApiResponse<DeviceStatusData>>
    
    /**
     * 获取单个设备状态（与web实现一致）
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/ui/app/dev/status")
    suspend fun getSingleDeviceStatus(
        @Header("authorization") token: String,
        @Query("did") deviceId: String,
        @Query("more") more: Boolean = false,
        @Query("promo") promo: Boolean = false
    ): Response<ApiResponse<SingleDeviceStatusData>>
    
    /**
     * 获取设备详情
     */
    @GET("api/v1/ui/app/dev/home/1")
    suspend fun getDeviceDetail(
        @Header("authorization") token: String,
        @Query("did") deviceId: String,
        @Query("apply") apply: Int = 6
    ): Response<ApiResponse<Any>>
    
    /**
     * 获取钱包余额
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/acc/wallet/owner")
    suspend fun getWalletBalance(
        @Header("authorization") token: String
    ): Response<ApiResponse<WalletResponseData>>
    
    /**
     * 获取订单列表
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/bill/lst-owner")
    suspend fun getOrderList(
        @Header("authorization") token: String,
        @Query("page") page: Int = 0,
        @Query("size") size: Int = 20,
        @Query("status") status: String? = null // 订单状态过滤
    ): Response<OrderListResponse>
    
    /**
     * 设备收藏管理
     */
    @Headers(
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Encoding: gzip",
        "applicationtype: 1,1",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/dev/favo")
    suspend fun manageFavoriteDevice(
        @Header("authorization") token: String,
        @Query("did") deviceId: String,
        @Query("remove") remove: Int // 0为添加，1为删除
    ): Response<ApiResponse<Any>>
    
    /**
     * 获取充值金额列表（旧版本，保留兼容性）
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/trans/recharge/amounts")
    suspend fun getRechargeAmounts(
        @Header("authorization") token: String
    ): Response<ApiResponse<List<RechargeAmount>>>
    
    /**
     * 获取充值产品列表（新版本，支持优惠信息）
     */
    @Headers(
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Encoding: gzip",
        "applicationtype: 1,1",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/prd/lst")
    suspend fun getRechargeProducts(
        @Header("authorization") token: String,
        @Query("eid") eid: String,
        @Query("type") type: Int = 1,
        @Query("status") status: Int = 1,
        @Query("all") all: Boolean = false,
        @Query("did") did: String = "",
        @Query("page") page: Int = 0,
        @Query("size") size: Int = 100,
        @Query("hasCount") hasCount: Boolean = false
    ): Response<ApiResponse<List<Product>>>
    
    /**
     * 创建充值订单
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @POST("api/v1/bill/save")
    suspend fun createRechargeOrder(
        @Header("authorization") token: String,
        @Body request: BillSaveRequest
    ): Response<ApiResponse<String>>
    
    /**
     * 获取支付渠道
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/bill/pay/channels")
    suspend fun getPaymentChannels(
        @Header("authorization") token: String,
        @Query("id") orderId: String
    ): Response<ApiResponse<PaymentChannelsResponse>>
    
    /**
     * 发起支付宝支付
     * 注意：此API返回的是字符串，不是JSON对象
     */
    @Headers(
        "Connection: keep-alive",
        "ApplicationType: 1,1",
        "Accept: */*",
        "User-Agent: Android_ilife798_2.0.11",
        "Accept-Language: zh-TW,zh-Hant;q=0.9",
        "Accept-Encoding: gzip, deflate, br",
        "versioncode: 2.0.11"
    )
    @GET("api/v1/trans/prepay/21")
    suspend fun initiateAlipayPayment(
        @Header("Authorization") token: String,
        @Query("id") id: String
    ): Response<ApiResponse<String>>
}
