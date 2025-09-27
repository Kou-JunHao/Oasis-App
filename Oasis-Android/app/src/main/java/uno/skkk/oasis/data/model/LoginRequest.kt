package uno.skkk.oasis.data.model

import com.google.gson.annotations.SerializedName

/**
 * 获取验证码请求模�?
 */
data class GetCodeRequest(
    @SerializedName("s")
    val s: Int,
    
    @SerializedName("authCode")
    val authCode: String,
    
    @SerializedName("un")
    val phoneNumber: String
)

/**
 * 登录请求模型
 */
data class LoginRequest(
    @SerializedName("openCode")
    val openCode: String = "",
    
    @SerializedName("un")
    val phoneNumber: String,
    
    @SerializedName("authCode")
    val smsCode: String,
    
    @SerializedName("cid")
    val cid: String = ""
)

/**
 * 用户信息模型
 */
data class User(
    val token: String,
    val userId: String,
    val username: String,
    val phoneNumber: String,
    val avatarUrl: String? = null,
    val eid: String? = null // 企业ID，用于获取充值产品
)
