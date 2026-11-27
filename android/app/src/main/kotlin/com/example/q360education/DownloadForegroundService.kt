package com.qimma.education

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DownloadForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "lecture_downloads"
        const val NOTIFICATION_ID = 7301
        const val ACTION_START = "download.start"
        const val ACTION_PROGRESS = "download.progress"
        const val ACTION_COMPLETE = "download.complete"
        const val ACTION_STOP = "download.stop"
        const val EXTRA_ID = "lecture_id"
        const val EXTRA_TITLE = "lecture_title"
        const val EXTRA_PROGRESS = "progress"
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "التنزيلات",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "تقدم تنزيل الملفات"
                setSound(null, null)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        val id = intent?.getStringExtra(EXTRA_ID).orEmpty()
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "الفيديو"
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0

        when (action) {
            ACTION_START, ACTION_PROGRESS -> {
                val notification = buildNotification(id, title, progress)
                if (action == ACTION_START) startForeground(NOTIFICATION_ID, notification)
                else getSystemService(NotificationManager::class.java)
                    .notify(NOTIFICATION_ID, notification)
            }
            ACTION_COMPLETE -> {
                val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                    .setSmallIcon(applicationInfo.icon)
                    .setContentTitle("اكتمل التنزيل")
                    .setContentText(title)
                    .setOnlyAlertOnce(true)
                    .setAutoCancel(true)
                    .build()
                stopForeground(STOP_FOREGROUND_REMOVE)
                getSystemService(NotificationManager::class.java)
                    .notify(NOTIFICATION_ID, notification)
                stopSelf()
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(id: String, title: String, progress: Int) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("جاري التنزيل")
            .setContentText("$title • $progress%")
            .setProgress(100, progress, false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "إلغاء",
                PendingIntent.getActivity(
                    this,
                    id.hashCode(),
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("cancel_download_id", id)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()

    override fun onBind(intent: Intent?): IBinder? = null
}
