package uno.skkk.oasis.ui.settings

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.android.material.snackbar.Snackbar
import androidx.lifecycle.lifecycleScope
import com.bumptech.glide.Glide
import com.bumptech.glide.load.resource.bitmap.CircleCrop
import io.noties.markwon.Markwon
import io.noties.markwon.html.HtmlPlugin
import io.noties.markwon.linkify.LinkifyPlugin
import io.noties.markwon.ext.strikethrough.StrikethroughPlugin
import io.noties.markwon.ext.tables.TablePlugin
import io.noties.markwon.simple.ext.SimpleExtPlugin
import uno.skkk.oasis.BuildConfig
import uno.skkk.oasis.LifeWaterApplication
import uno.skkk.oasis.R
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.databinding.FragmentSettingsBinding
import uno.skkk.oasis.databinding.DialogAppInfoBinding
import uno.skkk.oasis.ui.components.UnifiedTopBar
import uno.skkk.oasis.ui.base.LazyLoadFragment
import uno.skkk.oasis.ui.login.LoginActivity
import uno.skkk.oasis.ui.settings.OpenSourceLicensesActivity
import uno.skkk.oasis.utils.GitHubUpdateChecker
import uno.skkk.oasis.utils.ApkDownloadManager
import uno.skkk.oasis.utils.SharedPreferencesManager
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import dagger.hilt.android.AndroidEntryPoint
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import android.os.Build
import android.os.Environment

@AndroidEntryPoint
class SettingsFragment : LazyLoadFragment() {
    
    private var _binding: FragmentSettingsBinding? = null
    private val binding get() = _binding!!
    private lateinit var appRepository: AppRepository
    private lateinit var updateChecker: GitHubUpdateChecker
    private var downloadedApkPath: String? = null
    
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
        updateChecker = GitHubUpdateChecker(requireContext())
        
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
        // 动态设置版本号显示
        try {
            val packageInfo = requireContext().packageManager.getPackageInfo(requireContext().packageName, 0)
            binding.tvAppVersion.text = "版本 ${packageInfo.versionName}"
        } catch (e: PackageManager.NameNotFoundException) {
            binding.tvAppVersion.text = "版本 ${BuildConfig.VERSION_NAME}"
        }
        
        // 设置应用信息组件点击事件
        binding.layoutAppInfo.setOnClickListener {
            showAppInfoDialog()
        }
        
        // 设置检查更新选项点击事件
        binding.layoutCheckUpdate.setOnClickListener {
            checkForUpdates()
        }

        // 设置开源许可证卡片点击事件
        binding.cardOpenSourceLicenses.setOnClickListener {
            OpenSourceLicensesActivity.start(requireContext())
        }
        
