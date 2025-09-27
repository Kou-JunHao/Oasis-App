package uno.skkk.oasis.ui.login

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import uno.skkk.oasis.data.model.LoginUiState
import uno.skkk.oasis.data.repository.AppRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.launch

class LoginViewModel(application: Application) : AndroidViewModel(application) {
    
    private val repository = AppRepository.getInstance(application)
    
    // UI状态
    private val _phoneNumber = MutableStateFlow("")
    private val _captcha = MutableStateFlow("")
    private val _smsCode = MutableStateFlow("")
    private val _isLoading = MutableStateFlow(false)
    private val _isCodeSending = MutableStateFlow(false)
    private val _countdown = MutableStateFlow(0)
    
    // 验证码图片数据
    private val _captchaData = MutableStateFlow<ByteArray?>(null)
    val captchaData: StateFlow<ByteArray?> = _captchaData.asStateFlow()
    
    // 登录成功事件
    private val _loginSuccess = MutableStateFlow(false)
    val loginSuccess: StateFlow<Boolean> = _loginSuccess.asStateFlow()
    
    // 消息事件
    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()
    
    // 倒计时开始事件
    private val _startCountdown = MutableStateFlow(false)
    val startCountdown: StateFlow<Boolean> = _startCountdown.asStateFlow()
    
    // 组合UI状态
    val uiState: StateFlow<LoginUiState> = combine(
        _phoneNumber,
        _captcha,
        _smsCode,
        _isLoading,
        _isCodeSending,
        _countdown
    ) { flows ->
        val phoneNumber = flows[0] as String
        val captcha = flows[1] as String
        val smsCode = flows[2] as String
        val isLoading = flows[3] as Boolean
        val isCodeSending = flows[4] as Boolean
        val countdown = flows[5] as Int
        
        LoginUiState(
            phoneNumber = phoneNumber,
            captcha = captcha,
            smsCode = smsCode,
            isLoading = isLoading,
            isCodeSending = isCodeSending,
            countdown = countdown
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = LoginUiState()
    )
    
    fun updatePhoneNumber(phoneNumber: String) {
        _phoneNumber.value = phoneNumber
    }
    
    fun updateCaptcha(captcha: String) {
        _captcha.value = captcha
    }
    
    fun updateSmsCode(smsCode: String) {
        _smsCode.value = smsCode
    }
    
    fun updateCountdown(countdown: Int) {
        _countdown.value = countdown
    }
    

    
    fun loadCaptcha() {
        viewModelScope.launch {
            try {
                // 使用与Web版本一致的参数：随机数s和时间戳r
                val s = 500 // 转换为整数便于传输
                val r = System.currentTimeMillis().toInt() // 当前时间戳
                val result = repository.getCaptcha(s, r)
                result.onSuccess { data ->
                    android.util.Log.d("LoginViewModel", "验证码获取成功，数据大小: ${data.size} bytes")
                    _captchaData.value = data
                }.onFailure { error ->
                    android.util.Log.e("LoginViewModel", "验证码获取失败: ${error.message}")
                    _message.value = "获取验证码失败: ${error.message}"
                }
            } catch (e: Exception) {
                _message.value = "获取验证码失败: ${e.message}"
            }
        }
    }
    
    fun getSmsCode() {
        if (_isCodeSending.value) return
        
        viewModelScope.launch {
            _isCodeSending.value = true
            try {
                val s = 500  // 使用固定500，与抓包数据一致
                val authCode = _captcha.value
                val phoneNumber = _phoneNumber.value
                
                android.util.Log.d("LoginViewModel", "准备获取短信验证码")
                android.util.Log.d("LoginViewModel", "参数 - s: $s, authCode: $authCode, phoneNumber: $phoneNumber")
                
                if (authCode.isEmpty()) {
                    android.util.Log.e("LoginViewModel", "图形验证码为空")
                    _message.value = "请先获取图形验证码"
                    _isCodeSending.value = false
                    return@launch
                }
                
                if (phoneNumber.isEmpty()) {
                    android.util.Log.e("LoginViewModel", "手机号为空")
                    _message.value = "请输入手机号"
                    _isCodeSending.value = false
                    return@launch
                }
                
                val request = uno.skkk.oasis.data.model.GetCodeRequest(
                    s = s, // 使用与Web版本一致的随机数
                    authCode = authCode,
                    phoneNumber = phoneNumber
                )
                
                android.util.Log.d("LoginViewModel", "发送短信验证码请求: $request")
                val result = repository.getSmsCode(request)
                result.onSuccess {
                    android.util.Log.d("LoginViewModel", "短信验证码获取成功")
                    _message.value = "验证码已发送"
                    _startCountdown.value = true
                    _startCountdown.value = false // 重置事件
                }.onFailure { error ->
                    android.util.Log.e("LoginViewModel", "短信验证码获取失败: ${error.message}")
                    _message.value = "发送验证码失败: ${error.message}"
                }
            } catch (e: Exception) {
                android.util.Log.e("LoginViewModel", "短信验证码获取异常: ${e.message}")
                _message.value = "发送验证码失败: ${e.message}"
            } finally {
                _isCodeSending.value = false
            }
        }
    }
    
    fun login() {
        if (_isLoading.value) return
        
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val request = uno.skkk.oasis.data.model.LoginRequest(
                    phoneNumber = _phoneNumber.value,
                    smsCode = _smsCode.value
                )
                val result = repository.login(request)
                result.onSuccess { loginData ->
                    _message.value = "登录成功"
                    _loginSuccess.value = true
                }.onFailure { error ->
                    _message.value = "登录失败: ${error.message}"
                }
            } catch (e: Exception) {
                _message.value = "登录失败: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }
}
