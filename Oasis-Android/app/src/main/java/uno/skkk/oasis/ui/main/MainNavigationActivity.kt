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
                    android.util.Log.d("MainNavigationActivity", "用户信息刷新成功")
                } else {
                    android.util.Log.w("MainNavigationActivity", "用户信息刷新失败: ${result.exceptionOrNull()?.message}")
                }
            } catch (e: Exception) {
                android.util.Log.e("MainNavigationActivity", "用户信息刷新异常: ${e.message}")
            }
        }
    }
    
    private fun setupViewPager() {
        val adapter = MainPagerAdapter(this)
        binding.viewPager.adapter = adapter
        
        // 禁用ViewPager的滑动，只通过底部导航切换
        binding.viewPager.isUserInputEnabled = false
        
        // 设置offscreenPageLimit为1，这是最小允许值
        // 结合LazyLoadFragment的懒加载机制，可以避免不必要的数据加载
        binding.viewPager.offscreenPageLimit = 1
    }
    
    private fun setupBottomNavigation() {
        binding.bottomNavigation.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_devices -> {
                    binding.viewPager.currentItem = 0
                    true
                }
                R.id.nav_wallet -> {
                    binding.viewPager.currentItem = 1
                    true
                }
                R.id.nav_orders -> {
                    binding.viewPager.currentItem = 2
                    true
                }
                R.id.nav_settings -> {
                    binding.viewPager.currentItem = 3
                    true
                }
                else -> false
            }
        }
        
        // 设置默认选中第一个页�?        binding.bottomNavigation.selectedItemId = R.id.nav_devices
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
