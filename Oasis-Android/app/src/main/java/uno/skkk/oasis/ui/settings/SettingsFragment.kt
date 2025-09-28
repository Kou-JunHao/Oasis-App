package uno.skkk.oasis.ui.settings

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import androidx.lifecycle.lifecycleScope
import com.bumptech.glide.Glide
import com.bumptech.glide.load.resource.bitmap.CircleCrop
import uno.skkk.oasis.BuildConfig
import uno.skkk.oasis.LifeWaterApplication
import uno.skkk.oasis.R
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.databinding.FragmentSettingsBinding
import uno.skkk.oasis.databinding.DialogAppInfoBinding
import uno.skkk.oasis.ui.components.UnifiedTopBar
import uno.skkk.oasis.ui.base.LazyLoadFragment
import uno.skkk.oasis.ui.login.LoginActivity
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class SettingsFragment : LazyLoadFragment() {
    
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
        // 移除立即数据加载，改为懒加载机制
        // setupUserInfo(), setupAppearanceSettings(), setupAboutSection() 将在 loadData() 中调用
    }
    
    /**
     * 实现懒加载数据加载方法
     * 只有当Fragment对用户可见时才会调用此方法
     */
    override fun loadData() {
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
            
            // 设置跟随系统开关
            val isFollowSystemEnabled = LifeWaterApplication.isFollowSystemEnabled(requireContext())
            switchFollowSystem.isChecked = isFollowSystemEnabled
            
            switchFollowSystem.setOnCheckedChangeListener { _, isChecked ->
                // 设置跟随系统主题
                LifeWaterApplication.setFollowSystemEnabled(requireContext(), isChecked)
            }
        }
    }
    
    private fun setupAboutSection() {
        // 设置关于卡片点击事件
        binding.cardAbout.setOnClickListener {
            showAppInfoDialog()
        }
        
        // 设置开源许可证卡片点击事件
        binding.cardOpenSourceLicenses.setOnClickListener {
            OpenSourceLicensesActivity.start(requireContext())
        }
    }
    
    private fun showAppInfoDialog() {
        val dialogBinding = DialogAppInfoBinding.inflate(layoutInflater)
        
        // 获取应用信息
        val packageInfo = try {
            requireContext().packageManager.getPackageInfo(requireContext().packageName, 0)
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
        
        // 设置应用信息
        dialogBinding.apply {
            tvAppName.text = getString(R.string.app_name)
            tvVersion.text = packageInfo?.versionName ?: BuildConfig.VERSION_NAME
            
            // 设置真实构建时间
            tvBuildTime.text = BuildConfig.BUILD_DATE
            
            tvAuthor.text = "Kou-JunHao"
            tvProjectUrl.text = "GitHub"
            
            // 设置项目地址点击事件
            tvProjectUrl.setOnClickListener {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/Kou-JunHao/Oasis-App"))
                try {
                    startActivity(intent)
                } catch (e: Exception) {
                    // 如果无法打开浏览器，可以显示一个提示
                    android.util.Log.e("SettingsFragment", "无法打开项目地址", e)
                }
            }
        }
        
        // 创建并显示对话框
        val dialog = MaterialAlertDialogBuilder(requireContext())
            .setView(dialogBinding.root)
            .create()
        
        // 设置关闭按钮点击事件
        dialogBinding.btnClose.setOnClickListener {
            dialog.dismiss()
        }
        
        dialog.show()
        
        // 设置对话框窗口大小限制以适应不同DPI
        dialog.window?.let { window ->
            val displayMetrics = resources.displayMetrics
            val screenHeight = displayMetrics.heightPixels
            val maxHeight = (screenHeight * 0.85).toInt() // 最大高度为屏幕高度的85%
            val maxWidth = (displayMetrics.widthPixels * 0.9).toInt() // 最大宽度为屏幕宽度的90%
            
            window.setLayout(maxWidth, android.view.WindowManager.LayoutParams.WRAP_CONTENT)
            window.attributes = window.attributes.apply {
                if (height > maxHeight) {
                    height = maxHeight
                }
            }
        }
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