        // 设置请我一杯咖啡卡片点击事件
        binding.cardBuyMeACoffee.setOnClickListener {
            openBuyMeACoffeeLink()
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
            
            // 设置GitHub按钮点击事件
            dialogBinding.btnGitHub.setOnClickListener {
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
    
    /**
     * 检查更新功能
     */
    private fun checkForUpdates() {
        lifecycleScope.launch {
            try {
                // 显示加载提示
                val loadingSnackbar = Snackbar.make(binding.root, "正在检查更新...", Snackbar.LENGTH_INDEFINITE)
                loadingSnackbar.show()
                
                val updateInfo = updateChecker.checkForUpdates()
                loadingSnackbar.dismiss()
                
                if (updateInfo != null) {
                    // 有新版本可用
                    showUpdateDialog(updateInfo)
                } else {
                    // 已是最新版本
                    Snackbar.make(binding.root, "当前已是最新版本", Snackbar.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                // 检查更新失败
                Snackbar.make(binding.root, "检查更新失败: ${e.message}", Snackbar.LENGTH_LONG).show()
                android.util.Log.e("SettingsFragment", "检查更新失败", e)
            }
        }
    }
    
    /**
     * 显示更新对话框
     */
    private fun showUpdateDialog(updateInfo: GitHubUpdateChecker.UpdateInfo) {
        val context = requireContext()
        val sharedPreferencesManager = SharedPreferencesManager(context)
        
        // 检查是否跳过此版本
        if (sharedPreferencesManager.isVersionSkipped(updateInfo.tagName)) {
            android.util.Log.d("SettingsFragment", "Version ${updateInfo.tagName} is skipped")
            return
        }
        
        // 创建主容器
        val mainContainer = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(48, 24, 48, 24)
        }
        
        // 创建ScrollView来包装更新内容，支持长文本滚动
        val scrollView = android.widget.ScrollView(context).apply {
            // 设置最大高度，避免对话框过高
            val displayMetrics = context.resources.displayMetrics
            val maxHeight = (displayMetrics.heightPixels * 0.4).toInt() // 降低到屏幕高度的40%
            
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            )
            
            // 设置最大高度约束，但允许内容自适应
            maxHeight.let { max ->
                viewTreeObserver.addOnGlobalLayoutListener(object : android.view.ViewTreeObserver.OnGlobalLayoutListener {
                    override fun onGlobalLayout() {
                        viewTreeObserver.removeOnGlobalLayoutListener(this)
                        if (measuredHeight > max) {
                            layoutParams = layoutParams.apply {
                                height = max
                            }
                        }
                    }
                })
            }
            
            // 启用滚动条
            isVerticalScrollBarEnabled = true
            // 设置滚动条样式
            scrollBarStyle = android.view.View.SCROLLBARS_INSIDE_OVERLAY
        }
        
        // 创建内容容器
        val contentContainer = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
            gravity = android.view.Gravity.CENTER_VERTICAL // 垂直居中
        }
        
        // 创建标题TextView
        val titleTextView = android.widget.TextView(context).apply {
            text = "更新日志："
            textSize = 16f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = android.view.Gravity.START // 左对齐
            // 使用Material Design主题颜色
            val typedValue = android.util.TypedValue()
            if (context.theme.resolveAttribute(com.google.android.material.R.attr.colorOnSurface, typedValue, true)) {
                setTextColor(typedValue.data)
            } else {
                context.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)
                setTextColor(typedValue.data)
            }
            setPadding(0, 0, 0, 16)
        }
        
        // 创建更新内容TextView
        val contentTextView = android.widget.TextView(context).apply {
            textSize = 14f
            gravity = android.view.Gravity.START // 左对齐
            // 使用Material Design主题颜色
            val typedValue = android.util.TypedValue()
            if (context.theme.resolveAttribute(com.google.android.material.R.attr.colorOnSurface, typedValue, true)) {
                setTextColor(typedValue.data)
            } else {
                context.theme.resolveAttribute(android.R.attr.textColorPrimary, typedValue, true)
                setTextColor(typedValue.data)
            }
            // 设置行间距以提高可读性
            setLineSpacing(4f, 1.2f)
            // 允许文本选择
            setTextIsSelectable(true)
            // 设置更新内容
            text = updateInfo.body ?: "暂无更新内容"
            setPadding(0, 0, 0, 16)
        }
        
        // 创建发布日期TextView
        val dateTextView = android.widget.TextView(context).apply {
            textSize = 12f
            gravity = android.view.Gravity.START // 左对齐
            // 使用Material Design次要文字颜色
            val typedValue = android.util.TypedValue()
            if (context.theme.resolveAttribute(com.google.android.material.R.attr.colorOnSurfaceVariant, typedValue, true)) {
                setTextColor(typedValue.data)
            } else {
                context.theme.resolveAttribute(android.R.attr.textColorSecondary, typedValue, true)
                setTextColor(typedValue.data)
            }
            // 格式化发布日期
            val publishedDate = try {
                val inputFormat = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.getDefault())
                val outputFormat = java.text.SimpleDateFormat("发布日期：yyyy年MM月dd日", java.util.Locale.getDefault())
                val date = inputFormat.parse(updateInfo.publishedAt)
                outputFormat.format(date ?: java.util.Date())
            } catch (e: Exception) {
                "发布日期：${updateInfo.publishedAt}"
            }
            text = publishedDate
        }
        
        contentContainer.addView(titleTextView)
        contentContainer.addView(contentTextView)
        contentContainer.addView(dateTextView)
        
        scrollView.addView(contentContainer)
        mainContainer.addView(scrollView)
        
