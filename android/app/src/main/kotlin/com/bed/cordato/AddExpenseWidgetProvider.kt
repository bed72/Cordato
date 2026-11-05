package com.bed.cordato

import android.net.Uri
import android.content.Context
import android.widget.RemoteViews
import android.content.SharedPreferences
import android.appwidget.AppWidgetManager

import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class AddExpenseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.add_expense_widget)
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("cordato://widget/add-expense?homeWidget=true")
            )
            views.setOnClickPendingIntent(R.id.add_expense_widget, launchIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
