package uno.skkk.oasis.ui.wallet.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.data.model.RechargeAmount
import uno.skkk.oasis.databinding.ItemRechargeAmountBinding

class RechargeAmountAdapter(
    private val onAmountSelected: (RechargeAmount) -> Unit
) : ListAdapter<RechargeAmount, RechargeAmountAdapter.ViewHolder>(
    RechargeAmountDiffCallback()
) {

    private var selectedPosition = -1

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemRechargeAmountBinding.inflate(
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
        private val binding: ItemRechargeAmountBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(amount: RechargeAmount, isSelected: Boolean) {
            binding.textAmount.text = "¥${String.format("%.0f", amount.amount)}"
            
            // 设置选中状态的视觉效果
            binding.root.isSelected = isSelected
            binding.root.alpha = if (isSelected) 1.0f else 0.7f
            
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
                
                onAmountSelected(amount)
            }
        }
    }

    private class RechargeAmountDiffCallback : DiffUtil.ItemCallback<RechargeAmount>() {
        override fun areItemsTheSame(oldItem: RechargeAmount, newItem: RechargeAmount): Boolean {
            return oldItem.amount == newItem.amount
        }

        override fun areContentsTheSame(oldItem: RechargeAmount, newItem: RechargeAmount): Boolean {
            return oldItem == newItem
        }
    }
}