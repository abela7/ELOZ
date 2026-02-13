package com.eloz.life_manager

import android.app.ActivityManager
import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.os.Vibrator
import android.os.VibrationEffect
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.eloz.life_manager/widget"
    private val SYSTEM_CHANNEL = "com.eloz.life_manager/system"
    private val ALARM_CHANNEL = "com.eloz.life_manager/native_alarm"
    private val SOUND_PICKER_REQUEST_CODE = 1001
    private var pendingSoundPickerResult: MethodChannel.Result? = null
    
    // MediaPlayer for playing alarm sounds that bypass silent mode
    private var alarmPlayer: MediaPlayer? = null
    private var alarmVibrator: Vibrator? = null
    
    // Store the alarm ID that launched the app (if any)
    private var launchAlarmId: Int? = null
    private var launchAlarmTitle: String? = null
    private var launchAlarmBody: String? = null
    
    // Static reference for alarm channel to notify Flutter
    companion object {
        private var alarmMethodChannel: MethodChannel? = null
        
        // Store currently ringing alarm info for retrieval
        private var currentRingingAlarmId: Int? = null
        private var currentRingingTitle: String? = null
        private var currentRingingBody: String? = null
        
        fun notifyAlarmRing(alarmId: Int, title: String, body: String) {
            android.util.Log.d("MainActivity", "Notifying Flutter of alarm ring: $alarmId")
            
            // Store for later retrieval if Flutter isn't ready
            currentRingingAlarmId = alarmId
            currentRingingTitle = title
            currentRingingBody = body
            
            alarmMethodChannel?.invokeMethod("onAlarmRing", mapOf(
                "alarmId" to alarmId,
                "title" to title,
                "body" to body
            ))
        }
        
        fun getCurrentRingingAlarm(): Map<String, Any?>? {
            val id = currentRingingAlarmId ?: return null
            return mapOf(
                "alarmId" to id,
                "title" to (currentRingingTitle ?: "Special Task"),
                "body" to (currentRingingBody ?: "")
            )
        }
        
        fun clearCurrentRingingAlarm() {
            currentRingingAlarmId = null
            currentRingingTitle = null
            currentRingingBody = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check if app was launched by an alarm
        checkForAlarmLaunch(intent)

        // SECURITY (CRITICAL):
        // Never show the full app UI on the lock screen.
        // Only allow showing on lock screen when launched by a special-task alarm.
        applyLockScreenPolicy()
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Check if new intent is from an alarm
        checkForAlarmLaunch(intent)
        applyLockScreenPolicy()
    }
    
    private fun checkForAlarmLaunch(intent: Intent?) {
        // Reset launch state unless this intent is an alarm launch
        launchAlarmId = null
        launchAlarmTitle = null
        launchAlarmBody = null

        intent?.let {
            val alarmId = it.getIntExtra(AlarmPlayerService.EXTRA_ALARM_ID, -1)
            if (alarmId != -1) {
                android.util.Log.d("MainActivity", "App launched by alarm: $alarmId")
                launchAlarmId = alarmId
                launchAlarmTitle = it.getStringExtra(AlarmPlayerService.EXTRA_TITLE)
                launchAlarmBody = it.getStringExtra(AlarmPlayerService.EXTRA_BODY)
            }
        }
    }

    private fun applyLockScreenPolicy() {
        // Security-first:
        // Never show full app UI while locked. When locked, we show AlarmGateActivity (generic).
        val allowOnLockScreen = false

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(allowOnLockScreen)
            setTurnScreenOn(allowOnLockScreen)
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SOUND_PICKER_REQUEST_CODE) {
            val result = pendingSoundPickerResult ?: return
            pendingSoundPickerResult = null

            if (resultCode != Activity.RESULT_OK) {
                result.success(mapOf("uri" to null, "title" to null))
                return
            }

            val uri: Uri? = if (android.os.Build.VERSION.SDK_INT >= 33) {
                data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            }

            val title = try {
                if (uri != null) {
                    RingtoneManager.getRingtone(this, uri)?.getTitle(this)
                } else {
                    null
                }
            } catch (e: Exception) {
                null
            }

            result.success(mapOf("uri" to uri?.toString(), "title" to title))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                updateWidget()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryStatus" -> result.success(getBatteryStatus())
                "getDndAccessStatus" -> result.success(getDndAccessStatus())
                "openDndAccessSettings" -> {
                    openDndAccessSettings()
                    result.success(null)
                }
                "openAppDetailsSettings" -> {
                    openAppDetailsSettings()
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    openAppNotificationSettings()
                    result.success(null)
                }
                "openChannelSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    if (channelId != null) {
                        openChannelSettings(channelId)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Channel ID is required", null)
                    }
                }
                "pickNotificationSound" -> {
                    if (pendingSoundPickerResult != null) {
                        result.error("ALREADY_ACTIVE", "Sound picker already open", null)
                        return@setMethodCallHandler
                    }

                    pendingSoundPickerResult = result

                    val currentUriString = call.argument<String>("currentUri")
                    val currentUri = try {
                        if (!currentUriString.isNullOrBlank()) Uri.parse(currentUriString) else null
                    } catch (e: Exception) {
                        null
                    }

                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, currentUri)
                    }

                    try {
                        startActivityForResult(intent, SOUND_PICKER_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingSoundPickerResult = null
                        result.error("UNAVAILABLE", "Unable to open system sound picker", e.message)
                    }
                }
                "playAlarmSound" -> {
                    val soundUri = call.argument<String>("soundUri")
                    val vibrate = call.argument<Boolean>("vibrate") ?: true
                    playAlarmSound(soundUri, vibrate)
                    result.success(true)
                }
                "stopAlarmSound" -> {
                    stopAlarmSound()
                    result.success(true)
                }
                "isDeviceLocked" -> {
                    result.success(isDeviceLocked())
                }
                "finishIfLocked" -> {
                    // If device is locked, finish the activity to return to lock screen
                    if (isDeviceLocked()) {
                        finishAndRemoveTask()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "canUseFullScreenIntent" -> {
                    result.success(canUseFullScreenIntent())
                }
                "openFullScreenIntentSettings" -> {
                    openFullScreenIntentSettings()
                    result.success(true)
                }
                "getAndClearPendingNotificationResync" -> {
                    val prefs = getSharedPreferences(
                        NotificationSystemEventReceiver.PREFS_NAME,
                        Context.MODE_PRIVATE
                    )
                    val pending = prefs.getBoolean(
                        NotificationSystemEventReceiver.KEY_PENDING,
                        false
                    )
                    if (pending) {
                        prefs.edit().remove(NotificationSystemEventReceiver.KEY_PENDING).apply()
                    }
                    result.success(pending)
                }
                else -> result.notImplemented()
            }
        }
        
        // Native Alarm Channel - for scheduling alarms that use USAGE_ALARM audio stream
        val nativeAlarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
        alarmMethodChannel = nativeAlarmChannel  // Store for static access
        nativeAlarmChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    val triggerTimeMillis = call.argument<Long>("triggerTimeMillis") ?: 0L
                    val title = call.argument<String>("title") ?: "Alarm"
                    val body = call.argument<String>("body") ?: ""
                    val soundId = call.argument<String>("soundId") ?: "alarm"
                    val vibrationPatternId = call.argument<String>("vibrationPatternId") ?: "default"
                    val showFullscreen = call.argument<Boolean>("showFullscreen") ?: true
                    val audioStream = call.argument<String>("audioStream") ?: "alarm"
                    val oneShot = call.argument<Boolean>("oneShot") ?: false
                    val payload = call.argument<String>("payload") ?: ""
                    val iconPngBase64 = call.argument<String>("iconPngBase64")
                    val actionsEnabled = call.argument<Boolean>("actionsEnabled") ?: true
                    val actionButtonsJson = call.argument<String>("actionButtonsJson")
                    
                    try {
                        // Schedule with native AlarmManager
                        AlarmReceiver.scheduleAlarm(
                            this,
                            alarmId,
                            triggerTimeMillis,
                            title,
                            body,
                            soundId,
                            vibrationPatternId,
                            showFullscreen,
                            audioStream,
                            oneShot,
                            payload,
                            iconPngBase64,
                            actionsEnabled,
                            actionButtonsJson
                        )
                        // Save for reboot restoration
                        AlarmBootReceiver.saveAlarm(
                            this,
                            alarmId,
                            triggerTimeMillis,
                            title,
                            body,
                            soundId,
                            vibrationPatternId,
                            showFullscreen,
                            audioStream,
                            oneShot,
                            payload,
                            iconPngBase64,
                            actionsEnabled,
                            actionButtonsJson
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }
                "cancelAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    try {
                        AlarmReceiver.cancelAlarm(this, alarmId)
                        AlarmBootReceiver.removeAlarm(this, alarmId)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "getScheduledAlarms" -> {
                    try {
                        val alarms = AlarmBootReceiver.getScheduledAlarms(this)
                        result.success(alarms)
                    } catch (e: Exception) {
                        result.error("GET_ALARMS_ERROR", e.message, null)
                    }
                }
                "stopAlarm" -> {
                    try {
                        AlarmPlayerService.stop(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "isAlarmPlaying" -> {
                    result.success(AlarmPlayerService.isAlarmPlaying())
                }
                "getCurrentRingingAlarm" -> {
                    val alarmData = getCurrentRingingAlarm()
                    result.success(alarmData)
                }
                "playTestAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    val title = call.argument<String>("title") ?: "Test Alarm"
                    val body = call.argument<String>("body") ?: "This is a test"
                    val showFullscreen = call.argument<Boolean>("showFullscreen") ?: false
                    val soundId = call.argument<String>("soundId") ?: "alarm"
                    val vibrationPatternId = call.argument<String>("vibrationPatternId") ?: "default"
                    try {
                        AlarmPlayerService.start(this, alarmId, title, body, soundId = soundId, vibrationPatternId = vibrationPatternId, showFullscreen = showFullscreen)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }
                "previewSound" -> {
                    val soundId = call.argument<String>("soundId") ?: "alarm"
                    try {
                        AlarmPlayerService.start(this, 0, "Sound Preview", "Playing $soundId", soundId = soundId, vibrationPatternId = "none", showFullscreen = false)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PREVIEW_ERROR", e.message, null)
                    }
                }
                "previewVibration" -> {
                    val patternId = call.argument<String>("patternId") ?: "default"
                    try {
                        previewVibrationPattern(patternId)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VIBRATION_ERROR", e.message, null)
                    }
                }
                "stopVibration" -> {
                    try {
                        stopVibrationPreview()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_VIBRATION_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openChannelSettings(channelId: String) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            try {
                val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback to app notification settings
                openAppNotificationSettings()
            }
        } else {
            openAppNotificationSettings()
        }
    }

    private fun openAppNotificationSettings() {
        try {
            val intent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            } else {
                Intent("android.settings.APP_NOTIFICATION_SETTINGS").apply {
                    putExtra("app_package", packageName)
                    putExtra("app_uid", applicationInfo.uid)
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            openAppDetailsSettings()
        }
    }

    private fun updateWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val componentName = ComponentName(applicationContext, TodayTasksWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        
        for (appWidgetId in appWidgetIds) {
            TodayTasksWidgetProvider.updateAppWidget(applicationContext, appWidgetManager, appWidgetId)
        }
    }

    private fun getBatteryStatus(): Map<String, Any> {
        val sdkInt = android.os.Build.VERSION.SDK_INT

        val isIgnoringBatteryOptimizations = if (sdkInt >= android.os.Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }

        val isBackgroundRestricted = if (sdkInt >= android.os.Build.VERSION_CODES.P) {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.isBackgroundRestricted
        } else {
            false
        }

        return mapOf(
            "sdkInt" to sdkInt,
            "isIgnoringBatteryOptimizations" to isIgnoringBatteryOptimizations,
            "isBackgroundRestricted" to isBackgroundRestricted,
        )
    }

    private fun openAppDetailsSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback: open generic app settings
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        }
    }

    private fun getDndAccessStatus(): Map<String, Any> {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val hasAccess = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            nm.isNotificationPolicyAccessGranted
        } else {
            true // DND access not needed on older versions
        }
        return mapOf(
            "hasAccess" to hasAccess
        )
    }

    private fun openDndAccessSettings() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } else {
                openAppNotificationSettings()
            }
        } catch (e: Exception) {
            openAppNotificationSettings()
        }
    }

    /**
     * Play alarm sound using the ALARM audio stream - this BYPASSES silent mode!
     * This is exactly how the Clock app plays alarms.
     */
    private fun playAlarmSound(soundUri: String?, vibrate: Boolean) {
        // Stop any existing alarm first
        stopAlarmSound()

        try {
            // Get the sound URI - use provided URI, or fall back to default alarm
            val uri: Uri = if (!soundUri.isNullOrBlank()) {
                Uri.parse(soundUri)
            } else {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }

            // Create MediaPlayer with ALARM audio stream (bypasses silent mode!)
            alarmPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, uri)
                
                // CRITICAL: Use ALARM audio stream - this bypasses silent mode
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                
                isLooping = true  // Keep playing until stopped
                prepare()
                start()
            }

            // Also vibrate if requested
            if (vibrate) {
                alarmVibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                alarmVibrator?.let { vibrator ->
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        // Vibrate pattern: wait 0ms, vibrate 500ms, pause 200ms, vibrate 500ms - repeat
                        val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
                        vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0)) // 0 = repeat from start
                    } else {
                        @Suppress("DEPRECATION")
                        val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
                        vibrator.vibrate(pattern, 0)
                    }
                }
            }

            android.util.Log.d("MainActivity", "🔔 Alarm sound started on ALARM stream: $uri")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to play alarm sound: ${e.message}")
            // Fallback: try using Ringtone API
            try {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                    ringtone?.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                }
                ringtone?.play()
            } catch (e2: Exception) {
                android.util.Log.e("MainActivity", "Fallback also failed: ${e2.message}")
            }
        }
    }

    /**
     * Stop the currently playing alarm sound and vibration.
     */
    private fun stopAlarmSound() {
        try {
            alarmPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
            alarmPlayer = null

            alarmVibrator?.cancel()
            alarmVibrator = null
            
            android.util.Log.d("MainActivity", "🔕 Alarm sound stopped")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping alarm: ${e.message}")
        }
    }
    
    // Vibration preview for pattern selection
    private var previewVibrator: Vibrator? = null
    
    private fun previewVibrationPattern(patternId: String) {
        try {
            // Stop any existing preview
            stopVibrationPreview()
            
            val pattern = AlarmPlayerService.getVibrationPattern(patternId)
            
            // Skip if pattern is empty (none)
            if (pattern.isEmpty()) {
                android.util.Log.d("MainActivity", "📳 No vibration for pattern: $patternId")
                return
            }
            
            previewVibrator = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            // Use repeat index 0 for continuous preview, or -1 for single play
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                previewVibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                previewVibrator?.vibrate(pattern, 0)
            }
            
            android.util.Log.d("MainActivity", "📳 Preview vibration started: $patternId")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error previewing vibration: ${e.message}")
        }
    }
    
    private fun stopVibrationPreview() {
        try {
            previewVibrator?.cancel()
            previewVibrator = null
            android.util.Log.d("MainActivity", "📳 Preview vibration stopped")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping vibration preview: ${e.message}")
        }
    }

    /**
     * Check if the device is currently locked (keyguard is showing)
     */
    private fun isDeviceLocked(): Boolean {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
            keyguardManager.isDeviceLocked
        } else {
            keyguardManager.isKeyguardLocked
        }
    }

    /**
     * Check if the app can use full-screen intents (required for alarm-style lock screen overlays on Android 14+)
     */
    private fun canUseFullScreenIntent(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= 34) { // Android 14 (Upside-Down Cake)
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.canUseFullScreenIntent()
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error checking canUseFullScreenIntent: ${e.message}")
                true // Assume granted if check fails
            }
        } else {
            true // Not needed on older Android versions
        }
    }

    /**
     * Open system settings to allow user to grant full-screen intent permission (Android 14+)
     */
    private fun openFullScreenIntentSettings() {
        if (android.os.Build.VERSION.SDK_INT >= 34) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.fromParts("package", packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error opening full-screen intent settings: ${e.message}")
                // Fallback to app notification settings
                openAppNotificationSettings()
            }
        } else {
            // On older Android, open app notification settings
            openAppNotificationSettings()
        }
    }

    override fun onDestroy() {
        stopAlarmSound()
        stopVibrationPreview()
        super.onDestroy()
    }
}
