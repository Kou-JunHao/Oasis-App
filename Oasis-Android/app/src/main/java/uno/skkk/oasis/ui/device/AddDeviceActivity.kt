package uno.skkk.oasis.ui.device

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.widget.Toast
import androidx.activity.viewModels
import androidx.lifecycle.lifecycleScope
import uno.skkk.oasis.R
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.databinding.ActivityAddDeviceBinding
import uno.skkk.oasis.ui.base.BaseActivity
import kotlinx.coroutines.launch

/**
 * 添加设备Activity
 */
class AddDeviceActivity : BaseActivity() {
    
    private lateinit var binding: ActivityAddDeviceBinding
    private val viewModel: AddDeviceViewModel by viewModels {
        AddDeviceViewModelFactory(AppRepository.getInstance(this))
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAddDeviceBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupToolbar()
        setupUI()
        observeViewModel()
    }
    
    private fun setupToolbar() {
        setSupportActionBar(binding.toolbar)
        supportActionBar?.apply {
            setDisplayHomeAsUpEnabled(true)
            setDisplayShowHomeEnabled(true)
            title = "添加设备"
        }
        
        binding.toolbar.setNavigationOnClickListener {
            finish()
        }
    }
    
    private fun setupUI() {
        // 设置文本监听�?
        binding.etDeviceId.addTextChangedListener(createTextWatcher { text ->
            viewModel.updateDeviceId(text)
        })
        
        binding.etDeviceName.addTextChangedListener(createTextWatcher { text ->
            viewModel.updateDeviceName(text)
        })
        
        binding.etDeviceType.addTextChangedListener(createTextWatcher { text ->
            viewModel.updateDeviceType(text)
        })
        
        // 设置按钮点击监听�?
        binding.btnAddDevice.setOnClickListener {
            viewModel.addDevice()
        }
        
        binding.btnReset.setOnClickListener {
            viewModel.resetForm()
            clearInputs()
        }
    }
    
    private fun observeViewModel() {
        // 观察UI状�?
        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                updateUI(state)
            }
        }
        
        // 观察输入字段
        lifecycleScope.launch {
            viewModel.deviceId.collect { deviceId ->
                if (binding.etDeviceId.text.toString() != deviceId) {
                    binding.etDeviceId.setText(deviceId)
                    binding.etDeviceId.setSelection(deviceId.length)
                }
            }
        }
        
        lifecycleScope.launch {
            viewModel.deviceName.collect { deviceName ->
                if (binding.etDeviceName.text.toString() != deviceName) {
                    binding.etDeviceName.setText(deviceName)
                    binding.etDeviceName.setSelection(deviceName.length)
                }
            }
        }
        
        lifecycleScope.launch {
            viewModel.deviceType.collect { deviceType ->
                if (binding.etDeviceType.text.toString() != deviceType) {
                    binding.etDeviceType.setText(deviceType)
                    binding.etDeviceType.setSelection(deviceType.length)
                }
            }
        }
    }
    
    private fun updateUI(state: AddDeviceUiState) {
        // 更新加载状�?
        binding.btnAddDevice.isEnabled = !state.isLoading && state.isInputValid
        binding.progressBar.visibility = if (state.isLoading) {
            android.view.View.VISIBLE
        } else {
            android.view.View.GONE
        }
        
        // 显示错误消息
        state.errorMessage?.let { message ->
            showErrorSnackbar(message)
            viewModel.clearError()
        }
        
        // 处理成功状�?
        if (state.isSuccess) {
            showSuccessAnimation()
        }
    }
    
    private fun showErrorSnackbar(message: String) {
        com.google.android.material.snackbar.Snackbar.make(
            binding.root,
            message,
            com.google.android.material.snackbar.Snackbar.LENGTH_LONG
        ).apply {
            setBackgroundTint(getColor(R.color.status_error))
            setTextColor(getColor(android.R.color.white))
            setAction("重试") {
                // 可以在这里添加重试逻辑
            }
            setActionTextColor(getColor(android.R.color.white))
        }.show()
    }
    
    private fun showSuccessAnimation() {
        val successContainer = binding.successAnimationContainer
        val successIcon = binding.successIcon
        val successTitle = binding.successTitle
        val successSubtitle = binding.successSubtitle
        
        // 显示成功容器
        successContainer.visibility = android.view.View.VISIBLE
        
        // 创建动画序列
        val fadeInContainer = android.animation.ObjectAnimator.ofFloat(successContainer, "alpha", 0f, 1f).apply {
            duration = 300
        }
        
        val scaleInIcon = android.animation.AnimatorSet().apply {
            playTogether(
                android.animation.ObjectAnimator.ofFloat(successIcon, "scaleX", 0f, 1.2f, 1f),
                android.animation.ObjectAnimator.ofFloat(successIcon, "scaleY", 0f, 1.2f, 1f)
            )
            duration = 600
            interpolator = android.view.animation.OvershootInterpolator()
        }
        
        val fadeInTexts = android.animation.AnimatorSet().apply {
            playTogether(
                android.animation.ObjectAnimator.ofFloat(successTitle, "alpha", 0f, 1f).apply {
                    startDelay = 100L
                    duration = 400
                },
                android.animation.ObjectAnimator.ofFloat(successSubtitle, "alpha", 0f, 1f).apply {
                    startDelay = 200L
                    duration = 400
                }
            )
        }
        
        // 执行动画序列
        android.animation.AnimatorSet().apply {
            play(fadeInContainer).before(scaleInIcon)
            play(scaleInIcon).before(fadeInTexts)
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    // 延迟2秒后关闭Activity
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        setResult(RESULT_OK)
                        finish()
                        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
                    }, 2000)
                }
            })
        }.start()
    }
    
    private fun clearInputs() {
        binding.etDeviceId.text?.clear()
        binding.etDeviceName.text?.clear()
        binding.etDeviceType.text?.clear()
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
    
    companion object {
        const val REQUEST_CODE_ADD_DEVICE = 1001
    }
}
