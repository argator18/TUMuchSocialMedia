package com.example.tumuch_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.util.Log

class MainActivity : FlutterActivity() {

    private val CHANNEL = "app.channel.route"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel!!.setMethodCallHandler { call, result ->
            if (call.method == "getInitialRoute") {
                val route = intent.getStringExtra("route") ?: "/"
                Log.d("MainActivity", "getInitialRoute -> $route")
                result.success(route)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val newRoute = intent.getStringExtra("route")
        Log.d("MainActivity", "onNewIntent with route=$newRoute")
    }
}

