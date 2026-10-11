package com.anistar.anistar_tv

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var screenAwakeChannel: MethodChannel? = null
    private var resumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setScreenAwake(false)
        screenAwakeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "anistar_tv/playback_screen_awake"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        val enabled = call.arguments as? Boolean
                        if (enabled == null) {
                            result.error("invalid_argument", "Expected a boolean", null)
                        } else {
                            setScreenAwake(enabled && resumed)
                            result.success(null)
                        }
                    }
                    "isEnabled" -> result.success(
                        window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0
                    )
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        resumed = true
        super.onResume()
    }

    override fun onPause() {
        resumed = false
        setScreenAwake(false)
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        screenAwakeChannel?.setMethodCallHandler(null)
        screenAwakeChannel = null
        setScreenAwake(false)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        resumed = false
        setScreenAwake(false)
        super.onDestroy()
    }

    private fun setScreenAwake(enabled: Boolean) {
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
