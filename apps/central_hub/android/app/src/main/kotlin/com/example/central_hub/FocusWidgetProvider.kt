package com.example.central_hub

class FocusWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_focus
    override val imageViewId = R.id.widget_focus_image
    override val placeholderViewId = R.id.widget_focus_placeholder
    override val actionsContainerId = R.id.widget_focus_actions
    override val deepLinkHost = "focus"
}
