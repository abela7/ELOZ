package com.eloz.life_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

/**
 * Receives TIMEZONE_CHANGED and TIME_SET broadcasts (nek12 Layer 2).
 *
 * When time or timezone changes, scheduled notification times may be wrong.
 * We set a flag so the Flutter app resyncs all notifications on next launch.
 * WorkManager periodic task (15 min) provides a backup if the app is not opened.
 */
class NotificationSystemEventReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "NotificationSystemEventReceiver"
        const val PREFS_NAME = "notification_resync"
        const val KEY_PENDING = "pending"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_TIMEZONE_CHANGED &&
            action != "android.intent.action.TIME_SET") {
            return
        }

        Log.d(TAG, "Time/timezone changed, marking notification resync pending")
        val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_PENDING, true).apply()
    }
}
