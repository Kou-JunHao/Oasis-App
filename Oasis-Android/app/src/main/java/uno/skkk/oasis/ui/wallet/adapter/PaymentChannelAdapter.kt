package uno.skkk.oasis.ui.wallet.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.R
import uno.skkk.oasis.data.model.PaymentChannel
import uno.skkk.oasis.databinding.ItemPaymentChannelBinding

class PaymentChannelAdapter(
    private val onChannelSelected: (PaymentChannel) -> Unit
) : ListAdapter<PaymentChannel, PaymentChannelAdapter.ViewHolder>(
    PaymentChannelDiffCallback()
) {

    private var selectedPosition = -1

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemPaymentChannelBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position), position == selectedPosition)
    }

    fun clearSelection() {
        val previousPosition = selectedPosition
        selectedPosition = -1
        if (previousPosition != -1) {
            notifyItemChanged(previousPosition)
        }
    }

    inner class ViewHolder(
        private val binding: ItemPaymentChannelBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(channel: PaymentChannel, isSelected: Boolean) {
            binding.textChannelName.text = channel.name
            
            // 根据支付类型设置图标
            val iconRes = when (channel.type) {
                21 -> R.drawable.ic_alipay // 支付宝图标
                41 -> R.drawable.ic_unionpay // 云闪付图标
                else -> R.drawable.ic_payment_default // 默认支付图标
            }
            binding.imageChannelIcon.setImageResource(iconRes)
            
            // 设置选中状态的视觉效果
            binding.root.isSelected = isSelected
            binding.imageSelectedIndicator.visibility = if (isSelected) {
                android.view.View.VISIBLE
            } else {
                android.view.View.GONE
            }
            
            // 设置点击事件
            binding.root.setOnClickListener {
                val previousPosition = selectedPosition
                selectedPosition = adapterPosition
                
                // 更新之前选中的项目
                if (previousPosition != -1) {
                    notifyItemChanged(previousPosition)
                }
                // 更新当前选中的项目
                notifyItemChanged(selectedPosition)
                
                onChannelSelected(channel)
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