import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Messaging Background Handler
/// פונקציה זו נקראת כשהאפליקציה סגורה לחלוטין
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  debugPrint('🔔 Background message data: ${message.data}');
  debugPrint('🔔 Background message notification: ${message.notification?.title}');
  
  // כאן ניתן להוסיף לוגיקה לטיפול בהודעות ברקע
  // למשל שמירה ב-local storage או שליחה לשרת
  
  // הצגת התראה מקומית (אם האפליקציה לא פעילה)
  if (message.notification != null) {
    debugPrint('🔔 Background notification: ${message.notification!.title}');
    debugPrint('🔔 Background notification body: ${message.notification!.body}');
  }
}
