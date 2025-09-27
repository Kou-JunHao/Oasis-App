package uno.skkk.oasis.ui.wallet

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.R
import uno.skkk.oasis.data.model.PaymentChannel
import uno.skkk.oasis.databinding.ItemPaymentChannelBinding

class PaymentChannelAdapter(
    private val onChannelClick: (PaymentChannel) -> Unit
) : ListAdapter<PaymentChannel, PaymentChannelAdapter.PaymentChannelViewHolder>(
    PaymentChannelDiffCallback()
) {

    private var selectedChannelId: Int? = null

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): PaymentChannelViewHolder {
        val binding = ItemPaymentChannelBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return PaymentChannelViewHolder(binding)
    }

    override fun onBindViewHolder(holder: PaymentChannelViewHolder, position: Int) {
        val channel = getItem(position)
        val isSelected = channel.type == selectedChannelId
        holder.bind(channel, isSelected)
    }

    fun setSelectedChannel(channelId: Int?) {
        val oldSelectedPosition = currentList.indexOfFirst { it.type == selectedChannelId }
        val newSelectedPosition = currentList.indexOfFirst { it.type == channelId }
        
        selectedChannelId = channelId
        
        if (oldSelectedPosition != -1) {
            notifyItemChanged(oldSelectedPosition)
        }
        if (newSelectedPosition != -1) {
            notifyItemChanged(newSelectedPosition)
        }
    }

    inner class PaymentChannelViewHolder(
        private val binding: ItemPaymentChannelBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(channel: PaymentChannel, isSelected: Boolean) {
            binding.textChannelName.text = channel.name
            
            // 设置支付渠道图标
            val iconRes = when (channel.type) {
                1 -> R.drawable.ic_alipay  // 支付宝
                2 -> R.drawable.ic_unionpay  // 银联
                else -> R.drawable.ic_payment_default
            }
            binding.imageChannelIcon.setImageResource(iconRes)
            
            // 控制选中状态显示
            binding.imageSelectedIndicator.visibility = if (isSelected) View.VISIBLE else View.GONE
            
            // 设置点击事件
            binding.root.setOnClickListener {
                onChannelClick(channel)
            }
        }
    }

    private class PaymentChannelDiffCallback : DiffUtil.ItemCallback<PaymentChannel>() {
        override fun areItemsTheSame(oldItem: PaymentChannel, newItem: PaymentChannel): Boolean {
            return oldItem.type == newItem.type
        }

        override fun areContentsTheSame(oldItem: PaymentChannel, newItem: PaymentChannel): Boolean {
            return oldItem == newItem
        }
    }
}