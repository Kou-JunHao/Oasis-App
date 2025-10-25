package uno.skkk.oasis

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.ui.base.BaseActivity
import uno.skkk.oasis.ui.main.MainNavigationActivity
import uno.skkk.oasis.ui.login.LoginActivity
import uno.skkk.oasis.utils.GitHubUpdateChecker

class MainActivity : BaseActivity() {
    
    private var disclaimerDialog: DisclaimerDialog? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 首先检查是否已接受免责声明
        if (!DisclaimerDialog.isDisclaimerAccepted(this)) {
            showDisclaimerDialog()
        } else {
            proceedToNextActivity()
        }
    }
    
    private fun showDisclaimerDialog() {
        disclaimerDialog = DisclaimerDialog(this, object : DisclaimerDialog.OnDisclaimerActionListener {
            override fun onAccepted() {
                disclaimerDialog = null
                proceedToNextActivity()
            }
            
            override fun onCancelled() {
                disclaimerDialog = null
                // 用户取消，退出应用
                finishAffinity()
            }
        })
        disclaimerDialog?.show()
    }
    
    private fun proceedToNextActivity() {
        // 检查登录状态
        val repository = AppRepository.getInstance(this)
        val isLoggedIn = repository.isLoggedIn()
        
        // 在应用启动时检查更新
        checkForUpdatesOnStartup { hasUpdate ->
            if (!hasUpdate) {
                // 没有更新或检查失败，继续正常流程
                navigateToNextActivity(isLoggedIn)
            }
            // 如果有更新，对话框会显示，用户操作后再决定是否继续
        }
    }
    
    /**
     * 导航到下一个Activity
     */
    private fun navigateToNextActivity(isLoggedIn: Boolean) {
        if (isLoggedIn) {
            // 已登录，跳转到主导航页面
            startActivity(Intent(this, MainNavigationActivity::class.java))
        } else {
            // 未登录，跳转到登录页面
            startActivity(Intent(this, LoginActivity::class.java))
        }
        
        finish()
    }
    
    /**
     * 应用启动时检查更新
     */
    private fun checkForUpdatesOnStartup(callback: (hasUpdate: Boolean) -> Unit) {
        lifecycleScope.launch {
            try {
                val updateChecker = GitHubUpdateChecker(this@MainActivity)
                val updateInfo = updateChecker.checkForUpdates()
                
                if (updateInfo != null) {
                    Log.d("MainActivity", "发现新版本: ${updateInfo.tagName}")
                    // 发现新版本时弹出更新对话框
                    showUpdateDialog(updateInfo, updateChecker) {
                        // 对话框关闭后的回调
                        val repository = AppRepository.getInstance(this@MainActivity)
                        val isLoggedIn = repository.isLoggedIn()
                        navigateToNextActivity(isLoggedIn)
                    }
                    callback(true)
                } else {
                    Log.d("MainActivity", "当前已是最新版本")
                    callback(false)
                }
            } catch (e: Exception) {
                Log.e("MainActivity", "启动时检查更新失败", e)
                // 静默失败，不影响用户体验
                callback(false)
            }
        }
    }
    
    /**
     * 显示更新对话框
     */
    private fun showUpdateDialog(updateInfo: GitHubUpdateChecker.UpdateInfo, updateChecker: GitHubUpdateChecker, onDismiss: (() -> Unit)? = null) {
        val context = this
        
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
            .setPositiveButton("立即更新") { _, _ ->
                updateChecker.openDownloadPage(updateInfo.downloadUrl)
                onDismiss?.invoke()
            }
            .setNeutralButton("查看详情") { _, _ ->
                updateChecker.openDownloadPage(updateInfo.htmlUrl)
                onDismiss?.invoke()
            }
            .setNegativeButton("稍后提醒") { _, _ ->
                onDismiss?.invoke()
            }
            .setOnDismissListener {
                onDismiss?.invoke()
            }
            .create()
            
        dialog.show()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        disclaimerDialog?.dismiss()
    }
}
