package com.involvex.ssh_app_flutter

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var sharedText: String? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShareIntent(intent)
        sharedText?.let { text ->
            shareChannel?.invokeMethod("onSharedText", text)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONNECTION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val count = call.argument<Int>("connectionCount") ?: 1
                    val prominent = call.argument<Boolean>("prominent") ?: false
                    ConnectionForegroundService.start(this, count, prominent)
                    result.success(null)
                }
                "setNotificationPriority" -> {
                    val prominent = call.argument<Boolean>("prominent") ?: false
                    ConnectionForegroundService.setPriority(this, prominent)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    ConnectionForegroundService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedText" -> result.success(sharedText)
                    "clearSharedText" -> {
                        sharedText = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun captureShareIntent(intent: Intent?) {
        if (intent == null) {
            return
        }
        if (Intent.ACTION_SEND == intent.action &&
            intent.type?.startsWith("text/") == true
        ) {
            sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        }
    }

    companion object {
        private const val CONNECTION_CHANNEL =
            "com.involvex.ssh_app/connection_service"
        private const val SHARE_CHANNEL =
            "com.involvex.ssh_app/share_intent"
    }
}