        // 创建进度条容器（初始隐藏）
        val progressContainer = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            visibility = android.view.View.GONE
            setPadding(0, 24, 0, 0)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        
        val progressText = android.widget.TextView(context).apply {
            text = "准备下载..."
            textSize = 12f
            // 使用Material Design次要文字颜色，确保深浅色模式兼容
            val typedValue = android.util.TypedValue()
            if (context.theme.resolveAttribute(com.google.android.material.R.attr.colorOnSurfaceVariant, typedValue, true)) {
                setTextColor(typedValue.data)
            } else {
                // 备用方案：使用系统次要文字颜色
                context.theme.resolveAttribute(android.R.attr.textColorSecondary, typedValue, true)
                setTextColor(typedValue.data)
            }
            gravity = android.view.Gravity.CENTER
        }
        
        val progressBar = android.widget.ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 16
                bottomMargin = 8
            }
            
            // 设置进度条高度
            minimumHeight = 24
            
            // 使用Material Design颜色
            val typedValue = android.util.TypedValue()
            if (context.theme.resolveAttribute(androidx.appcompat.R.attr.colorPrimary, typedValue, true)) {
                progressTintList = android.content.res.ColorStateList.valueOf(typedValue.data)
            }
            
            // 设置背景色
            if (context.theme.resolveAttribute(androidx.appcompat.R.attr.colorControlHighlight, typedValue, true)) {
                progressBackgroundTintList = android.content.res.ColorStateList.valueOf(typedValue.data)
            }
        }
        
        progressContainer.addView(progressText)
        progressContainer.addView(progressBar)
        mainContainer.addView(progressContainer)
        
        // 添加提示文字
        val hintText = android.widget.TextView(context).apply {
            text = "长按稍后提醒跳过此次更新"
            textSize = 12f
            // 使用Material Design次要文字颜色，确保深浅色模式兼容
            val typedValue = android.util.TypedValue()
            if (context.theme.resolveAttribute(com.google.android.material.R.attr.colorOnSurfaceVariant, typedValue, true)) {
                setTextColor(typedValue.data)
            } else {
                // 备用方案：使用系统次要文字颜色
                context.theme.resolveAttribute(android.R.attr.textColorSecondary, typedValue, true)
                setTextColor(typedValue.data)
            }
            gravity = android.view.Gravity.CENTER
            setPadding(0, 16, 0, 0)
        }
        mainContainer.addView(hintText)
        
        val dialog = MaterialAlertDialogBuilder(context)
            .setTitle("发现新版本 ${updateInfo.tagName}")
            .setView(mainContainer)
            .setPositiveButton("立即更新", null) // 先设为null，稍后手动设置
            .setNeutralButton("查看详情") { _, _ ->
                updateChecker.openDownloadPage(updateInfo.htmlUrl)
            }
            .setNegativeButton("稍后提醒", null)
            .create()
            
        // 手动设置立即更新按钮的点击事件
        dialog.setOnShowListener {
            val positiveButton = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
            positiveButton.setOnClickListener {
                // 隐藏按钮，只显示进度条
                positiveButton.visibility = android.view.View.GONE
                dialog.getButton(AlertDialog.BUTTON_NEGATIVE).visibility = android.view.View.GONE
                
                // 显示进度条
                progressContainer.visibility = android.view.View.VISIBLE
                
                // 使用APK下载管理器直接下载并安装
                val apkDownloadManager = ApkDownloadManager(context)
                lifecycleScope.launch {
                    try {
                        progressText.text = "开始下载..."
                        
                        val result = apkDownloadManager.downloadAndInstallApk(
                            updateInfo.downloadUrl, 
                            "oasis_${updateInfo.tagName}.apk"
                        ) { progress ->
                            // 更新进度
                            requireActivity().runOnUiThread {
                                progressBar.progress = progress
                                when {
                                    progress < 100 -> {
                                        progressText.text = "下载中... $progress%"
                                    }
                                    progress == 100 -> {
                                        progressText.text = "下载完成，正在安装..."
                                    }
                                }
                            }
                        }
                        
                        requireActivity().runOnUiThread {
                            Log.d("SettingsFragment", "下载结果处理: isFailure=${result.isFailure}")
                            if (result.isFailure) {
                                val error = result.exceptionOrNull()
                                Log.e("SettingsFragment", "下载失败", error)
                                progressText.text = "下载失败: ${error?.message}"
                                Toast.makeText(context, "下载失败: ${error?.message}", Toast.LENGTH_LONG).show()
                                // 隐藏进度条并恢复按钮
                                progressContainer.visibility = android.view.View.GONE
                                positiveButton.visibility = android.view.View.VISIBLE
                                dialog.getButton(AlertDialog.BUTTON_NEGATIVE).visibility = android.view.View.VISIBLE
                                Log.d("SettingsFragment", "下载失败，按钮已恢复显示")
                            } else {
                                Log.d("SettingsFragment", "下载成功，开始自动安装")
                                progressText.text = "下载完成，正在安装..."
                                
                                // 保存下载的APK路径 - 修复路径拼接问题
                                downloadedApkPath = File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "apk/oasis_${updateInfo.tagName}.apk").absolutePath
                                Log.d("SettingsFragment", "APK路径已保存: $downloadedApkPath")
                                
                                // 自动调用安装流程
                                installDownloadedApk()
                                
                                // 关闭对话框
                                dialog.dismiss()
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("SettingsFragment", "下载异常", e)
                        requireActivity().runOnUiThread {
                            progressText.text = "下载失败: ${e.message}"
                            Toast.makeText(context, "下载失败: ${e.message}", Toast.LENGTH_LONG).show()
                            // 隐藏进度条并恢复按钮
                            progressContainer.visibility = android.view.View.GONE
                            positiveButton.visibility = android.view.View.VISIBLE
                            dialog.getButton(AlertDialog.BUTTON_NEGATIVE).visibility = android.view.View.VISIBLE
                        }
                    }
                }
            }
            
            // 设置长按稍后提醒按钮跳过此版本
            val negativeButton = dialog.getButton(AlertDialog.BUTTON_NEGATIVE)
            negativeButton.setOnLongClickListener {
                // 长按稍后提醒按钮跳过此版本
                sharedPreferencesManager.skipVersion(updateInfo.tagName)
                Toast.makeText(context, "已跳过版本 ${updateInfo.tagName}", Toast.LENGTH_SHORT).show()
                dialog.dismiss()
                true
            }
        }
        
        dialog.show()
    }
    
    /**
     * 安装下载的APK
     */
    private fun installDownloadedApk() {
        val apkPath = downloadedApkPath
        if (apkPath == null) {
            Toast.makeText(context, "未找到下载的安装包", Toast.LENGTH_SHORT).show()
            return
        }
        
        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            Toast.makeText(context, "安装包文件不存在", Toast.LENGTH_SHORT).show()
            return
        }
        
        val apkDownloadManager = ApkDownloadManager(requireContext())
        
        // 检查安装权限
        if (!apkDownloadManager.hasInstallPermission()) {
            // 请求安装权限
            Toast.makeText(context, "需要安装未知来源应用的权限，请在设置中允许", Toast.LENGTH_LONG).show()
            apkDownloadManager.requestInstallPermission()
            return
        }
        
        // 执行安装
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    // Android 7.0及以上使用FileProvider
                    val apkUri = FileProvider.getUriForFile(
                        requireContext(),
                        "${requireContext().packageName}.fileprovider",
                        apkFile
                    )
                    setDataAndType(apkUri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    // Android 7.0以下直接使用文件URI
                    setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive")
                }
            }
            
            startActivity(intent)
            Toast.makeText(context, "正在启动安装程序...", Toast.LENGTH_SHORT).show()
            
        } catch (e: Exception) {
            Log.e("SettingsFragment", "启动安装程序失败", e)
            Toast.makeText(context, "启动安装程序失败: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }
    
    /**
     * 打开Buy Me a Coffee链接
     */
    private fun openBuyMeACoffeeLink() {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://buymeacoffee.com/skkk"))
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // 如果无法打开浏览器，显示提示并复制链接到剪贴板
            Log.e("SettingsFragment", "无法打开Buy Me a Coffee链接", e)
            
            // 复制链接到剪贴板
            val clipboard = requireContext().getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            val clip = android.content.ClipData.newPlainText("Buy Me a Coffee", "https://buymeacoffee.com/skkk")
            clipboard.setPrimaryClip(clip)
            
            Toast.makeText(context, "无法打开浏览器，链接已复制到剪贴板", Toast.LENGTH_LONG).show()
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
