package com.example.central_hub

import android.content.SharedPreferences

class FocusWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_focus_medium
    override val imageViewId = R.id.widget_focus_image
    override val placeholderViewId = R.id.widget_focus_placeholder
    override val actionsContainerId = R.id.widget_focus_actions
    override val chronometerViewId = R.id.widget_focus_chrono
    override val deepLinkHost = "focus"

    // Pick the layout whose chronometer sits over the ring for the current size.
    override fun resolveLayout(widgetData: SharedPreferences, appWidgetId: Int): Int =
        when (widgetData.getString("widget_size_$appWidgetId", null)) {
            "small" -> R.layout.widget_focus_small
            "large" -> R.layout.widget_focus_large
            else -> R.layout.widget_focus_medium
        }
}
