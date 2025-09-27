package uno.skkk.oasis.ui.components

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.LinearLayout
import android.widget.TextView
import uno.skkk.oasis.databinding.LayoutSimpleTitleBinding

/**
 * 简单的纯文字标题组件
 * 没有任何背景、边框或阴影效果
 */
class SimpleTitle @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    private val binding: LayoutSimpleTitleBinding
    
    // 公开访问器
    val titleText: TextView get() = binding.titleText

    init {
        binding = LayoutSimpleTitleBinding.inflate(LayoutInflater.from(context), this, true)
    }

    /**
     * 设置标题文字
     */
    fun setTitle(title: String) {
        binding.titleText.text = title
    }

    /**
     * 获取标题文字
     */
    fun getTitle(): String {
        return binding.titleText.text.toString()
    }
}