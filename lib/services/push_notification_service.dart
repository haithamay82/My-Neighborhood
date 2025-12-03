import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'app_state_service.dart';
import 'notification_navigation_service.dart';
import 'tts_service.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static String? _lastProcessedMessageId;
  static DateTime? _lastProcessedMessageTime;

  /// אתחול שירות ההתראות
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔔 PushNotificationService already initialized, skipping...');
      return;
    }
    
    try {
      // הערה: בקשות הרשאות מועברות למסך התחברות בלבד
      // לא מבקשים הרשאות כאן כדי לא להציג דיאלוג במסך splash

      // קבלת token
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      
      if (token == null) {
        debugPrint('❌ FCM Token is null - notifications will not work');
        return;
      }
      
      debugPrint('✅ FCM Token received successfully');

      // האזנה להודעות ברקע (מוגדר ב-main.dart)
      // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // האזנה להודעות כשה-App פעיל
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // האזנה להודעות כשה-App נפתח מה-background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // האזנה להודעות כשה-App נפתח מה-terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // שמירת token למשתמש הנוכחי
      await _saveTokenToUser(token);

      _initialized = true;
      debugPrint('Push notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing push notification service: $e');
    }
  }

  /// בקשת הרשאות להתראות (ציבורי - נקרא ממסך התחברות)
  static Future<void> requestPermissions() async {
    // בקשת הרשאות Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      debugPrint('Android notification permission status: $status');
      
      if (status.isDenied) {
        debugPrint('❌ Android notification permission denied');
        return;
      }
    }

    // בקשת הרשאות iOS
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('FCM permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ FCM permission not authorized');
      return;
    }
    
    debugPrint('✅ All notification permissions granted');
  }

  /// טיפול בהודעות ברקע
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint('Handling background message: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
    debugPrint('Message notification: ${message.notification?.title}');
  }

  /// טיפול בהודעות כשה-App פעיל
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // מניעת עיבוד כפול של אותה הודעה
    // ננקה את ה-flag אחרי 5 שניות כדי לאפשר עיבוד מחדש אם צריך
    if (_lastProcessedMessageId == message.messageId) {
      if (_lastProcessedMessageTime != null) {
        final timeDiff = DateTime.now().difference(_lastProcessedMessageTime!);
        if (timeDiff.inSeconds < 5) {
          debugPrint('🔔 Message ${message.messageId} already processed ${timeDiff.inSeconds}s ago, skipping...');
          return;
        }
      }
    }
    _lastProcessedMessageId = message.messageId;
    _lastProcessedMessageTime = DateTime.now();
    
    debugPrint('🔔 Handling foreground message: ${message.messageId}');
    debugPrint('🔔 Message data: ${message.data}');
    debugPrint('🔔 Message notification title: ${message.notification?.title}');
    debugPrint('🔔 Message notification body: ${message.notification?.body}');
    
    // הצגת התראה מקומית (רק אם זה לא צ'אט)
    final messageType = message.data['type'];
    debugPrint('🔔 Message type: $messageType');
    
    if (messageType != 'chat_message') {
      await NotificationService.showLocalNotification(
        title: message.notification?.title ?? 'הודעה חדשה',
        body: message.notification?.body ?? '',
      );
      
      // אם זה התראה על הזמנה חדשה, נשמיע TTS
      debugPrint('🔊 Checking if order notification: messageType=$messageType');
      if (messageType == 'order_new' || messageType == 'order_delivery') {
        debugPrint('🔊 ✅ Order notification detected! Preparing TTS...');
        debugPrint('🔊 Message data: ${message.data}');
        
        // המתן קצת אחרי השמעת הצליל של ההתראה (יותר זמן כדי שהצליל יסתיים)
        debugPrint('🔊 Waiting 1 second before TTS...');
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // קבלת שם לפי סוג ההתראה:
        // - order_new: customerName (שם המזמין)
        // - order_delivery: providerName (שם העסק)
        String? nameToSpeak;
        if (messageType == 'order_new') {
          nameToSpeak = message.data['customerName'];
          debugPrint('🔊 Order new - customerName from data: $nameToSpeak');
        } else if (messageType == 'order_delivery') {
          nameToSpeak = message.data['providerName'];
          debugPrint('🔊 Order delivery - providerName from data: $nameToSpeak');
        }
        
        // אם אין שם, נשתמש בברירת מחדל
        final finalName = nameToSpeak ?? 'מזמין';
        debugPrint('🔊 Final name to speak: $finalName');
        debugPrint('🔊 ✅ NEW CODE: Separating text into two parts');
        
        // בדיקה אם עברית זמינה
        final isHebrewAvailable = await TtsService.isHebrewAvailable();
        debugPrint('🔊 Hebrew available: $isHebrewAvailable');
        
        // השמעת "הזמנה חדשה" בעברית או "NEW ORDER" באנגלית
        if (isHebrewAvailable) {
          debugPrint('🔊 ✅ NEW CODE: Speaking Hebrew text: "הזמנה חדשה"');
          await TtsService.speak('הזמנה חדשה');
        } else {
          debugPrint('🔊 ✅ NEW CODE: Speaking English text: "NEW ORDER"');
          // הגדרת שפה לאנגלית לפני speak
          await TtsService.speakWithLanguage('NEW ORDER', 'eng-default');
        }
        
        // המתן קצת בין שני הטקסטים
        await Future.delayed(const Duration(milliseconds: 300));
        
        // השמעת השם
        debugPrint('🔊 ✅ NEW CODE: Speaking name separately: "$finalName"');
        await TtsService.speak(finalName);
        debugPrint('🔊 ✅ NEW CODE: TtsService.speak() completed');
      } else {
        debugPrint('🔊 ❌ Not an order notification, skipping TTS');
      }
    } else {
      debugPrint('🔊 ❌ Chat message, skipping notification and TTS');
    }
  }

  /// טיפול בהודעות כשה-App נפתח
  static void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.messageId}');
    debugPrint('Message data: ${message.data}');
    
    // ניווט לפי payload
    final payload = message.data['payload'];
    final requestId = message.data['requestId'];
    final chatId = message.data['chatId'];
    final userId = message.data['userId'];
    final orderId = message.data['orderId'];
    
    if (payload != null) {
      final context = AppStateService.currentContext;
      if (context != null) {
        NotificationNavigationService.navigateFromNotification(
          context,
          payload,
          chatId: chatId,
          requestId: requestId,
          userId: userId,
          orderId: orderId,
        );
      }
    }
  }

  /// קבלת FCM token
  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// עדכון FCM token במשתמש
  static Future<void> updateUserToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        // שמירת ה-token במשתמש ב-Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM Token updated for user: ${user.uid}');
        }
      }
    } catch (e) {
      debugPrint('Error updating user token: $e');
    }
  }

  /// שמירת FCM token למשתמש
  static Future<void> _saveTokenToUser(String? token) async {
    if (token == null) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ No user logged in, FCM token not saved');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ FCM token saved for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// שליחת התראה Push למשתמש ספציפי
  static Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    String? payload,
    Map<String, String>? data,
  }) async {
    try {
      // קבלת FCM token של המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('User not found: $userId');
        return;
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null) {
        debugPrint('No FCM token for user: $userId');
        return;
      }

      // שליחת התראה דרך Cloud Function
      await FirebaseFirestore.instance
          .collection('push_notifications')
          .add({
        'userId': userId,
        'fcmToken': fcmToken,
        'title': title,
        'body': body,
        'payload': payload,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Push notification queued for user: $userId');
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  /// שליחת התראה Push לקבוצת משתמשים
  static Future<void> sendPushNotificationToGroup({
    required List<String> userIds,
    required String title,
    required String body,
    String? payload,
    Map<String, String>? data,
  }) async {
    try {
      for (final userId in userIds) {
        await sendPushNotification(
          userId: userId,
          title: title,
          body: body,
          payload: payload,
          data: data,
        );
      }
      debugPrint('Push notifications queued for ${userIds.length} users');
    } catch (e) {
      debugPrint('Error sending push notifications to group: $e');
    }
  }
}

/// פונקציה גלובלית לטיפול בהודעות ברקע
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService._firebaseMessagingBackgroundHandler(message);
}