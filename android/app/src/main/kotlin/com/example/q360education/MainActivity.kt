package com.qimma.education

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingCancelId: String? = null
    private var pronunciationRecorder: MediaRecorder? = null
    private var pendingAudioPermissionResult: MethodChannel.Result? = null
    private var pronunciationRecordingPath: String? = null
    private var pronunciationRecordingStartedAt = 0L

    companion object {
        private const val AUDIO_PERMISSION_REQUEST = 7401
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "q360education/downloads"
        )
        channel?.setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *>
            val id = args?.get("lectureId")?.toString().orEmpty()
            val title = args?.get("title")?.toString() ?: "الفيديو"
            val progress = (args?.get("progress") as? Number)?.toInt() ?: 0
            when (call.method) {
                "ready" -> {
                    deliverCancelRequest()
                    result.success(null)
                }
                "start", "progress", "complete", "stop" -> {
                    val action = when (call.method) {
                        "start" -> DownloadForegroundService.ACTION_START
                        "progress" -> DownloadForegroundService.ACTION_PROGRESS
                        "complete" -> DownloadForegroundService.ACTION_COMPLETE
                        else -> DownloadForegroundService.ACTION_STOP
                    }
                    val serviceIntent = Intent(this, DownloadForegroundService::class.java).apply {
                        this.action = action
                        putExtra(DownloadForegroundService.EXTRA_ID, id)
                        putExtra(DownloadForegroundService.EXTRA_TITLE, title)
                        putExtra(DownloadForegroundService.EXTRA_PROGRESS, progress)
                    }
                    if (call.method == "start") {
                        ContextCompat.startForegroundService(this, serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "q360education/novel_playback"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val serviceIntent = Intent(
                        this,
                        NovelPlaybackForegroundService::class.java
                    ).apply {
                        action = NovelPlaybackForegroundService.ACTION_START
                        putExtra(
                            NovelPlaybackForegroundService.EXTRA_TITLE,
                            call.argument<String>("title") ?: "رواية"
                        )
                    }
                    ContextCompat.startForegroundService(this, serviceIntent)
                    result.success(null)
                }
                "stop" -> {
                    stopService(
                        Intent(this, NovelPlaybackForegroundService::class.java)
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "q360education/uploads"
        ).setMethodCallHandler { call, result ->
            if (call.method != "enqueue") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val args = call.arguments as? Map<*, *>
            val uploadIntent = Intent(this, BackgroundUploadService::class.java).apply {
                action = BackgroundUploadService.ACTION_ENQUEUE
                putExtra(BackgroundUploadService.EXTRA_ID, args?.get("id")?.toString().orEmpty())
                putExtra(BackgroundUploadService.EXTRA_TITLE, args?.get("title")?.toString())
                putExtra(BackgroundUploadService.EXTRA_FILE_PATH, args?.get("filePath")?.toString())
                putExtra(BackgroundUploadService.EXTRA_UPLOAD_URL, args?.get("uploadUrl")?.toString())
                putExtra(BackgroundUploadService.EXTRA_CONTENT_TYPE, args?.get("contentType")?.toString())
            }
            ContextCompat.startForegroundService(this, uploadIntent)
            result.success(null)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "q360education/screen_protection"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disable" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "q360education/pronunciation_recorder"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECORD_AUDIO
                        ) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else if (pendingAudioPermissionResult != null) {
                        result.error("permission_pending", "Permission request is already active", null)
                    } else {
                        pendingAudioPermissionResult = result
                        requestPermissions(
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            AUDIO_PERMISSION_REQUEST
                        )
                    }
                }
                "start" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String
                    val maxDurationSeconds =
                        (args?.get("maxDurationSeconds") as? Number)?.toInt() ?: 10
                    if (path.isNullOrBlank() || maxDurationSeconds !in 1..10) {
                        result.error("invalid_recording", "Invalid recording settings", null)
                    } else if (pronunciationRecorder != null) {
                        result.error("recording_active", "A recording is already active", null)
                    } else if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECORD_AUDIO
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        result.error("permission_denied", "Microphone permission is required", null)
                    } else {
                        var recorder: MediaRecorder? = null
                        try {
                            @Suppress("DEPRECATION")
                            val activeRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                MediaRecorder(this)
                            } else {
                                MediaRecorder()
                            }
                            recorder = activeRecorder
                            activeRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                            activeRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                            activeRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                            activeRecorder.setAudioEncodingBitRate(16_000)
                            activeRecorder.setAudioSamplingRate(16_000)
                            activeRecorder.setAudioChannels(1)
                            activeRecorder.setMaxDuration(maxDurationSeconds * 1000)
                            activeRecorder.setOutputFile(path)
                            activeRecorder.prepare()
                            activeRecorder.start()
                            pronunciationRecorder = activeRecorder
                            pronunciationRecordingPath = path
                            pronunciationRecordingStartedAt = SystemClock.elapsedRealtime()
                            result.success(null)
                        } catch (error: Exception) {
                            recorder?.release()
                            pronunciationRecorder = null
                            pronunciationRecordingPath = null
                            pronunciationRecordingStartedAt = 0L
                            result.error("recording_start_failed", error.localizedMessage, null)
                        }
                    }
                }
                "amplitude" -> {
                    try {
                        val amplitude = pronunciationRecorder?.maxAmplitude ?: 0
                        result.success((amplitude / 32767.0).coerceIn(0.0, 1.0))
                    } catch (error: Exception) {
                        result.error("recording_amplitude_failed", error.localizedMessage, null)
                    }
                }
                "stop" -> {
                    val recorder = pronunciationRecorder
                    val path = pronunciationRecordingPath
                    if (recorder == null || path == null) {
                        result.success(null)
                    } else {
                        val durationMs =
                            (SystemClock.elapsedRealtime() - pronunciationRecordingStartedAt).toInt()
                        try {
                            recorder.stop()
                        } catch (_: RuntimeException) {
                            // A very short clip or the native duration guard may stop first.
                        } finally {
                            recorder.release()
                            pronunciationRecorder = null
                            pronunciationRecordingPath = null
                            pronunciationRecordingStartedAt = 0L
                        }
                        result.success(mapOf("path" to path, "durationMs" to durationMs))
                    }
                }
                else -> result.notImplemented()
            }
        }
        pendingCancelId = intent?.getStringExtra("cancel_download_id")
    }

    override fun onDestroy() {
        pronunciationRecorder?.let { recorder ->
            try {
                recorder.stop()
            } catch (_: RuntimeException) {
                // Release even if recording did not produce a playable clip.
            } finally {
                recorder.release()
            }
        }
        pronunciationRecorder = null
        pendingAudioPermissionResult?.error(
            "activity_destroyed",
            "Activity ended before microphone permission was resolved",
            null
        )
        pendingAudioPermissionResult = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == AUDIO_PERMISSION_REQUEST) {
            pendingAudioPermissionResult?.success(
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            pendingAudioPermissionResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingCancelId = intent.getStringExtra("cancel_download_id")
        deliverCancelRequest()
    }

    private fun deliverCancelRequest() {
        val id = pendingCancelId ?: return
        pendingCancelId = null
        channel?.invokeMethod("cancelRequested", id)
    }
}
