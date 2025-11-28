import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import '../l10n/app_localizations.dart';
import 'notification_service.dart';
import 'notification_preferences_service.dart';

class LocationService {
  /// בדיקת הרשאות מיקום
  static Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// בקשת הרשאות מיקום
  static Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      debugPrint('Location permission request result: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  /// קבלת המיקום הנוכחי
  static Future<Position?> getCurrentPosition() async {
    try {
      // בדיקת הרשאות
      bool hasPermission = await checkLocationPermission();
      debugPrint('Initial location permission status: $hasPermission');
      
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        debugPrint('After requesting permission: $hasPermission');
        if (!hasPermission) {
          debugPrint('Location permission denied by user');
          return null;
        }
      }

      // בדיקה אם המיקום מופעל
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('Location services enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return null;
      }

      // בדיקת הרשאות נוספת לפני קבלת המיקום
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Location permission check: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('Location permission after request: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        return null;
      }

      // קבלת המיקום
      debugPrint('Attempting to get current position...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Position obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// המרת קואורדינטות לכתובת
  static Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // בדיקת null safety עבור כל השדות
        String street = place.street ?? '';
        String locality = place.locality ?? '';
        String administrativeArea = place.administrativeArea ?? '';
        
        // בניית הכתובת רק עם השדות הזמינים
        List<String> addressParts = [];
        if (street.isNotEmpty) addressParts.add(street);
        if (locality.isNotEmpty) addressParts.add(locality);
        if (administrativeArea.isNotEmpty) addressParts.add(administrativeArea);
        
        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        } else {
          return 'מיקום לא ידוע';
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// המרת כתובת לקואורדינטות
  static Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        Location location = locations[0];
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting coordinates from address: $e');
      return null;
    }
  }

  /// חישוב מרחק בין שתי נקודות (בקילומטרים)
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // המרה לקילומטרים
  }

  /// בדיקה אם מיקום נמצא בטווח מסוים
  static bool isLocationInRange(
    double userLat, double userLon,
    double targetLat, double targetLon,
    double maxDistanceKm,
  ) {
    double distance = calculateDistance(userLat, userLon, targetLat, targetLon);
    return distance <= maxDistanceKm;
  }

  /// בדיקה אם מיקום נמצא בתוך גבולות ישראל
  static bool isLocationInIsrael(double latitude, double longitude) {
    // גבולות ישראל (קירוב)
    const double minLat = 29.5;  // דרום (אילת)
    const double maxLat = 33.3;  // צפון (מטולה)
    const double minLon = 34.2;  // מערב (אשקלון)
    const double maxLon = 35.9;  // מזרח (גולן)
    
    return latitude >= minLat && 
           latitude <= maxLat && 
           longitude >= minLon && 
           longitude <= maxLon;
  }

  /// בדיקה אם מיקום נמצא בטווח וגם בתוך ישראל
  static bool isLocationInRangeAndIsrael(
    double userLat, double userLon,
    double targetLat, double targetLon,
    double maxDistanceKm,
  ) {
    // בדיקה ראשונה - האם בתוך ישראל
    if (!isLocationInIsrael(targetLat, targetLon)) {
      debugPrint('❌ Location outside Israel: $targetLat, $targetLon');
      return false;
    }
    
    // בדיקה שנייה - האם בטווח
    return isLocationInRange(userLat, userLon, targetLat, targetLon, maxDistanceKm);
  }

  /// חישוב טווח מקסימלי לפי סוג משתמש (במטרים)
  static double calculateMaxRadiusForUser({
    required String userType,
    required bool isSubscriptionActive,
    int recommendationsCount = 0,
    double averageRating = 0.0,
    bool isAdmin = false,
  }) {
    // קביעת טווח מקסימלי קשיח לפי סוג המשתמש
    // הערכים הם במטרים
    if (isAdmin) {
      return 250000.0; // מנהל: 250 ק"מ
    }

    switch (userType) {
      case 'guest':
        return 5000.0; // אורח: 5 ק"מ
      case 'personal':
        return isSubscriptionActive ? 5000.0 : 3000.0; // פרטי מנוי: 5 ק"מ, פרטי חינם: 3 ק"מ
      case 'business':
        return isSubscriptionActive ? 8000.0 : 1000.0; // עסקי מנוי: 8 ק"מ (עסקי ללא מנוי: 1 ק"מ ברירת מחדל)
      case 'admin':
        return 250000.0; // גיבוי
      default:
        return 3000.0; // ברירת מחדל: 3 ק"מ
    }
  }

