package com.eloz.life_manager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Receives BOOT_COMPLETED broadcast to reschedule alarms after device reboot.
 * 
 * Alarms scheduled via AlarmManager are lost when the device reboots.
 * This receiver restores them from SharedPreferences.
 */
class AlarmBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmBootReceiver"
        private const val PREFS_NAME = "native_alarms"
        private const val KEY_ALARMS = "scheduled_alarms"
        
        /**
         * Save alarm info to SharedPreferences for restoration after reboot.
         */
        fun saveAlarm(
            context: Context,
            alarmId: Int,
            triggerTimeMillis: Long,
            title: String,
            body: String,
            soundId: String,
            vibrationPatternId: String,
            showFullscreen: Boolean,
            audioStream: String = "alarm",
            oneShot: Boolean = false,
            payload: String = "",
            iconPngBase64: String? = null,
            actionsEnabled: Boolean = true,
            actionsJson: String? = null
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val alarmsJson = prefs.getString(KEY_ALARMS, "[]") ?: "[]"
            val alarms = JSONArray(alarmsJson)
            
            // Remove existing alarm with same ID if present
            val newAlarms = JSONArray()
            for (i in 0 until alarms.length()) {
                val alarm = alarms.getJSONObject(i)
                if (alarm.getInt("id") != alarmId) {
                    newAlarms.put(alarm)
                }
            }
            
            // Add the new alarm
            val alarmObj = JSONObject().apply {
                put("id", alarmId)
                put("triggerTime", triggerTimeMillis)
                put("title", title)
                put("body", body)
                put("soundId", soundId)
                put("vibrationPatternId", vibrationPatternId)
                put("showFullscreen", showFullscreen)
                put("audioStream", audioStream)
                put("oneShot", oneShot)
                put("payload", payload)
                put("actionsEnabled", actionsEnabled)
                if (!iconPngBase64.isNullOrBlank()) {
                    put("iconPngBase64", iconPngBase64)
                }
                if (!actionsJson.isNullOrBlank()) {
                    put("actionsJson", actionsJson)
                }
            }
            newAlarms.put(alarmObj)
            
            prefs.edit().putString(KEY_ALARMS, newAlarms.toString()).apply()
            Log.d(TAG, "Saved alarm $alarmId for reboot restoration")
        }
        
        /**
         * Remove alarm info from SharedPreferences.
         */
        fun removeAlarm(context: Context, alarmId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val alarmsJson = prefs.getString(KEY_ALARMS, "[]") ?: "[]"
            val alarms = JSONArray(alarmsJson)
            
            val newAlarms = JSONArray()
            for (i in 0 until alarms.length()) {
                val alarm = alarms.getJSONObject(i)
                if (alarm.getInt("id") != alarmId) {
                    newAlarms.put(alarm)
                }
            }
            
            prefs.edit().putString(KEY_ALARMS, newAlarms.toString()).apply()
            Log.d(TAG, "Removed alarm $alarmId from reboot restoration")
        }
        
        /**
         * Clear all saved alarms.
         */
        fun clearAllAlarms(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_ALARMS).apply()
            Log.d(TAG, "Cleared all saved alarms")
        }

        /**
         * Get all scheduled alarms for Flutter (e.g. orphan detection).
         * Returns List<Map> with id, triggerTime, title, body, payload, oneShot, etc.
         * Android AlarmManager has no API to list alarms; this reads our own persistence.
         */
        fun getScheduledAlarms(context: Context): List<Map<String, Any?>> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val alarmsJson = prefs.getString(KEY_ALARMS, "[]") ?: "[]"
            val alarms = org.json.JSONArray(alarmsJson)
            val result = mutableListOf<Map<String, Any?>>()
            val currentTime = System.currentTimeMillis()
            for (i in 0 until alarms.length()) {
                try {
                    val alarm = alarms.getJSONObject(i)
                    val triggerTime = alarm.getLong("triggerTime")
                    if (triggerTime <= currentTime) continue
                    result.add(mapOf(
                        "id" to alarm.getInt("id"),
                        "triggerTime" to triggerTime,
                        "title" to alarm.getString("title"),
                        "body" to alarm.optString("body", ""),
                        "payload" to alarm.optString("payload", ""),
                        "oneShot" to alarm.optBoolean("oneShot", false),
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing alarm: ${e.message}")
                }
            }
            return result
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        Log.d(TAG, "Boot/update completed, restoring alarms...")
        
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alarmsJson = prefs.getString(KEY_ALARMS, "[]") ?: "[]"
        val alarms = JSONArray(alarmsJson)
        
        val currentTime = System.currentTimeMillis()
        val newAlarms = JSONArray()
        
        for (i in 0 until alarms.length()) {
            try {
                val alarm = alarms.getJSONObject(i)
                val alarmId = alarm.getInt("id")
                val triggerTime = alarm.getLong("triggerTime")
                val title = alarm.getString("title")
                val body = alarm.getString("body")
                val soundId = alarm.optString("soundId", "alarm")
                val vibrationPatternId = alarm.optString("vibrationPatternId", "default")
                val showFullscreen = alarm.optBoolean("showFullscreen", true)
                val audioStream = alarm.optString("audioStream", "alarm")
                val oneShot = alarm.optBoolean("oneShot", false)
                val payload = alarm.optString("payload", "")
                val iconPngBase64 = alarm.optString("iconPngBase64", "")
                val iconPngValue = if (iconPngBase64.isBlank()) null else iconPngBase64
                val actionsEnabled = alarm.optBoolean("actionsEnabled", true)
                val actionsJson = alarm.optString("actionsJson", "")
                val actionsJsonValue = if (actionsJson.isBlank()) null else actionsJson
                
                // Only reschedule future alarms
                if (triggerTime > currentTime) {
                    AlarmReceiver.scheduleAlarm(
                        context,
                        alarmId,
                        triggerTime,
                        title,
                        body,
                        soundId,
                        vibrationPatternId,
                        showFullscreen,
                        audioStream,
                        oneShot,
                        payload,
                        iconPngValue,
                        actionsEnabled,
                        actionsJsonValue
                    )
                    newAlarms.put(alarm)
                    Log.d(TAG, "Restored alarm $alarmId: $title")
                } else {
                    Log.d(TAG, "Skipped past alarm $alarmId")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error restoring alarm: ${e.message}")
            }
        }
        
        // Update saved alarms (remove expired ones)
        prefs.edit().putString(KEY_ALARMS, newAlarms.toString()).apply()
        Log.d(TAG, "Restored ${newAlarms.length()} alarms after boot")
    }
}
