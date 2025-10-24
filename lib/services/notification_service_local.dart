import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationServiceLocal {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // יצירת ערוץ התראות
    await _createNotificationChannel();
  }
  
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'neighborhood_channel',
      'שכונתי - התראות',
      description: 'התראות מהאפליקציה שכונתי',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
  
  static void _onNotificationTapped(NotificationResponse response) {
    // טיפול בלחיצה על התראה
    debugPrint('Notification tapped: ${response.payload}');
  }
  
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // בדיקת הרשאות לפני שליחת התראה
    final hasPermission = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    
    if (hasPermission != true) {
      debugPrint('Notifications are disabled');
      return;
    }
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'neighborhood_channel',
      'שכונתי - התראות',
      channelDescription: 'התראות מהאפליקציה שכונתי',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    
    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    
    debugPrint('Local notification sent: $title - $body');
  }
  
  static Future<void> showHelpNotification({
    required String requestTitle,
    required String helperName,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'מישהו רוצה לעזור! 🎉',
      body: '$helperName רוצה לעזור עם הבקשה: $requestTitle',
      payload: 'help_offered',
    );
  }
  
  static Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String requestTitle,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'הודעה חדשה מ-$senderName',
      body: 'בבקשה: $requestTitle\n$message',
      payload: 'new_message',
    );
  }
  
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
