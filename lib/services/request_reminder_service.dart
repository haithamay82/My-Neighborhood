import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class RequestReminderService {
  /// בדיקה יומית של בקשות ללא עוזרים במשך יותר משבוע
  static Future<void> checkAndSendReminderNotifications() async {
    try {
      debugPrint('🔍 ===== REQUEST REMINDER SERVICE START =====');
      debugPrint('🔍 Service called at: ${DateTime.now()}');
      debugPrint('🔍 Checking for requests WITHOUT helpers for more than a week...');
      
      // תאריך לפני שבוע
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      debugPrint('🔍 Looking for requests without helpers since: $oneWeekAgo');
      
      // מציאת בקשות פתוחות (נבדוק helpersCount בקוד)
      final requestsQuery = await FirebaseFirestore.instance
          .collection('requests')
          .where('status', isEqualTo: 'open')
          .get();

      debugPrint('📊 Found ${requestsQuery.docs.length} open requests total');
      
      if (requestsQuery.docs.isEmpty) {
        debugPrint('❌ No open requests found in Firestore');
        return;
      }
      
      debugPrint('🔍 Checking each request individually...');
      
      // בדיקת כל בקשה בנפרד
      for (final doc in requestsQuery.docs) {
        final data = doc.data();
        final requestId = doc.id;
        final helpersCount = data['helpersCount'] as int? ?? 0;
        final status = data['status'] as String?;
        final title = data['title'] as String? ?? 'Unknown';
        final creatorId = data['createdBy'] as String?;
        
        debugPrint('📋 Checking request: $title');
        debugPrint('   - ID: $requestId');
        debugPrint('   - Status: $status');
        debugPrint('   - Helpers Count: $helpersCount');
        debugPrint('   - Creator ID: $creatorId');
        
        // בדיקה אם הבקשה עומדת בתנאים - צריך שיהיה WITHOUT helpers
        if (status != 'open' || helpersCount != 0 || creatorId == null) {
          debugPrint('❌ Request $requestId does not meet criteria - skipping');
          debugPrint('   - Status: $status (needs: open)');
          debugPrint('   - Helpers Count: $helpersCount (needs: == 0)');
          debugPrint('   - Creator ID: $creatorId (needs: not null)');
          continue;
        }
        
        debugPrint('✅ Request $requestId meets criteria - checking reminder logic');
        
        // בדיקה אם הבקשה קיימת יותר משבוע
        final shouldSendReminder = await _shouldSendReminderForRequest(requestId, oneWeekAgo);
        if (!shouldSendReminder) {
          debugPrint('⏰ Request $requestId was created less than a week ago - skipping');
          continue;
        }

        // בדיקה אם נשלחה תזכורת בשבוע האחרון
        debugPrint('🔍 Checking if reminder sent in last week for request $requestId to creator $creatorId');
        final lastReminderTime = await _getLastReminderTime(requestId, creatorId);
        if (lastReminderTime != null) {
          final timeSinceLastReminder = DateTime.now().difference(lastReminderTime);
          if (timeSinceLastReminder < const Duration(days: 7)) {
            debugPrint('📝 Reminder sent recently for request $requestId (${timeSinceLastReminder.inDays} days ago) - SKIPPING');
            continue;
          }
        }
        debugPrint('✅ No recent reminder found for request $requestId - PROCEEDING');

        // שליחת התראה ליוצר הבקשה
        await _sendRequestReminderNotification(
          creatorId: creatorId,
          requestId: requestId,
          requestTitle: title,
        );

        debugPrint('✅ Reminder notification sent for request: $title');
      }

      debugPrint('🎯 Request reminder check completed');
    } catch (e) {
      debugPrint('❌ Error checking request reminders: $e');
    }
  }

  /// בדיקה אם צריך לשלוח תזכורת עבור בקשה ספציפית
  static Future<bool> _shouldSendReminderForRequest(String requestId, DateTime cutoffTime) async {
    try {
      // בדיקה אם הבקשה קיימת יותר משבוע ללא עוזרים
      
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        debugPrint('❌ Request $requestId not found');
        return false;
      }
      
      final data = requestDoc.data()!;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final helpersCount = data['helpersCount'] as int? ?? 0;
      
      if (helpersCount > 0) {
        debugPrint('📝 Request $requestId has helpers now - no reminder needed');
        return false;
      }
      
      // בדיקה אם עבר שבוע מאז יצירת הבקשה
      if (createdAt == null) {
        debugPrint('❌ Request $requestId has no creation date');
        return false;
      }
      
      final timeSinceCreation = DateTime.now().difference(createdAt);
      final shouldSend = timeSinceCreation > const Duration(days: 7);
      debugPrint('⏰ Request $requestId: created $createdAt, duration: $timeSinceCreation, should send: $shouldSend');
      return shouldSend;
    } catch (e) {
      debugPrint('❌ Error checking reminder timing for request $requestId: $e');
      return false;
    }
  }

  /// קבלת זמן התזכורת האחרונה שנשלחה עבור בקשה
  static Future<DateTime?> _getLastReminderTime(String requestId, String creatorId) async {
    try {
      debugPrint('🔍 Searching for last reminder time for request $requestId to user $creatorId');
      
      final notificationQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: creatorId)
          .where('type', isEqualTo: 'request_reminder')
          .where('data.requestId', isEqualTo: requestId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (notificationQuery.docs.isNotEmpty) {
        final lastNotification = notificationQuery.docs.first;
        final data = lastNotification.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        debugPrint('📅 Last reminder sent at: $createdAt');
        return createdAt;
      } else {
        debugPrint('📅 No previous reminders found');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting last reminder time: $e');
      return null;
    }
  }

  /// בדיקה אם כבר נשלחה התראה עבור בקשה זו
  static Future<bool> _hasReminderBeenSent(String requestId, String creatorId) async {
    try {
      debugPrint('🔍 Searching for existing notifications for request $requestId to user $creatorId');
      
      final notificationQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: creatorId)
          .where('type', isEqualTo: 'request_reminder')
          .where('data.requestId', isEqualTo: requestId)
          .get();

      debugPrint('🔍 Found ${notificationQuery.docs.length} existing reminder notifications');
      
      if (notificationQuery.docs.isNotEmpty) {
        for (final doc in notificationQuery.docs) {
          final data = doc.data();
          debugPrint('📋 Existing notification: ${data['title']} - ${data['message']}');
        }
      }

      return notificationQuery.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking if reminder was sent: $e');
      return false;
    }
  }

  /// שליחת התראה ליוצר הבקשה
  static Future<void> _sendRequestReminderNotification({
    required String creatorId,
    required String requestId,
    required String requestTitle,
  }) async {
    try {
      debugPrint('📤 ===== SENDING REMINDER NOTIFICATION =====');
      debugPrint('📤 To: $creatorId');
      debugPrint('📤 Request: $requestTitle ($requestId)');
      
      const title = 'תזכורת: בקשה ללא עוזרים 🔔';
      final message = 'הבקשה "$requestTitle" עדיין ללא עוזרים. האם תרצה לסגור אותה או לעדכן?';

      debugPrint('📤 Title: $title');
      debugPrint('📤 Message: $message');

      await NotificationService.sendNotification(
        toUserId: creatorId,
        title: title,
        message: message,
        type: 'request_reminder',
        data: {
          'requestId': requestId,
          'requestTitle': requestTitle,
          'reminderType': 'no_helpers_week_reminder',
        },
      );

      debugPrint('✅ Reminder notification sent successfully to creator: $creatorId');
    } catch (e) {
      debugPrint('❌ Error sending reminder notification: $e');
    }
  }

  /// בדיקה ידנית של בקשה ספציפית (לצורך בדיקות)
  static Future<void> checkSpecificRequest(String requestId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        debugPrint('❌ Request $requestId not found');
        return;
      }

      final requestData = requestDoc.data()!;
      final status = requestData['status'] as String?;
      final helpersCount = requestData['helpersCount'] as int? ?? 0;
      final createdAt = (requestData['createdAt'] as Timestamp?)?.toDate();
      final creatorId = requestData['createdBy'] as String?;
      final requestTitle = requestData['title'] as String? ?? 'הבקשה';

      if (status != 'open') {
        debugPrint('📝 Request $requestId is not open (status: $status)');
        return;
      }

      if (helpersCount != 0) {
        debugPrint('📝 Request $requestId already has helpers');
        return;
      }

      if (creatorId == null) {
        debugPrint('⚠️ Request $requestId has no creator ID');
        return;
      }

      if (createdAt == null) {
        debugPrint('⚠️ Request $requestId has no creation date');
        return;
      }

      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
      if (createdAt.isAfter(oneMinuteAgo)) {
        debugPrint('📝 Request $requestId was created less than a minute ago');
        return;
      }

      // בדיקה אם כבר נשלחה התראה
      final alreadyNotified = await _hasReminderBeenSent(requestId, creatorId);
      if (alreadyNotified) {
        debugPrint('📝 Reminder already sent for request $requestId');
        return;
      }

      // שליחת התראה
      await _sendRequestReminderNotification(
        creatorId: creatorId,
        requestId: requestId,
        requestTitle: requestTitle,
      );

      debugPrint('✅ Manual reminder check completed for request: $requestTitle');
    } catch (e) {
      debugPrint('❌ Error checking specific request: $e');
    }
  }
}