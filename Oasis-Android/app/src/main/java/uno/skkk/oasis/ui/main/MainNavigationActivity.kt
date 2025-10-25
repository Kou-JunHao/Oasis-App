package uno.skkk.oasis.ui.main

import android.os.Bundle
import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import androidx.lifecycle.lifecycleScope
import com.google.android.material.tabs.TabLayoutMediator
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.ActivityMainBinding
import uno.skkk.oasis.ui.base.BaseActivity
import uno.skkk.oasis.ui.device.DeviceListFragment
import uno.skkk.oasis.ui.wallet.WalletFragment
import uno.skkk.oasis.ui.order.OrderFragment
import uno.skkk.oasis.ui.settings.SettingsFragment
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.utils.GitHubUpdateChecker
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import android.util.Log

@AndroidEntryPoint
class MainNavigationActivity : BaseActivity() {
    
    private lateinit var binding: ActivityMainBinding
    private var isNavigating = false // 防止快速点击导致的重复切换
    private var lastNavigationTime = 0L // 记录上次切换时间
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupViewPager()
        setupBottomNavigation()
        
        // 应用启动时获取最新用户信息
        refreshUserInfo()
        
        // 延迟检查更新，确保主页面完全加载后再进行
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            checkForUpdatesAfterStartup()
        }, 2000) // 延迟2秒，确保界面完全加载
    }
    
    /**
     * 刷新用户信息
     */
    private fun refreshUserInfo() {
        lifecycleScope.launch {
            try {
                val repository = AppRepository.getInstance(this@MainNavigationActivity)
                val result = repository.getUserInfo()
                if (result.isSuccess) {
                    // 用户信息刷新成功
                } else {
                    // 用户信息刷新失败
                }
            } catch (e: Exception) {
                // 用户信息刷新异常
            }
        }
    }
    
    /**
     * 主页面加载完成后检查更新
     */
    private fun checkForUpdatesAfterStartup() {
        lifecycleScope.launch {
            try {
                Log.d("MainNavigationActivity", "开始检查更新")
                val updateChecker = GitHubUpdateChecker(this@MainNavigationActivity)
                val updateInfo = updateChecker.checkForUpdates()
                
                if (updateInfo != null) {
                    Log.d("MainNavigationActivity", "发现新版本: ${updateInfo.tagName}")
                    // 发现新版本时弹出更新对话框
                    showUpdateDialog(updateInfo, updateChecker)
                } else {
                    Log.d("MainNavigationActivity", "当前已是最新版本")
                }
            } catch (e: Exception) {
                Log.e("MainNavigationActivity", "检查更新失败", e)
                // 静默失败，不影响用户体验
            }
        }
    }
    
    /**
     * 显示更新对话框
     */
    private fun showUpdateDialog(updateInfo: GitHubUpdateChecker.UpdateInfo, updateChecker: GitHubUpdateChecker) {
        val context = this
        val sharedPreferencesManager = uno.skkk.oasis.utils.SharedPreferencesManager(context)
        
        // 检查是否跳过此版本
        if (sharedPreferencesManager.isVersionSkipped(updateInfo.tagName)) {
            Log.d("MainNavigationActivity", "Version ${updateInfo.tagName} is skipped")
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
                        layoutParams = layoutParams.apply {
                            if (height > max) {
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
            
            // 添加调试日志
            Log.d("MainNavigationActivity", "更新内容: '${updateInfo.body}'")
            Log.d("MainNavigationActivity", "显示文本: '${text}'")
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
        
        // 创建对话框
        val dialog = com.google.android.material.dialog.MaterialAlertDialogBuilder(context)
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
            val positiveButton = dialog.getButton(androidx.appcompat.app.AlertDialog.BUTTON_POSITIVE)
            positiveButton.setOnClickListener {
                // 隐藏按钮，只显示进度条
                positiveButton.visibility = android.view.View.GONE
                dialog.getButton(androidx.appcompat.app.AlertDialog.BUTTON_NEGATIVE).visibility = android.view.View.GONE
                
                // 显示进度条
                progressContainer.visibility = android.view.View.VISIBLE
                
                // 使用APK下载管理器直接下载并安装
                val apkDownloadManager = uno.skkk.oasis.utils.ApkDownloadManager(context)
                lifecycleScope.launch {
                    try {
                        progressText.text = "开始下载..."
                        
                        val result = apkDownloadManager.downloadAndInstallApk(
                            updateInfo.downloadUrl, 
                            "oasis_${updateInfo.tagName}.apk"
                        ) { progress ->
                            // 更新进度
                            runOnUiThread {
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
                        
                        runOnUiThread {
                            Log.d("MainNavigationActivity", "下载结果处理: isFailure=${result.isFailure}")
                            if (result.isFailure) {
                                val error = result.exceptionOrNull()
                                Log.e("MainNavigationActivity", "下载失败", error)
                                progressText.text = "下载失败: ${error?.message}"
                                android.widget.Toast.makeText(context, "下载失败: ${error?.message}", android.widget.Toast.LENGTH_LONG).show()
                                // 隐藏进度条并恢复按钮
                                progressContainer.visibility = android.view.View.GONE
                                positiveButton.visibility = android.view.View.VISIBLE
                                dialog.getButton(androidx.appcompat.app.AlertDialog.BUTTON_NEGATIVE).visibility = android.view.View.VISIBLE
                                Log.d("MainNavigationActivity", "下载失败，按钮已恢复显示")
                            } else {
                                Log.d("MainNavigationActivity", "下载成功，开始自动安装")
                                progressText.text = "下载完成，正在安装..."
                                
                                // 自动调用安装流程
                                dialog.dismiss()
                            }
                        }
                    } catch (e: Exception) {
                        Log.e("MainNavigationActivity", "下载异常", e)
                        runOnUiThread {
                            progressText.text = "下载失败: ${e.message}"
                            android.widget.Toast.makeText(context, "下载失败: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
                            // 隐藏进度条并恢复按钮
                            progressContainer.visibility = android.view.View.GONE
                            positiveButton.visibility = android.view.View.VISIBLE
                            dialog.getButton(androidx.appcompat.app.AlertDialog.BUTTON_NEGATIVE).visibility = android.view.View.VISIBLE
                        }
                    }
                }
            }
            
            // 设置长按稍后提醒按钮跳过此版本
            val negativeButton = dialog.getButton(androidx.appcompat.app.AlertDialog.BUTTON_NEGATIVE)
            negativeButton.setOnClickListener {
                // 点击稍后提醒直接关闭对话框
                dialog.dismiss()
            }
            negativeButton.setOnLongClickListener {
                // 长按稍后提醒按钮跳过此版本
                val sharedPreferencesManager = uno.skkk.oasis.utils.SharedPreferencesManager(context)
                sharedPreferencesManager.skipVersion(updateInfo.tagName)
                android.widget.Toast.makeText(context, "已跳过版本 ${updateInfo.tagName}", android.widget.Toast.LENGTH_SHORT).show()
                dialog.dismiss()
                true
            }
        }
            
        dialog.show()
    }
    
    private fun setupViewPager() {
        val adapter = MainPagerAdapter(this)
        binding.viewPager.adapter = adapter
        
        // 禁用ViewPager的滑动，只通过底部导航切换
        binding.viewPager.isUserInputEnabled = false
        
        // 设置offscreenPageLimit为3，预加载所有页面以避免切换时的创建开销
        // 这样可以确保所有Fragment都保持在内存中，提供更流畅的切换体验
        binding.viewPager.offscreenPageLimit = 3
        
        // 设置高性能页面转换器
        binding.viewPager.setPageTransformer(createOptimizedPageTransformer())
    }
    
    private fun setupBottomNavigation() {
        binding.bottomNavigation.setOnItemSelectedListener { item ->
            val targetPosition = when (item.itemId) {
                R.id.nav_devices -> 0
                R.id.nav_wallet -> 1
                R.id.nav_orders -> 2
                R.id.nav_settings -> 3
                else -> return@setOnItemSelectedListener false
            }
            
            // 优化页面切换逻辑：使用相邻页面跳转而非直接跳转
            navigateToPageSmoothly(targetPosition)
            true
        }
        
        // 设置默认选中第一个页面
        binding.bottomNavigation.selectedItemId = R.id.nav_devices
    }
    
    /**
     * 创建优化的页面转换器
     * 使用硬件加速和简化的动画计算，避免页面重叠显示
     */
    private fun createOptimizedPageTransformer(): androidx.viewpager2.widget.ViewPager2.PageTransformer {
        return androidx.viewpager2.widget.ViewPager2.PageTransformer { page, position ->
            val absPosition = kotlin.math.abs(position)
            
            when {
                // 当前页面
                position == 0f -> {
                    // 当前页面完全显示
                    page.alpha = 1f
                    page.scaleX = 1f
                    page.scaleY = 1f
                    page.translationX = 0f
                    page.setLayerType(android.view.View.LAYER_TYPE_HARDWARE, null)
                }
                // 相邻页面（切换过程中）
                absPosition <= 1f -> {
                    // 启用硬件加速
                    page.setLayerType(android.view.View.LAYER_TYPE_HARDWARE, null)
                    
                    // 只使用透明度变化，避免页面重叠
                    page.alpha = 1f - absPosition * 0.5f
                    page.scaleX = 1f
                    page.scaleY = 1f
                    page.translationX = 0f // 不使用平移，避免页面重叠
                }
                // 不可见的页面
                else -> {
                    page.alpha = 0f
                    page.scaleX = 1f
                    page.scaleY = 1f
                    page.translationX = 0f
                    page.setLayerType(android.view.View.LAYER_TYPE_NONE, null)
                }
            }
        }
    }

    /**
     * 智能页面切换逻辑
     * 根据距离和用户体验优化切换方式，包含防抖动机制
     */
    private fun navigateToPageSmoothly(targetPosition: Int) {
        val currentTime = System.currentTimeMillis()
        val currentPosition = binding.viewPager.currentItem
        
        // 防抖动：如果正在切换或距离上次切换时间太短，则忽略
        if (isNavigating || currentTime - lastNavigationTime < 100) {
            return
        }
        
        if (currentPosition == targetPosition) {
            return // 已经在目标页面，无需切换
        }
        
        isNavigating = true
        lastNavigationTime = currentTime
        val distance = kotlin.math.abs(targetPosition - currentPosition)
        
        when {
            // 相邻页面：直接切换，使用默认动画
            distance == 1 -> {
                binding.viewPager.setCurrentItem(targetPosition, true)
                // 动画完成后重置状态
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    isNavigating = false
                }, 250) // ViewPager2默认动画时长约250ms
            }
            
            // 距离为2：快速两步切换，减少延迟
            distance == 2 -> {
                val direction = if (targetPosition > currentPosition) 1 else -1
                val intermediatePosition = currentPosition + direction
                
                // 第一步：快速切换到中间页面
                binding.viewPager.setCurrentItem(intermediatePosition, true)
                
                // 第二步：延迟60ms后切换到目标页面（减少延迟）
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    binding.viewPager.setCurrentItem(targetPosition, true)
                    // 总动画完成后重置状态
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        isNavigating = false
                    }, 250)
                }, 60)
            }
            
            // 距离为3（最远距离）：直接切换，避免过多中间步骤
            distance == 3 -> {
                binding.viewPager.setCurrentItem(targetPosition, true)
                // 动画完成后重置状态
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    isNavigating = false
                }, 250)
            }
        }
    }
    
    private inner class MainPagerAdapter(activity: MainNavigationActivity) : 
        FragmentStateAdapter(activity) {
        
        override fun getItemCount(): Int = 4
        
        override fun createFragment(position: Int): Fragment {
            return when (position) {
                0 -> DeviceListFragment.newInstance()
                1 -> WalletFragment.newInstance()
                2 -> OrderFragment.newInstance()
                3 -> SettingsFragment.newInstance()
                else -> throw IllegalArgumentException("Invalid position: $position")
            }
        }
    }
}
