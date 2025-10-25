package uno.skkk.oasis.ui.wallet

import android.app.AlertDialog
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.viewpager2.widget.ViewPager2
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import uno.skkk.oasis.R
import uno.skkk.oasis.data.model.PaymentChannel
import uno.skkk.oasis.databinding.FragmentRechargeBinding
import uno.skkk.oasis.ui.wallet.adapter.PaymentChannelAdapter
import uno.skkk.oasis.ui.wallet.adapter.RechargeProductAdapter
import uno.skkk.oasis.data.model.Device
import uno.skkk.oasis.data.model.WalletInfo
import uno.skkk.oasis.data.model.AlipayPaymentData
import uno.skkk.oasis.ui.wallet.adapter.DeviceSelectionAdapter
import uno.skkk.oasis.ui.recharge.WalletSelectionAdapter
import uno.skkk.oasis.payment.AlipayManager

@AndroidEntryPoint
class RechargeFragment : Fragment() {

    private var _binding: FragmentRechargeBinding? = null
    private val binding get() = _binding!!

    private val viewModel: RechargeViewModel by viewModels()
    
    private lateinit var rechargeProductAdapter: RechargeProductAdapter
    private lateinit var paymentChannelAdapter: PaymentChannelAdapter
    private lateinit var walletSelectionAdapter: WalletSelectionAdapter
    private lateinit var alipayManager: AlipayManager
    
