package com.myneighborhood.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationManagerCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.myneighborhood.app/location_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openLocationSettings") {
                try {
                    val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to open location settings: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // יצירת Notification Channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannelCompat.Builder(
                "subscription_channel",
                android.app.NotificationManager.IMPORTANCE_HIGH
            )
                .setName("Subscription Notifications")
                .setDescription("Notifications for subscription updates")
                .setSound(android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION), null)
                .setVibrationEnabled(true)
                .build()
            
            val notificationManager = NotificationManagerCompat.from(this)
            notificationManager.createNotificationChannel(channel)
        }
        
        // ✅ תזמון בדיקת שירות המיקום גם כאשר האפליקציה סגורה
        LocationServiceWorker.schedulePeriodicCheck(this)
    }

}

