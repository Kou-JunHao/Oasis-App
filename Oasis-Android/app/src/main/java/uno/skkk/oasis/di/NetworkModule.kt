package uno.skkk.oasis.di

import uno.skkk.oasis.data.api.ApiService
import uno.skkk.oasis.data.api.NetworkConfig
import uno.skkk.oasis.data.TokenManager
import uno.skkk.oasis.data.repository.AppRepository
import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.hilt.android.qualifiers.ApplicationContext
import retrofit2.Retrofit
import javax.inject.Singleton

/**
 * 网络模块 - 提供API服务的依赖注入
 */
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    
    @Provides
    @Singleton
    fun provideRetrofit(): Retrofit {
        return NetworkConfig.createRetrofit()
    }
    
    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService {
        return retrofit.create(ApiService::class.java)
    }
    
    @Provides
    @Singleton
    fun provideTokenManager(
        @ApplicationContext context: Context
    ): TokenManager {
        return TokenManager(context)
    }
    
    @Provides
    @Singleton
    fun provideAppRepository(
        @ApplicationContext context: Context
    ): AppRepository {
        return AppRepository.getInstance(context)
    }

}
