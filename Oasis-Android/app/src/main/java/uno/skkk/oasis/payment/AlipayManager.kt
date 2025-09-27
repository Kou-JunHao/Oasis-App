package uno.skkk.oasis.payment

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.text.TextUtils
import android.util.Log
import com.alipay.sdk.app.PayTask
import uno.skkk.oasis.data.model.AlipayPaymentData
import java.lang.ref.WeakReference

/**
 * 支付宝支付管理器
 */
class AlipayManager {
    
    companion object {
        private const val TAG = "AlipayManager"
        private const val SDK_PAY_FLAG = 1
        
        // 支付结果状态码
        const val RESULT_CODE_SUCCESS = "9000" // 支付成功
        const val RESULT_CODE_PROCESSING = "8000" // 正在处理中，支付结果未知
        const val RESULT_CODE_FAILED = "4000" // 订单支付失败
        const val RESULT_CODE_CANCELLED = "5000" // 重复请求
        const val RESULT_CODE_USER_CANCELLED = "6001" // 用户中途取消
        const val RESULT_CODE_NETWORK_ERROR = "6002" // 网络连接出错
        const val RESULT_CODE_UNKNOWN = "6004" // 支付结果未知（有可能已经支付成功）
    }
    
    /**
     * 支付结果回调接口
     */
    interface PaymentCallback {
        fun onPaymentSuccess(result: PaymentResult)
        fun onPaymentFailed(result: PaymentResult)
        fun onPaymentCancelled(result: PaymentResult)
        fun onPaymentUnknown(result: PaymentResult)
    }
    
    /**
     * 支付结果数据类
     */
    data class PaymentResult(
        val resultStatus: String,
        val result: String,
        val memo: String,
        val isSuccess: Boolean = false,
        val message: String = ""
    )
    
    private var mCallback: PaymentCallback? = null
    private var mHandler: PaymentHandler? = null
    
    /**
     * 发起支付宝支付
     * @param activity 当前Activity
     * @param paymentData 支付数据
     * @param callback 支付结果回调
     */
    fun pay(activity: Activity, paymentData: AlipayPaymentData, callback: PaymentCallback) {
        mCallback = callback
        mHandler = PaymentHandler(this)
        
        val paymentString = paymentData.paymentString
        
        if (TextUtils.isEmpty(paymentString)) {
            callback.onPaymentFailed(
                PaymentResult(
                    resultStatus = RESULT_CODE_FAILED,
                    result = "",
                    memo = "支付参数为空",
                    message = "支付参数为空"
                )
            )
            return
        }
        
        Log.d(TAG, "开始支付宝支付，支付参数: $paymentString")
        
        // 在子线程中调用支付宝SDK
        Thread {
            try {
                val payTask = PayTask(activity)
                val result = payTask.payV2(paymentString, true)
                
                Log.d(TAG, "支付宝支付结果: $result")
                
                val msg = Message()
                msg.what = SDK_PAY_FLAG
                msg.obj = result
                mHandler?.sendMessage(msg)
                
            } catch (e: Exception) {
                Log.e(TAG, "支付宝支付异常", e)
                val errorResult = mapOf(
                    "resultStatus" to RESULT_CODE_FAILED,
                    "result" to "",
                    "memo" to "支付异常: ${e.message}"
                )
                
                val msg = Message()
                msg.what = SDK_PAY_FLAG
                msg.obj = errorResult
                mHandler?.sendMessage(msg)
            }
        }.start()
    }
    
    /**
     * 处理支付结果的Handler
     */
    private class PaymentHandler(manager: AlipayManager) : Handler(Looper.getMainLooper()) {
        private val managerRef = WeakReference(manager)
        
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                SDK_PAY_FLAG -> {
                    val manager = managerRef.get() ?: return
                    val payResult = PayResult(msg.obj as Map<String, String>)
                    manager.handlePaymentResult(payResult)
                }
            }
        }
    }
    
    /**
     * 处理支付结果
     */
    private fun handlePaymentResult(payResult: PayResult) {
        val resultStatus = payResult.resultStatus
        val result = PaymentResult(
            resultStatus = resultStatus,
            result = payResult.result,
            memo = payResult.memo,
            message = getResultMessage(resultStatus)
        )
        
        when (resultStatus) {
            RESULT_CODE_SUCCESS -> {
                Log.d(TAG, "支付成功")
                mCallback?.onPaymentSuccess(result.copy(isSuccess = true))
            }
            RESULT_CODE_PROCESSING, RESULT_CODE_UNKNOWN -> {
                Log.d(TAG, "支付结果未知")
                mCallback?.onPaymentUnknown(result)
            }
            RESULT_CODE_USER_CANCELLED -> {
                Log.d(TAG, "用户取消支付")
                mCallback?.onPaymentCancelled(result)
            }
            else -> {
                Log.d(TAG, "支付失败: $resultStatus")
                mCallback?.onPaymentFailed(result)
            }
        }
    }
    
    /**
     * 获取结果描述信息
     */
    private fun getResultMessage(resultStatus: String): String {
        return when (resultStatus) {
            RESULT_CODE_SUCCESS -> "支付成功"
            RESULT_CODE_PROCESSING -> "支付结果确认中"
            RESULT_CODE_FAILED -> "支付失败"
            RESULT_CODE_CANCELLED -> "重复请求"
            RESULT_CODE_USER_CANCELLED -> "用户取消支付"
            RESULT_CODE_NETWORK_ERROR -> "网络连接出错"
            RESULT_CODE_UNKNOWN -> "支付结果未知"
            else -> "未知错误"
        }
    }
    
    /**
     * 支付结果解析类
     */
    private class PayResult(rawResult: Map<String, String>) {
        val resultStatus: String = rawResult["resultStatus"] ?: ""
        val result: String = rawResult["result"] ?: ""
        val memo: String = rawResult["memo"] ?: ""
    }
}