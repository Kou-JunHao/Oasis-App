package uno.skkk.oasis.ui.recharge

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.data.model.WalletInfo
import uno.skkk.oasis.databinding.ItemWalletSelectionBinding

class WalletSelectionAdapter(
    private val onWalletSelected: (WalletInfo) -> Unit
) : ListAdapter<WalletInfo, WalletSelectionAdapter.WalletViewHolder>(WalletDiffCallback()) {

    private var selectedWalletId: String? = null

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): WalletViewHolder {
        val binding = ItemWalletSelectionBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return WalletViewHolder(binding)
    }

    override fun onBindViewHolder(holder: WalletViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    fun updateSelectedWallet(walletId: String?) {
        val oldSelectedId = selectedWalletId
        selectedWalletId = walletId
        
        // 更新之前选中的项
        if (oldSelectedId != null) {
            val oldIndex = currentList.indexOfFirst { it.id == oldSelectedId }
            if (oldIndex != -1) {
                notifyItemChanged(oldIndex)
            }
        }
        
        // 更新新选中的项
        if (walletId != null) {
            val newIndex = currentList.indexOfFirst { it.id == walletId }
            if (newIndex != -1) {
                notifyItemChanged(newIndex)
            }
        }
    }

    inner class WalletViewHolder(
        private val binding: ItemWalletSelectionBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        init {
            binding.root.setOnClickListener {
                val position = bindingAdapterPosition
                if (position != RecyclerView.NO_POSITION) {
                    val wallet = getItem(position)
                    onWalletSelected(wallet)
                }
            }
        }

        fun bind(wallet: WalletInfo) {
            binding.apply {
                tvWalletName.text = wallet.name
                tvDeviceCount.text = "${wallet.deviceCount} 台设备"
                tvWalletBalance.text = "余额: ¥${String.format("%.2f", wallet.balance)}"
                rbWalletSelected.isChecked = wallet.id == selectedWalletId
                
                // 更新卡片选中状态样式
                root.isSelected = wallet.id == selectedWalletId
            }
        }
    }

    fun getWalletAt(position: Int): WalletInfo {
        return getItem(position)
    }

    private class WalletDiffCallback : DiffUtil.ItemCallback<WalletInfo>() {
        override fun areItemsTheSame(oldItem: WalletInfo, newItem: WalletInfo): Boolean {
            return oldItem.id == newItem.id
        }

        override fun areContentsTheSame(oldItem: WalletInfo, newItem: WalletInfo): Boolean {
            return oldItem == newItem
        }
    }
}