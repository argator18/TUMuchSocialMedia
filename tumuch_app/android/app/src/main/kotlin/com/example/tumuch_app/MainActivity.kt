package com.example.tumuch_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel






class MainActivity : FlutterActivity() {

    private val CHANNEL = "app.channel.route"   // same channel as before
    private var methodChannel: MethodChannel? = null

    // ---- Existing route handling fields (for /reason etc.) ----
    // (We reuse methodChannel for both routing + screen capture)

    // ---- Screen capture fields ----
    private val SCREEN_CAPTURE_REQUEST_CODE = 1001
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var pendingCaptureResult: MethodChannel.Result? = null
    private var fgServiceIntent: Intent? = null   // <--- add this

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                // 1) Existing method to get initial route for Flutter
                "getInitialRoute" -> {
                    val route = intent.getStringExtra("route") ?: "/"
                    Log.d("MainActivity", "getInitialRoute -> $route")
                    result.success(route)
                }

                // 2) NEW: request a single screen capture
                "captureScreenOnce" -> {
                    startScreenCapture(result)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val newRoute = intent.getStringExtra("route")
        Log.d("MainActivity", "onNewIntent with route=$newRoute")

        // If you have the /reason navigation logic here, keep it:
        if (newRoute == "/reason") {
            methodChannel?.invokeMethod("openReason", null)
        }
    }

    // ---------------- SCREEN CAPTURE LOGIC ----------------

    private fun startScreenCapture(result: MethodChannel.Result) {
        if (pendingCaptureResult != null) {
            result.error("ALREADY_RUNNING", "A capture request is already pending.", null)
            return
        }

        mediaProjectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        val captureIntent = mediaProjectionManager!!.createScreenCaptureIntent()
        pendingCaptureResult = result

        startActivityForResult(captureIntent, SCREEN_CAPTURE_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            val result = pendingCaptureResult
            if (result == null) {
                return
            }

            if (resultCode == Activity.RESULT_OK && data != null) {
                // 1) Start foreground service of type mediaProjection
                fgServiceIntent = Intent(this, ScreenCaptureForegroundService::class.java)
                ContextCompat.startForegroundService(this, fgServiceIntent!!)

                // 2) Delay getMediaProjection slightly so the service has time
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        mediaProjection =
                            mediaProjectionManager?.getMediaProjection(resultCode, data)

                        if (mediaProjection == null) {
                            result.error("PROJECTION_NULL", "MediaProjection is null", null)
                            pendingCaptureResult = null
                            stopScreenCapture()
                        } else {
                            captureFrameOnce(result)
                        }
                    } catch (e: SecurityException) {
                        Log.e("MainActivity", "SecurityException in getMediaProjection", e)
                        result.error("SECURITY_EXCEPTION", e.message, null)
                        pendingCaptureResult = null
                        stopScreenCapture()
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error in getMediaProjection", e)
                        result.error("CAPTURE_ERROR", e.message, null)
                        pendingCaptureResult = null
                        stopScreenCapture()
                    }
                }, 200) // 200ms delay
            } else {
                result.error("DENIED", "User denied screen capture permission.", null)
                pendingCaptureResult = null
            }
        }
    }

private fun captureFrameOnce(result: MethodChannel.Result) {
    try {
        val metrics = DisplayMetrics()
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        wm.defaultDisplay.getRealMetrics(metrics)

        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        imageReader = ImageReader.newInstance(
            width,
            height,
            PixelFormat.RGBA_8888,
            2
        )

        // Required on Android 14+
        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                Log.d("MainActivity", "MediaProjection onStop() called")
                stopScreenCapture()
            }
        }, Handler(Looper.getMainLooper()))

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null
        )

        imageReader?.setOnImageAvailableListener({ reader ->
            // 🔐 GUARD: only respond once
            val currentResult = pendingCaptureResult ?: return@setOnImageAvailableListener
            // mark as handled so nobody else can respond
            pendingCaptureResult = null

            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener

            val plane = image.planes[0]
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * width

            val bitmapWidth = width + rowPadding / pixelStride

            val bitmap = android.graphics.Bitmap.createBitmap(
                bitmapWidth,
                height,
                android.graphics.Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)

            image.close()

            val cropped = android.graphics.Bitmap.createBitmap(
                bitmap,
                0,
                0,
                width,
                height
            )

            val outputStream = java.io.ByteArrayOutputStream()
            cropped.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, outputStream)
            val bytes = outputStream.toByteArray()

            bitmap.recycle()
            cropped.recycle()
            stopScreenCapture()

            // ✅ only this line will ever reply to Flutter:
            currentResult.success(bytes)

        }, Handler(Looper.getMainLooper()))

    } catch (e: Exception) {
        Log.e("MainActivity", "captureFrameOnce error: ${e.message}", e)

        // 🔐 also guard the error path
        val currentResult = pendingCaptureResult
        pendingCaptureResult = null
        stopScreenCapture()
        currentResult?.error("CAPTURE_ERROR", e.message, null)
    }
}

    private fun stopScreenCapture() {
        return
        //virtualDisplay?.release()
        //virtualDisplay = null
        //imageReader?.close()
        //imageReader = null
        //mediaProjection?.stop()
        //mediaProjection = null

        //fgServiceIntent?.let {
        //    stopService(it)
        //    fgServiceIntent = null
        //}
    }
}

