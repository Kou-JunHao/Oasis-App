package uno.skkk.oasis.ui.components

import android.content.Context
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.MenuItem
import android.view.View
import androidx.core.view.isVisible
import com.google.android.material.appbar.AppBarLayout
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.search.SearchBar
import com.google.android.material.tabs.TabLayout
import uno.skkk.oasis.databinding.LayoutUnifiedTopbarBinding

/**
 * 统一顶栏组件
 * 符合Material Design 3规范，提供简洁可靠的顶部导航
 */
class UnifiedTopBar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : AppBarLayout(context, attrs, defStyleAttr) {

    private val binding: LayoutUnifiedTopbarBinding
    
    // 公开访问器
    val toolbar: MaterialToolbar get() = binding.toolbar
    val searchBar: SearchBar get() = binding.searchBar
    val tabLayout: TabLayout get() = binding.tabLayout

    init {
        binding = LayoutUnifiedTopbarBinding.inflate(LayoutInflater.from(context), this, true)
        setupDefaults()
    }

    private fun setupDefaults() {
        // 设置默认状态
        searchBar.isVisible = false
        tabLayout.isVisible = false
        
        // 确保工具栏始终可见
        toolbar.visibility = View.VISIBLE
    }

    /**
     * 配置顶栏
     */
    fun configure(config: TopBarConfig) {
        // 设置标题
        if (config.title.isNotEmpty()) {
            toolbar.title = config.title
        }
        
        // 设置导航图标
        config.navigationIcon?.let { 
            toolbar.navigationIcon = it
        }
        
        // 设置导航点击监听
        config.onNavigationClick?.let { listener ->
            toolbar.setNavigationOnClickListener { listener() }
        }
        
        // 清除现有菜单并设置新菜单
        toolbar.menu.clear()
        config.menuRes?.let { menuRes ->
            toolbar.inflateMenu(menuRes)
        }
        
        // 设置菜单点击监听
        config.onMenuItemClick?.let { listener ->
            toolbar.setOnMenuItemClickListener(listener)
        }
        
        // 配置搜索栏
        configureSearchBar(config)
        
        // 配置Tab布局
        configureTabs(config)
    }

    private fun configureSearchBar(config: TopBarConfig) {
        searchBar.isVisible = config.showSearchBar
        
        if (config.showSearchBar) {
            config.searchHint?.let { hint ->
                searchBar.hint = hint
            }
            config.onSearchClick?.let { listener ->
                searchBar.setOnClickListener { listener() }
            }
        }
    }

    private fun configureTabs(config: TopBarConfig) {
        tabLayout.isVisible = config.showTabs && config.tabs.isNotEmpty()
        
        if (config.showTabs && config.tabs.isNotEmpty()) {
            // 清除现有标签
            tabLayout.removeAllTabs()
            
            // 添加新标签
            config.tabs.forEach { tabTitle ->
                tabLayout.addTab(tabLayout.newTab().setText(tabTitle))
            }
            
            // 设置标签选择监听器
            config.onTabSelected?.let { listener ->
                tabLayout.clearOnTabSelectedListeners()
                tabLayout.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
                    override fun onTabSelected(tab: TabLayout.Tab?) {
                        tab?.let { listener(it.position) }
                    }
                    override fun onTabUnselected(tab: TabLayout.Tab?) {}
                    override fun onTabReselected(tab: TabLayout.Tab?) {}
                })
            }
        }
    }

    /**
     * 顶栏配置数据类
     */
    data class TopBarConfig(
        val title: String = "",
        val navigationIcon: Drawable? = null,
        val onNavigationClick: (() -> Unit)? = null,
        val menuRes: Int? = null,
        val onMenuItemClick: ((MenuItem) -> Boolean)? = null,
        val showSearchBar: Boolean = false,
        val searchHint: String? = null,
        val onSearchClick: (() -> Unit)? = null,
        val showTabs: Boolean = false,
        val tabs: List<String> = emptyList(),
        val onTabSelected: ((Int) -> Unit)? = null
    )
}