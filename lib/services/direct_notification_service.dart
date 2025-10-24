import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// שירות לשליחת התראות ישירות דרך Firebase Admin SDK
class DirectNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// שליחת התראה ישירה למשתמש ספציפי
  static Future<void> sendDirectNotification({
    required String userId,
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('📱 Sending direct notification to user: $userId');
      
      // קבלת FCM token של המשתמש
      final userDoc = await _firestore.collection('users').doc(userId).get();
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
      
      debugPrint('✅ FCM token found for user: $userId');
      
      // יצירת התראה ב-Firestore (תפעיל את Cloud Function)
      final notificationData = {
        'userId': userId,
        'title': title,
        'body': body,
        'payload': payload ?? '',
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      };
      
      await _firestore.collection('push_notifications').add(notificationData);
      debugPrint('✅ Notification queued for sending');
      
    } catch (e) {
      debugPrint('❌ Error sending direct notification: $e');
    }
  }

  /// שליחת התראה לכל המשתמשים
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('📢 Sending broadcast notification');
      
      // קבלת כל המשתמשים עם FCM tokens
      final usersQuery = await _firestore
          .collection('users')
          .where('fcmToken', isNull: false)
          .get();
      
      debugPrint('👥 Found ${usersQuery.docs.length} users with FCM tokens');
      
      // שליחת התראה לכל משתמש
      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;
        
        if (fcmToken != null) {
          final notificationData = {
            'userId': userId,
            'title': title,
            'body': body,
            'payload': payload ?? '',
            'data': data ?? {},
            'createdAt': FieldValue.serverTimestamp(),
            'sent': false,
          };
          
          await _firestore.collection('push_notifications').add(notificationData);
        }
      }
      
      debugPrint('✅ Broadcast notification queued for all users');
      
    } catch (e) {
      debugPrint('❌ Error sending broadcast notification: $e');
    }
  }

  /// בדיקת FCM token של משתמש
  static Future<String?> getUserFCMToken(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['fcmToken'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// רשימת כל המשתמשים עם FCM tokens
  static Future<List<Map<String, dynamic>>> getUsersWithFCMTokens() async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('fcmToken', isNull: false)
          .get();

      return usersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'displayName': data['displayName'] ?? 'Unknown',
          'fcmToken': data['fcmToken'],
          'lastTokenUpdate': data['lastTokenUpdate'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting users with FCM tokens: $e');
      return [];
    }
  }
}
