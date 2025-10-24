import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/chat_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';

/// שירות לניווט לפי התראות
class NotificationNavigationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ניווט לפי סוג התראה
  static Future<void> navigateFromNotification(
    BuildContext context,
    String payload, {
    String? requestId,
    String? chatId,
    String? userId,
  }) async {
    debugPrint('🔔 Navigating from notification: $payload');
    
    try {
      switch (payload) {
        case 'new_request':
          await _navigateToHome(context);
          break;
          
        case 'chat_message':
          if (chatId != null) {
            await _navigateToChat(context, chatId);
          } else {
            await _navigateToHome(context);
          }
          break;
          
        case 'help_offered':
          if (requestId != null) {
            await _navigateToRequest(context, requestId);
          } else {
            await _navigateToHome(context);
          }
          break;
          
        case 'subscription_update':
        case 'subscription_approved':
          await _navigateToProfile(context);
          break;
          
        case 'new_notification':
          await _navigateToNotifications(context);
          break;
          
        default:
          await _navigateToHome(context);
      }
    } catch (e) {
      debugPrint('❌ Error navigating from notification: $e');
      // במקרה של שגיאה, נווט למסך הבית
      await _navigateToHome(context);
    }
  }

  /// ניווט למסך הבית
  static Future<void> _navigateToHome(BuildContext context) async {
    if (context.mounted) {
      // ניווט למסך הבית בלי למחוק את ה-MainScreen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => route.settings.name == '/main',
      );
    }
  }

  /// ניווט לצ'אט
  static Future<void> _navigateToChat(BuildContext context, String chatId) async {
    if (context.mounted) {
      // ניווט למסך הבית בלי למחוק את ה-MainScreen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => route.settings.name == '/main',
      );
      
      // המתן קצת ואז פתח את הצ'אט
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              requestTitle: 'בקשה',
            ),
          ),
        );
      }
    }
  }

  /// ניווט לבקשה ספציפית
  static Future<void> _navigateToRequest(BuildContext context, String requestId) async {
    if (context.mounted) {
      // ניווט למסך הבית בלי למחוק את ה-MainScreen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => route.settings.name == '/main',
      );
      
      // TODO: ניווט לבקשה ספציפית (אם יש מסך כזה)
      debugPrint('🔔 Navigating to request: $requestId');
    }
  }

  /// ניווט לפרופיל
  static Future<void> _navigateToProfile(BuildContext context) async {
    if (context.mounted) {
      // ניווט למסך הבית בלי למחוק את ה-MainScreen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => route.settings.name == '/main',
      );
      
      // המתן קצת ואז פתח את הפרופיל
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        );
      }
    }
  }

  /// ניווט להתראות
  static Future<void> _navigateToNotifications(BuildContext context) async {
    if (context.mounted) {
      // ניווט למסך הבית בלי למחוק את ה-MainScreen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => route.settings.name == '/main',
      );
      
      // המתן קצת ואז פתח את מסך ההתראות
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
          ),
        );
      }
    }
  }

  /// קבלת פרטי התראה לניווט
  static Future<Map<String, String?>> getNotificationData(String notificationId) async {
    try {
      final doc = await _firestore
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'requestId': data['requestId'] as String?,
          'chatId': data['chatId'] as String?,
          'userId': data['userId'] as String?,
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting notification data: $e');
    }
    
    return {};
  }
}
