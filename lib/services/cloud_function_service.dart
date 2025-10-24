import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CloudFunctionService {
  static Future<void> sendPushNotification({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get the FCM token of the target user
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(toUserId)
          .get();

      if (!userDoc.exists) {
        debugPrint('User document not found for: $toUserId');
        return;
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        debugPrint('No FCM token found for user: $toUserId');
        return;
      }

      // Create a notification document that will be processed
      await FirebaseFirestore.instance.collection('notification_queue').add({
        'to': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
        'userId': toUserId,
      });

      debugPrint('Push notification queued for user: $toUserId');
    } catch (e) {
      debugPrint('Error queuing push notification: $e');
    }
  }

  static Future<void> sendHelpOfferNotification({
    required String requestCreatorId,
    required String helperName,
    required String requestTitle,
  }) async {
    await sendPushNotification(
      toUserId: requestCreatorId,
      title: 'הצעת עזרה חדשה!',
      body: '$helperName הציע/ה עזרה לבקשה: "$requestTitle"',
      data: {
        'type': 'help_offer',
        'helperName': helperName,
        'requestTitle': requestTitle,
      },
    );
  }

  static Future<void> sendChatMessageNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String requestTitle,
  }) async {
    await sendPushNotification(
      toUserId: recipientId,
      title: 'הודעה חדשה בצ\'אט עבור "$requestTitle"',
      body: '$senderName: $message',
      data: {
        'type': 'chat_message',
        'senderName': senderName,
        'message': message,
        'requestTitle': requestTitle,
      },
    );
  }
}
