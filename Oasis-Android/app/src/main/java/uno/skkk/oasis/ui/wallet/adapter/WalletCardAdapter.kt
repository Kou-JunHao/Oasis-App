package uno.skkk.oasis.ui.wallet.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.data.model.WalletInfo
import uno.skkk.oasis.databinding.ItemWalletCardBinding
import java.text.SimpleDateFormat
import java.util.*

class WalletCardAdapter(
    private val onRefreshClick: (WalletInfo) -> Unit
) : ListAdapter<WalletInfo, WalletCardAdapter.WalletCardViewHolder>(WalletDiffCallback()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): WalletCardViewHolder {
        val binding = ItemWalletCardBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return WalletCardViewHolder(binding, onRefreshClick)
    }

    override fun onBindViewHolder(holder: WalletCardViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    class WalletCardViewHolder(
        private val binding: ItemWalletCardBinding,
        private val onRefreshClick: (WalletInfo) -> Unit
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(wallet: WalletInfo) {
            binding.apply {
                tvWalletName.text = wallet.name
                tvWalletBalance.text = String.format("%.2f", wallet.balance)
                tvLastUpdateTime.text = "最后更新: ${getCurrentTime()}"
                
                btnRefreshBalance.setOnClickListener {
                    onRefreshClick(wallet)
                }
            }
        }
        
        private fun getCurrentTime(): String {
            val formatter = SimpleDateFormat("MM-dd HH:mm", Locale.getDefault())
            return formatter.format(Date())
        }
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