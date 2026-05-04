package com.shakti.app

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * PowerButtonService
 * Detects 3 rapid power button presses using AccessibilityService.
 *
 * Required in AndroidManifest.xml:
 * <service
 *   android:name=".PowerButtonService"
 *   android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
 *   <intent-filter>
 *     <action android:name="android.accessibilityservice.AccessibilityService"/>
 *   </intent-filter>
 *   <meta-data
 *     android:name="android.accessibilityservice"
 *     android:resource="@xml/accessibility_config"/>
 * </service>
 */
class PowerButtonService : AccessibilityService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null
        private var pressCount = 0
        private var lastPressTime = 0L
        private const val PRESS_WINDOW_MS = 2000L
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    /**
     * Called on global actions (power button press triggers GLOBAL_ACTION_POWER_DIALOG)
     */
    override fun onKeyEvent(event: android.view.KeyEvent): Boolean {
        if (event.keyCode == android.view.KeyEvent.KEYCODE_POWER &&
            event.action == android.view.KeyEvent.ACTION_DOWN) {
            
            val now = System.currentTimeMillis()
            if (now - lastPressTime < PRESS_WINDOW_MS) {
                pressCount++
            } else {
                pressCount = 1
            }
            lastPressTime = now

            if (pressCount >= 3) {
                pressCount = 0
                // Notify Flutter via EventChannel
                eventSink?.success("sos_trigger")
            }
        }
        return false // Don't consume the event
    }
}
