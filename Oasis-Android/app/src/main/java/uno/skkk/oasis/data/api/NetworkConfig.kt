package uno.skkk.oasis.data.api

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * 网络配置类
 */
object NetworkConfig {
    
    private const val BASE_URL = "https://i.ilife798.com/"
    private const val TIMEOUT = 30L
    
    /**
     * 创建通用请求头拦截器
     */
    private fun createHeaderInterceptor(): Interceptor {
        return Interceptor { chain ->
            val original = chain.request()
            val requestBuilder = original.newBuilder()
                .header("Connection", "keep-alive")
                .header("ApplicationType", "1,1")
                .header("Accept", "*/*")
                .header("User-Agent", "Android_ilife798_2.0.11")
                .header("Accept-Language", "zh-TW,zh-Hant;q=0.9")
                .header("Accept-Encoding", "gzip, deflate, br")
                .header("versioncode", "2.0.11")
            
            // 如果是POST请求，添加Content-Type
            if (original.method == "POST") {
                requestBuilder.header("Content-Type", "application/json")
            }
            
            chain.proceed(requestBuilder.build())
        }
    }
    
    /**
     * 创建信任所有证书的TrustManager
     */
    private fun createTrustAllManager(): X509TrustManager {
        return object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
            override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        }
    }
    
    /**
     * 创建OkHttpClient
     */
    private fun createOkHttpClient(): OkHttpClient {
        val loggingInterceptor = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        }
        
        // 创建信任所有证书的SSL上下文
        val trustAllManager = createTrustAllManager()
        val sslContext = SSLContext.getInstance("SSL")
        sslContext.init(null, arrayOf<TrustManager>(trustAllManager), java.security.SecureRandom())
        
        return OkHttpClient.Builder()
            .addInterceptor(createHeaderInterceptor())
            .addInterceptor(loggingInterceptor)
            .connectTimeout(TIMEOUT, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT, TimeUnit.SECONDS)
            .writeTimeout(TIMEOUT, TimeUnit.SECONDS)
            .sslSocketFactory(sslContext.socketFactory, trustAllManager)
            .hostnameVerifier { _, _ -> true }
            .build()
    }
    
    /**
     * 创建Gson实例
     */
    private fun createGson(): Gson {
        return GsonBuilder()
            .create()
    }
    
    /**
     * 创建Retrofit实例
     */
    fun createRetrofit(): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(createOkHttpClient())
            .addConverterFactory(GsonConverterFactory.create(createGson()))
            .build()
    }
    
    /**
     * 创建ApiService实例
     */
    fun createApiService(): ApiService {
        return createRetrofit().create(ApiService::class.java)
    }
    
    /**
     * 全局ApiService实例
     */
    val apiService: ApiService by lazy {
        createApiService()
    }
}
