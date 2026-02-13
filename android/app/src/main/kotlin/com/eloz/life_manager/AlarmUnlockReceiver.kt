package com.eloz.life_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Security-first UX:
 * - When a special alarm rings, we wake the screen but do NOT show content while locked.
 * - When the user unlocks (USER_PRESENT), if an alarm is currently ringing we bring the app
 *   to foreground so Flutter can show the AlarmScreen with full details.
 */
class AlarmUnlockReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmUnlockReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_USER_PRESENT) return

        try {
            if (!AlarmPlayerService.isAlarmPlaying()) return

            val data = MainActivity.getCurrentRingingAlarm()
            val alarmId = (data?.get("alarmId") as? Int) ?: 0

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent == null) return

            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            launchIntent.putExtra(AlarmPlayerService.EXTRA_ALARM_ID, alarmId)

            Log.d(TAG, "🔓 Device unlocked while alarm ringing; launching app for alarmId=$alarmId")
            context.startActivity(launchIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling unlock: ${e.message}")
        }
    }
}

