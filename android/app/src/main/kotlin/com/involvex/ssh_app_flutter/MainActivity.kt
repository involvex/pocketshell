package com.involvex.ssh_app_flutter

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.os.PersistableBundle
import android.provider.OpenableColumns
import android.text.Selection
import android.text.Spannable
import android.widget.EditText
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var sharedText: String? = null
    private var sharedFiles: ArrayList<HashMap<String, String>>? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShareIntent(intent)
        sharedFiles?.let { files ->
            shareChannel?.invokeMethod("onSharedFiles", files)
            return
        }
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
            WINDOW_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureFlag" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    if (enabled) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
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
                    "getSharedFiles" -> result.success(sharedFiles)
                    "clearSharedFiles" -> {
                        sharedFiles = null
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
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val stream = readSingleStream(intent)
                if (stream != null) {
                    sharedText = null
                    val copied = copyUriToCache(stream)
                    sharedFiles = if (copied != null) {
                        arrayListOf(copied)
                    } else {
                        null
                    }
                    return
                }
                if (intent.type?.startsWith("text/") == true) {
                    sharedFiles = null
                    sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val streams = readMultipleStreams(intent)
                if (streams.isEmpty()) {
                    return
                }
                sharedText = null
                val copied = ArrayList<HashMap<String, String>>()
                for (uri in streams) {
                    val item = copyUriToCache(uri) ?: continue
                    copied.add(item)
                }
                sharedFiles = if (copied.isEmpty()) null else copied
            }
        }
    }

    private fun readSingleStream(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun readMultipleStreams(intent: Intent): List<Uri> {
        val list = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
        return list ?: emptyList()
    }

    /**
     * Streams a content [Uri] into app cache. Returns path + display name for
     * Dart; never loads the whole file into memory as a byte array.
     */
    private fun copyUriToCache(uri: Uri): HashMap<String, String>? {
        val displayName = resolveDisplayName(uri) ?: "shared_file"
        val safeName = sanitizeFileName(displayName)
        val dir = File(cacheDir, "shared_uploads").apply { mkdirs() }
        val outFile = File(dir, "${System.currentTimeMillis()}_$safeName")
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null
            hashMapOf(
                "path" to outFile.absolutePath,
                "name" to safeName,
            )
        } catch (_: Exception) {
            if (outFile.exists()) {
                outFile.delete()
            }
            null
        }
    }

    private fun resolveDisplayName(uri: Uri): String? {
        if (uri.scheme == "content") {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) {
                        val name = cursor.getString(index)
                        if (!name.isNullOrBlank()) {
                            return name
                        }
                    }
                }
            }
        }
        return uri.lastPathSegment
    }

    private fun sanitizeFileName(name: String): String {
        val trimmed = name.trim().ifEmpty { "shared_file" }
        return trimmed.replace(Regex("[\\\\/]+"), "_")
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
        private const val WINDOW_CHANNEL =
            "com.involvex.ssh_app/window"
    }
}
