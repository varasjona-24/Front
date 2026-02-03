package com.example.flutter_listenfy.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.widget.RemoteViews
import androidx.media.session.MediaButtonReceiver
import android.support.v4.media.session.PlaybackStateCompat
import com.example.flutter_listenfy.MainActivity
import com.example.flutter_listenfy.R
import android.view.View
import java.io.File

class PlayerWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (ACTION_WIDGET_UPDATE == intent.action) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, PlayerWidgetProvider::class.java)
            )
            onUpdate(context, mgr, ids)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            val views = buildViews(context)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString(KEY_TITLE, "Listenfy") ?: "Listenfy"
        val artist = prefs.getString(KEY_ARTIST, "") ?: ""
        val artPath = prefs.getString(KEY_ART_PATH, "") ?: ""
        val playing = prefs.getBoolean(KEY_PLAYING, false)
        val barColor = prefs.getInt(KEY_BAR_COLOR, 0xFF1E2633.toInt())

        val views = RemoteViews(context.packageName, R.layout.player_widget)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, artist)
        views.setViewVisibility(
            R.id.widget_artist,
            if (artist.isBlank()) View.GONE else View.VISIBLE
        )
        views.setInt(R.id.widget_controls, "setBackgroundColor", barColor)

        val coverFile = if (artPath.isNotEmpty()) File(artPath) else null
        if (coverFile != null && coverFile.exists()) {
            val bitmap = BitmapFactory.decodeFile(coverFile.absolutePath)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_cover, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_cover, R.mipmap.ic_launcher)
            }
        } else {
            views.setImageViewResource(R.id.widget_cover, R.mipmap.ic_launcher)
        }

        val playRes = if (playing) android.R.drawable.ic_media_pause
        else android.R.drawable.ic_media_play
        views.setImageViewResource(R.id.widget_play_pause, playRes)

        val contentIntent = Intent(context, MainActivity::class.java)
        val contentPending = PendingIntent.getActivity(
            context,
            0,
            contentIntent,
            pendingFlags()
        )
        views.setOnClickPendingIntent(R.id.widget_root, contentPending)

        val prevIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            context,
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        )
        val playPauseIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            context,
            PlaybackStateCompat.ACTION_PLAY_PAUSE
        )
        val nextIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            context,
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        )

        views.setOnClickPendingIntent(R.id.widget_prev, prevIntent)
        views.setOnClickPendingIntent(R.id.widget_play_pause, playPauseIntent)
        views.setOnClickPendingIntent(R.id.widget_next, nextIntent)

        return views
    }

    private fun pendingFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    companion object {
        const val ACTION_WIDGET_UPDATE =
            "com.example.flutter_listenfy.ACTION_WIDGET_UPDATE"

        const val PREFS = "player_widget"
        const val KEY_TITLE = "title"
        const val KEY_ARTIST = "artist"
        const val KEY_ART_PATH = "artPath"
        const val KEY_PLAYING = "playing"
        const val KEY_BAR_COLOR = "barColor"
    }
}
