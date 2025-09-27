package uno.skkk.oasis.data.model

/**
 * 通用UI状态封�?
 */
sealed class UiState<out T> {
    object Loading : UiState<Nothing>()
    data class Success<T>(val data: T) : UiState<T>()
    data class Error(val exception: Throwable) : UiState<Nothing>()
    object Idle : UiState<Nothing>()
}

/**
 * 登录页面状�?
 */
data class LoginUiState(
    val phoneNumber: String = "",
    val captcha: String = "",
    val smsCode: String = "",
    val isLoading: Boolean = false,
    val isCodeSending: Boolean = false,
    val countdown: Int = 0,
    val errorMessage: String? = null,
    val captchaUrl: String = ""
) {
    val isPhoneValid: Boolean
        get() = phoneNumber.length == 11 && phoneNumber.all { it.isDigit() }
    
    val isCaptchaValid: Boolean
        get() = captcha.isNotEmpty()
    
    val isSmsCodeValid: Boolean
        get() = smsCode.length == 6 && smsCode.all { it.isDigit() }
    
    val canGetCode: Boolean
        get() = isPhoneValid && isCaptchaValid && countdown == 0 && !isCodeSending
    
    val canLogin: Boolean
        get() = isPhoneValid && isCaptchaValid && isSmsCodeValid && !isLoading
}
