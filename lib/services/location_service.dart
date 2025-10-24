import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_tracking_service.dart';

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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

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

  /// חישוב טווח מקסימלי לפי סוג מנוי
  static double calculateMaxRadiusForUser({
    required String userType,
    required bool isSubscriptionActive,
    int recommendationsCount = 0,
    double averageRating = 0.0,
    bool isAdmin = false,
  }) {
    double baseRadius = 1000.0; // טווח בסיסי במטרים (1 ק"מ)

    // טווח לפי סוג משתמש (במטרים)
    switch (userType) {
      case 'guest':
        baseRadius = 3000.0; // 3 ק"מ - כמו עסקי מנוי
        break;
      case 'personal':
        baseRadius = isSubscriptionActive ? 2000.0 : 1000.0; // 2 ק"מ או 1 ק"מ
        break;
      case 'business':
        baseRadius = isSubscriptionActive ? 3000.0 : 1000.0; // 3 ק"מ או 1 ק"מ
        break;
      case 'admin':
        baseRadius = 50000.0; // 50 ק"מ
        break;
    }

    // בונוס המלצות (200 מטר לכל המלצה)
    final recommendationsBonus = recommendationsCount * 200.0;

    // בונוס דירוג (במטרים)
    double ratingBonus = 0.0;
    if (averageRating >= 4.5) {
      ratingBonus = 1500.0; // 1.5 ק"מ
    } else if (averageRating >= 4.0) {
      ratingBonus = 1000.0; // 1 ק"מ
    } else if (averageRating >= 3.5) {
      ratingBonus = 500.0; // 500 מטר
    }

    return baseRadius + recommendationsBonus + ratingBonus;
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

      // בדיקה אם כבר נשלחה התראה על הגדלת טווח עם אותם פרמטרים
      final hasBeenSent = await NotificationTrackingService.hasNotificationWithParamsBeenSent(
        userId: user.uid,
        notificationType: 'radius_increase',
        params: {
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating.toStringAsFixed(1),
          'radiusIncrease': radiusIncrease.toStringAsFixed(1),
        },
      );

      if (hasBeenSent) {
        debugPrint('Radius increase notification already sent for user: ${user.uid} with same parameters');
        return;
      }

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

      // סימון שההתראה נשלחה
      await NotificationTrackingService.markNotificationWithParamsAsSent(
        userId: user.uid,
        notificationType: 'radius_increase',
        params: {
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating.toStringAsFixed(1),
          'radiusIncrease': radiusIncrease.toStringAsFixed(1),
        },
      );

      debugPrint('✅ Radius increase notification sent: $message');
    } catch (e) {
      debugPrint('❌ Error sending radius increase notification: $e');
    }
  }
}
