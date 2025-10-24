import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// שירות פשוט לשליחת התראות
class SimpleNotificationService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// שליחת התראה למשתמש הנוכחי
  static Future<void> sendTestNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      await _sendNotificationToUser(
        userId: user.uid,
        title: 'בדיקת התראה 🧪',
        body: 'זוהי התראה לבדיקה - אם אתה רואה את זה, ההתראות עובדות!',
        payload: 'test_notification',
      );
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  /// שליחת התראה למשתמש ספציפי
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Error sending notification to user: $e');
    }
  }

  /// שליחת התראה דרך Cloud Function
  static Future<void> _sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      debugPrint('📱 Sending notification to user: $userId');
      
      final callable = _functions.httpsCallable('sendNotification');
      
      final result = await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'payload': payload ?? '',
      });
      
      debugPrint('✅ Notification sent successfully: ${result.data}');
    } catch (e) {
      debugPrint('❌ Error calling Cloud Function: $e');
      rethrow;
    }
  }

  /// שליחת התראה "אני מעוניין"
  static Future<void> sendInterestNotification({
    required String requestId,
    required String requestTitle,
    required String requesterId,
    required String helperId,
  }) async {
    try {
      await _sendNotificationToUser(
        userId: requesterId,
        title: 'מישהו מעוניין לעזור! 🎉',
        body: 'מישהו מעוניין לעזור בבקשה: $requestTitle',
        payload: 'help_offered',
      );
    } catch (e) {
      debugPrint('❌ Error sending interest notification: $e');
    }
  }

  /// שליחת התראה הודעת צ'אט
  static Future<void> sendChatNotification({
    required String chatId,
    required String message,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      await _sendNotificationToUser(
        userId: receiverId,
        title: 'הודעה חדשה 💬',
        body: message,
        payload: 'chat_message',
      );
    } catch (e) {
      debugPrint('❌ Error sending chat notification: $e');
    }
  }

  /// שליחת התראה בקשה חדשה
  static Future<void> sendNewRequestNotification({
    required String requestId,
    required String requestTitle,
    required String requesterId,
    required List<String> targetUserIds,
  }) async {
    try {
      for (final userId in targetUserIds) {
        await _sendNotificationToUser(
          userId: userId,
          title: 'בקשה חדשה! 📝',
          body: 'בקשה חדשה: $requestTitle',
          payload: 'new_request',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending new request notification: $e');
    }
  }
}
