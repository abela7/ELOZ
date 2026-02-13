package com.eloz.life_manager

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.KeyguardManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.util.Calendar

/**
 * Native Android Foreground Service for playing alarm sounds.
 * 
 * Uses USAGE_ALARM audio stream which:
 * - Bypasses silent mode and DND (for alarms)
 * - Respects the user's ALARM volume setting (not media volume)
 * - Works even when the app is killed
 */
class AlarmPlayerService : Service() {
    companion object {
        private const val TAG = "AlarmPlayerService"
        // IMPORTANT (Android 8+): channel sound is immutable once created/modified by OS/user.
        // If an older build created this channel with sound enabled (or the user changed it),
        // the foreground-service notification may "ding" with the device default sound.
        // Version the channel ID to guarantee a truly silent channel.
        //
        // ALSO IMPORTANT:
        // Full-screen intents/lock-screen "alarm style" UI requires HIGH importance on many OEMs.
        // So this channel is HIGH importance but still silent (no sound/vibration).
        // Bump channel ID when behavior changes (Android caches channel settings).
        private const val CHANNEL_ID = "alarm_player_channel_v5"
        private const val NOTIFICATION_ID = 9999
        
        const val ACTION_START = "com.eloz.life_manager.START_ALARM"
        const val ACTION_STOP = "com.eloz.life_manager.STOP_ALARM"
        
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_SOUND_ID = "sound_id"
        const val EXTRA_VIBRATION_PATTERN_ID = "vibration_pattern_id"
        const val EXTRA_SHOW_FULLSCREEN = "show_fullscreen"
        const val EXTRA_AUDIO_STREAM = "audio_stream" // alarm|notification|ring|media
        const val EXTRA_ONE_SHOT = "one_shot" // play once and stop
        const val EXTRA_PAYLOAD = "payload" // task|<id>|...
        const val EXTRA_ICON_PNG_BASE64 = "icon_png_base64"
        const val EXTRA_ACTIONS_ENABLED = "actions_enabled"
        const val EXTRA_ACTIONS_JSON = "actions_json" // [{"actionId":"view","label":"View"},...]
        
        // Melodic vibration patterns: [pause, vibrate, pause, vibrate...] in milliseconds
        private val VIBRATION_PATTERNS = mapOf(
            "default" to longArrayOf(0, 100, 200, 200, 200, 400, 200, 200, 200, 100, 1000),
            "echo" to longArrayOf(0, 300, 150, 100, 100, 100, 800),
            "rise" to longArrayOf(0, 50, 200, 100, 200, 200, 200, 400, 800),
            "dance" to longArrayOf(0, 150, 100, 150, 200, 300, 100, 150, 800),
            "serene" to longArrayOf(0, 600, 400, 600, 400, 1000),
            "chime" to longArrayOf(0, 100, 200, 150, 200, 200, 1000),
            "accent" to longArrayOf(0, 100, 150, 100, 800),
            "none" to longArrayOf()
        )
        
        fun getVibrationPattern(patternId: String): LongArray {
            return VIBRATION_PATTERNS[patternId] ?: VIBRATION_PATTERNS["default"]!!
        }
        
        private var isPlaying = false
        
        fun isAlarmPlaying(): Boolean = isPlaying
        
        /**
         * Start the alarm service
         * @param soundId The ID of the sound to play (e.g., "alarm", "sound_1", "sound_2")
         * @param vibrationPatternId The ID of the vibration pattern (e.g., "default", "short", "pulse")
         * @param showFullscreen If true, notifies Flutter to show AlarmScreen UI. If false, just plays sound.
         */
        fun start(
            context: Context,
            alarmId: Int,
            title: String,
            body: String,
            soundId: String = "alarm",
            vibrationPatternId: String = "default",
            showFullscreen: Boolean = true,
            audioStream: String = "alarm",
            oneShot: Boolean = false,
            payload: String = "",
            iconPngBase64: String? = null,
            actionsEnabled: Boolean = true,
            actionsJson: String? = null
        ) {
            val intent = Intent(context, AlarmPlayerService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_SOUND_ID, soundId)
                putExtra(EXTRA_VIBRATION_PATTERN_ID, vibrationPatternId)
                putExtra(EXTRA_SHOW_FULLSCREEN, showFullscreen)
                putExtra(EXTRA_AUDIO_STREAM, audioStream)
                putExtra(EXTRA_ONE_SHOT, oneShot)
                putExtra(EXTRA_PAYLOAD, payload)
                putExtra(EXTRA_ACTIONS_ENABLED, actionsEnabled)
                if (!iconPngBase64.isNullOrBlank()) {
                    putExtra(EXTRA_ICON_PNG_BASE64, iconPngBase64)
                }
                if (!actionsJson.isNullOrBlank()) {
                    putExtra(EXTRA_ACTIONS_JSON, actionsJson)
                }
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        /**
         * Stop the alarm service
         */
        fun stop(context: Context) {
            val intent = Intent(context, AlarmPlayerService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
    
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var screenWakeLock: PowerManager.WakeLock? = null
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "Service created")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START -> {
                val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, 0)
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Alarm"
                val body = intent.getStringExtra(EXTRA_BODY) ?: ""
                val soundId = intent.getStringExtra(EXTRA_SOUND_ID) ?: "alarm"
                val vibrationPatternId = intent.getStringExtra(EXTRA_VIBRATION_PATTERN_ID) ?: "default"
                val showFullscreen = intent.getBooleanExtra(EXTRA_SHOW_FULLSCREEN, true)
                val audioStream = intent.getStringExtra(EXTRA_AUDIO_STREAM) ?: "alarm"
                val oneShot = intent.getBooleanExtra(EXTRA_ONE_SHOT, false)
                val payload = intent.getStringExtra(EXTRA_PAYLOAD) ?: ""
                val iconPngBase64 = intent.getStringExtra(EXTRA_ICON_PNG_BASE64)
                val actionsEnabled = intent.getBooleanExtra(EXTRA_ACTIONS_ENABLED, true)
                val actionsJson = intent.getStringExtra(EXTRA_ACTIONS_JSON)
                
                startAlarm(alarmId, title, body, soundId, vibrationPatternId, showFullscreen, audioStream, oneShot, payload, iconPngBase64, actionsEnabled, actionsJson)
            }
            ACTION_STOP -> {
                stopAlarm()
            }
        }
        
        return START_STICKY
    }
    
