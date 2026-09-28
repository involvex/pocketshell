package com.involvex.ssh_app_flutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

class AgentQuickConnectWidget : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      SshQuickConnectWidget.updateWidget(
          context,
          appWidgetManager,
          widgetId,
          widgetData,
          SshQuickConnectWidget.WIDGET_MODE_AGENT,
      )
    }
  }
}
