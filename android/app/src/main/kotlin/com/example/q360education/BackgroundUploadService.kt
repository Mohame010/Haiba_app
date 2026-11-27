package com.qimma.education

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class BackgroundUploadService : Service() {
    companion object {
        const val CHANNEL_ID = "lesson_uploads"
        const val ACTION_ENQUEUE = "upload.enqueue"
        const val EXTRA_ID = "upload_id"
        const val EXTRA_TITLE = "upload_title"
        const val EXTRA_FILE_PATH = "upload_file_path"
        const val EXTRA_UPLOAD_URL = "upload_url"
        const val EXTRA_CONTENT_TYPE = "content_type"
    }

    private val executor = Executors.newFixedThreadPool(2)

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "رفع فيديوهات الحصص",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "تقدم رفع فيديوهات الحصص في الخلفية"
                setSound(null, null)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_ENQUEUE) return START_NOT_STICKY
        val id = intent.getStringExtra(EXTRA_ID).orEmpty()
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "فيديو الحصة"
        val filePath = intent.getStringExtra(EXTRA_FILE_PATH).orEmpty()
        val uploadUrl = intent.getStringExtra(EXTRA_UPLOAD_URL).orEmpty()
        val contentType = intent.getStringExtra(EXTRA_CONTENT_TYPE)
            ?: "application/octet-stream"
        val notificationId = (id.hashCode() and 0x7fffffff).coerceAtLeast(1)

        startForeground(notificationId, progressNotification(title, 0))
        executor.execute {
            upload(
                title = title,
                filePath = filePath,
                uploadUrl = uploadUrl,
                contentType = contentType,
                notificationId = notificationId
            )
            stopSelf(startId)
        }
        return START_REDELIVER_INTENT
    }

    private fun upload(
        title: String,
        filePath: String,
        uploadUrl: String,
        contentType: String,
        notificationId: Int
    ) {
        val manager = getSystemService(NotificationManager::class.java)
        try {
            val file = File(filePath)
            require(file.exists()) { "Upload file no longer exists" }
            val connection = URL(uploadUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "PUT"
            connection.doOutput = true
            connection.connectTimeout = 30_000
            connection.readTimeout = 60_000
            connection.setRequestProperty("Content-Type", contentType)
            connection.setFixedLengthStreamingMode(file.length())

            file.inputStream().use { input ->
                connection.outputStream.use { output ->
                    val buffer = ByteArray(256 * 1024)
                    var uploaded = 0L
                    var read: Int
                    var lastProgress = -1
                    while (input.read(buffer).also { read = it } >= 0) {
                        output.write(buffer, 0, read)
                        uploaded += read
                        val progress = if (file.length() == 0L) 100
                            else ((uploaded * 100) / file.length()).toInt()
                        if (progress != lastProgress) {
                            lastProgress = progress
                            manager.notify(
                                notificationId,
                                progressNotification(title, progress)
                            )
                        }
                    }
                }
            }

            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                throw IllegalStateException("Upload failed with HTTP $responseCode")
            }
            manager.notify(
                notificationId,
                resultNotification("اكتمل رفع الفيديو", title, false)
            )
            connection.disconnect()
        } catch (error: Exception) {
            manager.notify(
                notificationId,
                resultNotification("تعذر رفع الفيديو", "$title • ${error.message}", true)
            )
        } finally {
            stopForeground(STOP_FOREGROUND_DETACH)
        }
    }

    private fun progressNotification(title: String, progress: Int) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("جارٍ رفع فيديو الحصة")
            .setContentText("$title • $progress%")
            .setProgress(100, progress, false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(openAppIntent())
            .build()

    private fun resultNotification(title: String, body: String, failed: Boolean) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setOnlyAlertOnce(false)
            .setContentIntent(openAppIntent())
            .apply { if (!failed) setDefaults(NotificationCompat.DEFAULT_ALL) }
            .build()

    private fun openAppIntent() = PendingIntent.getActivity(
        this,
        7412,
        Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