    private fun startAlarm(
        alarmId: Int,
        title: String,
        body: String,
        soundId: String,
        vibrationPatternId: String,
        showFullscreen: Boolean,
        audioStream: String,
        oneShot: Boolean,
        payload: String,
        iconPngBase64: String?,
        actionsEnabled: Boolean = true,
        actionsJson: String? = null
    ) {
        // Acquire wake lock to keep CPU running
        acquireWakeLock()

        // Wake the screen briefly.
        wakeScreenBriefly()
        
        // Start foreground notification (required for Android 8+)
        val notification = createNotification(title, body, alarmId, showFullscreen, oneShot, payload, iconPngBase64, actionsEnabled, actionsJson)
        startForeground(NOTIFICATION_ID, notification)
        
        // Play sound using requested stream (alarm/media/ring/notification)
        playAlarmSound(soundId, audioStream, oneShot)
        
        // Repeat vibration only for "real alarms", not one-shot reminders.
        startVibration(vibrationPatternId, repeat = !oneShot)
        
        isPlaying = !oneShot
        Log.d(TAG, "🔔 Alarm started: $title (fullscreen: $showFullscreen)")

        // Only notify Flutter for "real" alarm UI flows.
        // One-shot reminders (regular tasks using media/ring/alarm stream) should NOT open AlarmScreen.
        if (showFullscreen && !oneShot) {
            try {
                MainActivity.notifyAlarmRing(alarmId, title, body)
            } catch (e: Exception) {
                Log.e(TAG, "Error notifying Flutter: ${e.message}")
            }
        }

        // Desired UX:
        // - If device is LOCKED: show a generic gate screen asking user to unlock (no details)
        // - If device is UNLOCKED: bring the full AlarmScreen immediately
        if (showFullscreen) {
            try {
                if (isDeviceLocked()) {
                    val gateIntent = Intent(this, AlarmGateActivity::class.java).apply {
                        addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        )
                        putExtra(EXTRA_ALARM_ID, alarmId)
                    }
                    startActivity(gateIntent)
                    Log.d(TAG, "🚪 Launched AlarmGateActivity (locked) for alarmId=$alarmId")
                } else {
                    val appIntent = Intent(this, MainActivity::class.java).apply {
                        addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        )
                        putExtra(EXTRA_ALARM_ID, alarmId)
                        putExtra(EXTRA_TITLE, title)
                        putExtra(EXTRA_BODY, body)
                    }
                    startActivity(appIntent)
                    Log.d(TAG, "🚀 Launched MainActivity (unlocked) for alarmId=$alarmId")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error launching alarm UI: ${e.message}")
            }
        }

