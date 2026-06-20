package com.example.central_hub

class FocusSmallWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_focus_small
    override val imageViewId = R.id.widget_focus_image
    override val placeholderViewId = R.id.widget_focus_placeholder
    override val actionsContainerId = R.id.widget_focus_actions
    override val chronometerViewId = R.id.widget_focus_chrono
    override val deepLinkHost = "focus"
}
