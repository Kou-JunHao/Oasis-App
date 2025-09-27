package uno.skkk.oasis.ui.wallet.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.data.model.Product
import uno.skkk.oasis.databinding.ItemRechargeProductBinding

class RechargeProductAdapter(
    private val onProductSelected: (Product) -> Unit
) : ListAdapter<Product, RechargeProductAdapter.ViewHolder>(
    RechargeProductDiffCallback()
) {

    private var selectedPosition = -1

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemRechargeProductBinding.inflate(
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
        private val binding: ItemRechargeProductBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(product: Product, isSelected: Boolean) {
            // 设置产品名称
            binding.textProductName.text = product.name
            
            // 设置金额
            binding.textAmount.text = "¥${String.format("%.0f", product.currentPrice)}"
            
            // 处理优惠信息
            var hasOffers = false
            
            // 根据mode字段判断是否有优惠：mode=2表示有优惠，mode=1表示普通充值
            val hasDiscount = product.mode == 2 && product.hasDiscount()
            
            // 显示折扣信息（如果有优惠）
            if (hasDiscount) {
                val discountAmount = product.getDiscountAmount()
                binding.textDiscount.text = "优惠¥${String.format("%.0f", discountAmount)}"
                binding.textDiscount.visibility = View.VISIBLE
                hasOffers = true
            } else {
                binding.textDiscount.visibility = View.GONE
            }
            
            // 显示赠送金额（使用优惠金额）
            if (hasDiscount) {
                val discountAmount = product.getDiscountAmount()
                binding.textBonus.text = "送¥${String.format("%.0f", discountAmount)}"
                binding.textBonus.visibility = View.VISIBLE
                hasOffers = true
            } else {
                binding.textBonus.visibility = View.GONE
            }
            
            // 显示产品描述
            if (product.description.isNotEmpty()) {
                binding.textGift.text = product.description
                binding.textGift.visibility = View.VISIBLE
                hasOffers = true
            } else {
                binding.textGift.visibility = View.GONE
            }
            
            // 显示或隐藏优惠信息容器
            binding.layoutOffers.visibility = if (hasOffers) View.VISIBLE else View.GONE
            
            // 设置选中状态的视觉效果
            binding.root.isSelected = isSelected
            binding.root.alpha = if (isSelected) 1.0f else 0.7f
            binding.viewSelectedIndicator.visibility = if (isSelected) View.VISIBLE else View.INVISIBLE
            
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
                
                onProductSelected(product)
            }
        }
    }

    private class RechargeProductDiffCallback : DiffUtil.ItemCallback<Product>() {
        override fun areItemsTheSame(oldItem: Product, newItem: Product): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(oldItem: Product, newItem: Product): Boolean {
            return oldItem == newItem
        }
    }
}