package com.involvex.ssh_app_flutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SshQuickConnectWidget : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      updateWidget(context, appWidgetManager, widgetId, widgetData, WIDGET_MODE_SSH)
    }
  }

  companion object {
    const val WIDGET_MODE_SSH = "ssh"
    const val WIDGET_MODE_AGENT = "agent"
    const val EXTRA_WIDGET_MODE = "widget_mode"

    fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences,
        widgetMode: String,
    ) {
      val views = RemoteViews(context.packageName, R.layout.widget_profiles)

      val title =
          if (widgetMode == WIDGET_MODE_SSH) {
            context.getString(R.string.widget_ssh_title)
          } else {
            context.getString(R.string.widget_agent_title)
          }
      views.setTextViewText(R.id.widget_title, title)

      val serviceIntent =
          Intent(context, ProfileWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(EXTRA_WIDGET_MODE, widgetMode)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
          }
      views.setRemoteAdapter(R.id.widget_list, serviceIntent)
      views.setEmptyView(R.id.widget_list, R.id.widget_empty)

      val path = if (widgetMode == WIDGET_MODE_SSH) "ssh" else "agent"
      val templateIntent =
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse("sshapp://widget/$path"),
          )
      views.setPendingIntentTemplate(R.id.widget_list, templateIntent)

      appWidgetManager.updateAppWidget(widgetId, views)
      appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
    }
  }
}
