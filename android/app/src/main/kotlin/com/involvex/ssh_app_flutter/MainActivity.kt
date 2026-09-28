package com.involvex.ssh_app_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
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
    }

    companion object {
        private const val CHANNEL = "com.involvex.ssh_app/connection_service"
    }
}
