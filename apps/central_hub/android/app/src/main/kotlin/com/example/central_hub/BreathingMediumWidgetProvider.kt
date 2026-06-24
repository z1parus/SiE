package com.example.central_hub

class BreathingMediumWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_breathing
    override val imageViewId = R.id.widget_breathing_image
    override val placeholderViewId = R.id.widget_breathing_placeholder
    override val actionsContainerId = R.id.widget_breathing_actions
    override val deepLinkHost = "breathing"
}
