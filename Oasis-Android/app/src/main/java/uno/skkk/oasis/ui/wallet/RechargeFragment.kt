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
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import uno.skkk.oasis.R
import uno.skkk.oasis.data.model.PaymentChannel
import uno.skkk.oasis.databinding.FragmentRechargeBinding
import uno.skkk.oasis.ui.wallet.adapter.PaymentChannelAdapter
import uno.skkk.oasis.ui.wallet.adapter.RechargeProductAdapter
import uno.skkk.oasis.data.model.AlipayPaymentData
import uno.skkk.oasis.payment.AlipayManager

@AndroidEntryPoint
class RechargeFragment : Fragment() {

    private var _binding: FragmentRechargeBinding? = null
    private val binding get() = _binding!!

    private val viewModel: RechargeViewModel by viewModels()
    
    private lateinit var rechargeProductAdapter: RechargeProductAdapter
    private lateinit var paymentChannelAdapter: PaymentChannelAdapter
    private lateinit var alipayManager: AlipayManager
    
    private var selectedAmount: Double = 0.0
    private var selectedProductId: String = ""
    private var selectedPaymentChannel: PaymentChannel? = null

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
        // 设置充值产品选择RecyclerView
        rechargeProductAdapter = RechargeProductAdapter { product ->
            selectedAmount = product.currentPrice
            selectedProductId = product.id
            binding.btnOneClickRecharge.isEnabled = selectedProductId.isNotEmpty()
            // 可以在这里更新UI显示选中的产品
        }
        
        binding.recyclerRechargeProducts.apply {
            layoutManager = GridLayoutManager(requireContext(), 2)
            adapter = rechargeProductAdapter
        }

        // 设置支付方式选择RecyclerView
        paymentChannelAdapter = PaymentChannelAdapter { channel ->
            selectedPaymentChannel = channel
            binding.btnRecharge.isEnabled = selectedPaymentChannel != null
            binding.tvPaymentHint.text = "已选择: ${channel.name}"
        }
        
