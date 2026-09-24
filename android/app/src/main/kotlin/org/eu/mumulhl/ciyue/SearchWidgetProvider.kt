package org.eu.mumulhl.ciyue

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SearchWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.search_widget_layout).apply {
                    val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("ciyue://search"),
                    )
                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
