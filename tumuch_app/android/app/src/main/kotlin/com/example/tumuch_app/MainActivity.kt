package com.example.tumuch_app

import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale



class MainActivity : FlutterActivity() {

    private val CHANNEL = "app.channel.route"
    private var methodChannel: MethodChannel? = null

    // ---- Screen capture fields ----
    private val SCREEN_CAPTURE_REQUEST_CODE = 1001
    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var pendingCaptureResult: MethodChannel.Result? = null
    private var fgServiceIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                // 1) Initial route for Flutter
                "getInitialRoute" -> {
                    val route = intent.getStringExtra("route") ?: "/"
                    Log.d("MainActivity", "getInitialRoute -> $route")
                    result.success(route)
                }

                // 2) Screen capture: one screenshot
                "captureScreenOnce" -> {
                    startScreenCapture(result)
                }

                // 3) Open usage access settings
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings(this)
                    result.success(null)
                }

                // 4) Get app usage summary (last 24h) as JSON
                "getUsageSummary" -> {
                    if (!hasUsageStatsPermission(this)) {
                        result.error("NO_PERMISSION", "Usage access not granted", null)
                    } else {
                        try {
                            val json = getUsageSummaryJson(this)
                            result.success(json)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "getUsageSummary error", e)
                            result.error("USAGE_ERROR", e.message, null)
                        }
                    }
                }

                "openAccessibilitySettings" -> {
                    openAccessibilitySettings(this)
                    result.success(null)
                }

                "getDailyUsageHistory" -> {
                    if (!hasUsageStatsPermission(this)) {
                        result.error("NO_PERMISSION", "Usage access not granted", null)
                    } else {
                        try {
                            // List of human-readable app names from Flutter
                            val selectedNames: List<String> =
                                call.argument<List<String>>("apps") ?: emptyList()
                            val json = getDailyUsageHistoryJson(this, selectedNames)
                            result.success(json)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "getDailyUsageHistory error", e)
                            result.error("USAGE_ERROR", e.message, null)
                        }
                    }
                }

                "setAllowedUntil" -> {
                    val appName = call.argument<String>("appName") ?: "Instagram"
                    val allowedUntil = call.argument<Long>("allowedUntil") ?: 0L

                    val prefs = getSharedPreferences("app_block_prefs", Context.MODE_PRIVATE)
                    if (appName == "Instagram") {
                        prefs.edit()
                            .putLong("allowed_until_instagram", allowedUntil)
                            .apply()
                    }
                    result.success(null)
                }



                else -> result.notImplemented()
            }
        }
    }

    private fun openAccessibilitySettings(context: Context) {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val newRoute = intent.getStringExtra("route")
        Log.d("MainActivity", "onNewIntent with route=$newRoute")

        if (newRoute == "/reason") {
            methodChannel?.invokeMethod("openReason", null)
        }
    }

    // ---------------- USAGE STATS HELPERS ----------------

    private fun hasUsageStatsPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings(context: Context) {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    /**
     * JSON array string of last 24h usage:
     * [
     *   { "packageName": "...", "totalTimeForeground": <ms>, "lastTimeUsed": <ms> },
     *   ...
     * ]
     */
    private fun getUsageSummaryJson(context: Context): String {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val end = System.currentTimeMillis()
        val start = end - 24L * 60L * 60L * 1000L // last 24 hours

        val rawStats: List<UsageStats> =
            usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end) ?: emptyList()

        val totalTime = mutableMapOf<String, Long>()
        val lastUsed = mutableMapOf<String, Long>()

        for (s in rawStats) {
            val pkg = s.packageName ?: continue
            val currentTime = totalTime[pkg] ?: 0L
            totalTime[pkg] = currentTime + s.totalTimeInForeground
            val currentLast = lastUsed[pkg] ?: 0L
            if (s.lastTimeUsed > currentLast) {
                lastUsed[pkg] = s.lastTimeUsed
            }
        }

        val arr = JSONArray()
        val pm = context.packageManager

        for ((pkg, t) in totalTime) {
            val minutes = (t / 60000).toInt()
            if (minutes <= 5) continue  // filter here: only > 0 min

            val appName = try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                pkg // fallback
            }

            // Build base64 icon
            val iconBase64: String? = try {
                val drawable = pm.getApplicationIcon(pkg)
                val bitmap: Bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                    drawable.bitmap
                } else {
                    // Render any non-bitmap drawable into a bitmap
                    val size = 128
                    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }

                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
            } catch (e: Exception) {
                null
            }

            val obj = JSONObject()
            obj.put("packageName", pkg)
            obj.put("appName", appName)
            obj.put("totalTimeForeground", t)
            obj.put("totalMinutes", minutes)
            obj.put("lastTimeUsed", lastUsed[pkg] ?: 0L)
            if (iconBase64 != null) {
                obj.put("iconBase64", iconBase64)
            }
            arr.put(obj)
        }

        // Sort array by totalMinutes DESC
        val sorted = JSONArray()
        arr.toList()
            .sortedByDescending { (it as JSONObject).getInt("totalMinutes") }
            .forEach { sorted.put(it) }

        return sorted.toString()
    }


    /**
     * Daily usage for the last N days as JSON array.
     * Only counts apps whose *label* is contained in selectedAppNames
     * (unless selectedAppNames is empty -> then we count all apps).
     *
     * [
     *   { "date": "2025-10-01", "totalMinutes": 123 },
     *   ...
     * ]
     */
    private fun getDailyUsageHistoryJson(
        context: Context,
        selectedAppNames: List<String>
    ): String {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = context.packageManager

        val daysBack = 180 // last 180 days
        val dayMillis = 24L * 60L * 60L * 1000L

        // Today at local midnight
        val cal = java.util.Calendar.getInstance()
        cal.timeInMillis = System.currentTimeMillis()
        cal.set(java.util.Calendar.HOUR_OF_DAY, 0)
        cal.set(java.util.Calendar.MINUTE, 0)
        cal.set(java.util.Calendar.SECOND, 0)
        cal.set(java.util.Calendar.MILLISECOND, 0)
        val todayMidnight = cal.timeInMillis

        val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        val arr = JSONArray()

        // Cache packageName -> appLabel to avoid repeated PM lookups
        val labelCache = mutableMapOf<String, String?>()

        fun getAppLabel(pkg: String): String? {
            return labelCache.getOrPut(pkg) {
                try {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: Exception) {
                    null
                }
            }
        }

        val filterByNames = selectedAppNames.isNotEmpty()

        // Oldest -> newest
        for (i in daysBack downTo 1) {
            val dayStart = todayMidnight - i * dayMillis
            val dayEnd = dayStart + dayMillis

            val stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                dayStart,
                dayEnd
            ) ?: emptyList()

            var totalMs = 0L

            for (s in stats) {
                val pkg = s.packageName ?: continue

                if (filterByNames) {
                    val label = getAppLabel(pkg) ?: continue
                    if (!selectedAppNames.contains(label)) {
                        // Skip apps not selected in settings
                        continue
                    }
                }

                totalMs += s.totalTimeInForeground
            }

            val minutes = (totalMs / 60000L).toInt()
            val obj = JSONObject()
            obj.put("date", dateFormat.format(java.util.Date(dayStart)))
            obj.put("totalMinutes", minutes)
            arr.put(obj)
        }

        return arr.toString()
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
                fgServiceIntent = Intent(this, ScreenCaptureForegroundService::class.java)
                ContextCompat.startForegroundService(this, fgServiceIntent!!)

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
                }, 200)
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
                val currentResult = pendingCaptureResult ?: return@setOnImageAvailableListener
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

                currentResult.success(bytes)

            }, Handler(Looper.getMainLooper()))

        } catch (e: Exception) {
            Log.e("MainActivity", "captureFrameOnce error: ${e.message}", e)
            val currentResult = pendingCaptureResult
            pendingCaptureResult = null
            stopScreenCapture()
            currentResult?.error("CAPTURE_ERROR", e.message, null)
        }
    }

    private fun stopScreenCapture() {
        try {
            //virtualDisplay?.release()
            //virtualDisplay = null

            //imageReader?.setOnImageAvailableListener(null, null)
            //imageReader?.close()
            //imageReader = null

            //mediaProjection?.stop()
            //mediaProjection = null

            //fgServiceIntent?.let {
                //stopService(it)
                //fgServiceIntent = null
            //}
        } catch (e: Exception) {
            Log.e("MainActivity", "stopScreenCapture error: ${e.message}", e)
        }
    }
}

private fun JSONArray.toList(): List<Any> {
    val list = mutableListOf<Any>()
    for (i in 0 until this.length()) {
        list.add(this.get(i))
    }
    return list
}

