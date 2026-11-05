package com.bed.cordato

import android.os.Bundle
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun shouldHandleDeeplinking(): Boolean {
        return intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION &&
            super.shouldHandleDeeplinking()
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
