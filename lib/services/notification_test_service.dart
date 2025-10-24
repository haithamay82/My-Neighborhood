import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'push_notification_service.dart';

/// שירות לבדיקת התראות
class NotificationTestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// שליחת התראה בדיקה למשתמש הנוכחי
  static Future<void> sendTestNotification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      await PushNotificationService.sendPushNotification(
        userId: user.uid,
        title: 'בדיקת התראה 🧪',
        body: 'זוהי התראה לבדיקה - אם אתה רואה את זה, ההתראות עובדות!',
        payload: 'test_notification',
      );

      debugPrint('✅ Test notification sent to user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  /// שליחת התראה בדיקה למשתמש ספציפי
  static Future<void> sendTestNotificationToUser(String userId) async {
    try {
      await PushNotificationService.sendPushNotification(
        userId: userId,
        title: 'בדיקת התראה 🧪',
        body: 'זוהי התראה לבדיקה - אם אתה רואה את זה, ההתראות עובדות!',
        payload: 'test_notification',
      );

      debugPrint('✅ Test notification sent to user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
    }
  }

  /// בדיקת FCM token של משתמש
  static Future<String?> getUserFCMToken(String userId) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final fcmToken = userData['fcmToken'] as String?;
        debugPrint('🔑 FCM Token for user $userId: $fcmToken');
        return fcmToken;
      } else {
        debugPrint('❌ User not found: $userId');
        return null;
      }
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

      final users = usersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'displayName': data['displayName'] ?? 'Unknown',
          'fcmToken': data['fcmToken'],
          'lastTokenUpdate': data['lastTokenUpdate'],
        };
      }).toList();

      debugPrint('👥 Found ${users.length} users with FCM tokens');
      return users;
    } catch (e) {
      debugPrint('❌ Error getting users with FCM tokens: $e');
      return [];
    }
  }
}
