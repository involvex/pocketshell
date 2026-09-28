package com.involvex.ssh_app_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ConnectionForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val count = intent?.getIntExtra(EXTRA_CONNECTION_COUNT, 1) ?: 1
                val prominent = intent?.getBooleanExtra(EXTRA_PROMINENT, lastProminent) ?: lastProminent
                startInForeground(count, prominent)
                return START_STICKY
            }
        }
    }

    private fun startInForeground(connectionCount: Int, prominent: Boolean) {
        lastCount = connectionCount
        lastProminent = prominent
        ensureChannel(prominent)
        startForeground(NOTIFICATION_ID, buildNotification(connectionCount))
    }

    private fun buildNotification(connectionCount: Int): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val label = if (connectionCount == 1) {
            "1 active connection"
        } else {
            "$connectionCount active connections"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PocketShell")
            .setContentText(label)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun desiredImportance(prominent: Boolean): Int {
        return if (prominent) {
            NotificationManager.IMPORTANCE_DEFAULT
        } else {
            NotificationManager.IMPORTANCE_LOW
        }
    }

    private fun ensureChannel(prominent: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Channel importance is immutable once created: delete and recreate
        // when the desired importance differs (e.g. after a settings toggle).
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null && existing.importance == desiredImportance(prominent)) {
            return
        }
        if (existing != null) {
            manager.deleteNotificationChannel(CHANNEL_ID)
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Active connections",
            desiredImportance(prominent),
        ).apply {
            description = "Keeps SSH and agent sessions alive in the background"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "ssh_app_connections"
        const val NOTIFICATION_ID = 1001
        const val EXTRA_CONNECTION_COUNT = "connectionCount"
        const val EXTRA_PROMINENT = "prominent"
        const val ACTION_STOP = "com.involvex.ssh_app.STOP_FGS"

        private var lastCount = 1
        private var lastProminent = false

        fun start(context: Context, connectionCount: Int, prominent: Boolean) {
            val intent = Intent(context, ConnectionForegroundService::class.java).apply {
                putExtra(EXTRA_CONNECTION_COUNT, connectionCount)
                putExtra(EXTRA_PROMINENT, prominent)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun setPriority(context: Context, prominent: Boolean) {
            lastProminent = prominent
            // Re-deliver to the running service so it recreates the channel
            // and re-posts the notification with the new importance.
            val intent = Intent(context, ConnectionForegroundService::class.java).apply {
                putExtra(EXTRA_CONNECTION_COUNT, lastCount)
                putExtra(EXTRA_PROMINENT, prominent)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, ConnectionForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
