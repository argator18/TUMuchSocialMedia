package com.example.tumuch_app   // <-- keep your real package

import android.os.Handler
import android.os.Looper
import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

class AppBlockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockService"
        private const val INSTAGRAM_PACKAGE = "com.instagram.android"

        private const val PREFS_NAME = "app_block_prefs"
        private const val KEY_USED_MILLIS = "used_millis_instagram"
        private const val KEY_SEEN_INTRO = "seen_instagram_intro"
        private const val KEY_ALLOWED_UNTIL = "allowed_until_instagram"  // <-- NEW

        // 30 minutes in milliseconds (here: 1 minute for testing)
        // private const val LIMIT_MILLIS = 30L * 60L * 1000L
        private const val LIMIT_MILLIS = 60L * 1000L
    }

    private val prefs by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    // when Instagram is currently in foreground, we track when that started
    private var currentInstagramStart: Long? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString() ?: return

        Log.d(TAG, "Event from package: $pkg, type: ${event.eventType}")

        // We only care about window / content changes
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            return
        }

        val root = rootInActiveWindow ?: return
        val now = System.currentTimeMillis()

        if (event.packageName?.toString() == "com.android.chrome" ||
            event.packageName?.toString() == "org.mozilla.firefox"
        ) {
            val url = findUrlInTree(root)
            if (url != null) {
                Log.d(TAG, "Aktuelle URL: $url")
            }
            if (!url.isNullOrEmpty() && url.contains("instagram", ignoreCase = true)) {
                performGlobalAction(GLOBAL_ACTION_BACK)
                handleInstagramForeground(now)
            }
        } else {
            Log.d(TAG, "Package: ${event.packageName}")
        }

        if (pkg == INSTAGRAM_PACKAGE) {
            handleInstagramForeground(now)
        } else {
            handleOtherAppForeground(now)
        }
    }

    private fun handleInstagramForeground(now: Long) {
        // ---------- NEW: respect allowed-until window ----------
        val allowedUntil = prefs.getLong(KEY_ALLOWED_UNTIL, 0L)
        if (allowedUntil > 0L && now < allowedUntil) {
            Log.d(
                TAG,
                "Instagram currently allowed until $allowedUntil (now=$now) -> letting it run"
            )
            // This session should NOT count towards the base daily limit
            currentInstagramStart = null
            return
        }
        // ------------------------------------------------------

        var used = prefs.getLong(KEY_USED_MILLIS, 0L)
        val seenIntro = prefs.getBoolean(KEY_SEEN_INTRO, false)

        // 1) FIRST TIME EVER user opens Instagram: open our Flutter app
        if (!seenIntro) {
            prefs.edit().putBoolean(KEY_SEEN_INTRO, true).apply()
            Log.d(TAG, "First Instagram open -> launching our app")
            launchOurApp()
        }

        // 2) Start session timing if not started
        if (currentInstagramStart == null) {
            currentInstagramStart = now
        }

        // Approximate total time including ongoing session
        val sessionStart = currentInstagramStart
        if (sessionStart != null) {
            val total = used + (now - sessionStart)
            Log.d(TAG, "Instagram total usage so far (limit-phase): $total ms")

            if (total >= LIMIT_MILLIS) {
                // Save the updated total and block
                prefs.edit().putLong(KEY_USED_MILLIS, total).apply()
                Log.d(TAG, "Limit reached -> blocking Instagram")
                blockInstagram()
            }
        }
    }

    private fun handleOtherAppForeground(now: Long) {
        // If we were timing an IG session and the user left IG, store elapsed time
        val start = currentInstagramStart ?: return

        val used = prefs.getLong(KEY_USED_MILLIS, 0L)
        val delta = now - start
        val newTotal = used + delta

        prefs.edit().putLong(KEY_USED_MILLIS, newTotal).apply()
        currentInstagramStart = null

        Log.d(TAG, "User left Instagram. Added $delta ms, total $newTotal ms")
    }

    private fun blockInstagram() {
        // 1) Go to home so IG loses focus
        performGlobalAction(GLOBAL_ACTION_HOME)

        // 2) After a short delay, launch our Flutter app
        Handler(Looper.getMainLooper()).postDelayed({
            launchOurApp()
        }, 300L) // 300 ms is usually enough; adjust if needed
    }

    override fun onInterrupt() {
        // No special cleanup
    }

    private fun launchOurApp() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                // Kill any existing task for this app and start a new one
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TASK
                )
                putExtra("route", "/reason")
            }
            Log.d(TAG, "launchOurApp: starting MainActivity with route=/reason (clear task)")
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching app: ${e.message}", e)
        }
    }

    // test: check browser content:
    private fun findUrlInTree(node: AccessibilityNodeInfo): String? {
        val txt = node.text?.toString() ?: ""

        if (txt.startsWith("http://") ||
            txt.startsWith("https://") ||
            txt.endsWith(".com") ||
            txt.endsWith(".de")
        ) {
            return txt
        }

        for (i in 0 until node.childCount) {
          val child = node.getChild(i) ?: continue
          val res = findUrlInTree(child)
          child.recycle()
          if (res != null) return res
        }
        return null
    }
}

