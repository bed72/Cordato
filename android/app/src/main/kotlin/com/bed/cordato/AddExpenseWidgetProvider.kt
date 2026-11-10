package com.bed.cordato

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.GregorianCalendar
import java.util.Locale
import org.json.JSONException
import org.json.JSONObject
import kotlin.math.min

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
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val views = createResponsiveViews(context, options, monthTitle, cents)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        scheduleMonthChange(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
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

    @Suppress("DEPRECATION")
    private fun createResponsiveViews(
        context: Context,
        options: Bundle,
        monthTitle: String,
        cents: Long?
    ): RemoteViews {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            if (!sizes.isNullOrEmpty()) {
                return RemoteViews(sizes.associateWith { size ->
                    createWidgetViews(context, monthTitle, cents, size.width, size.height)
                })
            }
        }

        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 150).toFloat()
        val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 150).toFloat()
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 150).toFloat()
        val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 150).toFloat()

        return RemoteViews(
            createWidgetViews(context, monthTitle, cents, maxWidth, minHeight),
            createWidgetViews(context, monthTitle, cents, minWidth, maxHeight)
        )
    }

    private fun createWidgetViews(
        context: Context,
        monthTitle: String,
        cents: Long?,
        width: Float,
        height: Float
    ): RemoteViews {
        val dimensions = WidgetDimensions(width, height)
        val layout = when {
            dimensions.compactAction -> R.layout.add_expense_widget_compact
            dimensions.horizontal -> R.layout.add_expense_widget_wide
            dimensions.tight -> R.layout.add_expense_widget_short
            else -> R.layout.add_expense_widget
        }
        val money = cents?.let(WidgetMoney::fromCents)
        val amount = money?.complete ?: context.getString(R.string.msg_home_widget_update_required)
        val monthLabel = if (dimensions.tight) monthTitle else {
            context.getString(R.string.label_home_widget_expenses_month, monthTitle)
        }
        val launchIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(LAUNCH_URI)
        )

        return RemoteViews(context.packageName, layout).apply {
            val density = context.resources.displayMetrics.density
            val horizontalPadding = (dimensions.horizontalPadding * density).toInt()
            val verticalPadding = (dimensions.verticalPadding * density).toInt()
            setViewPadding(
                R.id.add_expense_widget,
                horizontalPadding,
                verticalPadding,
                horizontalPadding,
                verticalPadding
            )
            setTextViewText(R.id.widget_month, monthLabel)
            setTextViewTextSize(
                R.id.widget_month,
                TypedValue.COMPLEX_UNIT_DIP,
                fittedFontSize(context, monthLabel, dimensions.summaryWidth - 2, 12f, 13f, false)
            )
            setTextViewTextSize(R.id.widget_update_hint, TypedValue.COMPLEX_UNIT_DIP, 13f)
            applyAction(context, dimensions)
            if (money != null) {
                applyMoney(context, dimensions, money)
            }
            setViewVisibility(R.id.widget_total, if (cents == null) View.GONE else View.VISIBLE)
            setViewVisibility(R.id.widget_update_hint, if (cents == null) View.VISIBLE else View.GONE)
            setContentDescription(
                R.id.add_expense_widget,
                context.getString(R.string.cd_home_widget_monthly_summary, monthTitle, amount)
            )
            setOnClickPendingIntent(R.id.add_expense_widget, launchIntent)
        }
    }

    private fun RemoteViews.applyAction(context: Context, dimensions: WidgetDimensions) {
        if (dimensions.compactAction) {
            return
        }

        val width = if (dimensions.horizontal) dimensions.actionWidth else dimensions.summaryWidth
        val label = context.getString(R.string.action_home_widget_add_expense)
        val height = (dimensions.actionHeight * context.resources.displayMetrics.density).toInt()

        setTextViewText(R.id.widget_action, label)
        if (dimensions.horizontal) {
            setInt(R.id.widget_action, "setWidth", (width * context.resources.displayMetrics.density).toInt())
        }
        setInt(R.id.widget_action, "setMinimumHeight", height)
        setTextViewTextSize(
            R.id.widget_action,
            TypedValue.COMPLEX_UNIT_DIP,
            fittedFontSize(context, label, width - 22, 15f, 18f, true)
        )
    }

    private fun RemoteViews.applyMoney(context: Context, dimensions: WidgetDimensions, money: WidgetMoney) {
        val baseFontSize = min(
            dimensions.preferredAmountFont * context.resources.configuration.fontScale,
            dimensions.maximumAmountFont
        )
        val amountLayout = WidgetAmountLayout.fit(
            money,
            dimensions.summaryWidth - 2,
            measuredWidth(context, money.complete, baseFontSize, true),
            measuredWidth(context, money.number, baseFontSize, true),
            baseFontSize,
            dimensions.canSplitCurrency
        )

        setViewVisibility(R.id.widget_currency, if (amountLayout.separateCurrency) View.VISIBLE else View.GONE)
        setInt(
            R.id.widget_total,
            "setHeight",
            (dimensions.amountHeight * context.resources.displayMetrics.density).toInt()
        )
        setTextViewTextSize(R.id.widget_currency, TypedValue.COMPLEX_UNIT_DIP, 12f)
        setTextViewText(R.id.widget_total, amountLayout.text)
        setTextViewTextSize(R.id.widget_total, TypedValue.COMPLEX_UNIT_DIP, amountLayout.fontSize)
    }

    private fun fittedFontSize(
        context: Context,
        text: String,
        width: Float,
        preferredSize: Float,
        maximumSize: Float,
        bold: Boolean
    ): Float {
        val fontSize = min(preferredSize * context.resources.configuration.fontScale, maximumSize)

        return fontSize * min(1f, width / measuredWidth(context, text, fontSize, bold).coerceAtLeast(1f))
    }

    private fun measuredWidth(context: Context, text: String, fontSize: Float, bold: Boolean): Float {
        val density = context.resources.displayMetrics.density
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = fontSize * density
            typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }

        return paint.measureText(text) / density
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
