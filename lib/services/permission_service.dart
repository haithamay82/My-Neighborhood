import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

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
    var status = await Permission.notification.status;
    return status.isGranted;
  }
}
