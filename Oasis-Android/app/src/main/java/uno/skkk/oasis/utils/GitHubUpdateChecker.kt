package uno.skkk.oasis.utils

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import uno.skkk.oasis.BuildConfig
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

/**
 * GitHub更新检查器
 * 用于检查GitHub仓库的最新版本并提供更新功能
 */
class GitHubUpdateChecker(private val context: Context) {
    
    companion object {
        private const val TAG = "GitHubUpdateChecker"
        private const val GITHUB_API_URL = "https://api.github.com/repos/Kou-JunHao/Oasis-App/releases/latest"
        private const val GITHUB_RELEASES_URL = "https://github.com/Kou-JunHao/Oasis-App/releases"
    }
    
    /**
     * 版本信息数据类
     */
    data class VersionInfo(
        val version: String,
        val versionCode: Int,
        val description: String,
        val downloadUrl: String,
        val htmlUrl: String,
        val publishedAt: String,
        val isPrerelease: Boolean
    )
    
    /**
     * 更新检查结果
     */
    sealed class UpdateResult {
        object NoUpdate : UpdateResult()
        data class HasUpdate(val versionInfo: VersionInfo) : UpdateResult()
        data class Error(val message: String) : UpdateResult()
    }
    
    /**
     * 更新信息数据类（用于UI显示）
     */
    data class UpdateInfo(
        val tagName: String,
        val body: String,
        val htmlUrl: String,
        val downloadUrl: String,
        val publishedAt: String
    )
    
