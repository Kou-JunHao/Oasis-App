package uno.skkk.oasis.ui.order

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.R
import uno.skkk.oasis.data.model.Order
import uno.skkk.oasis.databinding.ItemOrderBinding
import java.text.SimpleDateFormat
import java.util.*

/**
 * 订单列表适配器 */
class OrderAdapter(
    private val onOrderClick: (Order) -> Unit
) : ListAdapter<Order, OrderAdapter.OrderViewHolder>(OrderDiffCallback()) {
    
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): OrderViewHolder {
        val binding = ItemOrderBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return OrderViewHolder(binding)
    }
    
    override fun onBindViewHolder(holder: OrderViewHolder, position: Int) {
        holder.bind(getItem(position))
    }
    
    inner class OrderViewHolder(
        private val binding: ItemOrderBinding
    ) : RecyclerView.ViewHolder(binding.root) {
        
        fun bind(order: Order) {
            binding.apply {
                // 订单编号
                textOrderId.text = "订单号: ${order.id}"
                
                // 订单金额
                textOrderAmount.text = order.getFormattedAmount()
                
                // 订单状态
                textOrderStatus.text = order.getStatusText()
                
                // 根据状态设置颜色
                val statusColor = when (order.status) {
                    1 -> ContextCompat.getColor(root.context, R.color.orange) // 未付款
                    2 -> ContextCompat.getColor(root.context, R.color.blue)   // 待确认
                    3 -> ContextCompat.getColor(root.context, R.color.green)  // 已付款
                    4 -> ContextCompat.getColor(root.context, R.color.red)    // 订单失败
                    9 -> ContextCompat.getColor(root.context, R.color.gray)   // 已取消
                    else -> ContextCompat.getColor(root.context, R.color.black)
                }
                textOrderStatus.setTextColor(statusColor)
                
                // 设备信息
                textDeviceInfo.text = "设备: ${order.getDeviceName()}"
                
                // 订单类型
                textOrderType.text = order.getTypeText()
                
                // 创建时间
                textOrderTime.text = formatTime(order.createTime)
                
                // 设备信息（从消息中提取）
                textDeviceInfo.text = "设备: ${order.getDeviceName()}"
                textDeviceInfo.visibility = View.VISIBLE
                
                // 移除点击事件，订单卡片不可点击
                root.setOnClickListener(null)
                root.isClickable = false
            }
        }
        
        private fun formatTime(timestamp: Long): String {
            val date = Date(timestamp) // API返回的已经是毫秒级时间戳
            val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
            return formatter.format(date)
        }
    }
    
    /**
     * 更新订单列表
     */
    fun updateOrders(orders: List<Order>) {
        submitList(orders)
    }
    
    private class OrderDiffCallback : DiffUtil.ItemCallback<Order>() {
        override fun areItemsTheSame(oldItem: Order, newItem: Order): Boolean {
            return oldItem.id == newItem.id
        }
        
        override fun areContentsTheSame(oldItem: Order, newItem: Order): Boolean {
            return oldItem == newItem
        }
    }
}
