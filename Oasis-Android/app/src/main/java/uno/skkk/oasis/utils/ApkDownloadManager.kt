package uno.skkk.oasis.utils

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import androidx.core.content.getSystemService
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.resume

/**
 * APK下载和安装管理器
 */
class ApkDownloadManager(private val context: Context) {
    
    companion object {
        private const val TAG = "ApkDownloadManager"
    }
    
    /**
     * 使用自定义HTTP下载替代系统下载管理器
     * 下载完成后自动触发安装流程，无需用户手动点击下载管理器
     */
    suspend fun downloadAndInstallApk(
        downloadUrl: String,
        fileName: String = "oasis_update.apk",
        onProgress: ((progress: Int) -> Unit)? = null
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            // 检查安装权限
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (!context.packageManager.canRequestPackageInstalls()) {
                    return@withContext Result.failure(SecurityException("需要安装未知来源应用的权限"))
                }
            }
            
            Log.d(TAG, "开始自定义下载APK: $downloadUrl")
            
            // 创建下载目录
            val downloadDir = File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "apk")
            if (!downloadDir.exists()) {
                downloadDir.mkdirs()
            }
            
            val apkFile = File(downloadDir, fileName)
            Log.d(TAG, "APK文件保存路径: ${apkFile.absolutePath}")
            
            // 如果文件已存在，删除旧文件
            if (apkFile.exists()) {
                apkFile.delete()
                Log.d(TAG, "删除已存在的APK文件")
            }
            
            // 开始下载
            val url = URL(downloadUrl)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            connection.connect()
            
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                return@withContext Result.failure(Exception("下载失败，HTTP状态码: ${connection.responseCode}"))
            }
            
            val fileLength = connection.contentLength
            Log.d(TAG, "文件大小: $fileLength bytes")
            
            val inputStream: InputStream = connection.inputStream
            val outputStream = FileOutputStream(apkFile)
            
            val buffer = ByteArray(8192)
            var totalBytesRead = 0
            var bytesRead: Int
            
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
                totalBytesRead += bytesRead
                
                // 更新进度
                if (fileLength > 0 && onProgress != null) {
                    // 确保进度在0-100之间，防止负数或超过100%
                    val progress = ((totalBytesRead * 100L / fileLength).toInt()).coerceIn(0, 100)
                    withContext(Dispatchers.Main) {
                        onProgress(progress)
                    }
                    Log.d(TAG, "下载进度: $progress% ($totalBytesRead/$fileLength)")
                }
            }
            
            outputStream.close()
            inputStream.close()
            connection.disconnect()
            
            Log.d(TAG, "下载完成，文件大小: ${apkFile.length()} bytes")
            
            // 确保进度显示为100%
            withContext(Dispatchers.Main) {
                onProgress?.invoke(100)
            }
            
            // 验证文件完整性
            if (!apkFile.exists() || apkFile.length() == 0L) {
                return@withContext Result.failure(Exception("下载的文件无效"))
            }
            
            Log.d(TAG, "开始安装APK")
            
            // 在主线程中执行安装
            withContext(Dispatchers.Main) {
                try {
                    installApk(apkFile)
                    Log.d(TAG, "安装流程已启动")
                } catch (e: Exception) {
                    Log.e(TAG, "启动安装流程失败", e)
                    throw e
                }
            }
            
            Result.success(Unit)
            
        } catch (e: Exception) {
            Log.e(TAG, "自定义下载失败", e)
            Result.failure(e)
        }
    }
    
    /**
     * 安装APK文件
     */
    private fun installApk(apkFile: File) {
        Log.d(TAG, "准备安装APK: ${apkFile.absolutePath}")
        Log.d(TAG, "文件存在: ${apkFile.exists()}")
        Log.d(TAG, "文件大小: ${apkFile.length()} bytes")
        Log.d(TAG, "文件可读: ${apkFile.canRead()}")
        
        if (!apkFile.exists()) {
            Log.e(TAG, "APK文件不存在，无法安装")
            throw Exception("APK文件不存在")
        }
        
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    // Android 7.0及以上使用FileProvider
                    Log.d(TAG, "使用FileProvider (Android N+)")
                    val apkUri = FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        apkFile
                    )
                    setDataAndType(apkUri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    Log.d(TAG, "FileProvider URI: $apkUri")
                } else {
                    // Android 7.0以下直接使用文件URI
                    Log.d(TAG, "使用文件URI (Android < N)")
                    val fileUri = Uri.fromFile(apkFile)
                    setDataAndType(fileUri, "application/vnd.android.package-archive")
                    Log.d(TAG, "文件URI: $fileUri")
                }
            }
            
            // 检查是否有应用可以处理安装Intent
            val packageManager = context.packageManager
            val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.queryIntentActivities(intent, 0)
            }
            
            if (resolveInfos.isNotEmpty()) {
                Log.d(TAG, "找到 ${resolveInfos.size} 个可以处理安装的应用")
                Log.d(TAG, "启动安装Intent")
                context.startActivity(intent)
                Log.d(TAG, "安装Intent已启动")
            } else {
                Log.e(TAG, "没有找到可以处理APK安装的应用")
                throw Exception("系统中没有可以安装APK的应用")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "创建或启动安装Intent时发生异常", e)
            throw e
        }
    }
    
    /**
     * 检查是否有安装权限
     */
    fun hasInstallPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }
    
    /**
     * 请求安装权限
     */
    fun requestInstallPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!context.packageManager.canRequestPackageInstalls()) {
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            }
        }
    }
}