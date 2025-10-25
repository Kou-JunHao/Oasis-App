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
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

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
