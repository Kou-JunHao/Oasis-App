package uno.skkk.oasis.ui.qrcode

import android.Manifest
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.animation.LinearInterpolator
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import uno.skkk.oasis.R
import uno.skkk.oasis.databinding.ActivityQrcodeNewBinding
import uno.skkk.oasis.ui.base.BaseActivity
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class QRCodeScanActivityNew : BaseActivity() {
    
    private lateinit var binding: ActivityQrcodeNewBinding
    private lateinit var cameraExecutor: ExecutorService
    private lateinit var barcodeScanner: BarcodeScanner
    
    private var imageCapture: ImageCapture? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    
    private var isFlashOn = false
    private var isScanning = true
    
    // UI elements
    private lateinit var statusIcon: ImageView
    private lateinit var statusText: TextView
    private lateinit var scanLine: View
    private var scanLineAnimator: ObjectAnimator? = null
    
    companion object {
        private const val TAG = "QRCodeScanNew"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }
    
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            Log.d(TAG, "Camera permission granted")
            startCamera()
        } else {
            Log.e(TAG, "Camera permission denied")
            Toast.makeText(this, "需要相机权限才能扫描二维码", Toast.LENGTH_SHORT).show()
            finish()
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "QRCodeScanActivityNew onCreate")
        
        binding = ActivityQrcodeNewBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupUI()
        setupBarcodeScanner()
        
        cameraExecutor = Executors.newSingleThreadExecutor()
        
        // Request camera permissions
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            requestPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }
    
    private fun setupUI() {
        binding.btnBack.setOnClickListener {
            Log.d(TAG, "Back button clicked")
            finish()
        }
        
        binding.btnFlash.setOnClickListener {
            toggleFlashlight()
        }
        
        // Initialize UI elements
        statusIcon = findViewById(R.id.statusIcon)
        statusText = findViewById(R.id.statusText)
        scanLine = findViewById(R.id.scanLine)
        
        // Start scanning line animation
        startScanLineAnimation()
        
        // Update status to scanning
        updateScanningStatus("正在扫描...", R.drawable.ic_search)
    }
    
    private fun setupBarcodeScanner() {
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        
        barcodeScanner = BarcodeScanning.getClient(options)
        Log.d(TAG, "Barcode scanner initialized")
    }
    
    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun startCamera() {
        Log.d(TAG, "Starting camera")
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        
        cameraProviderFuture.addListener({
            try {
                // Used to bind the lifecycle of cameras to the lifecycle owner
                cameraProvider = cameraProviderFuture.get()
                
                // Preview
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(binding.previewView.surfaceProvider)
                }
                
                // Image analyzer for QR code detection
                imageAnalyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also {
                        it.setAnalyzer(cameraExecutor, QRCodeAnalyzer { qrCode ->
                            if (isScanning) {
                                isScanning = false
                                runOnUiThread {
                                    handleQRCodeDetected(qrCode)
                                }
                            }
                        })
                    }
                
                // Select back camera as a default
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                
                try {
                    // Unbind use cases before rebinding
                    cameraProvider?.unbindAll()
                    
                    // Bind use cases to camera
                    camera = cameraProvider?.bindToLifecycle(
                        this, cameraSelector, preview, imageAnalyzer
                    )
                    
                    Log.d(TAG, "Camera started successfully")
                    
                } catch (exc: Exception) {
                    Log.e(TAG, "Use case binding failed", exc)
                    Toast.makeText(this, "相机启动失败", Toast.LENGTH_SHORT).show()
                }
                
            } catch (exc: Exception) {
                Log.e(TAG, "Camera provider initialization failed", exc)
                Toast.makeText(this, "相机初始化失败", Toast.LENGTH_SHORT).show()
            }
        }, ContextCompat.getMainExecutor(this))
    }
    
    private fun toggleFlashlight() {
        camera?.let { camera ->
            if (camera.cameraInfo.hasFlashUnit()) {
                isFlashOn = !isFlashOn
                camera.cameraControl.enableTorch(isFlashOn)
                Log.d(TAG, "Flash toggled: $isFlashOn")
                
                // Update UI
                binding.btnFlash.setImageResource(
                    if (isFlashOn) R.drawable.ic_flash_on else R.drawable.ic_flash_off
                )
            } else {
                Toast.makeText(this, "设备不支持闪光灯", Toast.LENGTH_SHORT).show()
            }
        }
    }
    
    private fun startScanLineAnimation() {
        scanLineAnimator = ObjectAnimator.ofFloat(scanLine, "translationY", -140f, 140f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = LinearInterpolator()
            start()
        }
    }
    
    private fun stopScanLineAnimation() {
        scanLineAnimator?.cancel()
        scanLineAnimator = null
    }
    
    private fun updateScanningStatus(message: String, iconRes: Int) {
        runOnUiThread {
            statusText.text = message
            statusIcon.setImageResource(iconRes)
        }
    }
    
    private fun handleQRCodeDetected(qrCode: String) {
        Log.d(TAG, "QR Code detected: $qrCode")
        
        // Stop scanning animation and update status
        stopScanLineAnimation()
        updateScanningStatus("扫描成功!", R.drawable.ic_check)
        
        // Add a small delay to show success status
        Handler(Looper.getMainLooper()).postDelayed({
            val resultIntent = Intent().apply {
                putExtra("SCAN_RESULT", qrCode)
            }
            setResult(RESULT_OK, resultIntent)
            finish()
        }, 500)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "QRCodeScanActivityNew onDestroy")
        stopScanLineAnimation()
        cameraExecutor.shutdown()
        barcodeScanner.close()
    }
    
    private inner class QRCodeAnalyzer(private val onQRCodeDetected: (String) -> Unit) : ImageAnalysis.Analyzer {
        
        @androidx.camera.core.ExperimentalGetImage
        override fun analyze(imageProxy: ImageProxy) {
            val mediaImage = imageProxy.image
            if (mediaImage != null) {
                val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                
                barcodeScanner.process(image)
                    .addOnSuccessListener { barcodes ->
                        for (barcode in barcodes) {
                            barcode.rawValue?.let { qrCode ->
                                Log.d(TAG, "QR Code found: $qrCode")
                                onQRCodeDetected(qrCode)
                                return@addOnSuccessListener
                            }
                        }
                    }
                    .addOnFailureListener { exception ->
                        Log.e(TAG, "Barcode scanning failed", exception)
                    }
                    .addOnCompleteListener {
                        imageProxy.close()
                    }
            } else {
                imageProxy.close()
            }
        }
    }
}