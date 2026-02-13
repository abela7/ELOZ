package com.eloz.life_manager

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class TodayTasksWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Enter relevant functionality for when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Enter relevant functionality for when the last widget is disabled
    }

    companion object {
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Flutter shared_preferences uses "FlutterSharedPreferences" file with "flutter." prefix
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Flutter shared_preferences adds "flutter." prefix to keys
            val title = prefs.getString("flutter.title", "Today's Tasks") ?: "Today's Tasks"
            val subtitle = prefs.getString("flutter.subtitle", "Open app to load tasks") ?: "Open app to load tasks"
            val task0 = prefs.getString("flutter.task_0", "") ?: ""
            val task1 = prefs.getString("flutter.task_1", "") ?: ""
            val task2 = prefs.getString("flutter.task_2", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.home_widget)
            views.setTextViewText(R.id.title, title)
            views.setTextViewText(R.id.subtitle, subtitle)
            views.setTextViewText(R.id.task_0, task0)
            views.setTextViewText(R.id.task_1, task1)
            views.setTextViewText(R.id.task_2, task2)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
