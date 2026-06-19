package com.example.central_hub

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Base class for all SiE home-screen widgets. Renders the Flutter-generated
 * PNG into an ImageView, wires a whole-widget deep-link, and overlays one
 * transparent tap-zone per row for quick-actions (e.g. toggle a habit).
 */
abstract class SieWidgetProvider : HomeWidgetProvider() {
    abstract val layoutId: Int
    abstract val imageViewId: Int
    abstract val placeholderViewId: Int
    abstract val actionsContainerId: Int
    abstract val deepLinkHost: String

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)

            // ── PNG ──────────────────────────────────────────────────────────
            val imagePath = widgetData.getString("widget_img_$appWidgetId", null)
            val bitmap = if (imagePath != null) BitmapFactory.decodeFile(imagePath) else null
            if (bitmap != null) {
                views.setImageViewBitmap(imageViewId, bitmap)
                views.setViewVisibility(imageViewId, View.VISIBLE)
                views.setViewVisibility(placeholderViewId, View.GONE)
            } else {
                // No render yet — keep the branded placeholder card visible.
                views.setViewVisibility(imageViewId, View.GONE)
                views.setViewVisibility(placeholderViewId, View.VISIBLE)
            }

            // ── Whole-widget deep-link ───────────────────────────────────────
            val host = widgetData.getString("widget_host_$appWidgetId", deepLinkHost)
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("sie://widget/$host?widgetId=$appWidgetId")
            )
            views.setOnClickPendingIntent(imageViewId, launchIntent)
            views.setOnClickPendingIntent(placeholderViewId, launchIntent)

            // ── Per-row quick-action tap zones ───────────────────────────────
            views.removeAllViews(actionsContainerId)
            val zonesJson = widgetData.getString("widget_zones_$appWidgetId", null)
            if (zonesJson != null) {
                try {
                    val zones = JSONArray(zonesJson)
                    for (i in 0 until zones.length()) {
                        val zone = zones.getJSONObject(i)
                        val action = zone.optString("action")
                        val entityId = zone.optString("id")
                        val row = RemoteViews(context.packageName, R.layout.widget_action_row)
                        val actionUri = Uri.parse(
                            "sie://action/$action?widget=$appWidgetId&id=$entityId"
                        )
                        val backgroundIntent =
                            HomeWidgetBackgroundIntent.getBroadcast(context, actionUri)
                        row.setOnClickPendingIntent(R.id.action_row, backgroundIntent)
                        views.addView(actionsContainerId, row)
                    }
                } catch (_: Exception) {
                    // Malformed zones — fall back to deep-link only.
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
