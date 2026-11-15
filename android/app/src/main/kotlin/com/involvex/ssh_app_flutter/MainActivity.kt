package com.involvex.ssh_app_flutter

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.text.Selection
import android.text.Spannable
import android.widget.EditText
import android.widget.FrameLayout
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CLIPBOARD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setClipboardText" -> {
                    val text = call.argument<String>("text") ?: ""
                    result.success(copyTextForImeHistory(text))
                }
                "getClipboardText" -> {
                    val clipboard =
                        getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = clipboard.primaryClip
                    if (clip == null || clip.itemCount == 0) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(clip.getItemAt(0).coerceToText(this)?.toString())
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

    /**
     * Writes plain text the way a normal EditText copy does so Gboard / other
     * IMEs record it in clipboard history. Phone Link already sees a plain
     * [ClipboardManager.setPrimaryClip]; Gboard is pickier about source.
     */
    private fun copyTextForImeHistory(text: String): Boolean {
        if (text.isEmpty()) {
            return false
        }
        setPrimaryClipPlain(text)
        // Second pass via a real selectable editor mirrors user "Copy" and is
        // what Gboard's history listener typically keys off of.
        try {
            copyViaTransientEditor(text)
        } catch (_: Exception) {
            // Primary clip already set.
        }
        // Re-assert after IME / Flutter focus churn from clearing selection.
        Handler(Looper.getMainLooper()).postDelayed({
            setPrimaryClipPlain(text)
        }, 120)
        return true
    }

    private fun setPrimaryClipPlain(text: String) {
        val clipboard =
            getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        // Null label matches TextView's own copy path.
        val clip = ClipData.newPlainText(null, text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, false)
            }
        }
        clipboard.setPrimaryClip(clip)
    }

    private fun copyViaTransientEditor(text: String) {
        val root = window?.decorView as? FrameLayout ?: return
        val editor = EditText(this).apply {
            // Keep off-screen / zero-size so it never flashes in the UI.
            layoutParams = FrameLayout.LayoutParams(1, 1)
            alpha = 0f
            importantForAccessibility =
                android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
            setText(text, android.widget.TextView.BufferType.EDITABLE)
            val editable = getText()
            if (editable is Spannable) {
                Selection.setSelection(editable, 0, editable.length)
            } else {
                setSelection(0, text.length)
            }
        }
        root.addView(editor)
        editor.requestFocus()
        editor.onTextContextMenuItem(android.R.id.copy)
        root.post {
            root.removeView(editor)
        }
    }

    companion object {
        private const val CONNECTION_CHANNEL =
            "com.involvex.ssh_app/connection_service"
        private const val SHARE_CHANNEL =
            "com.involvex.ssh_app/share_intent"
        private const val CLIPBOARD_CHANNEL =
            "com.involvex.ssh_app/clipboard"
    }
}