  /// בדיקה אם טווח חשיפה לא חורג מגבולות ישראל
  static bool isExposureRadiusWithinIsrael(
    double centerLat, double centerLon,
    double radiusKm,
  ) {
    // גבולות ישראל
    const double minLat = 29.5;  // דרום
    const double maxLat = 33.3;  // צפון
    const double minLon = 34.2;  // מערב
    const double maxLon = 35.9;  // מזרח
    
    // בדיקה שהמרכז בתוך ישראל
    if (!isLocationInIsrael(centerLat, centerLon)) {
      debugPrint('❌ Center location outside Israel: $centerLat, $centerLon');
      return false;
    }
    
    // חישוב המרחק לגבולות
    final distToNorth = calculateDistance(centerLat, centerLon, maxLat, centerLon);
    final distToSouth = calculateDistance(centerLat, centerLon, minLat, centerLon);
    final distToWest = calculateDistance(centerLat, centerLon, centerLat, minLon);
    final distToEast = calculateDistance(centerLat, centerLon, centerLat, maxLon);
    
    // הטווח המקסימלי הוא המרחק הקטן ביותר לגבול
    final maxAllowedRadius = [distToNorth, distToSouth, distToWest, distToEast].reduce((a, b) => a < b ? a : b);
    
    // בדיקה שהטווח לא חורג
    if (radiusKm > maxAllowedRadius) {
      debugPrint('❌ Exposure radius $radiusKm km exceeds Israel boundary (max: $maxAllowedRadius km)');
      return false;
    }
    
    debugPrint('✅ Exposure radius $radiusKm km is within Israel boundary (max: $maxAllowedRadius km)');
    return true;
  }

