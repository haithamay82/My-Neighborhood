import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// שירות למעקב אחר התראות שנשלחו למשתמשים כדי למנוע כפילויות
class NotificationTrackingService {
  static const String _notificationPrefix = 'notification_sent_';
  static const String _userNotificationPrefix = 'user_notification_sent_';
  
  /// בדיקה אם התראה כבר נשלחה למשתמש
  static Future<bool> hasNotificationBeenSent({
    required String userId,
    required String notificationType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_userNotificationPrefix${userId}_$notificationType';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return false;
    }
  }
  
  /// סימון שהתראה נשלחה למשתמש
  static Future<void> markNotificationAsSent({
    required String userId,
    required String notificationType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_userNotificationPrefix${userId}_$notificationType';
      await prefs.setBool(key, true);
      debugPrint('✅ Marked notification as sent: $notificationType for user: $userId');
    } catch (e) {
      debugPrint('Error marking notification as sent: $e');
    }
  }
  
  /// בדיקה אם התראה כללית כבר נשלחה (ללא קשר למשתמש ספציפי)
  static Future<bool> hasGlobalNotificationBeenSent(String notificationType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_notificationPrefix$notificationType';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('Error checking global notification status: $e');
      return false;
    }
  }
  
  /// סימון שהתראה כללית נשלחה
  static Future<void> markGlobalNotificationAsSent(String notificationType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_notificationPrefix$notificationType';
      await prefs.setBool(key, true);
      debugPrint('✅ Marked global notification as sent: $notificationType');
    } catch (e) {
      debugPrint('Error marking global notification as sent: $e');
    }
  }
  
  /// בדיקה אם התראה נשלחה למשתמש עם פרמטרים ספציפיים
  static Future<bool> hasNotificationWithParamsBeenSent({
    required String userId,
    required String notificationType,
    required Map<String, dynamic> params,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // יצירת מפתח ייחודי על בסיס הפרמטרים
      final paramsString = params.entries
          .map((e) => '${e.key}:${e.value}')
          .join('|');
      final key = '$_userNotificationPrefix${userId}_${notificationType}_$paramsString';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('Error checking notification with params status: $e');
      return false;
    }
  }
  
  /// סימון שהתראה עם פרמטרים ספציפיים נשלחה
  static Future<void> markNotificationWithParamsAsSent({
    required String userId,
    required String notificationType,
    required Map<String, dynamic> params,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paramsString = params.entries
          .map((e) => '${e.key}:${e.value}')
          .join('|');
      final key = '$_userNotificationPrefix${userId}_${notificationType}_$paramsString';
      await prefs.setBool(key, true);
      debugPrint('✅ Marked notification with params as sent: $notificationType for user: $userId');
    } catch (e) {
      debugPrint('Error marking notification with params as sent: $e');
    }
  }
  
  /// מחיקת כל המעקב אחר התראות (לצורך בדיקות)
  static Future<void> clearAllNotificationTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final notificationKeys = keys.where((key) => 
          key.startsWith(_notificationPrefix) || 
          key.startsWith(_userNotificationPrefix)
      ).toList();
      
      for (final key in notificationKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('✅ Cleared all notification tracking data');
    } catch (e) {
      debugPrint('Error clearing notification tracking: $e');
    }
  }
  
  /// מחיקת מעקב התראות למשתמש ספציפי
  static Future<void> clearUserNotificationTracking(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final userNotificationKeys = keys.where((key) => 
          key.startsWith('$_userNotificationPrefix${userId}_')
      ).toList();
      
      for (final key in userNotificationKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('✅ Cleared notification tracking for user: $userId');
    } catch (e) {
      debugPrint('Error clearing user notification tracking: $e');
    }
  }
  
  /// קבלת רשימת כל ההתראות שנשלחו למשתמש
  static Future<List<String>> getSentNotificationsForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final userNotificationKeys = keys.where((key) => 
          key.startsWith('$_userNotificationPrefix${userId}_')
      ).toList();
      
      return userNotificationKeys.map((key) => 
          key.replaceFirst('$_userNotificationPrefix${userId}_', '')
      ).toList();
    } catch (e) {
      debugPrint('Error getting sent notifications for user: $e');
      return [];
    }
  }
}

