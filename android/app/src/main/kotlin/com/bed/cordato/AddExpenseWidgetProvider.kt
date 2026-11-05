package com.bed.cordato

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.math.BigDecimal
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.Locale
import org.json.JSONException
import org.json.JSONObject

class AddExpenseWidgetProvider : HomeWidgetProvider() {
    private val brazilianLocale = Locale.forLanguageTag("pt-BR")

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val now = GregorianCalendar().time
        val monthKey = SimpleDateFormat("yyyy-MM", Locale.US).format(now)
        val monthTitle = SimpleDateFormat("MMMM", brazilianLocale).format(now)
            .replaceFirstChar { it.titlecase(brazilianLocale) }
        val cents = readMonthlyCents(widgetData.getString(MONTHLY_SUMMARY_KEY, null), monthKey)
        val views = createWidgetViews(context, monthTitle, cents)

        for (widgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        scheduleMonthChange(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> refreshInstalledWidgets(context)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        context.getSystemService(AlarmManager::class.java).cancel(monthChangeIntent(context))
    }

    private fun refreshInstalledWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val widgetIds = manager.getAppWidgetIds(ComponentName(context, javaClass))
        if (widgetIds.isEmpty()) {
            return
        }

        onUpdate(context, manager, widgetIds)
    }

    private fun createWidgetViews(context: Context, monthTitle: String, cents: Long?): RemoteViews {
        val amount = formatAmount(context, cents)
        val launchIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(LAUNCH_URI)
        )

        return RemoteViews(context.packageName, R.layout.add_expense_widget).apply {
            setTextViewText(R.id.widget_total, amount)
            setTextViewText(R.id.widget_month, monthTitle)
            setViewVisibility(R.id.widget_total, if (cents == null) View.GONE else View.VISIBLE)
            setViewVisibility(R.id.widget_update_hint, if (cents == null) View.VISIBLE else View.GONE)
            setContentDescription(
                R.id.add_expense_widget,
                context.getString(R.string.widget_content_description, monthTitle, amount)
            )
            setOnClickPendingIntent(R.id.add_expense_widget, launchIntent)
        }
    }

    private fun formatAmount(context: Context, cents: Long?): String {
        if (cents == null) {
            return context.getString(R.string.widget_update_hint)
        }

        return NumberFormat.getCurrencyInstance(brazilianLocale)
            .format(BigDecimal.valueOf(cents, 2))
    }

    private fun readMonthlyCents(summary: String?, monthKey: String): Long? {
        if (summary == null) {
            return null
        }

        return try {
            val snapshot = JSONObject(summary)
            if (snapshot.optString("month") != monthKey) {
                return null
            }

            when (val cents = snapshot.get("cents")) {
                is Long -> cents
                is Int -> cents.toLong()
                else -> null
            }
        } catch (error: JSONException) {
            null
        }
    }

    private fun scheduleMonthChange(context: Context) {
        context.getSystemService(AlarmManager::class.java).set(
            AlarmManager.RTC,
            nextMonthStartMillis(),
            monthChangeIntent(context)
        )
    }

    private fun nextMonthStartMillis(): Long {
        return GregorianCalendar().apply {
            set(Calendar.DAY_OF_MONTH, 1)
            add(Calendar.MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun monthChangeIntent(context: Context): PendingIntent {
        val manager = AppWidgetManager.getInstance(context)
        val widgetIds = manager.getAppWidgetIds(ComponentName(context, javaClass))
        val intent = Intent(context, javaClass).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
        }

        return PendingIntent.getBroadcast(
            context,
            MONTH_CHANGE_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private companion object {
        const val MONTHLY_SUMMARY_KEY = "monthly_summary"
        const val MONTH_CHANGE_REQUEST_CODE = 1
        const val LAUNCH_URI = "cordato://widget/add-expense?homeWidget=true"
    }
}
