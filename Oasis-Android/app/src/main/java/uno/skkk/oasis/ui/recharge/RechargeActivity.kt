package uno.skkk.oasis.ui.recharge

import android.os.Bundle
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.ActivityRechargeBinding
import uno.skkk.oasis.ui.base.BaseActivity
import uno.skkk.oasis.ui.wallet.RechargeFragment
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class RechargeActivity : BaseActivity() {
    
    private lateinit var binding: ActivityRechargeBinding
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityRechargeBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupFragment(savedInstanceState)
    }
    
    private fun setupFragment(savedInstanceState: Bundle?) {
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, RechargeFragment.newInstance())
                .commit()
        }
    }
}