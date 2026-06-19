package com.example.central_hub

class HabitsWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_habits
    override val imageViewId = R.id.widget_image
    override val deepLinkHost = "habits"
}
