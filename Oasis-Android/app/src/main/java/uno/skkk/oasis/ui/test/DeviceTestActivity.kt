package uno.skkk.oasis.ui.test

import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.lifecycle.lifecycleScope
import uno.skkk.oasis.R
import uno.skkk.oasis.data.repository.AppRepository
import uno.skkk.oasis.ui.base.BaseActivity
import kotlinx.coroutines.launch

/**
 * 设备控制测试Activity
 * 用于验证与web实现的功能同步
 */
class DeviceTestActivity : BaseActivity() {
    
    private lateinit var repository: AppRepository
    private lateinit var deviceIdInput: EditText
    private lateinit var statusText: TextView
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = AppRepository.getInstance(this)
        
        setupUI()
    }
    
    private fun setupUI() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }
        
        // 标题
        val title = TextView(this).apply {
            text = "设备控制功能测试"
            textSize = 20f
            setPadding(0, 0, 0, 32)
        }
        layout.addView(title)
        
        // 设备ID输入
        deviceIdInput = EditText(this).apply {
            hint = "输入设备ID"
            setPadding(16, 16, 16, 16)
        }
        layout.addView(deviceIdInput)
        
        // 获取设备列表按钮
        val getDevicesBtn = Button(this).apply {
            text = "获取设备列表"
            setOnClickListener { getDeviceList() }
        }
        layout.addView(getDevicesBtn)
        
        // 智能控制按钮
        val smartControlBtn = Button(this).apply {
            text = "智能控制设备"
            setOnClickListener { smartControlDevice() }
        }
        layout.addView(smartControlBtn)
        
        // 查询状态按钮
        val statusBtn = Button(this).apply {
            text = "查询设备状态"
            setOnClickListener { checkDeviceStatus() }
        }
        layout.addView(statusBtn)
        
        // 状态显示
        statusText = TextView(this).apply {
            text = "等待操作..."
            setPadding(0, 32, 0, 0)
        }
        layout.addView(statusText)
        
        setContentView(layout)
    }
    
    private fun getDeviceList() {
        lifecycleScope.launch {
            try {
                statusText.text = "正在获取设备列表..."
                val result = repository.getDeviceList()
                if (result.isSuccess) {
                    val devices = result.getOrNull()?.devices ?: emptyList()
                    statusText.text = "获取到 ${devices.size} 个设备\n" + 
                        devices.joinToString("\n") { "${it.name} (${it.id})" }
                    Toast.makeText(this@DeviceTestActivity, "获取设备列表成功", Toast.LENGTH_SHORT).show()
                } else {
                    statusText.text = "获取设备列表失败: ${result.exceptionOrNull()?.message}"
                    Toast.makeText(this@DeviceTestActivity, "获取设备列表失败", Toast.LENGTH_LONG).show()
                }
            } catch (e: Exception) {
                statusText.text = "错误: ${e.message}"
                Toast.makeText(this@DeviceTestActivity, "错误: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
    
    private fun smartControlDevice() {
        val deviceId = deviceIdInput.text.toString().trim()
        if (deviceId.isEmpty()) {
            Toast.makeText(this, "请输入设备ID", Toast.LENGTH_SHORT).show()
            return
        }
        
        lifecycleScope.launch {
            try {
                statusText.text = "正在控制设备 $deviceId..."
                val result = repository.startOrEndDevice(deviceId)
                if (result.isSuccess) {
                    statusText.text = "设备控制成功: ${result.getOrNull()}"
                    Toast.makeText(this@DeviceTestActivity, result.getOrNull(), Toast.LENGTH_SHORT).show()
                } else {
                    statusText.text = "设备控制失败: ${result.exceptionOrNull()?.message}"
                    Toast.makeText(this@DeviceTestActivity, "操作失败", Toast.LENGTH_LONG).show()
                }
            } catch (e: Exception) {
                statusText.text = "错误: ${e.message}"
                Toast.makeText(this@DeviceTestActivity, "错误: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
    
    private fun checkDeviceStatus() {
        val deviceId = deviceIdInput.text.toString().trim()
        if (deviceId.isEmpty()) {
            Toast.makeText(this, "请输入设备ID", Toast.LENGTH_SHORT).show()
            return
        }
        
        lifecycleScope.launch {
            try {
                statusText.text = "正在查询设备 $deviceId 状态..."
                val result = repository.getSingleDeviceStatus(deviceId)
                if (result.isSuccess) {
                    val status = result.getOrNull()
                    val statusText = when (status?.status) {
                        0 -> "已停止"
                        1 -> "运行中"
                        else -> "未知"
                    }
                    val onlineText = if (status?.online == true) "在线" else "离线"
                    this@DeviceTestActivity.statusText.text = "设备状态: $statusText, $onlineText\n设备名称: ${status?.name ?: "未知"}"
                    Toast.makeText(this@DeviceTestActivity, "设备状态: $statusText, $onlineText", Toast.LENGTH_LONG).show()
                } else {
                    this@DeviceTestActivity.statusText.text = "查询设备状态失败: ${result.exceptionOrNull()?.message}"
                    Toast.makeText(this@DeviceTestActivity, "查询失败", Toast.LENGTH_LONG).show()
                }
            } catch (e: Exception) {
                this@DeviceTestActivity.statusText.text = "错误: ${e.message}"
                Toast.makeText(this@DeviceTestActivity, "错误: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
}
