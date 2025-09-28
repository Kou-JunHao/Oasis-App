package uno.skkk.oasis.ui.base

import androidx.fragment.app.Fragment

/**
 * 懒加载Fragment基类
 * 实现延迟数据加载机制，只有当Fragment真正对用户可见时才加载数据
 */
abstract class LazyLoadFragment : Fragment() {
    
    // 标记是否已经加载过数据
    protected var isDataLoaded = false
    
    // 标记View是否已经创建
    private var isViewCreated = false
    
    override fun onViewCreated(view: android.view.View, savedInstanceState: android.os.Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        isViewCreated = true
    }
    
    override fun onResume() {
        super.onResume()
        // Fragment变为可见状态，检查是否需要首次加载数据
        checkAndLoadData()
    }
    
    /**
     * 检查并加载数据
     * 只有当Fragment对用户可见、View已创建且数据未加载时才执行数据加载
     */
    private fun checkAndLoadData() {
        if (isViewCreated && !isDataLoaded) {
            isDataLoaded = true
            loadData()
        }
    }
    
    /**
     * 强制重新加载数据
     * 用于下拉刷新等场景
     */
    protected fun forceReloadData() {
        if (isViewCreated) {
            loadData()
        }
    }
    
    /**
     * 重置数据加载状态
     * 用于需要重新触发懒加载的场景
     */
    protected fun resetDataLoadState() {
        isDataLoaded = false
        checkAndLoadData()
    }
    
    /**
     * 子类需要实现的数据加载方法
     * 在这个方法中执行网络请求、数据库查询等重量级操作
     */
    protected abstract fun loadData()
}