package com.example.central_hub

class PlanningSmallWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_planning
    override val imageViewId = R.id.widget_planning_image
    override val placeholderViewId = R.id.widget_planning_placeholder
    override val actionsContainerId = R.id.widget_planning_actions
    override val deepLinkHost = "planning"
}
