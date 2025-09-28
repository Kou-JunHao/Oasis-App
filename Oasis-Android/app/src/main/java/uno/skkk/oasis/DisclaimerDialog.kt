package uno.skkk.oasis

import android.app.Dialog
import android.content.Context
import android.content.SharedPreferences
import android.os.CountDownTimer
import android.view.LayoutInflater
import android.widget.Button
import com.google.android.material.dialog.MaterialAlertDialogBuilder

class DisclaimerDialog(
    private val context: Context,
    private val listener: OnDisclaimerActionListener?
) {
    
    interface OnDisclaimerActionListener {
        fun onAccepted()
        fun onCancelled()
    }
    
    companion object {
        private const val PREFS_NAME = "disclaimer_prefs"
        private const val KEY_DISCLAIMER_ACCEPTED = "disclaimer_accepted"
        private const val COUNTDOWN_SECONDS = 5
        
        fun isDisclaimerAccepted(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_DISCLAIMER_ACCEPTED, false)
        }
        
        fun resetDisclaimerStatus(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_DISCLAIMER_ACCEPTED).apply()
        }
    }
    
    private var dialog: Dialog? = null
    private var btnAgree: Button? = null
    private var countDownTimer: CountDownTimer? = null
    
    init {
        createDialog()
    }
    
    private fun createDialog() {
        val dialogView = LayoutInflater.from(context).inflate(R.layout.dialog_disclaimer, null)
        
        btnAgree = dialogView.findViewById(R.id.btnAgree)
        val btnCancel = dialogView.findViewById<Button>(R.id.btnCancel)
        
        // 设置按钮点击事件
        btnAgree?.setOnClickListener {
            countDownTimer?.cancel()
            saveDisclaimerAccepted()
            listener?.onAccepted()
            dismiss()
        }
        
        btnCancel.setOnClickListener {
            countDownTimer?.cancel()
            listener?.onCancelled()
            dismiss()
        }
        
        // 创建Material 3风格的对话框
        dialog = MaterialAlertDialogBuilder(context)
            .setView(dialogView)
            .setCancelable(false)
            .create()
        
        // 启动倒计时
        startCountdown()
    }
    
    private fun startCountdown() {
        countDownTimer = object : CountDownTimer((COUNTDOWN_SECONDS * 1000).toLong(), 1000) {
            override fun onTick(millisUntilFinished: Long) {
                val secondsLeft = (millisUntilFinished / 1000).toInt()
                btnAgree?.text = "同意并继续 ($secondsLeft)"
            }
            
            override fun onFinish() {
                btnAgree?.text = "同意并继续"
                btnAgree?.isEnabled = true
            }
        }
        countDownTimer?.start()
    }
    
    fun show() {
        dialog?.takeIf { !it.isShowing }?.show()
    }
    
    fun dismiss() {
        dialog?.takeIf { it.isShowing }?.dismiss()
        countDownTimer?.cancel()
    }
    
    private fun saveDisclaimerAccepted() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_DISCLAIMER_ACCEPTED, true).apply()
    }
}