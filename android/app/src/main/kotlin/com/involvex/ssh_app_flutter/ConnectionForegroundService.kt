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
                startInForeground(count)
                return START_STICKY
            }
        }
    }

    private fun startInForeground(connectionCount: Int) {
        createChannel()

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

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PocketShell")
            .setContentText(label)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Active connections",
            NotificationManager.IMPORTANCE_LOW,
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
        const val ACTION_STOP = "com.involvex.ssh_app.STOP_FGS"

        fun start(context: Context, connectionCount: Int) {
            val intent = Intent(context, ConnectionForegroundService::class.java).apply {
                putExtra(EXTRA_CONNECTION_COUNT, connectionCount)
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
