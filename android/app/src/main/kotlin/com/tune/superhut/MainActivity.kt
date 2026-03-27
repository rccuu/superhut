package com.tune.superhut

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val TARGET_REFRESH_RATE = 120f
        private const val COURSE_WIDGET_CHANNEL =
            "com.superhut.rice.superhut/coursetable_widget"
        private const val WIDGET_ACTIONS_CHANNEL =
            "com.superhut.rice.superhut/widget_actions"
        private const val EXTRA_WIDGET_ACTION = "widget_action"
        private const val COURSE_WIDGET_PAYLOAD_FILE = "course_widget_payload.json"
    }

    private var widgetActionsChannel: MethodChannel? = null

    private data class PreferredRefreshSelection(
        val refreshRate: Float,
        val preferredDisplayModeId: Int? = null,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyPreferredHighRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            COURSE_WIDGET_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncCourseTableWidget" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val payloadJson = arguments?.get("payloadJson") as? String
                    cacheCompactCourseWidgetPayload(payloadJson)
                    refreshCourseTableWidgets()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        widgetActionsChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                WIDGET_ACTIONS_CHANNEL,
            ).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getInitialWidgetAction" -> result.success(consumeInitialWidgetAction())
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onResume() {
        super.onResume()
        applyPreferredHighRefreshRate()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchWidgetAction(intent)
    }

    private fun consumeInitialWidgetAction(): String? {
        val action = intent?.getStringExtra(EXTRA_WIDGET_ACTION)
        intent?.removeExtra(EXTRA_WIDGET_ACTION)
        return action
    }

    private fun dispatchWidgetAction(intent: Intent?) {
        val action = intent?.getStringExtra(EXTRA_WIDGET_ACTION) ?: return
        widgetActionsChannel?.invokeMethod("navigateToFunction", action)
        intent.removeExtra(EXTRA_WIDGET_ACTION)
    }

    private fun cacheCompactCourseWidgetPayload(payloadJson: String?) {
        if (payloadJson.isNullOrBlank()) {
            return
        }

        val appDir = applicationContext.filesDir.parentFile ?: return
        val flutterDir =
            File(appDir, "app_flutter").apply {
                if (!exists()) {
                    mkdirs()
                }
            }

        File(flutterDir, COURSE_WIDGET_PAYLOAD_FILE).writeText(payloadJson)

        val filesDir =
            File(appDir, "files").apply {
                if (!exists()) {
                    mkdirs()
                }
            }
        File(filesDir, COURSE_WIDGET_PAYLOAD_FILE).writeText(payloadJson)
    }

    private fun refreshCourseTableWidgets() {
        val context = applicationContext
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, CourseTableWidgetProvider::class.java)
        val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
        if (widgetIds.isEmpty()) {
            return
        }

        val refreshIntent =
            Intent(context, CourseTableWidgetProvider::class.java).apply {
                action = CourseTableWidgetProvider.ACTION_REFRESH
            }
        context.sendBroadcast(refreshIntent)
    }

    private fun applyPreferredHighRefreshRate() {
        val preferredRefreshSelection = preferredRefreshSelection() ?: return
        val attributes = window.attributes
        var changed = false

        if (attributes.preferredRefreshRate != preferredRefreshSelection.refreshRate) {
            attributes.preferredRefreshRate = preferredRefreshSelection.refreshRate
            changed = true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val preferredDisplayModeId =
                preferredRefreshSelection.preferredDisplayModeId ?: 0

            if (attributes.preferredDisplayModeId != preferredDisplayModeId) {
                attributes.preferredDisplayModeId = preferredDisplayModeId
                changed = true
            }
        }

        if (!changed) {
            return
        }

        // Request a high refresh rate when the device supports it.
        // The system may still override this due to thermal, battery, power,
        // or vendor policies.
        window.attributes = attributes
    }

    private fun preferredRefreshSelection(): PreferredRefreshSelection? {
        val display = currentDisplay() ?: return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val currentMode = display.mode
            val sameResolutionModes =
                display.supportedModes.filter {
                    it.physicalWidth == currentMode.physicalWidth &&
                        it.physicalHeight == currentMode.physicalHeight
                }

            val preferredMode = selectPreferredMode(sameResolutionModes)
            val preferredRefreshRate =
                preferredMode?.refreshRate
                    ?: selectPreferredRefreshRate(
                        display.supportedModes.map { it.refreshRate },
                    )
                    ?: return null

            PreferredRefreshSelection(
                refreshRate = preferredRefreshRate,
                preferredDisplayModeId = preferredMode?.modeId,
            )
        } else {
            @Suppress("DEPRECATION")
            display.refreshRate.takeIf { it > 60f }?.let {
                PreferredRefreshSelection(refreshRate = it)
            }
        }
    }

    private fun selectPreferredMode(modes: List<Display.Mode>): Display.Mode? {
        return modes
            .filter { it.refreshRate > 60f }
            .sortedBy { it.refreshRate }
            .lastOrNull { it.refreshRate <= TARGET_REFRESH_RATE }
            ?: modes
                .filter { it.refreshRate > 60f }
                .maxByOrNull { it.refreshRate }
    }

    private fun selectPreferredRefreshRate(refreshRates: List<Float>): Float? {
        val sortedRates = refreshRates.distinct().sorted()
        return sortedRates
            .lastOrNull { it > 60f && it <= TARGET_REFRESH_RATE }
            ?: sortedRates.lastOrNull { it > 60f }
    }

    private fun currentDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
    }
}
