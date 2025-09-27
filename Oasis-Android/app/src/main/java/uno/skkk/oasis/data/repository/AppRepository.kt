package uno.skkk.oasis.data.repository

import android.content.Context
import android.content.SharedPreferences
import uno.skkk.oasis.data.api.ApiService
import uno.skkk.oasis.data.api.NetworkConfig
import uno.skkk.oasis.data.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * 应用数据仓库
 */
class AppRepository private constructor(context: Context) {
    
    companion object {
        @Volatile
        private var INSTANCE: AppRepository? = null
        
        fun getInstance(context: Context? = null): AppRepository {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AppRepository(context!!).also { INSTANCE = it }
            }
        }
        
        private const val PREFS_NAME = "app_prefs"
        private const val KEY_TOKEN = "token"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_USERNAME = "username"
        private const val KEY_PHONE = "phone"
        private const val KEY_AVATAR_URL = "avatar_url"
        private const val KEY_EID = "eid"
    }
    
    private val apiService = NetworkConfig.apiService
    private val sharedPreferences: SharedPreferences = context.getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
    
    /**
     * 获取图形验证码
     */
    suspend fun getCaptcha(s: Int, r: Int): Result<ByteArray> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.getCaptcha(s, r)
            if (response.isSuccessful && response.body() != null) {
                val responseBody = response.body()!!
                val bytes = responseBody.bytes()
                android.util.Log.d("AppRepository", "验证码响应成功，数据大小: ${bytes.size} bytes")
                Result.success(bytes)
            } else {
                android.util.Log.e("AppRepository", "验证码响应失败: ${response.code()}")
                Result.failure(Exception("获取验证码失败: HTTP ${response.code()}"))
            }
        } catch (e: Exception) {
            android.util.Log.e("AppRepository", "验证码获取异�? ${e.message}")
            Result.failure(e)
        }
    }
    
    /**
     * 获取短信验证�?
     */
    suspend fun getSmsCode(request: GetCodeRequest): Result<String> = withContext(Dispatchers.IO) {
        try {
            android.util.Log.d("AppRepository", "发送短信验证码请求: s=${request.s}, authCode=${request.authCode}, phoneNumber=${request.phoneNumber}")
            val response = apiService.getSmsCode(request)
            android.util.Log.d("AppRepository", "短信验证码响应状�? ${response.code()}")
            
            if (response.isSuccessful) {
                val apiResponse = response.body()
                android.util.Log.d("AppRepository", "短信验证码响应内�? $apiResponse")
                
                if (apiResponse?.isSuccess() == true) {
                    android.util.Log.d("AppRepository", "短信验证码发送成功")
                    Result.success("验证码已发送")
                } else {
                    val errorCode = apiResponse?.code
                    android.util.Log.e("AppRepository", "短信验证码发送失败，错误码: $errorCode, 消息: ${apiResponse?.message}")
                    val errorMsg = when (errorCode) {
                        -2 -> "图形验证码错误"
                        -1 -> "参数错误"
                        -3 -> "手机号格式错误"
                        -4 -> "发送频率过快"
                        else -> "发送失败，请重试(错误码: $errorCode)"
                    }
                    Result.failure(Exception(errorMsg))
                }
            } else {
                android.util.Log.e("AppRepository", "短信验证码网络请求失�? HTTP ${response.code()}")
                Result.failure(Exception("网络请求失败: HTTP ${response.code()}"))
            }
        } catch (e: Exception) {
            android.util.Log.e("AppRepository", "短信验证码请求异�? ${e.message}")
            Result.failure(e)
        }
    }
    
    /**
     * 用户登录
     */
    suspend fun login(request: LoginRequest): Result<User> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.login(request)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                    val loginData = apiResponse.data
                    val authData = loginData.al
                    val user = User(
                        token = authData.token,
                        userId = authData.uid,
                        username = request.phoneNumber, // 使用手机号作为用户名
                        phoneNumber = request.phoneNumber,
                        eid = authData.eid // 保存企业ID
                    )
                    saveUser(user)
                    
                    // 登录成功后获取用户信息（包括头像和昵称）
                    try {
                        val userInfoResult = getUserInfo()
                        if (userInfoResult.isSuccess) {
                            android.util.Log.d("AppRepository", "用户信息获取成功")
                        } else {
                            android.util.Log.w("AppRepository", "获取用户信息失败: ${userInfoResult.exceptionOrNull()?.message}")
                        }
                    } catch (e: Exception) {
                        // 获取用户信息失败不影响登录成功
                        android.util.Log.w("AppRepository", "获取用户信息异常: ${e.message}")
                    }
                    
                    Result.success(user)
                } else {
                    val errorMsg = when (apiResponse?.code) {
                        -2 -> "验证码错误"
                        else -> "登录失败，请重试"
                    }
                    Result.failure(Exception(errorMsg))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 获取设备列表
     */
    suspend fun getDeviceList(): Result<DeviceListData> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            val response = apiService.getDeviceList(token)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception("获取设备列表失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 获取用户信息和设备列表（完整的Master响应）
     */
    suspend fun getUserInfo(): Result<MasterResponseData> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            val response = apiService.getMasterData(token)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                    val account = apiResponse.data.account
                    
                    // 添加调试日志
                    android.util.Log.d("AppRepository", "获取到的用户信息 - 昵称: ${account.name}, 头像: ${account.avatarUrl}")
                    
                    // 保存用户头像URL
                    val avatarUrl = account.avatarUrl
                    if (!avatarUrl.isNullOrEmpty()) {
                        saveUserAvatarUrl(avatarUrl)
                        android.util.Log.d("AppRepository", "已保存用户头像URL: $avatarUrl")
                    }
                    
                    // 保存用户昵称
                    val userName = account.name
                    if (!userName.isNullOrEmpty()) {
                        saveUserName(userName)
                        android.util.Log.d("AppRepository", "已保存用户昵称: $userName")
                    }
                    
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception("获取用户信息失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 保存用户头像URL
     */
    private fun saveUserAvatarUrl(avatarUrl: String) {
        android.util.Log.d("AppRepository", "保存头像URL到SharedPreferences: $avatarUrl")
        sharedPreferences.edit()
            .putString(KEY_AVATAR_URL, avatarUrl)
            .apply()
        android.util.Log.d("AppRepository", "头像URL保存完成")
    }
    
    /**
     * 保存用户昵称
     */
    private fun saveUserName(userName: String) {
        sharedPreferences.edit()
            .putString(KEY_USERNAME, userName)
            .apply()
    }

    /**
     * 检查设备状�?
     */
    suspend fun checkDeviceStatus(deviceIds: List<String>): Result<DeviceStatusData> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            val idsString = deviceIds.joinToString(",")
            val response = apiService.checkDeviceStatus(token, idsString)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception("检查设备状态失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 获取单个设备状态（与web实现一致）
     */
    suspend fun getSingleDeviceStatus(deviceId: String): Result<SingleDeviceStatusData> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            val response = apiService.getSingleDeviceStatus(token, deviceId)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception("获取设备状态失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 启动设备
     */
    suspend fun startDevice(deviceId: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            val response = apiService.startDevice(token, deviceId)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true) {
                    Result.success("设备启动成功")
                } else {
                    Result.failure(Exception("设备启动失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 停止设备
     */
    suspend fun stopDevice(deviceId: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            val response = apiService.stopDevice(token, deviceId)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true) {
                    Result.success("设备停止成功")
                } else {
                    Result.failure(Exception("设备停止失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 添加设备（绑定设备）
     */
    suspend fun addDevice(deviceId: String, deviceName: String? = null, deviceType: String? = null): Result<Device> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            // 使用收藏设备API来添加设备
            val response = apiService.manageFavoriteDevice(token, deviceId, 0) // 0为添加
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true) {
                    // 创建一个Device对象返回
                    val device = Device(
                        id = deviceId,
                        name = deviceName ?: "设备$deviceId",
                        status = 0, // 默认状�?
                        btype = 0, // 默认类型
                        ltime = System.currentTimeMillis()
                    )
                    Result.success(device)
                } else {
                    val errorMsg = when (apiResponse?.code) {
                        -1 -> "设备ID格式错误"
                        -2 -> "设备已被绑定"
                        -3 -> "设备不存在"
                        -4 -> "绑定失败，请重试"
                        1 -> "参数错误"
                        2 -> "设备ID不能为空"
                        3 -> "设备ID已存在"
                        else -> apiResponse?.message ?: "添加设备失败，请重试"
                    }
                    Result.failure(Exception(errorMsg))
                }
            } else {
                val errorMsg = when (response.code()) {
                    400 -> "请求参数错误"
                    401 -> "用户未登录或登录已过期"
                    403 -> "没有权限执行此操作"
                    404 -> "设备不存在"
                    500 -> "服务器内部错误"
                    else -> "网络请求失败 (${response.code()})"
                }
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 智能设备控制（与web实现的startOrEnd功能一致）
     * 先查询设备状态，然后根据状态决定启动或停止
     */
    suspend fun startOrEndDevice(deviceId: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            // 首先获取设备状态
            val statusResult = getSingleDeviceStatus(deviceId)
            if (statusResult.isFailure) {
                return@withContext Result.failure(statusResult.exceptionOrNull() ?: Exception("获取设备状态失败"))
            }
            
            val deviceStatus = statusResult.getOrNull()
            if (deviceStatus == null) {
                return@withContext Result.failure(Exception("设备状态数据为空"))
            }
            
            // 根据设备状态决定操作
            val result = if (deviceStatus.status == 1) {
                // 设备正在运行，执行停止操作
                stopDevice(deviceId)
            } else {
                // 设备已停止，执行启动操作
                startDevice(deviceId)
            }
            
            result
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 获取设备详情
     */
    suspend fun getDeviceDetail(deviceId: String): Result<Any> = withContext(Dispatchers.IO) {
        try {
            val token = getToken()
            if (token.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("用户未登录"))
            }
            
            val response = apiService.getDeviceDetail(token, deviceId)
            if (response.isSuccessful) {
                val apiResponse = response.body()
                if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                    Result.success(apiResponse.data)
                } else {
                    Result.failure(Exception("获取设备详情失败"))
                }
            } else {
                Result.failure(Exception("网络请求失败"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    /**
     * 保存用户信息
     */
    private fun saveUser(user: User) {
        sharedPreferences.edit().apply {
            putString(KEY_TOKEN, user.token)
            putString(KEY_USER_ID, user.userId)
            putString(KEY_USERNAME, user.username)
            putString(KEY_PHONE, user.phoneNumber)
            // 只在avatarUrl不为空时才保存，避免覆盖已保存的头像URL
            if (!user.avatarUrl.isNullOrEmpty()) {
                putString(KEY_AVATAR_URL, user.avatarUrl)
            }
            // 保存企业ID
            if (!user.eid.isNullOrEmpty()) {
                putString(KEY_EID, user.eid)
            }
            apply()
        }
    }
    
    /**
     * 获取保存的用户信�?
     */
    fun getSavedUser(): User? {
        val token = sharedPreferences.getString(KEY_TOKEN, null)
        val userId = sharedPreferences.getString(KEY_USER_ID, null)
        val username = sharedPreferences.getString(KEY_USERNAME, null)
        val phone = sharedPreferences.getString(KEY_PHONE, null)
        val avatarUrl = sharedPreferences.getString(KEY_AVATAR_URL, null)
        val eid = sharedPreferences.getString(KEY_EID, null)
        
        return if (token != null && userId != null && username != null && phone != null) {
            User(token, userId, username, phone, avatarUrl, eid)
        } else {
            null
        }
    }
    
    /**
     * 获取Token
     */
    private fun getToken(): String? {
        return sharedPreferences.getString(KEY_TOKEN, null)
    }
    
    /**
     * 清除用户信息
     */
    fun clearUser() {
        sharedPreferences.edit().clear().apply()
    }
    
    /**
     * 检查是否已登录
     */
    fun isLoggedIn(): Boolean {
        return !getToken().isNullOrEmpty()
    }
    
    /**
     * 获取用户手机�?
     */
    fun getUserPhone(): String? {
        return sharedPreferences.getString(KEY_PHONE, null)
    }
    
    /**
     * 获取用户头像URL
     */
    fun getUserAvatarUrl(): String? {
        val avatarUrl = sharedPreferences.getString(KEY_AVATAR_URL, null)
        android.util.Log.d("AppRepository", "从SharedPreferences读取头像URL: $avatarUrl")
        return avatarUrl
    }
    
    /**
     * 获取用户昵称
     */
    fun getUserName(): String? {
        return sharedPreferences.getString(KEY_USERNAME, null)
    }
    
    /**
     * 退出登�?
     */
    suspend fun logout() = withContext(Dispatchers.IO) {
        clearUser()
    }
}
