package com.involvex.ssh_app_flutter

import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class ProfileWidgetService : RemoteViewsService() {
  override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
    return ProfileRemoteViewsFactory(applicationContext, intent)
  }
}

private data class WidgetProfile(
    val id: String,
    val name: String,
    val host: String,
    val port: Int,
    val agentPort: Int,
)

private class ProfileRemoteViewsFactory(
    private val context: android.content.Context,
    private val intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

  private val profiles = mutableListOf<WidgetProfile>()
  private var widgetMode: String = SshQuickConnectWidget.WIDGET_MODE_SSH

  override fun onCreate() = Unit

  override fun onDataSetChanged() {
    profiles.clear()
    widgetMode =
        intent.getStringExtra(SshQuickConnectWidget.EXTRA_WIDGET_MODE)
            ?: SshQuickConnectWidget.WIDGET_MODE_SSH

    val json =
        HomeWidgetPlugin.getData(context).getString("widget_profiles_json", null)
            ?: return

    try {
      val array = JSONArray(json)
      for (index in 0 until array.length()) {
        val item = array.getJSONObject(index)
        profiles.add(item.toWidgetProfile())
      }
    } catch (_: Exception) {
      profiles.clear()
    }
  }

  override fun onDestroy() {
    profiles.clear()
  }

  override fun getCount(): Int = if (profiles.isEmpty()) 1 else profiles.size

  override fun getViewAt(position: Int): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_profile_item)

    if (profiles.isEmpty()) {
      views.setTextViewText(R.id.widget_profile_name, context.getString(R.string.widget_no_profiles))
      views.setTextViewText(R.id.widget_profile_host, "")
      return views
    }

    val profile = profiles[position]
    views.setTextViewText(R.id.widget_profile_name, profile.name)
    views.setTextViewText(
        R.id.widget_profile_host,
        "${profile.host}:${profile.port}",
    )

    val fillInIntent =
        Intent().apply {
          data =
              Uri.parse(
                  "sshapp://widget/$widgetMode?profileId=${Uri.encode(profile.id)}",
              )
        }
    views.setOnClickFillInIntent(R.id.widget_profile_item, fillInIntent)
    return views
  }

  override fun getLoadingView(): RemoteViews? = null

  override fun getViewTypeCount(): Int = 1

  override fun getItemId(position: Int): Long =
      if (profiles.isEmpty()) {
        -1L
      } else {
        profiles[position].id.hashCode().toLong()
      }

  override fun hasStableIds(): Boolean = true
}

private fun JSONObject.toWidgetProfile(): WidgetProfile {
  return WidgetProfile(
      id = getString("id"),
      name = getString("name"),
      host = getString("host"),
      port = optInt("port", 22),
      agentPort = optInt("agentPort", 5000),
  )
}