    /**
     * 检查更新（简化版本，直接返回UpdateInfo或null）
     */
    suspend fun checkForUpdates(): UpdateInfo? = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "开始检查更新")
            
            val latestVersionInfo = getLatestVersionFromGitHub()
            if (latestVersionInfo == null) {
                Log.w(TAG, "无法获取最新版本信息")
                return@withContext null
            }
            
            // 获取当前版本（从BuildConfig或其他地方）
            val currentVersion = getCurrentVersion()
            Log.d(TAG, "当前版本: $currentVersion, 最新版本: ${latestVersionInfo.version}")
            
            // 比较版本
            if (isNewerVersion(currentVersion, latestVersionInfo.version)) {
                Log.i(TAG, "发现新版本: ${latestVersionInfo.version}")
                UpdateInfo(
                    tagName = latestVersionInfo.version,
                    body = latestVersionInfo.description,
                    htmlUrl = latestVersionInfo.htmlUrl,
                    downloadUrl = latestVersionInfo.downloadUrl,
                    publishedAt = latestVersionInfo.publishedAt
                )
            } else {
                Log.i(TAG, "当前已是最新版本")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "检查更新时发生错误", e)
            throw e
        }
    }
    
    /**
     * 获取当前应用版本
     */
    private fun getCurrentVersion(): String {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            packageInfo.versionName ?: BuildConfig.VERSION_NAME
        } catch (e: Exception) {
            Log.w(TAG, "无法获取当前版本", e)
            BuildConfig.VERSION_NAME
        }
    }
    
    /**
     * 打开下载页面（使用URL字符串）
     */
    fun openDownloadPage(url: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            Log.i(TAG, "打开下载页面: $url")
        } catch (e: Exception) {
            Log.e(TAG, "无法打开下载页面", e)
            // 如果无法打开下载链接，尝试打开releases页面
            openReleasePage()
        }
    }
    
    /**
     * 打开GitHub releases页面
     */
    fun openReleasePage() {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(GITHUB_RELEASES_URL))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            Log.i(TAG, "打开GitHub releases页面")
        } catch (e: Exception) {
            Log.e(TAG, "无法打开GitHub releases页面", e)
        }
    }
    
    /**
     * 从GitHub API获取最新版本信息
     */
    private suspend fun getLatestVersionFromGitHub(): VersionInfo? = withContext(Dispatchers.IO) {
        var connection: HttpURLConnection? = null
        try {
            Log.d(TAG, "开始请求GitHub API: $GITHUB_API_URL")
            val url = URL(GITHUB_API_URL)
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 15000 // 增加超时时间
            connection.readTimeout = 15000
            connection.setRequestProperty("Accept", "application/vnd.github.v3+json")
            connection.setRequestProperty("User-Agent", "Oasis-Android-App")
            
            Log.d(TAG, "连接已建立，等待响应...")
            val responseCode = connection.responseCode
            Log.d(TAG, "GitHub API响应码: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val reader = BufferedReader(InputStreamReader(connection.inputStream))
                val response = reader.readText()
                reader.close()
                
                Log.d(TAG, "GitHub API响应成功，数据长度: ${response.length}")
                Log.d(TAG, "GitHub API响应前200字符: ${response.take(200)}...")
                
                parseVersionInfo(response)
            } else {
                // 读取错误响应
                val errorStream = connection.errorStream
                val errorResponse = if (errorStream != null) {
                    BufferedReader(InputStreamReader(errorStream)).readText()
                } else {
                    "无错误详情"
                }
                Log.w(TAG, "GitHub API请求失败，响应码: $responseCode, 错误信息: $errorResponse")
                null
            }
        } catch (e: java.net.UnknownHostException) {
            Log.e(TAG, "网络连接失败：无法解析主机名", e)
            null
        } catch (e: java.net.SocketTimeoutException) {
            Log.e(TAG, "网络连接超时", e)
            null
        } catch (e: java.net.ConnectException) {
            Log.e(TAG, "网络连接被拒绝", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "请求GitHub API时发生未知错误: ${e.javaClass.simpleName} - ${e.message}", e)
            null
        } finally {
            connection?.disconnect()
        }
    }
    
    /**
     * 解析GitHub API返回的版本信息
     */
    private fun parseVersionInfo(jsonResponse: String): VersionInfo? {
        try {
            val jsonObject = JSONObject(jsonResponse)
            
            val tagName = jsonObject.getString("tag_name")
            val releaseName = jsonObject.optString("name", "")
            
            // 优先使用name字段作为版本号，如果name字段包含版本号格式
            val version = when {
                releaseName.matches(Regex(".*[vV]?\\d+\\.\\d+.*")) -> {
                    // name字段包含版本号格式，提取版本号
                    extractVersionFromString(releaseName)
                }
                tagName.matches(Regex(".*[vV]?\\d+\\.\\d+.*")) -> {
                    // tag_name包含版本号格式，提取版本号
                    extractVersionFromString(tagName)
                }
                else -> {
                    // 都不包含标准版本号格式，使用tag_name
                    Log.w(TAG, "未找到标准版本号格式，tag_name: $tagName, name: $releaseName")
                    tagName.removePrefix("v").removePrefix("V")
                }
            }
            
            val description = jsonObject.optString("body", "")
            val htmlUrl = jsonObject.getString("html_url")
            val publishedAt = jsonObject.getString("published_at")
            val isPrerelease = jsonObject.getBoolean("prerelease")
            
            // 查找APK下载链接
            val assetsArray = jsonObject.getJSONArray("assets")
            var downloadUrl = ""
            
            for (i in 0 until assetsArray.length()) {
                val asset = assetsArray.getJSONObject(i)
                val name = asset.getString("name")
                if (name.endsWith(".apk", ignoreCase = true)) {
                    downloadUrl = asset.getString("browser_download_url")
                    break
                }
            }
            
            // 如果没有找到APK文件，使用releases页面链接
            if (downloadUrl.isEmpty()) {
                downloadUrl = GITHUB_RELEASES_URL
            }
            
            // 尝试从版本号中提取版本代码
            val versionCode = extractVersionCode(version)
            
            Log.d(TAG, "解析版本信息成功: tag_name=$tagName, name=$releaseName, 提取的版本=$version")
            
            return VersionInfo(
                version = version,
                versionCode = versionCode,
                description = description,
                downloadUrl = downloadUrl,
                htmlUrl = htmlUrl,
                publishedAt = publishedAt,
                isPrerelease = isPrerelease
            )
        } catch (e: Exception) {
            Log.e(TAG, "解析版本信息时发生错误", e)
            return null
        }
    }
    
    /**
     * 从字符串中提取版本号
     * 例如: "V1.0.1" -> "1.0.1", "Release v2.3.4" -> "2.3.4"
     */
    private fun extractVersionFromString(input: String): String {
        val versionRegex = Regex("[vV]?(\\d+\\.\\d+(?:\\.\\d+)?)")
        val matchResult = versionRegex.find(input)
        return matchResult?.groupValues?.get(1) ?: input.removePrefix("v").removePrefix("V")
    }
    
    /**
     * 从版本字符串中提取版本代码
     * 例如: "1.2.3" -> 10203
     */
    private fun extractVersionCode(version: String): Int {
        return try {
            Log.d(TAG, "提取版本代码，输入版本: $version")
            
            // 先尝试提取数字版本号
            val cleanVersion = extractVersionFromString(version)
            Log.d(TAG, "清理后的版本号: $cleanVersion")
            
            val parts = cleanVersion.split(".")
            Log.d(TAG, "版本号分割结果: ${parts.joinToString(", ")}")
            
            var code = 0
            for (i in parts.indices) {
                if (i < 3) { // 只处理前三个部分
                    val partValue = parts[i].toIntOrNull() ?: 0
                    code += partValue * when (i) {
                        0 -> 10000 // 主版本号
                        1 -> 100   // 次版本号
                        2 -> 1     // 修订版本号
                        else -> 1
                    }
                    Log.d(TAG, "处理版本部分 $i: $partValue, 当前代码: $code")
                }
            }
            
            Log.d(TAG, "最终版本代码: $code")
            code
        } catch (e: Exception) {
            Log.e(TAG, "提取版本代码时发生错误: $version", e)
            0
        }
    }
    
    /**
     * 比较版本号，判断是否有新版本
     * @param currentVersion 当前版本
     * @param latestVersion 最新版本
     * @return true 如果最新版本更新
     */
    private fun isNewerVersion(currentVersion: String, latestVersion: String): Boolean {
        return try {
            val currentCode = extractVersionCode(currentVersion)
            val latestCode = extractVersionCode(latestVersion)
            
            Log.d(TAG, "版本比较: 当前版本代码=$currentCode, 最新版本代码=$latestCode")
            
            latestCode > currentCode
        } catch (e: Exception) {
            Log.e(TAG, "版本比较时发生错误", e)
            // 如果版本代码比较失败，尝试字符串比较
            latestVersion != currentVersion
        }
    }
    
    /**
     * 打开下载页面
     * @param versionInfo 版本信息
     */
    fun openDownloadPage(versionInfo: VersionInfo) {
        openDownloadPage(versionInfo.downloadUrl)
    }
    
    /**
     * 打开GitHub releases页面（别名方法）
     */
    fun openReleasesPage() {
        openReleasePage()
    }
}