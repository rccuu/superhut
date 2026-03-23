package com.tune.superhut

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val targetRefreshRate = 120f

    private data class PreferredRefreshSelection(
        val refreshRate: Float,
        val preferredDisplayModeId: Int? = null,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyPreferredHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        applyPreferredHighRefreshRate()
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
            .lastOrNull { it.refreshRate <= targetRefreshRate }
            ?: modes
                .filter { it.refreshRate > 60f }
                .maxByOrNull { it.refreshRate }
    }

    private fun selectPreferredRefreshRate(refreshRates: List<Float>): Float? {
        val sortedRates = refreshRates.distinct().sorted()
        return sortedRates
            .lastOrNull { it > 60f && it <= targetRefreshRate }
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
