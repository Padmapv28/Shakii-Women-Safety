package com.shakti.app

import android.os.Bundle
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val POWER_CHANNEL = "com.shakti/power_button"
    private val CALL_CHANNEL = "com.shakti/call"
    private val NOTIF_CHANNEL = "com.shakti/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Power button event stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, POWER_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    PowerButtonService.eventSink = events
                }
                override fun onCancel(args: Any?) {
                    PowerButtonService.eventSink = null
                }
            })

        // Direct call (no UI prompt)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "call") {
                    val number = call.argument<String>("number") ?: ""
                    val intent = android.content.Intent(android.content.Intent.ACTION_CALL).apply {
                        data = android.net.Uri.parse("tel:$number")
                        flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    result.success(true)
                }
            }

        // Local notifications (safety prompts)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showSafetyPrompt" -> {
                        val message = call.argument<String>("message") ?: "Are you safe?"
                        val alertId = call.argument<String>("alertId") ?: ""
                        showNotification(
                            title = "Shakti Safety Check",
                            message = message,
                            alertId = alertId,
                            type = "safety"
                        )
                        result.success(true)
                    }
                    "showAnomalyPrompt" -> {
                        val message = call.argument<String>("message") ?: "Unusual activity detected"
                        showNotification(
                            title = "Shakti AI Alert",
                            message = message,
                            alertId = "",
                            type = "anomaly"
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun showNotification(title: String, message: String, alertId: String, type: String) {
        val notifManager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        
        // Create high-priority channel
        val channel = android.app.NotificationChannel(
            "shakti_safety", "Shakti Safety",
            android.app.NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Safety alerts from Shakti"
            enableVibration(true)
            setSound(
                android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI,
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                    .build()
            )
        }
        notifManager.createNotificationChannel(channel)

        val notification = android.app.Notification.Builder(this, "shakti_safety")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(message)
            .setFullScreenIntent(null, true)
            .setAutoCancel(true)
            .build()

        notifManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
