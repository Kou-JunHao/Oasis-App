package uno.skkk.oasis.ui.settings

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.MenuItem
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import uno.skkk.oasis.R
import uno.skkk.oasis.ui.base.BaseActivity
import uno.skkk.oasis.databinding.ActivityOpenSourceLicensesBinding

class OpenSourceLicensesActivity : BaseActivity() {

    private lateinit var binding: ActivityOpenSourceLicensesBinding
    private lateinit var licensesAdapter: LicensesAdapter

    companion object {
        fun start(context: Context) {
            val intent = Intent(context, OpenSourceLicensesActivity::class.java)
            context.startActivity(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityOpenSourceLicensesBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupToolbar()
        setupRecyclerView()
        loadLicenses()
    }

    private fun setupToolbar() {
        setSupportActionBar(binding.toolbar)
        supportActionBar?.apply {
            setDisplayHomeAsUpEnabled(true)
            setDisplayShowHomeEnabled(true)
            title = "开放源代码许可"
        }
    }

    private fun setupRecyclerView() {
        licensesAdapter = LicensesAdapter { license ->
            openLicenseUrl(license.url)
        }
        binding.recyclerView.apply {
            layoutManager = LinearLayoutManager(this@OpenSourceLicensesActivity)
            adapter = licensesAdapter
        }
    }

    private fun loadLicenses() {
        val licenses = listOf(
            License("Android Jetpack", "Apache License 2.0", "https://github.com/androidx/androidx/blob/androidx-main/LICENSE.txt"),
            License("Kotlin", "Apache License 2.0", "https://github.com/JetBrains/kotlin/blob/master/license/LICENSE.txt"),
            License("Material Components for Android", "Apache License 2.0", "https://github.com/material-components/material-components-android/blob/master/LICENSE"),
            License("Retrofit", "Apache License 2.0", "https://github.com/square/retrofit/blob/master/LICENSE.txt"),
            License("OkHttp", "Apache License 2.0", "https://github.com/square/okhttp/blob/master/LICENSE.txt"),
            License("Gson", "Apache License 2.0", "https://github.com/google/gson/blob/master/LICENSE"),
            License("Glide", "BSD License", "https://github.com/bumptech/glide/blob/master/LICENSE"),
            License("Dagger Hilt", "Apache License 2.0", "https://github.com/google/dagger/blob/master/LICENSE.txt"),
            License("ZXing Core", "Apache License 2.0", "https://github.com/zxing/zxing/blob/master/LICENSE"),
            License("CameraX", "Apache License 2.0", "https://github.com/androidx/androidx/blob/androidx-main/LICENSE.txt"),
            License("ML Kit", "Apache License 2.0", "https://developers.google.com/ml-kit/terms"),
            License("JUnit", "Eclipse Public License 1.0", "https://github.com/junit-team/junit4/blob/main/LICENSE-junit.txt")
        )
        licensesAdapter.submitList(licenses)
    }

    private fun openLicenseUrl(url: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            startActivity(intent)
        } catch (e: Exception) {
            // 处理无法打开链接的情况
        }
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                onBackPressed()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }
}

data class License(
    val name: String,
    val licenseName: String,
    val url: String
)