import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:firebase_messaging/firebase_messaging.dart';

class PermissionService {
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    // בדיקה אם ההרשאה כבר ניתנה
    var status = await Permission.notification.status;
    
    if (status.isGranted) {
      return true;
    }
    
    // אם ההרשאה לא ניתנה, בקש אותה
    if (status.isDenied) {
      status = await Permission.notification.request();
      
      if (status.isGranted) {
        return true;
      }
    }
    
    // אם ההרשאה נדחתה לצמיתות, הצג הודעה
    if (status.isPermanentlyDenied) {
      // Guard context usage after async gap
      if (!context.mounted) return false;
      _showPermissionDeniedDialog(context);
    }
    
    return false;
  }
  
  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('הרשאת התראות נדחתה'),
          content: const Text(
            'כדי לקבל התראות מהאפליקציה, אנא עבור להגדרות הטלפון והפעל הרשאות התראות עבור אפליקציה זו.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('פתח הגדרות'),
            ),
          ],
        );
      },
    );
  }
  
  static Future<bool> checkNotificationPermission() async {
    // ב-iOS, בודקים את הרשאות מערכת - אם יש הרשאות מערכת, זה מספיק
    // FCM יכול להיות authorized או provisional (שניהם תקינים)
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        // בדיקה ראשונית - הרשאות מערכת iOS
        final systemStatus = await Permission.notification.status;
        final systemGranted = systemStatus.isGranted;
        
        debugPrint('🔔 iOS Notification Permission Check:');
        debugPrint('   System Status: $systemStatus (granted: $systemGranted)');
        
        // אם יש הרשאות מערכת, זה מספיק
        if (systemGranted) {
          // נבדוק גם את FCM רק ללוג, אבל לא נדרוש אותו
          try {
            final messaging = FirebaseMessaging.instance;
            final settings = await messaging.getNotificationSettings();
            debugPrint('   FCM Status: ${settings.authorizationStatus}');
            debugPrint('   ✅ System permission granted - notifications allowed');
          } catch (e) {
            debugPrint('   ⚠️ Could not check FCM status: $e');
          }
          return true;
        }
        
        // אם אין הרשאות מערכת, נבדוק גם FCM (למקרה שהוא provisional)
        try {
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.getNotificationSettings();
          final fcmStatus = settings.authorizationStatus;
          
          // FCM יכול להיות authorized או provisional (שניהם תקינים)
          final fcmAllowed = fcmStatus == AuthorizationStatus.authorized || 
                            fcmStatus == AuthorizationStatus.provisional;
          
          debugPrint('   FCM Status: $fcmStatus (allowed: $fcmAllowed)');
          debugPrint('   Final Result: $fcmAllowed (system denied, checking FCM)');
          
          // אם FCM מאושר (גם provisional), נחזיר true
          if (fcmAllowed) {
            debugPrint('   ✅ FCM permission allowed (provisional or authorized)');
            return true;
          }
        } catch (e) {
          debugPrint('   ⚠️ Could not check FCM status: $e');
        }
        
        debugPrint('   ❌ No notification permissions granted');
        return false;
      } catch (e) {
        debugPrint('❌ Error checking iOS notification permission: $e');
        // במקרה של שגיאה, נבדוק רק את הרשאות מערכת
        var status = await Permission.notification.status;
        return status.isGranted;
      }
    }
    
    // ב-Android, בודקים רק את הרשאות מערכת
    var status = await Permission.notification.status;
    return status.isGranted;
  }

  static Future<bool> requestLocationPermission(BuildContext context) async {
    // בדיקה אם ההרשאה כבר ניתנה
    var status = await Permission.location.status;
    
    if (status.isGranted) {
      return true;
    }
    
    // אם ההרשאה לא ניתנה, בקש אותה
    if (status.isDenied) {
      status = await Permission.location.request();
      
      if (status.isGranted) {
        return true;
      }
    }
    
    // אם ההרשאה נדחתה לצמיתות, הצג הודעה
    if (status.isPermanentlyDenied) {
      // Guard context usage after async gap
      if (!context.mounted) return false;
      _showLocationPermissionDeniedDialog(context);
    }
    
    return false;
  }

  static void _showLocationPermissionDeniedDialog(BuildContext context) {
    // בדיקה שהקונטקסט מוכן לפני הצגת הדיאלוג
    if (!context.mounted) return;
    
    // השהיה קטנה כדי לוודא שה-Material context מוכן
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('הרשאת מיקום נדחתה'),
            content: const Text(
              'כדי לראות בקשות קרובות אליך ולהציג את המיקום שלך במפה, אנא עבור להגדרות הטלפון והפעל הרשאות מיקום עבור אפליקציה זו.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('פתח הגדרות'),
            ),
          ],
        );
      },
    );
    });
  }

  static Future<bool> checkLocationPermission() async {
    var status = await Permission.location.status;
    return status.isGranted;
  }
}
