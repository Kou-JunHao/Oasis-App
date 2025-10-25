package uno.skkk.oasis.ui.wallet

import android.content.Intent
import android.os.Bundle

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.viewpager2.widget.ViewPager2
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.FragmentWalletBinding
import uno.skkk.oasis.ui.components.UnifiedTopBar
import uno.skkk.oasis.ui.recharge.RechargeActivity
import uno.skkk.oasis.ui.base.LazyLoadFragment
import uno.skkk.oasis.ui.wallet.adapter.WalletCardAdapter
import uno.skkk.oasis.data.model.WalletInfo
import uno.skkk.oasis.ui.base.UserManager
import uno.skkk.oasis.data.repository.WalletRepository
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class WalletFragment : LazyLoadFragment() {
    
    private var _binding: FragmentWalletBinding? = null
    private val binding get() = _binding!!
    
    private val viewModel: WalletViewModel by viewModels()
    private val rechargeViewModel: RechargeViewModel by viewModels()
    private var isFirstLoad = true
    
    @Inject
    lateinit var userManager: UserManager
    
    @Inject
    lateinit var walletRepository: WalletRepository
    
    private lateinit var walletCardAdapter: WalletCardAdapter
    private var currentWalletIndex = 0
    
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
        rechargeViewModel.loadDeviceList() // 加载钱包列表
        isFirstLoad = false
    }
    
    override fun onResume() {
        super.onResume()
        // 页面切换时静默刷新钱包数据，不显示LoadingIndicator
        if (!isFirstLoad && isDataLoaded) {
            loadWalletData(showLoading = false)
            rechargeViewModel.loadDeviceList() // 刷新钱包列表
        }
    }
    
    private fun updateWalletCounter() {
        val wallets = walletCardAdapter.currentList
        if (wallets.isNotEmpty()) {
            binding.tvWalletCounter.text = "${currentWalletIndex + 1}/${wallets.size}"
        } else {
            binding.tvWalletCounter.text = "0/0"
        }
    }
    
    private fun refreshWalletBalance(walletId: String) {
        lifecycleScope.launch {
            try {
                val token = userManager.getToken()
                if (token.isNullOrEmpty()) {
                    Toast.makeText(requireContext(), "请先登录", Toast.LENGTH_SHORT).show()
                    return@launch
                }

                val result = walletRepository.getWalletResponseData(token)
                result.fold(
                    onSuccess = { walletResponseData ->
                        // 找到对应的钱包索引
                        val walletIndex = rechargeViewModel.walletList.value.indexOfFirst { it.id == walletId }
                        
                        // 获取所有钱包数据
                        val allWalletData = walletResponseData.getAllWalletData()
                        val primaryWalletData = walletResponseData.getPrimaryWalletData()
                        
                        // 根据索引获取对应的钱包数据，如果索引无效则使用主钱包数据
                        val walletData = if (walletIndex >= 0 && walletIndex < allWalletData.size) {
                            allWalletData[walletIndex]
                        } else {
                            primaryWalletData
                        }
                        
                        // 更新钱包列表中对应钱包的余额
                        val updatedWallets = rechargeViewModel.walletList.value.map { wallet ->
                            if (wallet.id == walletId) {
                                wallet.copy(balance = walletData?.getDisplayBalance() ?: 0.0)
                            } else {
                                wallet
                            }
                        }
                        
                        // 通知适配器更新
                        walletCardAdapter.submitList(updatedWallets)
                        
                        Toast.makeText(requireContext(), "余额已刷新", Toast.LENGTH_SHORT).show()
                    },
                    onFailure = { exception ->
                        Toast.makeText(requireContext(), "刷新失败: ${exception.message}", Toast.LENGTH_SHORT).show()
                    }
                )
            } catch (e: Exception) {
                Toast.makeText(requireContext(), "刷新失败: ${e.message}", Toast.LENGTH_SHORT).show()
            }
        }
    }
    
    private fun setupTopBar() {
        binding.simpleTitle.setTitle("钱包")
    }
    
    private fun setupUI() {
        // 初始化钱包卡片适配器
        walletCardAdapter = WalletCardAdapter { wallet ->
            // 刷新特定钱包的余额
            refreshWalletBalance(wallet.id)
        }
        
        // 设置ViewPager2
        binding.vpWalletCards.apply {
            adapter = walletCardAdapter
            orientation = ViewPager2.ORIENTATION_VERTICAL
            
            // 监听页面变化
            registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                override fun onPageSelected(position: Int) {
                    super.onPageSelected(position)
                    currentWalletIndex = position
                    updateWalletCounter()
                }
            })
        }
        
        binding.apply {
            btnRecharge.setOnClickListener {
                showRechargeDialog()
            }
        }
    }
    
    private fun observeViewModel() {
        // 观察钱包列表数据
        lifecycleScope.launch {
            rechargeViewModel.walletList.collect { wallets ->
                if (wallets.isNotEmpty()) {
                    // 钱包列表更新成功
                    walletCardAdapter.submitList(wallets)
                    updateWalletCounter()
                    
                    // 计算并显示总余额
                    updateTotalBalance(wallets)
                    
                    // 如果只有一个钱包，自动选择
                    if (wallets.size == 1) {
                        currentWalletIndex = 0
                        binding.vpWalletCards.setCurrentItem(0, false)
                    }
                } else {
                    // 钱包列表为空
                    // 钱包列表为空时，总余额显示为0
                    binding.tvTotalBalance.text = "¥0.00"
                }
            }
        }
        
        // 观察原有的钱包余额数据（兼容性保留）
        lifecycleScope.launch {
            viewModel.walletData.collect { walletData ->
                if (walletData != null) {
                    // 显示钱包余额
                } else {
                    // 钱包数据为空
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
                    // 显示错误信息
                    Toast.makeText(requireContext(), errorMessage, Toast.LENGTH_SHORT).show()
                    viewModel.clearError()
                }
            }
        }
    }
    
    /**
     * 计算并更新总余额显示
     */
    private fun updateTotalBalance(wallets: List<WalletInfo>) {
        val totalBalance = wallets.sumOf { it.balance }
        binding.tvTotalBalance.text = "¥%.2f".format(totalBalance)
        // 更新总余额显示
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
