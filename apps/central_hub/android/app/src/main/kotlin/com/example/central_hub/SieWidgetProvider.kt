package com.example.central_hub

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

abstract class SieWidgetProvider : AppWidgetProvider() {
    abstract val layoutId: Int
    abstract val imageViewId: Int
    abstract val deepLinkHost: String

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, layoutId)

        val imagePath = widgetData.getString("widget_img_$appWidgetId", null)
        if (imagePath != null) {
            val bitmap = android.graphics.BitmapFactory.decodeFile(imagePath)
            if (bitmap != null) {
                views.setImageViewBitmap(imageViewId, bitmap)
            }
        }

        val deepLinkIntent = android.content.Intent(
            android.content.Intent.ACTION_VIEW,
            android.net.Uri.parse("sie://widget/$deepLinkHost?widgetId=$appWidgetId"),
            context,
            MainActivity::class.java
        )
        val pendingIntent = android.app.PendingIntent.getActivity(
            context, appWidgetId, deepLinkIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(imageViewId, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
