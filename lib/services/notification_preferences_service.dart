import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_preferences.dart';

class NotificationPreferencesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// שמירת העדפות התראות למשתמש
  static Future<void> saveNotificationPreferences(NotificationPreferences preferences) async {
    try {
      await _firestore
          .collection('notification_preferences')
          .doc(preferences.userId)
          .set(preferences.toMap());
      
      debugPrint('✅ Notification preferences saved for user: ${preferences.userId}');
    } catch (e) {
      debugPrint('❌ Error saving notification preferences: $e');
      throw Exception('שגיאה בשמירת העדפות ההתראות');
    }
  }

  /// קבלת העדפות התראות של משתמש
  static Future<NotificationPreferences?> getNotificationPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('notification_preferences')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return NotificationPreferences.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting notification preferences: $e');
      return null;
    }
  }

  /// קבלת העדפות התראות עם ברירת מחדל אם לא קיימות
  static Future<NotificationPreferences> getNotificationPreferencesWithDefaults(String userId) async {
    final existing = await getNotificationPreferences(userId);
    
    if (existing != null) {
      return existing;
    }
    
    // יצירת העדפות ברירת מחדל
    final defaults = NotificationPreferences(userId: userId);
    await saveNotificationPreferences(defaults);
    
    return defaults;
  }

  /// עדכון העדפת תראה ספציפית
  static Future<void> updateNotificationPreference({
    required String userId,
    required String preferenceKey,
    required bool value,
  }) async {
    try {
      await _firestore
          .collection('notification_preferences')
          .doc(userId)
          .update({
        preferenceKey: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Notification preference updated: $preferenceKey = $value');
    } catch (e) {
      debugPrint('❌ Error updating notification preference: $e');
      throw Exception('שגיאה בעדכון העדפת ההתראה');
    }
  }
}


