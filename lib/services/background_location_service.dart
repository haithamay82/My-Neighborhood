import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

/// שירות לעדכון מיקום נייד ברקע כל דקה (60 שניות)
class BackgroundLocationService {
  static Timer? _updateTimer;
  static Timer? _locationServiceCheckTimer;
  static bool _isRunning = false;

  /// הפעלת עדכון מיקום ברקע
  static void start() {
    if (_isRunning) {
      debugPrint('⚠️ Background location service already running');
      return;
    }

    _isRunning = true;
    debugPrint('🚀 Starting background location update service');

    // עדכון ראשוני
    LocationService.updateMobileLocationInBackground();

    // עדכון תקופתי כל דקה (60 שניות)
    _updateTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      LocationService.updateMobileLocationInBackground();
    });
    
    // ✅ בדיקה תקופתית של שירות המיקום כל 5 שניות כאשר האפליקציה פתוחה
    _locationServiceCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkLocationServicePeriodically();
    });
  }
  
  /// ✅ בדיקה תקופתית של שירות המיקום כאשר האפליקציה פתוחה או ברקע
  /// התראה תישלח פעם אחת בלבד (לא כל 5 שניות)
  static Future<void> _checkLocationServicePeriodically() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        // בדיקה אם כבר שלחנו התראה (פעם אחת בלבד)
        final prefs = await SharedPreferences.getInstance();
        final notificationSent = prefs.getBool('locationServiceNotificationSentWhenOpen') ?? false;
        
        if (!notificationSent) {
          debugPrint('📍 Location service disabled detected (periodic check) - showing notification ONCE');
          await LocationService.checkAndShowLocationServiceNotification();
          // שמירה שכבר שלחנו התראה
          await prefs.setBool('locationServiceNotificationSentWhenOpen', true);
        } else {
          debugPrint('📍 Location service disabled but notification already sent - skipping');
        }
      } else {
        // אם שירות המיקום פעיל, נאפס את הסטטוס כדי שנוכל לשלוח התראה שוב אם ייסגר
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('locationServiceNotificationLastShown', 0);
        await prefs.setInt('locationServiceDialogLastShown', 0);
        await prefs.setBool('locationServiceNotificationSentWhenOpen', false);
      }
    } catch (e) {
      debugPrint('❌ Error checking location service periodically: $e');
    }
  }

  /// ✅ בדיקת שירות המיקום כאשר האפליקציה עוברת לרקע
  /// התראה תישלח פעם אחת בלבד
  static Future<void> checkLocationServiceWhenBackground() async {
    try {
      // בדיקה אם שירות המיקום פעיל
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        // בדיקה אם כבר שלחנו התראה (פעם אחת בלבד)
        final prefs = await SharedPreferences.getInstance();
        final notificationSent = prefs.getBool('locationServiceNotificationSentWhenOpen') ?? false;
        
        if (!notificationSent) {
          debugPrint('📍 Location service disabled detected when app went to background - showing notification ONCE');
          // הצגת התראה אם שירות המיקום מבוטל (פעם אחת בלבד)
          await LocationService.checkAndShowLocationServiceNotification();
          // שמירה שכבר שלחנו התראה
          await prefs.setBool('locationServiceNotificationSentWhenOpen', true);
        } else {
          debugPrint('📍 Location service disabled but notification already sent - skipping');
        }
      } else {
        // אם שירות המיקום פעיל, נאפס את הסטטוס כדי שנוכל לשלוח התראה שוב אם ייסגר
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('locationServiceNotificationSentWhenOpen', false);
      }
    } catch (e) {
      debugPrint('❌ Error checking location service when background: $e');
    }
  }


  /// עצירת עדכון מיקום ברקע
  static void stop() {
    if (!_isRunning) {
      return;
    }

    _isRunning = false;
    _updateTimer?.cancel();
    _updateTimer = null;
    _locationServiceCheckTimer?.cancel();
    _locationServiceCheckTimer = null;
    debugPrint('🛑 Background location update service stopped');
  }

  /// בדיקה אם השירות פועל
  static bool get isRunning => _isRunning;

  /// עדכון מיקום ידני (לצורך בדיקות)
  static Future<void> updateLocationNow() async {
    await LocationService.updateMobileLocationInBackground();
  }
}

