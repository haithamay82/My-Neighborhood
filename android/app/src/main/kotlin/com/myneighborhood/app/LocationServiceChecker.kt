package com.myneighborhood.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.LocationManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.FirebaseApp

class LocationServiceChecker : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("LocationServiceChecker", "Broadcast received: ${intent.action}")
        
        try {
            // ✅ אם זה BOOT_COMPLETED, נתזמן את ה-WorkManager כדי שימשיך לבדוק גם לאחר הפעלה מחדש
            if (Intent.ACTION_BOOT_COMPLETED == intent.action) {
                Log.d("LocationServiceChecker", "Boot completed - scheduling WorkManager")
                LocationServiceWorker.schedulePeriodicCheck(context)
                return
            }
            
            // ✅ תמיד לתזמן את ה-WorkManager כאשר מקבלים PROVIDERS_CHANGED או MODE_CHANGED
            // זה מבטיח שה-WorkManager ימשיך לבדוק גם כאשר האפליקציה סגורה לחלוטין
            Log.d("LocationServiceChecker", "Location service changed - scheduling WorkManager")
            LocationServiceWorker.schedulePeriodicCheck(context)
            
            // בדיקה אם שירות המיקום פעיל
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isLocationEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                                    locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            
            val prefs = context.getSharedPreferences("location_service_prefs", Context.MODE_PRIVATE)
            
            // ✅ קריאת העדפות מ-SharedPreferences ברירת המחדל של Flutter
            // Flutter SharedPreferences נשמר תחת שם ספציפי - FlutterSharedPreferences
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            if (!isLocationEnabled) {
                // ✅ בדיקה אם המשתמש סימן את הצ'יקבוקס "סנן בקשות על פי המיקום הנייד שלי..."
                // אם לא סימן, לא נשלח התראה
                // קריאה מ-SharedPreferences ברירת המחדל של Flutter
                val useMobileLocation = flutterPrefs.getBoolean("flutter.user_use_mobile_location", false)
                val useBothLocations = flutterPrefs.getBoolean("flutter.user_use_both_locations", false)
                
                if (!useMobileLocation && !useBothLocations) {
                    Log.d("LocationServiceChecker", "📍 User has not enabled mobile location filter - skipping location service notification")
                    return
                }
                
                // בדיקה אם כבר שלחנו התראה
                val notificationSent = prefs.getBoolean("notification_sent", false)
                
                if (!notificationSent) {
                    Log.d("LocationServiceChecker", "📍 Location service is disabled - sending FCM notification IMMEDIATELY via BroadcastReceiver")
                    sendLocationServiceNotificationViaFCM(context, flutterPrefs)
                    
                    // שמירה שכבר שלחנו התראה
                    prefs.edit().putBoolean("notification_sent", true).apply()
                } else {
                    Log.d("LocationServiceChecker", "Location service is disabled but notification already sent - skipping")
                }
            } else {
                // ✅ אם שירות המיקום מופעל, איפוס הסטטוס כדי שנוכל לשלוח התראה שוב אם ייסגר
                Log.d("LocationServiceChecker", "📍 Location service is enabled - resetting notification flag")
                prefs.edit().putBoolean("notification_sent", false).apply()
            }
        } catch (e: Exception) {
            Log.e("LocationServiceChecker", "Error in onReceive: ${e.message}")
        }
    }
    
    // ✅ שליחת התראה דרך Firebase Cloud Messaging (FCM) במקום התראה מקומית
    // זה עובד גם כאשר האפליקציה סגורה לחלוטין, בדיוק כמו התראות על בקשות חדשות
    private fun sendLocationServiceNotificationViaFCM(context: Context, flutterPrefs: SharedPreferences) {
        try {
            // ✅ וידוא ש-Firebase מאותחל
            try {
                FirebaseApp.initializeApp(context)
            } catch (e: Exception) {
                // Firebase כבר מאותחל - זה בסדר
                Log.d("LocationServiceChecker", "Firebase already initialized or error: ${e.message}")
            }
            
            // קבלת userId מ-SharedPreferences
            val userId = flutterPrefs.getString("flutter.current_user_id", null)
            
            if (userId.isNullOrEmpty()) {
                Log.d("LocationServiceChecker", "📍 No user ID found in SharedPreferences - cannot send FCM notification")
                return
            }
            
            Log.d("LocationServiceChecker", "📍 Sending FCM notification for user: $userId")
            
            // יצירת מסמך ב-Firestore ב-push_notifications collection
            // Cloud Function sendPushNotification ישלח את ההתראה דרך FCM
            val firestore = FirebaseFirestore.getInstance()
            val notificationData = hashMapOf(
                "userId" to userId,
                "title" to "שירות המיקום כבוי",
                "body" to "שירות המיקום במכשיר שלך כבוי. אנא הפעל את שירות המיקום בהגדרות המכשיר כדי להשתמש בתכונות מבוססות מיקום.",
                "payload" to "location_service_disabled",
                "data" to hashMapOf(
                    "type" to "location_service_disabled",
                    "screen" to "home"
                )
            )
            
            firestore.collection("push_notifications")
                .add(notificationData)
                .addOnSuccessListener { documentReference ->
                    Log.d("LocationServiceChecker", "✅ FCM notification queued successfully: ${documentReference.id}")
                }
                .addOnFailureListener { e ->
                    Log.e("LocationServiceChecker", "❌ Error queuing FCM notification: ${e.message}")
                }
        } catch (e: Exception) {
            Log.e("LocationServiceChecker", "❌ Error sending FCM notification: ${e.message}")
        }
    }
    
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location Service Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for location service status"
            }
            
            val notificationManager = context.getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    companion object {
        private const val CHANNEL_ID = "location_service_channel"
    }
}

