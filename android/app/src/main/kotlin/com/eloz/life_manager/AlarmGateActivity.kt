package com.eloz.life_manager

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

/**
 * Privacy-safe "alarm overlay" shown on top of the lock screen.
 *
 * - Appears like a real alarm UI (on top), but shows NO sensitive task content.
 * - Prompts the owner to unlock.
 * - After unlock, it launches the app so Flutter shows AlarmScreen with full details.
 *
 * KEY IMPLEMENTATION NOTES:
 * 1. setShowWhenLocked() and setTurnScreenOn() must be called BEFORE setContentView()
 * 2. For secure lock screens, requestDismissKeyguard() shows the unlock UI
 * 3. We directly start this activity from AlarmPlayerService for reliability
 */
class AlarmGateActivity : Activity() {
    companion object {
        private const val TAG = "AlarmGateActivity"
    }

    private var alarmId: Int = 0
    private var alarmTitle: String = "Special alert"
    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // CRITICAL: Set window flags BEFORE super.onCreate() and setContentView()
        setupWindowFlags()
        
        super.onCreate(savedInstanceState)

        Log.d(TAG, "🚨 AlarmGateActivity onCreate - START")

        // Extract intent data
        alarmId = intent?.getIntExtra(AlarmPlayerService.EXTRA_ALARM_ID, 0) ?: 0
        alarmTitle = intent?.getStringExtra(AlarmPlayerService.EXTRA_TITLE) ?: "Special alert"

        // Acquire wake lock to keep screen on
        acquireWakeLock()

        setContentView(R.layout.activity_alarm_gate)

        // Set up UI
        setupUI()

        Log.d(TAG, "🚨 AlarmGateActivity displayed for alarmId=$alarmId, locked=${isDeviceLocked()}, title=$alarmTitle")
    }

    private fun setupWindowFlags() {
        // Make sure window appears over lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) { // API 27+
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        
        // Add all necessary window flags
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        
        // Prevent screenshots for privacy
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun setupUI() {
        // Update subtitle if needed
        findViewById<TextView>(R.id.subtitle)?.text = "Unlock to view details"
        
        // Set up unlock button
        findViewById<Button>(R.id.unlockButton)?.setOnClickListener {
            Log.d(TAG, "🔓 Unlock button clicked")
            handleUnlockOrDismiss()
        }

        // Also handle tap anywhere on the screen
        findViewById<View>(android.R.id.content)?.setOnClickListener {
            Log.d(TAG, "🔓 Screen tapped")
            handleUnlockOrDismiss()
        }
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "LifeManager::AlarmGateWakeLock"
            ).apply {
                setReferenceCounted(false)
                acquire(5 * 60 * 1000L) // 5 minutes max
            }
            Log.d(TAG, "🔆 Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
            wakeLock = null
            Log.d(TAG, "🔆 Wake lock released")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}")
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "🚨 AlarmGateActivity onResume, locked=${isDeviceLocked()}")

        // If device is already unlocked, go straight to app
        if (!isDeviceLocked()) {
            Log.d(TAG, "✅ Device not locked, launching app directly")
            launchAppForAlarm()
            finish()
            return
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        Log.d(TAG, "🚨 AlarmGateActivity onAttachedToWindow")
    }

    private fun handleUnlockOrDismiss() {
        if (!isDeviceLocked()) {
            // Already unlocked, launch app
            launchAppForAlarm()
            finish()
            return
        }

        // Ask the system to show unlock UI (user-driven).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) { // API 26+
            try {
                val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                km.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() {
                        Log.d(TAG, "✅ Keyguard dismissed successfully")
                        handler.post {
                            launchAppForAlarm()
                            finish()
                        }
                    }

                    override fun onDismissError() {
                        Log.e(TAG, "❌ Keyguard dismiss error")
                    }

                    override fun onDismissCancelled() {
                        Log.d(TAG, "⚠️ Keyguard dismiss cancelled by user")
                    }
                })
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting keyguard dismiss: ${e.message}")
            }
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
        } catch (e: Exception) {
            Log.e(TAG, "Error checking device lock: ${e.message}")
            false
        }
    }

    private fun launchAppForAlarm() {
        Log.d(TAG, "🚀 Launching app for alarm $alarmId")
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                Log.e(TAG, "❌ Could not get launch intent for package")
                return
            }
            
            launchIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            launchIntent.putExtra(AlarmPlayerService.EXTRA_ALARM_ID, alarmId)
            startActivity(launchIntent)
            Log.d(TAG, "✅ App launched for alarm $alarmId")
        } catch (e: Exception) {
            Log.e(TAG, "Error launching app: ${e.message}")
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "🚨 AlarmGateActivity onDestroy")
        handler.removeCallbacksAndMessages(null)
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onBackPressed() {
        // Don't allow back press to dismiss - user must unlock or dismiss alarm
        Log.d(TAG, "⚠️ Back press ignored - must unlock to dismiss")
    }
}

