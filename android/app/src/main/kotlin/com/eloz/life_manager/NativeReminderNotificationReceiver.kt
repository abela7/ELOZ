package com.eloz.life_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Bridges native AlarmPlayerService notifications (one-shot reminders) to Flutter's
 * NotificationHandler flow by storing a pending payload/action in FlutterSharedPreferences.
 *
 * This ensures:
 * - Tapping the native notification opens the normal TaskReminderPopup
 * - Action buttons (Done/Snooze) reuse the same Dart logic
 */
class NativeReminderNotificationReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "NativeReminderNotifRx"

        const val ACTION_TAP = "com.eloz.life_manager.NATIVE_REMINDER_TAP"
        const val ACTION_ACTION = "com.eloz.life_manager.NATIVE_REMINDER_ACTION"

        const val EXTRA_PAYLOAD = "payload"
        const val EXTRA_ACTION_ID = "action_id"
        const val EXTRA_NOTIFICATION_ID = "notification_id"

        // shared_preferences Android implementation uses this file + prefix.
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_PAYLOAD = "flutter.pending_notification_payload"
        private const val KEY_ACTION = "flutter.pending_notification_action"
        private const val KEY_ID = "flutter.pending_notification_id"

        // Some shared_preferences versions / OEM builds may not apply the "flutter." prefix
        // consistently for externally-written values. Write both keys defensively.
        private const val KEY_PAYLOAD_RAW = "pending_notification_payload"
        private const val KEY_ACTION_RAW = "pending_notification_action"
        private const val KEY_ID_RAW = "pending_notification_id"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return

        val payload = intent.getStringExtra(EXTRA_PAYLOAD) ?: ""
        val actionId = intent.getStringExtra(EXTRA_ACTION_ID) ?: ""
        val notifId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        if (payload.isBlank()) return

        try {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_PAYLOAD, payload)
                .putString(KEY_ACTION, actionId)
                .putInt(KEY_ID, notifId)
                .putString(KEY_PAYLOAD_RAW, payload)
                .putString(KEY_ACTION_RAW, actionId)
                .putInt(KEY_ID_RAW, notifId)
                .commit()

            Log.d(TAG, "Stored pending payload (action=$actionId id=$notifId)")

            // If this was an action button, cancel the notification immediately (UX parity with flutter_local_notifications).
            if (intent.action == ACTION_ACTION) {
                try {
                    val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    nm.cancel(notifId)
                } catch (_: Exception) {}
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                context.startActivity(launchIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling native reminder notification: ${e.message}")
        }
    }
}

