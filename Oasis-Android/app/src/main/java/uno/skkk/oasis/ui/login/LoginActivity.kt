package uno.skkk.oasis.ui.login

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.os.CountDownTimer
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.animation.AnimationUtils
import android.widget.Toast
import androidx.activity.viewModels
import androidx.lifecycle.lifecycleScope
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.ActivityLoginBinding
import uno.skkk.oasis.ui.base.BaseActivity
import uno.skkk.oasis.ui.main.MainNavigationActivity
import kotlinx.coroutines.launch

class LoginActivity : BaseActivity() {
    
    private lateinit var binding: ActivityLoginBinding
    private val viewModel: LoginViewModel by viewModels()
    private var countDownTimer: CountDownTimer? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupUI()
        observeViewModel()
        loadCaptcha()
        startEntranceAnimation()
    }
    
    private fun setupUI() {
        // 设置文本监听�?
        binding.etPhone.addTextChangedListener(createTextWatcher { text ->
            viewModel.updatePhoneNumber(text)
        })
        
        binding.etCaptcha.addTextChangedListener(createTextWatcher { text ->
            viewModel.updateCaptcha(text)
        })
        
        binding.etSmsCode.addTextChangedListener(createTextWatcher { text ->
            viewModel.updateSmsCode(text)
        })
        
        // 设置点击监听�?
        binding.ivCaptcha.setOnClickListener {
            // 添加验证码刷新动�?
            val refreshAnimation = AnimationUtils.loadAnimation(this, R.anim.captcha_refresh)
            binding.ivCaptcha.startAnimation(refreshAnimation)
            loadCaptcha()
        }
        
        binding.btnGetCode.setOnClickListener {
            // 添加按钮点击动画
            val bounceAnimation = AnimationUtils.loadAnimation(this, R.anim.button_bounce)
            binding.btnGetCode.startAnimation(bounceAnimation)
            viewModel.getSmsCode()
        }
        
        binding.btnLogin.setOnClickListener {
            // 添加按钮点击动画
            val bounceAnimation = AnimationUtils.loadAnimation(this, R.anim.button_bounce)
            binding.btnLogin.startAnimation(bounceAnimation)
            viewModel.login()
        }
    }
    
    private fun observeViewModel() {
        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                updateUI(state)
            }
        }
        
        lifecycleScope.launch {
            viewModel.captchaData.collect { data ->
                data?.let {
                    android.util.Log.d("LoginActivity", "收到验证码数据，大小: ${it.size} bytes")
                    try {
                        // 使用BitmapFactory.Options优化图片解码
                        val options = BitmapFactory.Options().apply {
                            inPreferredConfig = Bitmap.Config.ARGB_8888
                            inScaled = false
                        }
                        val bitmap = BitmapFactory.decodeByteArray(it, 0, it.size, options)
                        if (bitmap != null) {
                            android.util.Log.d("LoginActivity", "验证码Bitmap创建成功: ${bitmap.width}x${bitmap.height}")
                            // 确保在主线程设置图片
                            runOnUiThread {
                                binding.ivCaptcha.setImageBitmap(bitmap)
                                // 强制重新布局以适应新图�?
                                binding.ivCaptcha.requestLayout()
                            }
                        } else {
                            android.util.Log.e("LoginActivity", "验证码Bitmap创建失败，数据可能不是有效的图片格式")
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("LoginActivity", "验证码处理异常: ${e.message}")
                    }
                } ?: run {
                    android.util.Log.d("LoginActivity", "验证码数据为空")
                }
            }
        }
        
        lifecycleScope.launch {
            viewModel.loginSuccess.collect { success ->
                if (success) {
                    startActivity(Intent(this@LoginActivity, MainNavigationActivity::class.java))
                    finish()
                }
            }
        }
        
        lifecycleScope.launch {
            viewModel.message.collect { message ->
                message?.let {
                    Toast.makeText(this@LoginActivity, it, Toast.LENGTH_SHORT).show()
                }
            }
        }
        
        lifecycleScope.launch {
            viewModel.startCountdown.collect { start ->
                if (start) {
                    startCountdown()
                }
            }
        }
    }
    
    private fun updateUI(state: uno.skkk.oasis.data.model.LoginUiState) {
        // 更新按钮状�?
        binding.btnGetCode.isEnabled = state.canGetCode
        binding.btnLogin.isEnabled = state.canLogin
        
        // 更新加载状�?
        binding.progressIndicator.visibility = if (state.isLoading) View.VISIBLE else View.GONE
        
        // 更新获取验证码按钮文�?
        if (state.countdown > 0) {
            binding.btnGetCode.text = "${state.countdown}s"
        } else {
            binding.btnGetCode.text = "获取验证码"
        }
        
        // 更新获取验证码按钮加载状态
        binding.btnGetCode.isEnabled = !state.isCodeSending && state.canGetCode
    }
    
    private fun loadCaptcha() {
        viewModel.loadCaptcha()
    }
    
    private fun startCountdown() {
        countDownTimer?.cancel()
        countDownTimer = object : CountDownTimer(60000, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = (millisUntilFinished / 1000).toInt()
                viewModel.updateCountdown(seconds)
            }
            
            override fun onFinish() {
                viewModel.updateCountdown(0)
            }
        }.start()
    }
    
    private fun createTextWatcher(onTextChanged: (String) -> Unit): TextWatcher {
        return object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                onTextChanged(s?.toString() ?: "")
            }
        }
    }
    
    private fun startEntranceAnimation() {
        // 为主要UI元素添加入场动画
        val fadeInAnimation = AnimationUtils.loadAnimation(this, R.anim.disney_fade_in)
        
        // 延迟启动动画，创建层次感
        binding.cardHeader.startAnimation(fadeInAnimation)
        
        binding.cardForm.postDelayed({
            binding.cardForm.startAnimation(fadeInAnimation)
        }, 150)
        
        binding.btnLogin.postDelayed({
            binding.btnLogin.startAnimation(fadeInAnimation)
        }, 300)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        countDownTimer?.cancel()
    }
}
