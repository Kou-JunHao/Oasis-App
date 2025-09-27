package uno.skkk.oasis.ui.settings

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.bumptech.glide.Glide
import com.bumptech.glide.load.resource.bitmap.CircleCrop
import uno.skkk.oasis.LifeWaterApplication
import uno.skkk.oasis.R
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.databinding.FragmentSettingsBinding
import uno.skkk.oasis.ui.components.UnifiedTopBar
import uno.skkk.oasis.ui.login.LoginActivity
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers

class SettingsFragment : Fragment() {
    
    private var _binding: FragmentSettingsBinding? = null
    private val binding get() = _binding!!
    
    private lateinit var appRepository: AppRepository
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSettingsBinding.inflate(inflater, container, false)
        return binding.root
    }
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        appRepository = AppRepository.getInstance(requireContext())
        
        setupTopBar()
        setupUserInfo()
        setupAppearanceSettings()
        setupAboutSection()
    }
    
    private fun setupTopBar() {
        binding.simpleTitle.setTitle("设置")
    }
    
    private fun setupUserInfo() {
        // 设置用户昵称
        val userName = appRepository.getUserName()
        val phoneNumber = appRepository.getUserPhone()
        val avatarUrl = appRepository.getUserAvatarUrl()
        
        // 添加调试日志
        android.util.Log.d("SettingsFragment", "用户昵称: $userName")
        android.util.Log.d("SettingsFragment", "用户手机号: $phoneNumber")
        android.util.Log.d("SettingsFragment", "用户头像URL: $avatarUrl")
        
        binding.tvUserName.text = userName ?: "用户"
        binding.tvUserPhone.text = phoneNumber ?: "未设置"
        
        // 设置用户头像
        setupUserAvatar()
        
        // 设置退出登录按钮点击事件
        binding.btnLogout.setOnClickListener {
            logout()
        }
    }
    
    private fun setupUserAvatar() {
        val avatarUrl = appRepository.getUserAvatarUrl()
        android.util.Log.d("SettingsFragment", "头像URL: $avatarUrl")
        
        if (!avatarUrl.isNullOrEmpty()) {
            android.util.Log.d("SettingsFragment", "开始加载头像: $avatarUrl")
            
            // 测试网络连接
            testNetworkConnection(avatarUrl)
            
            // 加载网络头像，清除tint
            binding.ivUserAvatar.imageTintList = null
            binding.ivUserAvatar.clearColorFilter()
            Glide.with(this)
                .load(avatarUrl)
                .transform(CircleCrop())
                .placeholder(R.drawable.ic_avatar_default)
                .error(R.drawable.ic_avatar_default)
                .into(binding.ivUserAvatar)
        } else {
            android.util.Log.d("SettingsFragment", "头像URL为空，显示默认头像")
            // 显示默认头像，应用tint
            binding.ivUserAvatar.setImageResource(R.drawable.ic_avatar_default)
            val typedValue = android.util.TypedValue()
            requireContext().theme.resolveAttribute(com.google.android.material.R.attr.colorOnPrimary, typedValue, true)
            binding.ivUserAvatar.setColorFilter(typedValue.data)
        }
    }
    
    private fun setupAppearanceSettings() {
        binding.apply {
            // 设置Monet颜色开关
            val isMonetEnabled = LifeWaterApplication.isMonetEnabled(requireContext())
            switchMonet.isChecked = isMonetEnabled
            
            switchMonet.setOnCheckedChangeListener { _, isChecked ->
                // 保存Monet设置
                val sharedPrefs = requireContext().getSharedPreferences("app_settings", 0)
                sharedPrefs.edit().putBoolean("monet_enabled", isChecked).apply()
                
                // 重新创建Activity以应用新主题
                requireActivity().recreate()
            }
        }
    }
    
    private fun setupAboutSection() {
        // 关于部分的信息已经在布局文件中硬编码
        // 如果需要动态设置版本号，可以在这里添加逻辑
    }
    
    private fun logout() {
        lifecycleScope.launch {
            // 清除登录信息
            appRepository.logout()
            
            // 返回登录页面
            val intent = Intent(requireContext(), LoginActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            startActivity(intent)
            requireActivity().finish()
        }
    }
    
    private fun testNetworkConnection(url: String) {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                android.util.Log.d("SettingsFragment", "开始测试网络连接: $url")
                val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                connection.requestMethod = "HEAD"
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                
                val responseCode = connection.responseCode
                android.util.Log.d("SettingsFragment", "网络连接测试结果 - 响应码: $responseCode")
                
                if (responseCode == 200) {
                    android.util.Log.d("SettingsFragment", "网络连接成功，URL可访问")
                } else {
                    android.util.Log.w("SettingsFragment", "网络连接失败，响应码: $responseCode")
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                android.util.Log.e("SettingsFragment", "网络连接测试异常: ${e.message}", e)
            }
        }
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
    
    companion object {
        fun newInstance() = SettingsFragment()
    }
}
