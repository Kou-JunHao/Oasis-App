package uno.skkk.oasis.ui.wallet

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.FragmentWalletBinding
import uno.skkk.oasis.ui.components.UnifiedTopBar
import uno.skkk.oasis.ui.recharge.RechargeActivity
import uno.skkk.oasis.ui.base.LazyLoadFragment
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch

@AndroidEntryPoint
class WalletFragment : LazyLoadFragment() {
    
    private var _binding: FragmentWalletBinding? = null
    private val binding get() = _binding!!
    
    private val viewModel: WalletViewModel by viewModels()
    private var isFirstLoad = true
    
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentWalletBinding.inflate(inflater, container, false)
        return binding.root
    }
    
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        setupTopBar()
        setupUI()
        observeViewModel()
        // 移除立即数据加载，改为懒加载机制
        // loadWalletData() 将在 loadData() 中调用
    }
    
    /**
     * 实现懒加载数据加载方法
     * 只有当Fragment对用户可见时才会调用此方法
     */
    override fun loadData() {
        loadWalletData() // 首次加载，显示LoadingIndicator
        isFirstLoad = false
    }
    
    override fun onResume() {
        super.onResume()
        // 页面切换时静默刷新钱包数据，不显示LoadingIndicator
        if (!isFirstLoad && isDataLoaded) {
            loadWalletData(showLoading = false)
        }
    }
    
    private fun setupTopBar() {
        binding.simpleTitle.setTitle("钱包")
    }
    
    private fun setupUI() {
        binding.apply {
            btnRecharge.setOnClickListener {
                showRechargeDialog()
            }
            
            btnRefreshBalance.setOnClickListener {
                viewModel.loadWalletBalance()
            }
            

        }
    }
    
    private fun observeViewModel() {
        lifecycleScope.launch {
            viewModel.walletData.collect { walletData ->
                if (walletData != null) {
                    // 添加调试日志
                    Log.d("WalletFragment", "原始余额数据: balance=${walletData.balance}, olCash=${walletData.olCash}")
                    val displayBalance = walletData.getDisplayBalance()
                    Log.d("WalletFragment", "显示余额: $displayBalance")
                    
                    binding.textWalletBalance.text = String.format("%.2f", displayBalance)
                    binding.textLastUpdateTime.text = "最后更新: ${getCurrentTime()}"
                } else {
                    // 当walletData为null时，检查是否有错误信息
                    Log.d("WalletFragment", "钱包数据为null")
                }
            }
        }
        
        lifecycleScope.launch {
            viewModel.isLoading.collect { isLoading ->
                binding.progressIndicator.visibility = if (isLoading) View.VISIBLE else View.GONE
            }
        }
        
        lifecycleScope.launch {
            viewModel.errorMessage.collect { errorMessage ->
                if (errorMessage.isNotEmpty()) {
                    // 当有错误时，显示错误信息并更新UI
                    Log.d("WalletFragment", "错误信息: $errorMessage")
                    binding.textWalletBalance.text = "获取失败"
                    binding.textLastUpdateTime.text = "更新失败: ${getCurrentTime()}"
                    Toast.makeText(requireContext(), errorMessage, Toast.LENGTH_SHORT).show()
                    viewModel.clearError()
                }
            }
        }
    }
    
    private fun loadWalletData(showLoading: Boolean = true) {
        viewModel.loadWalletBalance(showLoading = showLoading)
    }
    
    private fun showRechargeDialog() {
        // 启动充值Activity
        val intent = Intent(requireContext(), RechargeActivity::class.java)
        startActivity(intent)
    }

    private fun showPaymentDialog(amount: String) {
        // 这个方法现在由RechargeScreen处理
        // 保留以防需要向后兼容
    }
    
    private fun getCurrentTime(): String {
        val formatter = java.text.SimpleDateFormat("MM-dd HH:mm", java.util.Locale.getDefault())
        return formatter.format(java.util.Date())
    }
    
    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
    
    companion object {
        fun newInstance() = WalletFragment()
    }
}
