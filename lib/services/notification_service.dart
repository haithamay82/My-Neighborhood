import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/notification.dart';
import 'app_state_service.dart';
import 'notification_navigation_service.dart';
import 'push_notification_service.dart';
import 'direct_fcm_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// אתחול שירות ההתראות
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    _initialized = true;
  }

  /// מטפל בלחיצה על התראה
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('🔔 Notification tapped with payload: $payload');
    
    if (payload != null) {
      _handleNotificationNavigation(payload);
    }
  }

  /// ניווט לפי סוג התראה
  static void _handleNotificationNavigation(String payload) {
    debugPrint('🔔 Handling notification navigation for: $payload');
    
    // קבלת context מהמסך הנוכחי
    final context = AppStateService.currentContext;
    if (context != null) {
      NotificationNavigationService.navigateFromNotification(
        context,
        payload,
      );
    } else {
      debugPrint('❌ No context available for notification navigation');
    }
  }

  /// בקשת הרשאות התראות
  static Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// שליחת התראה מקומית
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'subscription_channel',
      'Subscription Notifications',
      channelDescription: 'Notifications for subscription updates',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// עדכון פרופיל משתמש אוטומטי
  static Future<void> updateUserProfileOnNotification({
    required String userId,
    required String userType,
    required String subscriptionStatus,
    required List<String> businessCategories,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'userType': userType,
        'subscriptionStatus': subscriptionStatus,
        'businessCategories': businessCategories,
        'isSubscriptionActive': subscriptionStatus == 'active',
        'subscriptionExpiry': subscriptionStatus == 'active' 
            ? DateTime.now().add(const Duration(days: 365))
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('User profile updated successfully for user: $userId');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
  }

  /// האזנה להתראות מנוי
  static void listenToSubscriptionNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('subscription_notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        _handleSubscriptionNotification(data, doc.id);
      }
    });
  }

  /// טיפול בהתראה
  static Future<void> _handleSubscriptionNotification(
    Map<String, dynamic> data,
    String notificationId,
  ) async {
    try {
      // הצגת התראה
      await showLocalNotification(
        title: data['title'] ?? 'עדכון מנוי',
        body: data['message'] ?? 'המנוי שלך עודכן',
        payload: 'subscription_update',
      );

      // עדכון הפרופיל
      await updateUserProfileOnNotification(
        userId: data['userId'],
        userType: data['userType'] ?? 'business',
        subscriptionStatus: data['subscriptionStatus'] ?? 'active',
        businessCategories: List<String>.from(data['businessCategories'] ?? ['all']),
      );

      // סימון ההתראה כנקראה
      await FirebaseFirestore.instance
          .collection('subscription_notifications')
          .doc(notificationId)
          .update({'read': true});

      debugPrint('Subscription notification handled successfully');
    } catch (e) {
      debugPrint('Error handling subscription notification: $e');
    }
  }

  /// שליחת התראה למשתמש
  static Future<void> sendSubscriptionNotification({
    required String userId,
    required String title,
    required String message,
    required String userType,
    required String subscriptionStatus,
    required List<String> businessCategories,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('subscription_notifications')
          .add({
        'userId': userId,
        'title': title,
        'message': message,
        'userType': userType,
        'subscriptionStatus': subscriptionStatus,
        'businessCategories': businessCategories,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Subscription notification sent to user: $userId');
    } catch (e) {
      debugPrint('Error sending subscription notification: $e');
    }
  }

  /// שליחת התראה על הצעת עזרה
  static Future<void> notifyHelpOffered({
    required String requestCreatorId,
    required String helperName,
    required String requestTitle,
  }) async {
    try {
      // שליחת push notification
      await PushNotificationService.sendPushNotification(
        userId: requestCreatorId,
        title: 'מישהו רוצה לעזור! 🤝',
        body: '$helperName רוצה לעזור עם "$requestTitle"',
        payload: 'help_offered',
      );

      // שמירת התראה ב-Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'toUserId': requestCreatorId,
        'message': '$helperName רוצה לעזור עם "$requestTitle"',
        'type': 'help_offered',
        'requestTitle': requestTitle,
        'helperName': helperName,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      debugPrint('Help offer notification sent to user: $requestCreatorId');
    } catch (e) {
      debugPrint('Error sending help offer notification: $e');
    }
  }

  /// שליחת התראה על אישור/דחיית מנוי
  static Future<void> sendSubscriptionApprovalNotification({
    required String userId,
    required bool approved,
    required String userName,
    String? rejectionReason,
    String? subscriptionType, // business או personal
    String? paymentMethod, // cash, payme, etc.
  }) async {
    debugPrint('🔔 sendSubscriptionApprovalNotification called: userId=$userId, approved=$approved, userName=$userName, rejectionReason=$rejectionReason, subscriptionType=$subscriptionType, paymentMethod=$paymentMethod');
    try {
      // קביעת סוג המנוי - קודם מהפרמטר, אחר כך מבקשת התשלום, אחר כך מהפרופיל
      String requestedType = 'personal';
      
      // אם סופק subscriptionType בפרמטר - השתמש בו
      if (subscriptionType != null) {
        requestedType = subscriptionType.toLowerCase();
        debugPrint('🎯 Using provided subscriptionType: $requestedType');
      } else {
        try {
          // קודם מנסה מתוך בקשת התשלום האחרונה
          final paymentQuery = await FirebaseFirestore.instance
              .collection('payment_requests')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          
          if (paymentQuery.docs.isNotEmpty) {
            final paymentData = paymentQuery.docs.first.data();
            final subType = (paymentData['subscriptionType'] as String?)?.toLowerCase();
            debugPrint('🔍 Found payment request with subscriptionType: $subType');
            
            if (subType == 'business') {
              requestedType = 'business';
            } else {
              requestedType = 'personal';
            }
          } else {
            // גיבוי: מתוך פרופיל המשתמש
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final data = userDoc.data()!;
              final req = (data['requestedSubscriptionType'] as String?)?.toLowerCase();
              final currentUserType = (data['userType'] as String?)?.toLowerCase();
              debugPrint('🔍 Found user requestedSubscriptionType: $req, currentUserType: $currentUserType');
              
              if (req == 'business') {
                requestedType = 'business';
              } else if (req == 'personal') {
                requestedType = 'personal';
              } else {
                // אם אין requestedSubscriptionType, נבדוק את ה-userType הנוכחי
                if (currentUserType == 'business') {
                  requestedType = 'business';
                } else {
                  requestedType = 'personal'; // ברירת מחדל לפרטי מנוי
                }
              }
            }
          }
          
          debugPrint('🎯 Final requestedType determined: $requestedType');
        } catch (e) {
          debugPrint('⚠️ Failed determining requested subscription type, defaulting to personal: $e');
        }
      }

      final isBusiness = requestedType == 'business';
      final isCashPayment = paymentMethod == 'cash';
      final subscriptionTypeName = isBusiness ? 'עסקי' : 'פרטי';
      final paymentMethodText = isCashPayment ? 'תמורת תשלום במזומן' : '';
      
      final title = approved ? 'מנוי אושר! ✅' : 'מנוי נדחה ❌';
      final message = approved
          ? (isBusiness
              ? 'המנוי העסקי שלך אושר בהצלחה. כעת תוכל לראות בקשות בתשלום.'
              : 'המנוי הפרטי שלך אושר בהצלחה.')
          : rejectionReason != null && rejectionReason.isNotEmpty
              ? (paymentMethodText.isNotEmpty
                  ? 'בקשתך למנוי $subscriptionTypeName $paymentMethodText נדחתה.\nסיבת הדחייה: $rejectionReason'
                  : 'בקשתך למנוי $subscriptionTypeName נדחתה.\nסיבת הדחייה: $rejectionReason')
              : (paymentMethodText.isNotEmpty
                  ? 'בקשתך למנוי $subscriptionTypeName $paymentMethodText נדחתה. אנא פנה לתמיכה לפרטים נוספים.'
                  : 'בקשתך למנוי $subscriptionTypeName נדחתה. אנא פנה לתמיכה לפרטים נוספים.');

      final notification = AppNotification(
        notificationId: '',
        toUserId: userId,
        title: title,
        message: message,
        type: approved ? NotificationType.subscriptionApproved : NotificationType.subscriptionRejected,
        data: {
          'userName': userName,
          'approved': approved,
          if (rejectionReason != null) 'rejectionReason': rejectionReason,
          if (paymentMethod != null) 'paymentMethod': paymentMethod,
        },
        createdAt: DateTime.now(),
        read: false, // וידוא שההתראה מסומנת כלא נקראה
      );

      // שמירה ב-Firestore
      final notificationData = notification.toFirestore();
      debugPrint('📝 Saving notification to Firestore: $notificationData');
      
      final notificationRef = await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);
      
      debugPrint('✅ Notification saved to Firestore with ID: ${notificationRef.id}');
      debugPrint('📧 Notification details: title="$title", message="$message", userId=$userId, approved=$approved');

      // שליחת push notification
      try {
        await PushNotificationService.sendPushNotification(
          userId: userId,
          title: title,
          body: message,
          payload: approved ? 'subscription_approved' : 'subscription_rejected',
          data: {
            'type': approved ? 'subscription_approved' : 'subscription_rejected',
            'screen': 'profile',
            if (rejectionReason != null) 'rejectionReason': rejectionReason,
            if (subscriptionType != null) 'subscriptionType': subscriptionType,
            if (paymentMethod != null) 'paymentMethod': paymentMethod,
          },
        );
        debugPrint('✅ Push notification queued for user: $userId');
      } catch (pushError) {
        debugPrint('⚠️ Error sending push notification (notification still saved): $pushError');
        // המשך גם אם push notification נכשל - ההתראה נשמרה ב-Firestore
      }

      debugPrint('✅ Subscription notification sent to user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending subscription notification: $e');
      // לא זורקים שגיאה - ההתראה יכולה להישמר גם אם push notification נכשל
    }
  }

  /// שליחת התראה על הודעה בצ'אט (רק אם המשתמש לא בתוך הצ'אט)
  static Future<void> sendChatNotification({
    required String toUserId,
    required String fromUserName,
    required String requestTitle,
    required String chatId,
    required String messageText,
  }) async {
    try {
      // בדיקה אם המשתמש נמצא בתוך הצ'אט הזה
      if (AppStateService.isInChat(chatId)) {
        debugPrint('User is in chat $chatId - not sending notification');
        return;
      }

      final title = 'הודעה חדשה בצ\'אט 💬';
      final message = '$fromUserName: $messageText';

      final notification = AppNotification(
        notificationId: '',
        toUserId: toUserId,
        title: title,
        message: message,
        type: NotificationType.chatMessage,
        data: {
          'chatId': chatId,
          'fromUserName': fromUserName,
          'requestTitle': requestTitle,
          'messageText': messageText,
        },
        createdAt: DateTime.now(),
      );

      // שמירה ב-Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notification.toFirestore());

      // שליחת push notification
      await PushNotificationService.sendPushNotification(
        userId: toUserId,
        title: title,
        body: message,
        payload: 'chat_message',
        data: {'chatId': chatId},
      );

      debugPrint('Chat notification sent to user: $toUserId');
    } catch (e) {
      debugPrint('Error sending chat notification: $e');
    }
  }

  /// שליחת התראה על בקשה חדשה בתחום
  static Future<void> sendNewRequestNotification({
    required String toUserId,
    required String requestTitle,
    required String requestCategory,
    required String requestId,
    required String creatorName,
    double? distanceKm,
    String? distanceSourceHeb, // 'מהמיקום הנייד' | 'מהמיקום הקבוע' | 'מהמיקום שלך'
  }) async {
    try {
      final title = 'בקשה חדשה בתחום שלך! 🆕';
      final String distanceLine = (distanceKm != null)
          ? '\nמרחק: ${distanceKm.toStringAsFixed(1)} ק"מ ${distanceSourceHeb ?? 'מהמיקום שלך'}'
          : '';
      final message = '$creatorName פרסם בקשה חדשה ב$requestCategory: "$requestTitle"$distanceLine';

      final notification = AppNotification(
        notificationId: '',
        toUserId: toUserId,
        title: title,
        message: message,
        type: NotificationType.newRequest,
        data: {
          'requestId': requestId,
          'requestTitle': requestTitle,
          'requestCategory': requestCategory,
          'creatorName': creatorName,
          if (distanceKm != null) 'distanceKm': distanceKm,
          if (distanceSourceHeb != null) 'distanceSource': distanceSourceHeb,
        },
        createdAt: DateTime.now(),
      );

      // שמירה ב-Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notification.toFirestore());

      // שליחת push notification
      await DirectFCMService.sendDirectNotification(
        userId: toUserId,
        title: title,
        body: message,
        payload: 'new_request',
        data: {
          'requestId': requestId,
          'requestTitle': requestTitle,
          'requestCategory': requestCategory,
          'creatorName': creatorName,
          if (distanceKm != null) 'distanceKm': distanceKm,
          if (distanceSourceHeb != null) 'distanceSource': distanceSourceHeb,
        },
      );

      debugPrint('New request notification sent to user: $toUserId');
    } catch (e) {
      debugPrint('Error sending new request notification: $e');
    }
  }

  /// קבלת רשימת התראות למשתמש
  static Stream<List<AppNotification>> getUserNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList();
          // מיון ב-client לפי תאריך (חדש לישן)
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  /// סימון התראה כנקראה
  static Future<void> markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      
      debugPrint('Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// סימון כל ההתראות כנקראות
  static Future<void> markAllAsRead(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      debugPrint('All notifications marked as read for user: $userId');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// ספירת התראות לא נקראות
  static Stream<int> getUnreadCount(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// שליחת התראה כללית
  static Future<void> sendNotification({
    required String toUserId,
    required String title,
    required String message,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    try {
      debugPrint('📤 Sending notification to $toUserId: $title');
      
      // שמירת ההתראה ב-Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': toUserId,
        'title': title,
        'message': message,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': data ?? {},
      });
      
      debugPrint('✅ Notification saved to Firestore');
      
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }
}