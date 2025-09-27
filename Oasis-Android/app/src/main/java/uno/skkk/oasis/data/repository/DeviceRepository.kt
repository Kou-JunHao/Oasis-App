package uno.skkk.oasis.data.repository

import uno.skkk.oasis.data.api.ApiService
import uno.skkk.oasis.data.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 设备数据仓库
 */
@Singleton
class DeviceRepository @Inject constructor(
    private val apiService: ApiService
) {
    
    /**
     * 获取设备列表
     */
    suspend fun getDeviceList(token: String): Result<List<Device>> {
        return withContext(Dispatchers.IO) {
            try {
                val response = apiService.getDeviceList(token)
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true) {
                        Result.success(apiResponse.data?.devices ?: emptyList())
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "获取设备列表失败"))
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
    }
    
    /**
     * 启动设备
     */
    suspend fun startDevice(token: String, deviceId: String): Result<String> {
        return withContext(Dispatchers.IO) {
            try {
                val response = apiService.startDevice(token, deviceId)
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true) {
                        Result.success("设备启动成功")
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "启动设备失败"))
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
    }
    
    /**
     * 停止设备
     */
    suspend fun stopDevice(token: String, deviceId: String): Result<String> {
        return withContext(Dispatchers.IO) {
            try {
                val response = apiService.stopDevice(token, deviceId)
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true) {
                        Result.success("设备停止成功")
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "停止设备失败"))
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
    }
    
    /**
     * 检查设备状态
     */
    suspend fun checkDeviceStatus(token: String, deviceIds: List<String>): Result<List<DeviceStatus>> {
        return withContext(Dispatchers.IO) {
            try {
                val idsString = deviceIds.joinToString(",")
                val response = apiService.checkDeviceStatus(token, idsString)
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true) {
                        Result.success(apiResponse.data?.statusList ?: emptyList())
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "获取设备状态失败"))
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
    }
    
    /**
     * 获取单个设备状态
     */
    suspend fun getSingleDeviceStatus(token: String, deviceId: String): Result<SingleDeviceStatusData> {
        return withContext(Dispatchers.IO) {
            try {
                val response = apiService.getSingleDeviceStatus(token, deviceId)
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true && apiResponse.data != null) {
                        Result.success(apiResponse.data)
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "获取设备状态失败"))
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
    }
    
    /**
     * 添加设备到收藏
     */
    suspend fun addFavoriteDevice(token: String, deviceId: String): Result<Unit> {
        return withContext(Dispatchers.IO) {
            try {
                val response = apiService.manageFavoriteDevice(token, deviceId, 0) // 0为添加
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true) {
                        Result.success(Unit)
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "添加收藏失败"))
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
    }
    
    /**
     * 从收藏中移除设备
     */
    suspend fun removeFavoriteDevice(token: String, deviceId: String): Result<Unit> {
        return withContext(Dispatchers.IO) {
            try {
                val response = apiService.manageFavoriteDevice(token, deviceId, 1) // 1为删除
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true) {
                        Result.success(Unit)
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "移除收藏失败"))
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
    }
    
    /**
     * 添加新设备
     */
    suspend fun addDevice(token: String, deviceId: String, deviceName: String? = null): Result<Device> {
        return withContext(Dispatchers.IO) {
            try {
                // 使用收藏设备API来添加设备
                val response = apiService.manageFavoriteDevice(token, deviceId, 0) // 0为添加
                if (response.isSuccessful) {
                    val apiResponse = response.body()
                    if (apiResponse?.isSuccess() == true) {
                        // 创建一个Device对象返回
                        val device = Device(
                            id = deviceId,
                            name = deviceName ?: "设备$deviceId",
                            status = 0, // 默认状态
                            btype = 0, // 默认类型
                            ltime = System.currentTimeMillis()
                        )
                        Result.success(device)
                    } else {
                        Result.failure(Exception(apiResponse?.message ?: "添加设备失败"))
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
    }
}