        // One-shot reminders: stop automatically after a short window (safety net).
        if (oneShot) {
            Handler(Looper.getMainLooper()).postDelayed({ stopOneShotKeepNotification() }, 12_000L)
        }
    }

    private fun stopOneShotKeepNotification() {
        // Stop audio/vibration but keep notification in the shade.
        try {
            try {
                mediaPlayer?.apply {
                    if (isPlaying) stop()
                    release()
                }
            } catch (_: Exception) {}
            mediaPlayer = null

            try {
                vibrator?.cancel()
            } catch (_: Exception) {}
            vibrator = null

            releaseWakeLock()
            releaseScreenWakeLock()

            isPlaying = false

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(false)
            }
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping one-shot: ${e.message}")
        }
    }
    
    private fun stopAlarm() {
        Log.d(TAG, "🔕 Stopping alarm")
        
        // Stop audio
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping media player: ${e.message}")
        }
        
        // Stop vibration
        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping vibrator: ${e.message}")
        }
        
        // Release wake lock
        releaseWakeLock()
        releaseScreenWakeLock()
        
        isPlaying = false
        try {
            MainActivity.clearCurrentRingingAlarm()
        } catch (_: Exception) {}
        
        // Stop the foreground service
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
    
    /**
     * Play alarm sound using ALARM audio stream.
     * This respects the user's alarm volume setting (not media volume).
     * 
     * @param soundId The ID of the sound to play (e.g., "alarm", "sound_1", "sound_2", etc.)
     */
    private fun playAlarmSound(soundId: String, audioStream: String, oneShot: Boolean) {
        try {
            // Clean up any existing player (without stopping service)
            try {
                mediaPlayer?.apply {
                    if (isPlaying) stop()
                    release()
                }
                mediaPlayer = null
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning up old player: ${e.message}")
            }
            
            mediaPlayer = MediaPlayer()
            
            // CRITICAL: Set audio attributes BEFORE setting data source
            val usage = when (audioStream) {
                "media" -> AudioAttributes.USAGE_MEDIA
                "ring" -> AudioAttributes.USAGE_NOTIFICATION_RINGTONE
                "notification" -> AudioAttributes.USAGE_NOTIFICATION
                else -> AudioAttributes.USAGE_ALARM
            }

            // Some OEMs treat "silent mode" like DND and may suppress alarm usage unless
            // we enforce audibility. This keeps regular reminder sounds audible when the
            // user explicitly selected Alarm stream.
            val attrsBuilder = AudioAttributes.Builder()
                .setUsage(usage)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)

            if (usage == AudioAttributes.USAGE_ALARM) {
                try {
                    attrsBuilder.setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                } catch (_: Exception) {}
            }

            val audioAttributes = attrsBuilder.build()
            
            mediaPlayer?.setAudioAttributes(audioAttributes)
            
            // `soundId` can be:
            // - a raw resource name (e.g. "alarm")
            // - a URI string (content://..., file://..., android.resource://..., content://settings/...)
            val soundLower = soundId.lowercase()
            val isUri = soundLower.startsWith("content://") ||
                soundLower.startsWith("file://") ||
                soundLower.startsWith("android.resource://")

            if (isUri) {
                try {
                    val uri = Uri.parse(soundId)
                    mediaPlayer?.setDataSource(applicationContext, uri)
                    Log.d(TAG, "Using URI sound: $uri")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to use URI sound ($soundId): ${e.message}")
                    // Fall through to resource/default
                    val fallbackResId = resources.getIdentifier("alarm", "raw", packageName)
                    if (fallbackResId != 0) {
                        val uri = Uri.parse("android.resource://$packageName/$fallbackResId")
                        mediaPlayer?.setDataSource(applicationContext, uri)
                        Log.d(TAG, "URI failed, using alarm.mp3")
                    } else {
                        val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        mediaPlayer?.setDataSource(applicationContext, defaultUri)
                        Log.d(TAG, "URI failed, using system default")
                    }
                }
            } else {
                // Treat as raw resource name
                val resId = resources.getIdentifier(soundId, "raw", packageName)
                if (resId != 0) {
                    val uri = Uri.parse("android.resource://$packageName/$resId")
                    mediaPlayer?.setDataSource(applicationContext, uri)
                    Log.d(TAG, "Using raw resource: $soundId")
                } else {
                    // Fallback to default alarm.mp3 if sound not found
                    val fallbackResId = resources.getIdentifier("alarm", "raw", packageName)
                    if (fallbackResId != 0) {
                        val uri = Uri.parse("android.resource://$packageName/$fallbackResId")
                        mediaPlayer?.setDataSource(applicationContext, uri)
                        Log.d(TAG, "Sound $soundId not found, using alarm.mp3")
                    } else {
                        // Last resort: system default alarm
                        val defaultUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        mediaPlayer?.setDataSource(applicationContext, defaultUri)
                        Log.d(TAG, "No raw resources found, using system default")
                    }
                }
            }
            
            mediaPlayer?.isLooping = !oneShot
            mediaPlayer?.prepare()
            mediaPlayer?.start()
            
            if (oneShot) {
                mediaPlayer?.setOnCompletionListener {
                    Log.d(TAG, "🔊 One-shot playback complete")
                    stopOneShotKeepNotification()
                }
            }

            Log.d(TAG, "🔊 Playing $soundId (stream=$audioStream, oneShot=$oneShot)")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing alarm sound: ${e.message}")
            e.printStackTrace()
            
            // Fallback: try using Ringtone API
            tryFallbackRingtone()
        }
    }
    
    private fun tryFallbackRingtone() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            
            ringtone?.play()
            Log.d(TAG, "Fallback ringtone playing")
        } catch (e: Exception) {
            Log.e(TAG, "Fallback ringtone also failed: ${e.message}")
        }
    }
    
    private fun startVibration(patternId: String = "default", repeat: Boolean = true) {
        try {
            val pattern = getVibrationPattern(patternId)
            
            // Skip vibration if pattern is "none" or empty
            if (pattern.isEmpty()) {
                Log.d(TAG, "📳 Vibration disabled (pattern: $patternId)")
                return
            }
            
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            val repeatIndex = if (repeat) 0 else -1
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, repeatIndex))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, repeatIndex)
            }
            
            Log.d(TAG, "📳 Vibration started (pattern: $patternId)")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting vibration: ${e.message}")
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Player",
                // Must be HIGH so full-screen intent can appear over lock screen.
                // We keep it silent via setSound(null) + vibration disabled + builder.setSilent(true).
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm notifications"
                setSound(null, null) // We handle audio ourselves
                enableVibration(false) // We handle vibration ourselves
                setShowBadge(false)
                // Privacy-safe on lock screen: do not show task details.
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                // Best-effort: allow display during DND (sound is handled by our player).
                try {
                    setBypassDnd(true)
                } catch (_: Exception) {}
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(
        title: String,
        body: String,
        alarmId: Int,
        showFullscreen: Boolean,
        oneShot: Boolean,
        payload: String,
        iconPngBase64: String?,
        actionsEnabled: Boolean = true,
        actionsJson: String? = null
    ): Notification {
        // For one-shot regular reminders, tapping the notification should open the normal task popup,
        // not the Alarm UI. We do this by storing a "pending payload" for Flutter's NotificationHandler.
        val openPendingIntent: PendingIntent = if (oneShot && payload.isNotBlank()) {
            val tapIntent = Intent(this, NativeReminderNotificationReceiver::class.java).apply {
                action = NativeReminderNotificationReceiver.ACTION_TAP
                putExtra(NativeReminderNotificationReceiver.EXTRA_PAYLOAD, payload)
                putExtra(NativeReminderNotificationReceiver.EXTRA_NOTIFICATION_ID, alarmId)
            }
            PendingIntent.getBroadcast(
                this,
                alarmId,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            val openIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
            }
            PendingIntent.getActivity(
                this,
                alarmId,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        
        // Intent to dismiss the alarm
        val dismissIntent = Intent(this, AlarmPlayerService::class.java).apply {
            action = ACTION_STOP
        }
        val dismissPendingIntent = PendingIntent.getService(
            this, 1, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // One-shot reminders are "regular task notifications" UI-wise, even when the sound is played
        // via native streams (alarm/media/ring). Payload is used to enable popup/actions.
        val isRegularReminderUi = oneShot && !showFullscreen
        val hasPayload = payload.isNotBlank()
        val isHabitPayload = payload.startsWith("habit|")
        val reminderLabel = if (isHabitPayload) "Habit reminder" else "Task reminder"
        val largeIcon: Bitmap? = if (isRegularReminderUi) {
            decodePngBase64ToBitmap(iconPngBase64)
        } else {
            null
        }

        // Public version shown on lock screen.
        val publicVersion = if (isRegularReminderUi) {
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(reminderLabel)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setSilent(true)
                .build()
        } else {
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Life Manager")
                .setContentText("Special alert")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setSilent(true)
                .build()
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            // Match regular task notification UX:
            // - Title is the task title
            // - Body line is "Task reminder" (like flutter_local_notifications)
            .setContentTitle(if (isRegularReminderUi) title else "Life Manager")
            .setContentText(if (isRegularReminderUi) reminderLabel else "Special alert")
            .setSmallIcon(if (isRegularReminderUi) R.mipmap.ic_launcher else android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(if (isRegularReminderUi) NotificationCompat.CATEGORY_REMINDER else NotificationCompat.CATEGORY_ALARM)
            .setVisibility(if (isRegularReminderUi) NotificationCompat.VISIBILITY_PUBLIC else NotificationCompat.VISIBILITY_PRIVATE)
            // Ensure the foreground-service notification never makes noise/vibrates
            // (we play sound/vibration ourselves via MediaPlayer/Vibrator).
            .setSilent(true)
            // Important on Android 12+: make this foreground-service notification show immediately.
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setOnlyAlertOnce(true)
            .setOngoing(!oneShot)
            .setAutoCancel(oneShot)
            .setContentIntent(openPendingIntent)
            .setPublicVersion(publicVersion)
            .setStyle(
                if (isRegularReminderUi)
                    NotificationCompat.BigTextStyle().bigText(body.ifBlank { reminderLabel })
                else
                    NotificationCompat.BigTextStyle().bigText("Special alert")
            )

        if (isRegularReminderUi) {
            builder.setShowWhen(false)
            builder.setColor(0xFFCDAF56.toInt())
            builder.setColorized(true)
            if (largeIcon != null) {
                builder.setLargeIcon(largeIcon)
            }
        }

        // Add action buttons: dynamic (Hub) or hardcoded (task/habit).
        // Hub notifications pass actionsJson; task/habit use built-in actions.
        if (isRegularReminderUi && hasPayload && actionsEnabled) {
            val hasDynamicActions = !actionsJson.isNullOrBlank()
            if (hasDynamicActions) {
                try {
                    val arr = org.json.JSONArray(actionsJson!!)
                    for (i in 0 until arr.length()) {
                        val obj = arr.getJSONObject(i)
                        val actionId = obj.optString("actionId", "")
                        val label = obj.optString("label", "Action")
                        if (actionId.isBlank()) continue
                        val actionIntent = Intent(this, NativeReminderNotificationReceiver::class.java).apply {
                            action = NativeReminderNotificationReceiver.ACTION_ACTION
                            putExtra(NativeReminderNotificationReceiver.EXTRA_ACTION_ID, actionId)
                            putExtra(NativeReminderNotificationReceiver.EXTRA_PAYLOAD, payload)
                            putExtra(NativeReminderNotificationReceiver.EXTRA_NOTIFICATION_ID, alarmId)
                        }
                        val actionPending = PendingIntent.getBroadcast(
                            this, alarmId + 1000 + i, actionIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        builder.addAction(
                            android.R.drawable.ic_menu_info_details,
                            label.take(20),
                            actionPending
                        )
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing actionsJson, falling back to default: ${e.message}")
                    addTaskHabitActions(builder, payload, alarmId)
                }
            } else {
                addTaskHabitActions(builder, payload, alarmId)
            }
        } else {
            // Special-task / alarm UI: keep a dismiss action.
            builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Dismiss", dismissPendingIntent)
        }

        // Full-screen intent (best-effort). Some devices may still suppress it,
        // but we also start an Activity directly from the service when showFullscreen=true.
        if (showFullscreen) {
            builder.setFullScreenIntent(openPendingIntent, true)
        }
        
        return builder.build()
    }

    private fun addTaskHabitActions(
        builder: NotificationCompat.Builder,
        payload: String,
        alarmId: Int
    ) {
        val isHabitPayload = payload.startsWith("habit|")
        val doneIntent = Intent(this, NativeReminderNotificationReceiver::class.java).apply {
            action = NativeReminderNotificationReceiver.ACTION_ACTION
            putExtra(NativeReminderNotificationReceiver.EXTRA_ACTION_ID, "mark_done")
            putExtra(NativeReminderNotificationReceiver.EXTRA_PAYLOAD, payload)
            putExtra(NativeReminderNotificationReceiver.EXTRA_NOTIFICATION_ID, alarmId)
        }
        val snooze5Intent = Intent(this, NativeReminderNotificationReceiver::class.java).apply {
            action = NativeReminderNotificationReceiver.ACTION_ACTION
            putExtra(NativeReminderNotificationReceiver.EXTRA_ACTION_ID, "snooze_5")
            putExtra(NativeReminderNotificationReceiver.EXTRA_PAYLOAD, payload)
            putExtra(NativeReminderNotificationReceiver.EXTRA_NOTIFICATION_ID, alarmId)
        }
        builder.addAction(
            android.R.drawable.checkbox_on_background,
            "✓ Done",
            PendingIntent.getBroadcast(
                this, alarmId + 1, doneIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
        builder.addAction(
            android.R.drawable.ic_lock_idle_alarm,
            "Snooze 5m",
            PendingIntent.getBroadcast(
                this, alarmId + 3, snooze5Intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
        if (isHabitPayload) {
            val skipIntent = Intent(this, NativeReminderNotificationReceiver::class.java).apply {
                action = NativeReminderNotificationReceiver.ACTION_ACTION
                putExtra(NativeReminderNotificationReceiver.EXTRA_ACTION_ID, "skip")
                putExtra(NativeReminderNotificationReceiver.EXTRA_PAYLOAD, payload)
                putExtra(NativeReminderNotificationReceiver.EXTRA_NOTIFICATION_ID, alarmId)
            }
            builder.addAction(
                android.R.drawable.ic_media_next,
                "⏭ Skip",
                PendingIntent.getBroadcast(
                    this, alarmId + 4, skipIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        } else {
            val snoozeIntent = Intent(this, NativeReminderNotificationReceiver::class.java).apply {
                action = NativeReminderNotificationReceiver.ACTION_ACTION
                putExtra(NativeReminderNotificationReceiver.EXTRA_ACTION_ID, "snooze")
                putExtra(NativeReminderNotificationReceiver.EXTRA_PAYLOAD, payload)
                putExtra(NativeReminderNotificationReceiver.EXTRA_NOTIFICATION_ID, alarmId)
            }
            builder.addAction(
                android.R.drawable.ic_lock_idle_alarm,
                "Snooze",
                PendingIntent.getBroadcast(
                    this, alarmId + 2, snoozeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
    }

    private fun decodePngBase64ToBitmap(iconPngBase64: String?): Bitmap? {
        if (iconPngBase64.isNullOrBlank()) return null
        return try {
            val bytes = Base64.decode(iconPngBase64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: Exception) {
            Log.e(TAG, "Error decoding icon bitmap: ${e.message}")
            null
        }
    }

    private fun isDeviceLocked(): Boolean {
        return try {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                km.isDeviceLocked
            } else {
                @Suppress("DEPRECATION")
                km.isKeyguardLocked
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun wakeScreenBriefly() {
        try {
            // Release any existing screen wake lock
            releaseScreenWakeLock()

            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val flags = PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE
            screenWakeLock = pm.newWakeLock(flags, "LifeManager::AlarmScreenWake").apply {
                setReferenceCounted(false)
                acquire(6_000L) // wake screen briefly
            }

            // Extra safety: release after a short delay.
            Handler(Looper.getMainLooper()).postDelayed({ releaseScreenWakeLock() }, 6_000L)

            Log.d(TAG, "🔆 Screen wake requested (locked=${isDeviceLocked()})")
        } catch (e: Exception) {
            Log.e(TAG, "Error waking screen: ${e.message}")
        }
    }

    private fun releaseScreenWakeLock() {
        try {
            screenWakeLock?.let {
                if (it.isHeld) it.release()
            }
            screenWakeLock = null
        } catch (_: Exception) {}
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "LifeManager::AlarmWakeLock"
            )
            wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes max
            Log.d(TAG, "Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock: ${e.message}")
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
    }
}

/**
 * BroadcastReceiver to receive alarm triggers from AlarmManager.
 * This allows alarms to fire even when the app is completely killed.
 */
class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmReceiver"
        
        /**
         * Schedule an alarm using Android's native AlarmManager.
         * This works even when the app is killed.
         */
        fun scheduleAlarm(
            context: Context,
            alarmId: Int,
            triggerTimeMillis: Long,
            title: String,
            body: String,
            soundId: String = "alarm",
            vibrationPatternId: String = "default",
            showFullscreen: Boolean = true,
            audioStream: String = "alarm",
            oneShot: Boolean = false,
            payload: String = "",
            iconPngBase64: String? = null,
            actionsEnabled: Boolean = true,
            actionsJson: String? = null
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.eloz.life_manager.ALARM_TRIGGER"
                putExtra(AlarmPlayerService.EXTRA_ALARM_ID, alarmId)
                putExtra(AlarmPlayerService.EXTRA_TITLE, title)
                putExtra(AlarmPlayerService.EXTRA_BODY, body)
                putExtra(AlarmPlayerService.EXTRA_SOUND_ID, soundId)
                putExtra(AlarmPlayerService.EXTRA_VIBRATION_PATTERN_ID, vibrationPatternId)
                putExtra(AlarmPlayerService.EXTRA_SHOW_FULLSCREEN, showFullscreen)
                putExtra(AlarmPlayerService.EXTRA_AUDIO_STREAM, audioStream)
                putExtra(AlarmPlayerService.EXTRA_ONE_SHOT, oneShot)
                putExtra(AlarmPlayerService.EXTRA_PAYLOAD, payload)
                putExtra(AlarmPlayerService.EXTRA_ACTIONS_ENABLED, actionsEnabled)
                if (!iconPngBase64.isNullOrBlank()) {
                    putExtra(AlarmPlayerService.EXTRA_ICON_PNG_BASE64, iconPngBase64)
                }
                if (!actionsJson.isNullOrBlank()) {
                    putExtra(AlarmPlayerService.EXTRA_ACTIONS_JSON, actionsJson)
                }
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Use setAlarmClock for highest priority - shows in system alarm UI
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val showIntent = PendingIntent.getActivity(
                    context,
                    alarmId,
                    context.packageManager.getLaunchIntentForPackage(context.packageName),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerTimeMillis, showIntent)
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                Log.d(TAG, "⏰ Alarm scheduled with setAlarmClock for ID: $alarmId at $triggerTimeMillis")
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
            }
        }
        
        /**
         * Cancel a scheduled alarm.
         */
        fun cancelAlarm(context: Context, alarmId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.eloz.life_manager.ALARM_TRIGGER"
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "⏰ Alarm cancelled for ID: $alarmId")
        }
    }

    /**
     * Check if the alarm is blocked by quiet hours.
     * Uses **habit** notification settings when [isHabit] is true,
     * otherwise uses task notification settings.
     *
     * Habit settings key: "flutter.habit_notification_settings"
     * Task settings key:  "flutter.notification_settings"
     *
     * For habits, `allowSpecialDuringQuietHours` maps to `allowUrgentDuringQuietHours`
     * in the generic settings model.
     */
    private fun isBlockedByQuietHours(context: Context, isHabit: Boolean): Boolean {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            val settingsKey = if (isHabit) {
                prefs.getString("flutter.habit_notification_settings", null)
                    ?: prefs.getString("habit_notification_settings", null)
            } else {
                prefs.getString("flutter.notification_settings", null)
                    ?: prefs.getString("notification_settings", null)
            }
            if (settingsKey == null) return false

            val json = JSONObject(settingsKey)
            val quietEnabled = json.optBoolean("quietHoursEnabled", false)
            if (!quietEnabled) return false

            // For habits the field is "allowSpecialDuringQuietHours",
            // for tasks it's "allowUrgentDuringQuietHours".
            val allowSpecialKey = if (isHabit) "allowSpecialDuringQuietHours" else "allowUrgentDuringQuietHours"
            val allowSpecial = json.optBoolean(allowSpecialKey, true)
            if (allowSpecial) return false

            val quietStart = json.optInt("quietHoursStart", 1380)
            val quietEnd = json.optInt("quietHoursEnd", 420)
            val quietDays = json.optJSONArray("quietHoursDays")

            val calendar = Calendar.getInstance()
            val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) // 1=Sunday..7=Saturday
            val dartWeekday = if (dayOfWeek == Calendar.SUNDAY) 7 else dayOfWeek - 1

            if (quietDays != null && quietDays.length() > 0) {
                var matchesDay = false
                for (i in 0 until quietDays.length()) {
                    if (quietDays.optInt(i) == dartWeekday) {
                        matchesDay = true
                        break
                    }
                }
                if (!matchesDay) return false
            }

            val currentMinutes = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
            if (quietStart > quietEnd) {
                currentMinutes >= quietStart || currentMinutes < quietEnd
            } else {
                currentMinutes >= quietStart && currentMinutes < quietEnd
            }
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Error checking quiet hours: ${e.message}")
            false
        }
    }

    /** Backwards-compatible wrapper used by existing callsites. */
    private fun isSpecialTaskBlockedByQuietHours(context: Context): Boolean =
        isBlockedByQuietHours(context, isHabit = false)
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🔔 Alarm received! Action: ${intent.action}")
        
        val alarmId = intent.getIntExtra(AlarmPlayerService.EXTRA_ALARM_ID, 0)
        val title = intent.getStringExtra(AlarmPlayerService.EXTRA_TITLE) ?: "Special Task"
        val body = intent.getStringExtra(AlarmPlayerService.EXTRA_BODY) ?: ""
        val soundId = intent.getStringExtra(AlarmPlayerService.EXTRA_SOUND_ID) ?: "alarm"
        val vibrationPatternId = intent.getStringExtra(AlarmPlayerService.EXTRA_VIBRATION_PATTERN_ID) ?: "default"
        val showFullscreen = intent.getBooleanExtra(AlarmPlayerService.EXTRA_SHOW_FULLSCREEN, true)
        val audioStream = intent.getStringExtra(AlarmPlayerService.EXTRA_AUDIO_STREAM) ?: "alarm"
        val oneShot = intent.getBooleanExtra(AlarmPlayerService.EXTRA_ONE_SHOT, false)
        val payload = intent.getStringExtra(AlarmPlayerService.EXTRA_PAYLOAD) ?: ""
        val iconPngBase64 = intent.getStringExtra(AlarmPlayerService.EXTRA_ICON_PNG_BASE64)
        val actionsEnabled = intent.getBooleanExtra(AlarmPlayerService.EXTRA_ACTIONS_ENABLED, true)
        val actionsJson = intent.getStringExtra(AlarmPlayerService.EXTRA_ACTIONS_JSON)

        // Determine if this alarm is for a habit based on payload prefix.
        val isHabitPayload = payload.startsWith("habit|")

        // Quiet Hours guard for special tasks/habits (oneShot == false).
        if (!oneShot && isBlockedByQuietHours(context, isHabit = isHabitPayload)) {
            Log.d(TAG, "🌙 Quiet hours active and special alerts disabled — skipping alarm $alarmId")
            AlarmBootReceiver.removeAlarm(context, alarmId)
            return
        }
        
        // Start the alarm player service using the scheduled sound/pattern.
        AlarmPlayerService.start(
            context,
            alarmId,
            title,
            body,
            soundId = soundId,
            vibrationPatternId = vibrationPatternId,
            showFullscreen = showFullscreen,
            audioStream = audioStream,
            oneShot = oneShot,
            payload = payload,
            iconPngBase64 = iconPngBase64,
            actionsEnabled = actionsEnabled,
            actionsJson = actionsJson
        )
    }
}
