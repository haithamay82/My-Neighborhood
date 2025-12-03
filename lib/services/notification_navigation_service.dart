import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/chat_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/order_management_screen.dart';
import 'app_state_service.dart';

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
    String? orderId,
  }) async {
    debugPrint('🔔 Navigating from notification: $payload');
    
    try {
      switch (payload) {
        case 'new_request':
          if (requestId != null) {
            await _navigateToRequest(context, requestId);
          } else {
          await _navigateToHome(context);
          }
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
          
        case 'filter_match':
          if (requestId != null) {
            await _navigateToRequest(context, requestId);
          } else {
            await _navigateToHome(context);
          }
          break;
          
        case 'service_provider_match':
          if (requestId != null) {
            await _navigateToRequest(context, requestId);
          } else {
            await _navigateToHome(context);
          }
          break;
          
        case 'order_new':
        case 'order_delivery':
          await _navigateToOrderManagement(context, orderId);
          break;
          
        default:
          await _navigateToHome(context);
      }
    } catch (e) {
      debugPrint('❌ Error navigating from notification: $e');
      // במקרה של שגיאה, נווט למסך הבית
      // Guard context usage after async gap
      if (!context.mounted) return;
      await _navigateToHome(context);
    }
  }

  /// ניווט למסך הבית
  static Future<void> _navigateToHome(BuildContext context) async {
    if (context.mounted) {
      // ניווט למסך הראשי המוגדר באפליקציה
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
      );
    }
  }

  /// ניווט לצ'אט
  static Future<void> _navigateToChat(BuildContext context, String chatId) async {
    if (context.mounted) {
      // ניווט למסך הראשי
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
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
      // הגדרת סמן שמגיעים מהתראות
      AppStateService.setFromNotification(true);
      // שמירת הבקשה לפתיחה במסך הבית
      AppStateService.setPendingRequestToOpen(requestId);
      
      // ניווט למסך הראשי
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
      );
      
      // TODO: ניווט לבקשה ספציפית (אם יש מסך כזה)
      debugPrint('🔔 Navigating to request: $requestId');
      
      // איפוס הסמן לאחר זמן קצר כדי לאפשר למסך להיטען
      Future.delayed(const Duration(seconds: 2), () {
        AppStateService.clearFromNotification();
      });
    }
  }

  /// ניווט לפרופיל
  static Future<void> _navigateToProfile(BuildContext context) async {
    if (context.mounted) {
      // ניווט למסך הראשי
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
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
      // ניווט למסך הראשי
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
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

  /// ניווט למסך ניהול הזמנות
  static Future<void> _navigateToOrderManagement(BuildContext context, String? orderId) async {
    if (context.mounted) {
      // ניווט למסך הראשי
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/main',
        (route) => false,
      );
      
      // המתן קצת ואז פתח את מסך ניהול הזמנות
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OrderManagementScreen(),
          ),
        );
      }
      
      debugPrint('🔔 Navigating to order management${orderId != null ? ' with orderId: $orderId' : ''}');
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
        final notificationData = data['data'] as Map<String, dynamic>?;
        return {
          'requestId': data['requestId'] as String?,
          'chatId': data['chatId'] as String?,
          'userId': data['userId'] as String?,
          'orderId': notificationData?['orderId'] as String?,
        };
      }
    } catch (e) {
      debugPrint('❌ Error getting notification data: $e');
    }
    
    return {};
  }
}
