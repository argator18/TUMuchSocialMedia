package com.example.tumuch_app   // <-- CHANGE to your real package

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.content.Context
import android.util.Log

class AppBlockAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockService"
        private const val INSTAGRAM_PACKAGE = "com.instagram.android"

        private const val PREFS_NAME = "app_block_prefs"
        private const val KEY_USED_MILLIS = "used_millis_instagram"
        private const val KEY_SEEN_INTRO = "seen_instagram_intro"

        // 30 minutes in milliseconds
        //private const val LIMIT_MILLIS = 30L * 60L * 1000L
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

        val now = System.currentTimeMillis()

        if (pkg == INSTAGRAM_PACKAGE) {
            handleInstagramForeground(now)
        } else {
            handleOtherAppForeground(now)
        }
    }

    private fun handleInstagramForeground(now: Long) {
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
            Log.d(TAG, "Instagram total usage so far: $total ms")

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
        // Go to home so IG loses focus
        performGlobalAction(GLOBAL_ACTION_HOME)

        // Then open our Flutter app (MainActivity -> main.dart)
        launchOurApp()
    }

    private fun launchOurApp() {
        try {
            // MainActivity is the default Flutter entry activity
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching app: ${e.message}", e)
        }
    }

    override fun onInterrupt() {
        // No special cleanup
    }
}

