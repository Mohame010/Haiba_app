package com.qimma.education

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class NovelPlaybackForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "novel_audio_playback"
        const val NOTIFICATION_ID = 7302
        const val ACTION_START = "novel.playback.start"
        const val ACTION_STOP = "novel.playback.stop"
        const val EXTRA_TITLE = "novel_title"
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "تشغيل الروايات",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "إشعار تشغيل صوت الرواية في الخلفية"
                setSound(null, null)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> startForeground(
                NOTIFICATION_ID,
                buildNotification(intent?.getStringExtra(EXTRA_TITLE) ?: "رواية")
            )
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(title: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(
                if (title == "أصوات خلفية للمذاكرة")
                    "أصوات الخلفية تعمل"
                else
                    "جاري تشغيل الرواية"
            )
            .setContentText(title)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    NOTIFICATION_ID,
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()

    override fun onBind(intent: Intent?): IBinder? = null
}