  /// בדיקת שינוי בטווח ושליחת התראה
  static Future<void> checkAndShowRadiusIncreaseNotification(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userType = userData['userType'] as String? ?? 'personal';
      final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
      final recommendationsCount = userData['recommendationsCount'] as int? ?? 0;
      final averageRating = userData['averageRating'] as double? ?? 0.0;
      final isAdmin = userData['isAdmin'] as bool? ?? false;

      // חישוב הטווח הנוכחי
      final currentRadius = calculateMaxRadiusForUser(
        userType: userType,
        isSubscriptionActive: isSubscriptionActive,
        recommendationsCount: recommendationsCount,
        averageRating: averageRating,
        isAdmin: isAdmin,
      );

      // חישוב הטווח הקודם (ללא הבונוסים הנוכחיים)
      final baseRadius = calculateMaxRadiusForUser(
        userType: userType,
        isSubscriptionActive: isSubscriptionActive,
        recommendationsCount: 0,
        averageRating: 0.0,
        isAdmin: isAdmin,
      );

      // בדיקה אם יש שינוי משמעותי בטווח
      final radiusIncrease = currentRadius - baseRadius;
      if (radiusIncrease > 0) {
        await _sendRadiusIncreaseNotification(radiusIncrease, recommendationsCount, averageRating);
      }
    } catch (e) {
      debugPrint('❌ Error checking radius increase: $e');
    }
  }

  /// שליחת התראה על הגדלת טווח
  static Future<void> _sendRadiusIncreaseNotification(
double radiusIncrease,
    int recommendationsCount,
    double averageRating,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // בדיקה פשוטה
      debugPrint('Checking radius increase notification');

      String message = '';
      String details = '';
      
      if (recommendationsCount > 0) {
        final recommendationsBonus = recommendationsCount * 200.0;
        message += '🎉 תודה על $recommendationsCount המלצות שלך! ';
        details += 'המלצות: +${(recommendationsBonus / 1000).toStringAsFixed(1)} ק"מ ';
      }
      
      if (averageRating >= 3.5) {
        double ratingBonus = 0.0;
        if (averageRating >= 4.5) {
          ratingBonus = 1500.0;
        } else if (averageRating >= 4.0) {
          ratingBonus = 1000.0;
        } else if (averageRating >= 3.5) {
          ratingBonus = 500.0;
        }
        message += '⭐ דירוג מעולה של ${averageRating.toStringAsFixed(1)}! ';
        details += 'דירוג גבוה: +${(ratingBonus / 1000).toStringAsFixed(1)} ק"מ ';
      }
      
      message += '🚀 הטווח שלך גדל ב-${(radiusIncrease / 1000).toStringAsFixed(1)} ק"מ!';

      // יצירת התראה
      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'toUserId': user.uid,
        'title': 'הטווח שלך גדל!',
        'message': message,
        'type': 'radius_increase',
        'data': {
          'radiusIncrease': radiusIncrease,
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating,
          'details': details.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      };

      // שמירת ההתראה ב-Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notification);

      // התראה נשלחה
      debugPrint('Radius increase notification sent for user: ${user.uid}');

      debugPrint('✅ Radius increase notification sent: $message');
    } catch (e) {
      debugPrint('❌ Error sending radius increase notification: $e');
    }
  }

  /// עדכון מיקום נייד ברקע - שומר ב-Firestore
  static Future<void> updateMobileLocationInBackground() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ No user logged in, skipping mobile location update');
        return;
      }

      // בדיקת הרשאות
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        debugPrint('⚠️ No location permission, skipping mobile location update');
        return;
      }

      // בדיקה אם המיקום מופעל
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services disabled, clearing mobile location from Firestore');
        // אם שירות המיקום מבוטל, נמחק את המיקום הנייד מ-Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'mobileLatitude': FieldValue.delete(),
          'mobileLongitude': FieldValue.delete(),
          'mobileLocationUpdatedAt': FieldValue.delete(),
        });
        debugPrint('📍 Mobile location cleared from Firestore (location service disabled)');
        return;
      }

      // קבלת מיקום נוכחי
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // עדכון ב-Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'mobileLatitude': position.latitude,
        'mobileLongitude': position.longitude,
        'mobileLocationUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📍 Background mobile location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Error updating mobile location in background: $e');
    }
  }

  /// ✅ בדיקה והצגת דיאלוג אם שירות המיקום מבוטל
  static Future<void> checkAndShowLocationServiceDialog(BuildContext context, {bool forceShow = false}) async {
    try {
      // בדיקה אם שירות המיקום פעיל
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (serviceEnabled) {
        // ✅ אם שירות המיקום פעיל, נאפס את הסטטוס כדי שנוכל לשלוח התראה/דיאלוג שוב אם ייסגר
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('locationServiceDialogLastShown', 0);
        debugPrint('📍 Location service is enabled - resetting dialog status');
        return;
      }
      
      // שירות המיקום מבוטל
      // בדיקה אם כבר הצגנו את הדיאלוג לאחרונה (למניעת הצגה חוזרת)
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getInt('locationServiceDialogLastShown') ?? 0;
      
      // אם forceShow = false, נבדוק אם כבר הצגנו את הדיאלוג לאחרונה
      if (!forceShow) {
        // אם lastShown = 0, זה אומר ששירות המיקום הופעל לאחרונה, אז נציג את הדיאלוג
        if (lastShown != 0) {
          final now = DateTime.now().millisecondsSinceEpoch;
          const oneHourInMs = 60 * 60 * 1000; // שעה אחת במילישניות
          
          // אם הצגנו את הדיאלוג בשעה האחרונה, לא נציג שוב
          if (now - lastShown < oneHourInMs) {
            debugPrint('📍 Location service dialog shown recently, skipping');
            return;
          }
        }
      } else {
        // אם forceShow = true (בכניסה לאפליקציה), נציג את הדיאלוג רק אם לא הצגנו אותו בשעה האחרונה
        // זה מונע הצגה חוזרת גם בכניסה לאפליקציה
        if (lastShown != 0) {
          final now = DateTime.now().millisecondsSinceEpoch;
          const oneHourInMs = 60 * 60 * 1000; // שעה אחת במילישניות
          
          // אם הצגנו את הדיאלוג בשעה האחרונה, לא נציג שוב (גם עם forceShow: true)
          if (now - lastShown < oneHourInMs) {
            debugPrint('📍 Location service dialog shown recently (within 1 hour), skipping even with forceShow');
            return;
          }
        }
      }
      
      // Guard context usage after async gap
      if (!context.mounted) return;
      
      // שמירת זמן הצגת הדיאלוג
      await prefs.setInt('locationServiceDialogLastShown', DateTime.now().millisecondsSinceEpoch);
      
      // Guard context usage after async gap again
      if (!context.mounted) return;
      
      final l10n = AppLocalizations.of(context);
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(l10n.locationServiceDisabledTitle),
            content: SingleChildScrollView(
              child: Text(l10n.locationServiceDisabledMessage),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: Text(l10n.openSettings),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Error checking location service: $e');
    }
  }

  /// ✅ פתיחת הגדרות שירות המיקום של המכשיר
  static Future<void> openLocationSettings() async {
    try {
      if (Platform.isAndroid) {
        // פתיחת הגדרות שירות המיקום של Android באמצעות platform channel
        const platform = MethodChannel('com.example.flutter1/location_settings');
        try {
          await platform.invokeMethod('openLocationSettings');
          debugPrint('✅ Successfully opened location settings');
        } on PlatformException catch (e) {
          debugPrint('❌ Error opening location settings via platform channel: ${e.message}');
          // Fallback: פתיחת הגדרות האפליקציה
          await openAppSettings();
        }
      } else if (Platform.isIOS) {
        // ב-iOS, פתיחת הגדרות האפליקציה (iOS לא מאפשר לפתוח הגדרות שירות מיקום ישירות)
        await openAppSettings();
      } else {
        // Fallback: פתיחת הגדרות האפליקציה
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('❌ Error opening location settings: $e');
      // Fallback: פתיחת הגדרות האפליקציה
      try {
        await openAppSettings();
      } catch (e2) {
        debugPrint('❌ Error opening app settings: $e2');
      }
    }
  }

  /// ✅ הצגת דיאלוג "הפעל שירותי מיקום" כאשר המשתמש מסמן את הצ'קבוקס מיקום נייד
  static Future<bool> showEnableLocationServiceDialog(BuildContext context) async {
    try {
      // Guard context usage after async gap
      if (!context.mounted) return false;
      
      final l10n = AppLocalizations.of(context);
      
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(l10n.enableLocationServiceTitle),
            content: SingleChildScrollView(
              child: Text(l10n.enableLocationServiceMessage),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                  openLocationSettings();
                },
                child: Text(l10n.enableLocationService),
              ),
            ],
          );
        },
      );
      
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error showing enable location service dialog: $e');
      return false;
    }
  }

  /// ✅ בדיקה והצגת התראה אם שירות המיקום מבוטל (כאשר אין context)
  /// התראה תישלח רק למשתמשים שסימנו את הצ'יקבוקס "סנן בקשות על פי המיקום הנייד שלי..."
  static Future<void> checkAndShowLocationServiceNotification() async {
    try {
      // ✅ בדיקה אם המשתמש סימן את הצ'יקבוקס "סנן בקשות על פי המיקום הנייד שלי..."
      // אם לא סימן, לא נשלח התראה
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('📍 No user logged in - skipping location service notification');
        return;
      }
      
      // בדיקה אם המשתמש סימן את הצ'יקבוקס "סנן בקשות על פי המיקום הנייד שלי..."
      final notificationPrefs = await NotificationPreferencesService.getNotificationPreferences(user.uid);
      final useMobileLocation = notificationPrefs?.newRequestsUseMobileLocation ?? false;
      final useBothLocations = notificationPrefs?.newRequestsUseBothLocations ?? false;
      
      if (!useMobileLocation && !useBothLocations) {
        debugPrint('📍 User has not enabled mobile location filter - skipping location service notification');
        return;
      }
      
      // בדיקה אם שירות המיקום פעיל
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (serviceEnabled) {
        // ✅ אם שירות המיקום פעיל, נאפס את הסטטוס כדי שנוכל לשלוח התראה שוב אם ייסגר
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('locationServiceNotificationLastShown', 0);
        debugPrint('📍 Location service is enabled - resetting notification status');
        return;
      }
      
      // שירות המיקום מבוטל
      // בדיקה אם כבר הצגנו את ההתראה לאחרונה (למניעת הצגה חוזרת)
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getInt('locationServiceNotificationLastShown') ?? 0;
      
      // אם lastShown = 0, זה אומר ששירות המיקום הופעל לאחרונה, אז נציג את ההתראה
      if (lastShown != 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        const oneHourInMs = 60 * 60 * 1000; // שעה אחת במילישניות
        
        // אם הצגנו את ההתראה בשעה האחרונה, לא נציג שוב
        if (now - lastShown < oneHourInMs) {
          debugPrint('📍 Location service notification shown recently, skipping');
          return;
        }
      }
      
      // שמירת זמן הצגת ההתראה
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('locationServiceNotificationLastShown', now);
      
      // הצגת התראה מקומית
      // נשתמש בתרגום בסיסי - נשתמש בעברית כגיבוי
      // TODO: להוסיף תרגום דינמי לפי שפת האפליקציה
      const title = 'שירות המיקום כבוי';
      const message = 'שירות המיקום במכשיר שלך כבוי. אנא הפעל את שירות המיקום בהגדרות המכשיר כדי להשתמש בתכונות מבוססות מיקום.';
      
      await NotificationService.showLocalNotification(
        title: title,
        body: message,
        id: 9999, // ID ייחודי להתראות שירות מיקום
        payload: 'location_service_disabled',
      );
      
      debugPrint('✅ Location service notification shown');
    } catch (e) {
      debugPrint('❌ Error checking and showing location service notification: $e');
    }
  }
}
