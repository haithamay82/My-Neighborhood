package com.example.flutter1

import android.content.Context
import android.content.SharedPreferences
import android.location.LocationManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.PeriodicWorkRequest
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.FirebaseApp
import java.util.concurrent.TimeUnit

class LocationServiceWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        Log.d("LocationServiceWorker", "Checking location service status")
        
        try {
            val locationManager = applicationContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isLocationEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                                    locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // ✅ קריאת העדפות מ-SharedPreferences ברירת המחדל של Flutter
            // Flutter SharedPreferences נשמר תחת שם ספציפי - FlutterSharedPreferences
            val flutterPrefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            if (!isLocationEnabled) {
                // ✅ בדיקה אם המשתמש סימן את הצ'יקבוקס "סנן בקשות על פי המיקום הנייד שלי..."
                // אם לא סימן, לא נשלח התראה
                // קריאה מ-SharedPreferences ברירת המחדל של Flutter
                val useMobileLocation = flutterPrefs.getBoolean("flutter.user_use_mobile_location", false)
                val useBothLocations = flutterPrefs.getBoolean("flutter.user_use_both_locations", false)
                
                // ✅ לוגים לבדיקה
                Log.d("LocationServiceWorker", "📍 Checking user preferences: useMobileLocation=$useMobileLocation, useBothLocations=$useBothLocations")
                Log.d("LocationServiceWorker", "📍 All SharedPreferences keys: ${prefs.all.keys}")
                
                if (!useMobileLocation && !useBothLocations) {
                    Log.d("LocationServiceWorker", "📍 User has not enabled mobile location filter - skipping location service notification")
                    // ✅ גם אם המשתמש לא סימן את הצ'יקבוקס, נמשיך לבדוק בהתאם ללוגיקה (10 שניות אם ראשון, 24 שעות אחרת)
                    val firstCheckDone = prefs.getBoolean(KEY_FIRST_CHECK_DONE, false)
                    if (!firstCheckDone) {
                        scheduleFirstCheck(applicationContext)
                        prefs.edit().putBoolean(KEY_FIRST_CHECK_DONE, true).apply()
                    } else {
                        scheduleDailyCheck(applicationContext)
                    }
                    return Result.success()
                }
                
                // ✅ כאשר האפליקציה סגורה לחלוטין - בדיקה אם כבר נשלחה התראה
                // אם לא נשלחה התראה, נשלח התראה פעם אחת
                val notificationSent = prefs.getBoolean(KEY_NOTIFICATION_SENT, false)
                
                if (!notificationSent) {
                    Log.d("LocationServiceWorker", "📍 Location service is disabled - sending FCM notification ONCE (app closed)")
                    sendLocationServiceNotificationViaFCM(applicationContext, flutterPrefs)
                    
                    // שמירה שכבר נשלחה התראה
                    prefs.edit().putBoolean(KEY_NOTIFICATION_SENT, true).apply()
                } else {
                    Log.d("LocationServiceWorker", "📍 Location service is disabled but notification already sent - skipping")
                }
                
            } else {
                Log.d("LocationServiceWorker", "📍 Location service is enabled - resetting notification flag")
                // אם שירות המיקום מופעל, איפוס הסטטוס כדי שנוכל לשלוח התראה שוב אם ייסגר
                prefs.edit().putBoolean(KEY_NOTIFICATION_SENT, false).apply()
                prefs.edit().putLong(KEY_LAST_CHECK_WHEN_CLOSED, 0L).apply() // איפוס זמן הבדיקה האחרונה
                prefs.edit().putBoolean(KEY_FIRST_CHECK_DONE, false).apply() // איפוס בדיקה ראשונית
            }
            
            // ✅ תזמון בדיקה נוספת:
            // - אם זו הבדיקה הראשונה (אחרי סגירת האפליקציה) - בדיקה בעוד 10 שניות (פעם אחת)
            // - אחרת - בדיקה כל 24 שעות
            val firstCheckDone = prefs.getBoolean(KEY_FIRST_CHECK_DONE, false)
            
            if (!firstCheckDone) {
                // ✅ בדיקה ראשונית - בעוד 10 שניות (פעם אחת)
                Log.d("LocationServiceWorker", "📍 Scheduling first check in 10 seconds (one time)")
                scheduleFirstCheck(applicationContext)
                // סימון שהבדיקה הראשונה בוצעה
                prefs.edit().putBoolean(KEY_FIRST_CHECK_DONE, true).apply()
            } else {
                // ✅ בדיקה יומית - כל 24 שעות
                Log.d("LocationServiceWorker", "📍 Scheduling daily check in 24 hours")
                scheduleDailyCheck(applicationContext)
            }
            
            return Result.success()
        } catch (e: Exception) {
            Log.e("LocationServiceWorker", "Error checking location service: ${e.message}")
            // ✅ גם במקרה של שגיאה, נמשיך לבדוק בהתאם ללוגיקה (10 שניות אם ראשון, 24 שעות אחרת)
            val prefs = applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val firstCheckDone = prefs.getBoolean(KEY_FIRST_CHECK_DONE, false)
            
            if (!firstCheckDone) {
                scheduleFirstCheck(applicationContext)
                prefs.edit().putBoolean(KEY_FIRST_CHECK_DONE, true).apply()
            } else {
                scheduleDailyCheck(applicationContext)
            }
            return Result.retry()
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
                Log.d("LocationServiceWorker", "Firebase already initialized or error: ${e.message}")
            }
            
            // קבלת userId מ-SharedPreferences
            val userId = flutterPrefs.getString("flutter.current_user_id", null)
            
            if (userId.isNullOrEmpty()) {
                Log.d("LocationServiceWorker", "📍 No user ID found in SharedPreferences - cannot send FCM notification")
                return
            }
            
            Log.d("LocationServiceWorker", "📍 Sending FCM notification for user: $userId")
            
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
                    Log.d("LocationServiceWorker", "✅ FCM notification queued successfully: ${documentReference.id}")
                }
                .addOnFailureListener { e ->
                    Log.e("LocationServiceWorker", "❌ Error queuing FCM notification: ${e.message}")
                }
        } catch (e: Exception) {
            Log.e("LocationServiceWorker", "❌ Error sending FCM notification: ${e.message}")
        }
    }
    
    private fun createNotificationChannel(context: Context) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                CHANNEL_ID,
                "Location Service Notifications",
                android.app.NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for location service status"
            }
            
            val notificationManager = context.getSystemService(android.app.NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    companion object {
        private const val CHANNEL_ID = "location_service_channel"
        private const val WORK_NAME = "location_service_check"
        private const val PREFS_NAME = "location_service_prefs"
        private const val KEY_NOTIFICATION_SENT = "notification_sent"
        private const val KEY_LAST_CHECK_WHEN_CLOSED = "last_check_when_closed" // תאריך הבדיקה האחרונה כאשר האפליקציה סגורה לחלוטין
        private const val KEY_FIRST_CHECK_DONE = "first_check_done" // האם הבדיקה הראשונה (אחרי 10 שניות) כבר בוצעה
        
        fun schedulePeriodicCheck(context: Context) {
            // ✅ בדיקה ראשונית מיידית (0 שניות) כדי לזהות שינויים מיידיים
            val immediateWorkRequest = OneTimeWorkRequestBuilder<LocationServiceWorker>()
                .setInitialDelay(0, TimeUnit.SECONDS)
                .addTag("location_service_check")
                .setConstraints(
                    androidx.work.Constraints.Builder()
                        .setRequiredNetworkType(androidx.work.NetworkType.NOT_REQUIRED)
                        .build()
                )
                .build()
            
            WorkManager.getInstance(context).enqueueUniqueWork(
                WORK_NAME,
                androidx.work.ExistingWorkPolicy.REPLACE,
                immediateWorkRequest
            )
            
            Log.d("LocationServiceWorker", "Scheduled immediate location service check")
            
            // ✅ איפוס סטטוס הבדיקה הראשונית כאשר האפליקציה נפתחת
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_FIRST_CHECK_DONE, false).apply()
            
            // ✅ תזמון בדיקה ראשונית בעוד 10 שניות (כשהאפליקציה נסגרת)
            scheduleFirstCheck(context)
        }
        
        // ✅ תזמון בדיקה ראשונית בעוד 10 שניות (פעם אחת) - כשהאפליקציה נסגרת
        // זה עובד גם כשהאפליקציה סגורה לחלוטין
        fun scheduleFirstCheck(context: Context) {
            val firstCheckRequest = OneTimeWorkRequestBuilder<LocationServiceWorker>()
                .setInitialDelay(10, TimeUnit.SECONDS) // 10 שניות
                .addTag("location_service_check_first")
                .setConstraints(
                    androidx.work.Constraints.Builder()
                        .setRequiredNetworkType(androidx.work.NetworkType.NOT_REQUIRED)
                        .build()
                )
                .build()
            
            WorkManager.getInstance(context).enqueueUniqueWork(
                "${WORK_NAME}_first",
                androidx.work.ExistingWorkPolicy.REPLACE,
                firstCheckRequest
            )
            
            Log.d("LocationServiceWorker", "Scheduled first location service check in 10 seconds (one time, when app is closed)")
        }
        
        // ✅ תזמון בדיקה יומית פעם ב-24 שעות כאשר האפליקציה סגורה לחלוטין
        // זה מבטיח שה-WorkManager ימשיך לבדוק פעם ב-24 שעות גם כאשר האפליקציה סגורה לחלוטין
        fun scheduleDailyCheck(context: Context) {
            val dailyCheckRequest = OneTimeWorkRequestBuilder<LocationServiceWorker>()
                .setInitialDelay(24, TimeUnit.HOURS)
                .addTag("location_service_check_daily")
                .setConstraints(
                    androidx.work.Constraints.Builder()
                        .setRequiredNetworkType(androidx.work.NetworkType.NOT_REQUIRED)
                        .build()
                )
                .build()
            
            WorkManager.getInstance(context).enqueueUniqueWork(
                "${WORK_NAME}_daily",
                androidx.work.ExistingWorkPolicy.REPLACE,
                dailyCheckRequest
            )
            
            Log.d("LocationServiceWorker", "Scheduled daily location service check every 24 hours (when app is closed)")
        }
    }
}

