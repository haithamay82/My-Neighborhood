import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// שירות לשליחת התראות ישירות דרך FCM REST API
class DirectFCMService {

  /// שליחת התראה ישירה למשתמש
  static Future<void> sendDirectNotification({
    required String userId,
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('📱 Sending direct FCM notification to user: $userId');
      
      // קבלת FCM token של המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        debugPrint('❌ User not found: $userId');
        return;
      }
      
      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;
      
      if (fcmToken == null) {
        debugPrint('❌ No FCM token for user: $userId');
        return;
      }
      
      // שליחת התראה דרך Firestore (תפעיל את Cloud Function)
      await FirebaseFirestore.instance.collection('push_notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'payload': payload ?? '',
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });
      
      debugPrint('✅ Notification queued for sending');
      
    } catch (e) {
      debugPrint('❌ Error sending direct notification: $e');
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
      await sendDirectNotification(
        userId: requesterId,
        title: 'מישהו מעוניין לעזור! 🎉',
        body: 'מישהו מעוניין לעזור בבקשה: $requestTitle',
        payload: 'help_offered',
        data: {
          'requestId': requestId,
          'helperId': helperId,
        },
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
      await sendDirectNotification(
        userId: receiverId,
        title: 'הודעה חדשה 💬',
        body: message,
        payload: 'chat_message',
        data: {
          'chatId': chatId,
          'senderId': senderId,
        },
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
        await sendDirectNotification(
          userId: userId,
          title: 'בקשה חדשה! 📝',
          body: 'בקשה חדשה: $requestTitle',
          payload: 'new_request',
          data: {
            'requestId': requestId,
            'requesterId': requesterId,
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending new request notification: $e');
    }
  }
}