    private var selectedAmount: Double = 0.0
    private var selectedProductId: String = ""
    private var selectedPaymentChannel: PaymentChannel? = null
    private var selectedWallet: WalletInfo? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentRechargeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        alipayManager = AlipayManager()
        setupBackPressedHandler()
        setupRecyclerViews()
        setupClickListeners()
        observeViewModel()
    }

    private fun setupBackPressedHandler() {
        // 处理系统返回键
        val callback = object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // 检查是否在Activity中，如果是则关闭Activity
                if (parentFragmentManager.backStackEntryCount == 0) {
                    requireActivity().finish()
                } else {
                    parentFragmentManager.popBackStack()
                }
            }
        }
        requireActivity().onBackPressedDispatcher.addCallback(viewLifecycleOwner, callback)
    }

    private fun setupRecyclerViews() {
        // 设置钱包选择列表
        walletSelectionAdapter = WalletSelectionAdapter { wallet ->
            selectedWallet = wallet
            walletSelectionAdapter.updateSelectedWallet(wallet.id)
            updateOneClickRechargeButtonState()
        }
        // 设置钱包选择ViewPager2
        binding.vpWalletSelection.apply {
            adapter = walletSelectionAdapter
            orientation = ViewPager2.ORIENTATION_VERTICAL
            // 添加页面变化监听器
            registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                override fun onPageSelected(position: Int) {
                    super.onPageSelected(position)
                    // 更新钱包计数器
                    updateWalletCounter(position + 1, walletSelectionAdapter.itemCount)
                    // 更新选中的钱包
                    if (position < walletSelectionAdapter.itemCount) {
                        val wallet = walletSelectionAdapter.getWalletAt(position)
                        selectedWallet = wallet
                        updateOneClickRechargeButtonState()
                    }
                }
            })
        }
        
        // 设置充值产品选择RecyclerView
        rechargeProductAdapter = RechargeProductAdapter { product ->
            selectedAmount = product.currentPrice
            selectedProductId = product.id
            updateOneClickRechargeButtonState()
        }
        
        binding.rvRechargeProducts.apply {
            layoutManager = GridLayoutManager(requireContext(), 2)
            adapter = rechargeProductAdapter
        }

        // 设置支付方式选择RecyclerView（如果存在的话）
        paymentChannelAdapter = PaymentChannelAdapter { channel ->
            selectedPaymentChannel = channel
            binding.btnRecharge.isEnabled = selectedPaymentChannel != null
        }
    }

    private fun setupClickListeners() {
        // 设置SimpleTitle
        binding.simpleTitle.setTitle("钱包充值")
        
        // 充值按钮 - 统一处理逻辑
        binding.btnRecharge.setOnClickListener {
            // 验证钱包选择
            if (selectedWallet == null) {
                Toast.makeText(requireContext(), "请选择充值钱包", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            
            // 验证充值金额
            if (selectedAmount <= 0 || selectedProductId.isEmpty()) {
                Toast.makeText(requireContext(), "请选择充值金额", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            
            // 验证钱包ID
            val walletId = selectedWallet?.id
            if (walletId.isNullOrEmpty()) {
                Toast.makeText(requireContext(), "钱包ID无效", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            
            // 显示支付状态提示
            // 已移除提示栏组件
            
            // 发起一键充值（支付宝支付）
            lifecycleScope.launch {
                viewModel.oneClickRecharge(
                    productId = selectedProductId,
                    walletId = walletId
                )
            }
        }
        
        // 添加设备按钮
        binding.btnAddDevice.setOnClickListener {
            // TODO: 跳转到添加设备页面
            Toast.makeText(requireContext(), "跳转到添加设备页面", Toast.LENGTH_SHORT).show()
        }
    }
    
    private fun updateOneClickRechargeButtonState() {
        binding.btnRecharge.isEnabled = 
            selectedWallet != null && 
            selectedAmount > 0 && 
            selectedProductId.isNotEmpty()
    }

    private fun observeViewModel() {
        // 观察钱包列表
        lifecycleScope.launch {
            viewModel.walletList.collect { wallets ->
                if (wallets.isEmpty()) {
                    // 显示无设备提示
                    binding.vpWalletSelection.visibility = View.GONE
                    binding.layoutEmptyWallet.visibility = View.VISIBLE
                } else {
                    // 显示钱包列表
                    binding.vpWalletSelection.visibility = View.VISIBLE
                    binding.layoutEmptyWallet.visibility = View.GONE
                    
                    walletSelectionAdapter.submitList(wallets)
                    
                    // 初始化钱包计数器
                    updateWalletCounter(1, wallets.size)
                    
                    // 如果只有一个钱包，自动选择
                    if (wallets.size == 1) {
                        selectedWallet = wallets.first()
                        walletSelectionAdapter.updateSelectedWallet(wallets.first().id)
                        updateOneClickRechargeButtonState()
                    }
                }
            }
        }
        
        // 观察UI状态
        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                when {
                    state.isLoading -> {
                        binding.progressBar.visibility = View.VISIBLE
                        // 已移除提示栏组件
                        binding.btnRecharge.isEnabled = false
                    }
                    state.errorMessage != null -> {
                        binding.progressBar.visibility = View.GONE
                        // 已移除提示栏组件
                        binding.btnRecharge.isEnabled = true
                        Toast.makeText(requireContext(), state.errorMessage, Toast.LENGTH_LONG).show()
                        viewModel.clearError()
                        updateOneClickRechargeButtonState()
                    }
                    else -> {
                        binding.progressBar.visibility = View.GONE
                        // 已移除提示栏组件
                        binding.btnRecharge.isEnabled = true
                        updateOneClickRechargeButtonState()
                    }
                }
            }
        }
        
        // 观察充值产品列表
        lifecycleScope.launch {
            viewModel.rechargeProducts.collect { products ->
                rechargeProductAdapter.submitList(products)
            }
        }
        

        
        // 观察支付渠道
        lifecycleScope.launch {
            viewModel.paymentChannels.collect { channelsResponse ->
                channelsResponse?.let {
                    paymentChannelAdapter.submitList(it.channels)
                }
            }
        }
        
        // 观察支付宝支付数据
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.alipayPaymentData.collect { paymentData ->
                paymentData?.let {
                    // 更新状态提示
                    binding.progressBar.visibility = View.VISIBLE
                    // 已移除提示栏组件
                    binding.btnRecharge.isEnabled = false
                    
                    // 处理支付宝支付
                    processAlipayPayment(it.paymentString)
                }
            }
        }
    }



    private fun processAlipayPayment(paymentString: String) {
        // 创建AlipayPaymentData对象
        val paymentData = AlipayPaymentData.fromApiResponse(paymentString)
        
        alipayManager.pay(
            activity = requireActivity(),
            paymentData = paymentData,
            callback = object : AlipayManager.PaymentCallback {
                override fun onPaymentSuccess(result: AlipayManager.PaymentResult) {
                    requireActivity().runOnUiThread {
                        // 显示支付成功状态
                        binding.progressBar.visibility = View.GONE
                        // 已移除提示栏组件
                        binding.btnRecharge.isEnabled = true
                        
                        Toast.makeText(requireContext(), "支付成功！", Toast.LENGTH_SHORT).show()
                        
                        // 支付成功后重置支付数据并可能刷新余额
                        viewModel.resetPaymentData()
                        
                        // 3秒后重置提示文本
                        binding.root.postDelayed({
                            // 已移除提示栏组件
                            updateOneClickRechargeButtonState()
                        }, 3000)
                        
                        // TODO: 可以添加刷新钱包余额的逻辑
                    }
                }
                
                override fun onPaymentFailed(result: AlipayManager.PaymentResult) {
                    requireActivity().runOnUiThread {
                        // 显示支付失败状态
                        binding.progressBar.visibility = View.GONE
                        // 已移除提示栏组件
                        binding.btnRecharge.isEnabled = true
                        
                        Toast.makeText(
                            requireContext(), 
                            "支付失败：${result.memo}", 
                            Toast.LENGTH_SHORT
                        ).show()
                        
                        viewModel.resetPaymentData()
                        
                        // 5秒后重置提示文本
                        binding.root.postDelayed({
                            // 已移除提示栏组件
                            updateOneClickRechargeButtonState()
                        }, 5000)
                    }
                }
                
                override fun onPaymentCancelled(result: AlipayManager.PaymentResult) {
                    requireActivity().runOnUiThread {
                        // 显示支付取消状态
                        binding.progressBar.visibility = View.GONE
                        // 已移除提示栏组件
                        binding.btnRecharge.isEnabled = true
                        
                        Toast.makeText(requireContext(), "支付已取消", Toast.LENGTH_SHORT).show()
                        
                        viewModel.resetPaymentData()
                        
                        // 3秒后重置提示文本
                        binding.root.postDelayed({
                            // 已移除提示栏组件
                            updateOneClickRechargeButtonState()
                        }, 3000)
                    }
                }
                
                override fun onPaymentUnknown(result: AlipayManager.PaymentResult) {
                    requireActivity().runOnUiThread {
                        // 显示支付结果未知状态
                        binding.progressBar.visibility = View.GONE
                        // 已移除提示栏组件
                        binding.btnRecharge.isEnabled = true
                        
                        Toast.makeText(requireContext(), "支付结果未知，请稍后查询订单状态", Toast.LENGTH_SHORT).show()
                        
                        viewModel.resetPaymentData()
                        
                        // 5秒后重置提示文本
                        binding.root.postDelayed({
                            // 已移除提示栏组件
                            updateOneClickRechargeButtonState()
                        }, 5000)
                    }
                }
            }
        )
    }

    private fun updateWalletCounter(currentPosition: Int, totalCount: Int) {
        binding.tvWalletCounter.text = "$currentPosition/$totalCount"
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    companion object {
        fun newInstance() = RechargeFragment()
    }
}