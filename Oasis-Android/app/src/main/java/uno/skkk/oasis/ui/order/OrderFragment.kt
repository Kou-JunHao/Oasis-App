package uno.skkk.oasis.ui.order

import android.os.Bundle
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.color.MaterialColors
import com.google.android.material.tabs.TabLayout
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.FragmentOrderBinding
import uno.skkk.oasis.ui.components.UnifiedTopBar
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

@AndroidEntryPoint
class OrderFragment : Fragment() {
    
    private var _binding: FragmentOrderBinding? = null
    private val binding get() = _binding!!
    
    private val viewModel: OrderViewModel by viewModels()
    private lateinit var orderAdapter: OrderAdapter
    private var isFirstLoad = true
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentOrderBinding.inflate(inflater, container, false)
        return binding.root
    }
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        setupTopBar()
        setupUI()
        setupRecyclerView()
        setupSwipeRefresh()
        observeViewModel()
        loadOrders() // 首次加载，显示LoadingIndicator
        isFirstLoad = false
    }
    
    override fun onResume() {
        super.onResume()
        // 只在非首次加载时静默刷新数据（不显示LoadingIndicator）
        if (!isFirstLoad) {
            loadOrders(showLoading = false)
        }
    }
    
    private fun setupTopBar() {
        binding.simpleTitle.setTitle("我的订单")
    }
    
    private fun setupUI() {
        binding.apply {
            // 筛选按钮点击事件
            buttonFilter.setOnClickListener {
                showFilterDialog()
            }
        }
    }
    
    private fun showFilterDialog() {
        val statusOptions = arrayOf("全部", "未付款", "已付款", "待确认", "订单失败", "已取消")
        val statusValues = arrayOf(null, 1, 3, 2, 4, 9)
        
        val builder = androidx.appcompat.app.AlertDialog.Builder(requireContext())
        builder.setTitle("筛选订单")
        builder.setItems(statusOptions) { _, which ->
            viewModel.loadOrdersByStatus(statusValues[which])
        }
        builder.show()
    }
    
    private fun setupRecyclerView() {
        orderAdapter = OrderAdapter { order ->
            // 订单卡片已设置为不可点击
        }
        
        binding.recyclerViewOrders.apply {
            layoutManager = LinearLayoutManager(requireContext())
            adapter = orderAdapter
        }
    }
    
    private fun setupSwipeRefresh() {
        binding.swipeRefreshLayout.setOnRefreshListener {
            loadOrders()
        }
        
        // 设置MD3E动态颜色主题
        val context = requireContext()
        
        // 使用MaterialColors获取MD3E颜色
        val colorPrimary = MaterialColors.getColor(context, android.R.attr.colorPrimary, 0)
        val colorAccent = MaterialColors.getColor(context, android.R.attr.colorAccent, 0)
        val colorBackground = MaterialColors.getColor(context, android.R.attr.colorBackground, 0)
        
        binding.swipeRefreshLayout.setColorSchemeColors(
            colorPrimary,
            colorAccent
        )
        
        binding.swipeRefreshLayout.setProgressBackgroundColorSchemeColor(colorBackground)
    }
    
    private fun observeViewModel() {
        lifecycleScope.launch {
            viewModel.orders.collect { orders ->
                orderAdapter.updateOrders(orders)
                updateEmptyState(orders.isEmpty())
            }
        }
        
        lifecycleScope.launch {
            viewModel.allOrders.collect { allOrders ->
                updateStatistics(allOrders)
            }
        }
        
        lifecycleScope.launch {
            viewModel.isLoading.collect { isLoading ->
                // 处理下拉刷新状态
                binding.swipeRefreshLayout.isRefreshing = isLoading
                
                // 只在非下拉刷新时显示进度条
                binding.progressIndicator.visibility = if (isLoading && !binding.swipeRefreshLayout.isRefreshing) View.VISIBLE else View.GONE
            }
        }
        
        lifecycleScope.launch {
            viewModel.errorMessage.collect { errorMessage ->
                if (errorMessage.isNotEmpty()) {
                    Toast.makeText(requireContext(), errorMessage, Toast.LENGTH_SHORT).show()
                    viewModel.clearError()
                }
            }
        }
    }
    
    private fun updateStatistics(orders: List<uno.skkk.oasis.data.model.Order>) {
        val totalOrders = orders.size
        
        // 计算本月订单数（简化版本，实际应该根据时间戳计算）
        val currentTime = System.currentTimeMillis() / 1000
        val monthAgo = currentTime - (30 * 24 * 60 * 60) // 30天前
        val monthOrders = orders.count { it.createTime > monthAgo }
        
        binding.textTotalOrders.text = totalOrders.toString()
        binding.textMonthOrders.text = monthOrders.toString()
    }
    
    private fun loadOrders(showLoading: Boolean = true) {
        viewModel.loadAllOrders(showLoading = showLoading)
    }
    
    private fun updateEmptyState(isEmpty: Boolean) {
        binding.emptyStateLayout.visibility = if (isEmpty) View.VISIBLE else View.GONE
        binding.recyclerViewOrders.visibility = if (isEmpty) View.GONE else View.VISIBLE
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
    
    companion object {
        fun newInstance() = OrderFragment()
    }
}
