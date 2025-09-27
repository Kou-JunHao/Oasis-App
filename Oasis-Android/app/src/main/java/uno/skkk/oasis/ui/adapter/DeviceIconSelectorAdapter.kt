package uno.skkk.oasis.ui.adapter

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.R
import uno.skkk.oasis.data.model.DeviceIconType
import uno.skkk.oasis.databinding.ItemDeviceIconSelectorBinding

class DeviceIconSelectorAdapter(
    private val iconTypes: List<DeviceIconType>,
    private val onIconSelected: (DeviceIconType) -> Unit
) : RecyclerView.Adapter<DeviceIconSelectorAdapter.IconViewHolder>() {

    private var selectedIconType: DeviceIconType = DeviceIconType.WATER_DISPENSER

    fun setSelectedIcon(iconType: DeviceIconType) {
        val oldPosition = iconTypes.indexOf(selectedIconType)
        val newPosition = iconTypes.indexOf(iconType)
        
        selectedIconType = iconType
        
        if (oldPosition != -1) {
            notifyItemChanged(oldPosition)
        }
        if (newPosition != -1) {
            notifyItemChanged(newPosition)
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): IconViewHolder {
        val binding = ItemDeviceIconSelectorBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return IconViewHolder(binding)
    }

    override fun onBindViewHolder(holder: IconViewHolder, position: Int) {
        holder.bind(iconTypes[position])
    }

    override fun getItemCount(): Int = iconTypes.size

    inner class IconViewHolder(
        private val binding: ItemDeviceIconSelectorBinding
    ) : RecyclerView.ViewHolder(binding.root) {

        fun bind(iconType: DeviceIconType) {
            binding.apply {
                ivIcon.setImageResource(iconType.iconRes)
                tvIconName.text = iconType.displayName
                
                // 设置选中状态
                val isSelected = iconType == selectedIconType
                if (isSelected) {
                    root.strokeColor = ContextCompat.getColor(root.context, R.color.md_theme_primary)
                    root.setCardBackgroundColor(
                        ContextCompat.getColor(root.context, R.color.md_theme_primary_container)
                    )
                    ivIcon.setColorFilter(
                        ContextCompat.getColor(root.context, R.color.md_theme_on_primary_container)
                    )
                    tvIconName.setTextColor(
                        ContextCompat.getColor(root.context, R.color.md_theme_on_primary_container)
                    )
                } else {
                    root.strokeColor = ContextCompat.getColor(root.context, android.R.color.transparent)
                    root.setCardBackgroundColor(
                        ContextCompat.getColor(root.context, R.color.md_theme_surface)
                    )
                    ivIcon.setColorFilter(
                        ContextCompat.getColor(root.context, R.color.md_theme_on_surface_variant)
                    )
                    tvIconName.setTextColor(
                        ContextCompat.getColor(root.context, R.color.md_theme_on_surface_variant)
                    )
                }
                
                root.setOnClickListener {
                    if (selectedIconType != iconType) {
                        setSelectedIcon(iconType)
                        onIconSelected(iconType)
                    }
                }
            }
        }
    }
}