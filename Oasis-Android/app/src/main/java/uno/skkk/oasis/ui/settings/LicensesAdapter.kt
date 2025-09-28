package uno.skkk.oasis.ui.settings

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.databinding.ItemLicenseBinding

class LicensesAdapter(
    private val onLicenseClick: (License) -> Unit
) : ListAdapter<License, LicensesAdapter.LicenseViewHolder>(LicenseDiffCallback()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): LicenseViewHolder {
        val binding = ItemLicenseBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return LicenseViewHolder(binding)
    }

    override fun onBindViewHolder(holder: LicenseViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    inner class LicenseViewHolder(
        private val binding: ItemLicenseBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(license: License) {
            binding.apply {
                textLibraryName.text = license.name
                textLicenseName.text = license.licenseName
                
                root.setOnClickListener {
                    onLicenseClick(license)
                }
            }
        }
    }

    private class LicenseDiffCallback : DiffUtil.ItemCallback<License>() {
        override fun areItemsTheSame(oldItem: License, newItem: License): Boolean {
            return oldItem.name == newItem.name
        }

        override fun areContentsTheSame(oldItem: License, newItem: License): Boolean {
            return oldItem == newItem
        }
    }
}