        binding.rvPaymentMethods.apply {
            layoutManager = LinearLayoutManager(requireContext())
            adapter = paymentChannelAdapter
        }
    }

    private fun setupClickListeners() {
        // 设置MaterialToolbar
        binding.toolbar.setNavigationOnClickListener {
            // 检查是否在Activity中，如果是则关闭Activity
            if (parentFragmentManager.backStackEntryCount == 0) {
                requireActivity().finish()
            } else {
                parentFragmentManager.popBackStack()
            }
        }
        
        binding.toolbar.setOnMenuItemClickListener { menuItem ->
            when (menuItem.itemId) {
                R.id.btn_refresh_amounts -> {
                    viewModel.refreshAll()
                    true
                }
                else -> false
            }
        }
        
        // 一键充值
        binding.btnOneClickRecharge.setOnClickListener {
            if (selectedProductId.isNotEmpty()) {
                // 显示支付状态提示
                binding.cardPaymentStatus.visibility = View.VISIBLE
                binding.tvPaymentStatusMessage.text = "正在创建订单..."
                
                // 调用一键充值方法
                viewModel.oneClickRecharge(selectedProductId)
            } else {
                Toast.makeText(requireContext(), "请选择充值产品", Toast.LENGTH_SHORT).show()
            }
        }
        
        // 发起支付
        binding.btnRecharge.setOnClickListener {
            val channel = selectedPaymentChannel
            if (channel != null) {
                // 根据支付渠道处理支付
                    when (selectedPaymentChannel?.type) {
                        21 -> { // 支付宝
                            viewModel.initiateAlipayPayment()
                        }
                        22 -> { // 银联
                            // TODO: 实现银联支付
                            Toast.makeText(requireContext(), "银联支付暂未实现", Toast.LENGTH_SHORT).show()
                        }
                        else -> {
                            Toast.makeText(requireContext(), "不支持的支付方式", Toast.LENGTH_SHORT).show()
                        }
                    }
            } else {
                Toast.makeText(requireContext(), "请选择支付方式", Toast.LENGTH_SHORT).show()
            }
        }
        

    }

    private fun observeViewModel() {
        // 观察UI状态
        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                binding.progressBar.visibility = if (state.isLoading) View.VISIBLE else View.GONE
                
                // 更新支付状态提示
                if (state.isLoading) {
                    binding.cardPaymentStatus.visibility = View.VISIBLE
                    if (state.currentOrder != null) {
                        binding.tvPaymentStatusMessage.text = "正在获取支付渠道..."
                    } else {
                        binding.tvPaymentStatusMessage.text = "正在创建订单..."
                    }
                } else {
                    // 如果没有错误且不在加载中，隐藏状态提示
                    if (state.errorMessage == null) {
                        binding.cardPaymentStatus.visibility = View.GONE
                    }
                }
                
                state.errorMessage?.let { message ->
                    // 显示错误状态
                    binding.cardPaymentStatus.visibility = View.VISIBLE
                    binding.tvPaymentStatusMessage.text = "充值失败：$message"
                    
                    Toast.makeText(requireContext(), message, Toast.LENGTH_LONG).show()
                    viewModel.clearError()
                    
                    // 3秒后隐藏错误提示
                    binding.root.postDelayed({
                        binding.cardPaymentStatus.visibility = View.GONE
                    }, 3000)
                }
                
                // 订单创建成功后更新状态提示
                if (state.currentOrder != null && state.isLoading) {
                    binding.tvPaymentStatusMessage.text = "订单创建成功，正在发起支付..."
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
                    binding.cardPaymentStatus.visibility = View.VISIBLE
                    binding.tvPaymentStatusMessage.text = "正在跳转支付宝..."
                    
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
                        binding.cardPaymentStatus.visibility = View.VISIBLE
                        binding.tvPaymentStatusMessage.text = "支付成功！"
                        
                        Toast.makeText(requireContext(), "支付成功！", Toast.LENGTH_SHORT).show()
                        
                        // 支付成功后重置支付数据并可能刷新余额
                        viewModel.resetPaymentData()
                        
                        // 3秒后隐藏状态提示
                        binding.root.postDelayed({
                            binding.cardPaymentStatus.visibility = View.GONE
                        }, 3000)
                        
                        // TODO: 可以添加刷新钱包余额的逻辑
                    }
                }
                
                override fun onPaymentFailed(result: AlipayManager.PaymentResult) {
                    requireActivity().runOnUiThread {
                        // 显示支付失败状态
                        binding.cardPaymentStatus.visibility = View.VISIBLE
                        binding.tvPaymentStatusMessage.text = "支付失败：${result.memo}"
                        
                        Toast.makeText(
                            requireContext(), 
                            "支付失败：${result.memo}", 
                            Toast.LENGTH_SHORT
                        ).show()
                        
                        viewModel.resetPaymentData()
                        
                        // 5秒后隐藏状态提示
                        binding.root.postDelayed({
                            binding.cardPaymentStatus.visibility = View.GONE
                        }, 5000)
                    }
                }
                
                override fun onPaymentCancelled(result: AlipayManager.PaymentResult) {
                    requireActivity().runOnUiThread {
                        // 显示支付取消状态
                        binding.cardPaymentStatus.visibility = View.VISIBLE
                        binding.tvPaymentStatusMessage.text = "支付已取消"
                        
                        Toast.makeText(requireContext(), "支付已取消", Toast.LENGTH_SHORT).show()
                        
                        viewModel.resetPaymentData()
                        
                        // 3秒后隐藏状态提示
                        binding.root.postDelayed({
                            binding.cardPaymentStatus.visibility = View.GONE
                        }, 3000)
                    }
                }
                
                override fun onPaymentUnknown(result: AlipayManager.PaymentResult) {
                    requireActivity().runOnUiThread {
                        // 显示支付结果未知状态
                        binding.cardPaymentStatus.visibility = View.VISIBLE
                        binding.tvPaymentStatusMessage.text = "支付结果未知，请稍后查询订单状态"
                        
                        Toast.makeText(requireContext(), "支付结果未知，请稍后查询订单状态", Toast.LENGTH_SHORT).show()
                        
                        viewModel.resetPaymentData()
                        
                        // 5秒后隐藏状态提示
                        binding.root.postDelayed({
                            binding.cardPaymentStatus.visibility = View.GONE
                        }, 5000)
                    }
                }
            }
        )
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    companion object {
        fun newInstance() = RechargeFragment()
    }
}