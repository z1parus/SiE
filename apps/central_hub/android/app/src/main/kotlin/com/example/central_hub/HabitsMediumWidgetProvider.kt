package com.example.central_hub

class HabitsMediumWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_habits
    override val imageViewId = R.id.widget_image
    override val placeholderViewId = R.id.widget_placeholder
    override val actionsContainerId = R.id.widget_actions
    override val deepLinkHost = "habits"
}
