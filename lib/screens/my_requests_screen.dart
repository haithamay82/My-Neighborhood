import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../models/request.dart';
import '../models/user_profile.dart';
import 'edit_request_screen.dart';
import 'select_helper_for_rating_screen.dart';
import 'chat_screen.dart';
import 'image_gallery_screen.dart';
import '../services/chat_service.dart';
import '../services/app_state_service.dart';
import '../services/like_service.dart';
import '../services/location_service.dart';
import '../services/audio_service.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

// מבנה לשמירת מידע על מיקום נותן שירות (קבוע או נייד)
class HelperLocation {
  final UserProfile helper;
  final double latitude;
  final double longitude;
  final bool isFixedLocation; // true = מיקום קבוע, false = מיקום נייד

  HelperLocation({
    required this.helper,
    required this.latitude,
    required this.longitude,
    required this.isFixedLocation,
  });
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  
  @override
  void initState() {
    super.initState();
  }
  
  // פונקציה להפעלת צליל לחיצה
  Future<void> playButtonSound() async {
    await AudioService().playSound(AudioEvent.buttonClick);
  }
  
  // פונקציה ליצירת stream של עוזרים רלוונטיים למפה
  Stream<List<HelperLocation>> _getRelevantHelpersStream(Request request) {
    return Stream.periodic(const Duration(seconds: 10))
        .asyncMap((_) => _loadRelevantHelpersForMap(request));
  }

  // פתיחת מפה במסך מלא עם אותם סימונים
  void _openFullScreenMap(BuildContext context, Request request, List<HelperLocation> helperLocations) async {
    final markers = await _createMarkersForMap(request, helperLocations, context);
    // Guard context usage after async gap
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).fullScreenMap),
          ),
          body: SafeArea(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                // מרכז ארץ ישראל
                target: const LatLng(31.4, 35.0),
                // זום שמציג את כל ארץ ישראל
                zoom: 7.5,
              ),
              markers: markers,
              circles: _createCirclesForMap(request),
              polygons: _createPolygonsForMap(request),
              mapType: MapType.normal,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
            ),
          ),
        ),
      ),
    );
  }

  // טעינת נותני שירות רלוונטיים למפה
  Future<List<HelperLocation>> _loadRelevantHelpersForMap(Request request) async {
    // הסרת debug prints מיותרים - הפונקציה נקראת כל 10 שניות
    if (request.latitude == null || request.longitude == null || request.exposureRadius == null) {
      return [];
    }
    
    // רק עבור בקשות בתשלום
    if (request.type != RequestType.paid) {
      return [];
    }
    
    try {
      final helperLocations = <HelperLocation>[];
      
      // מנהלים לא מופיעים במפה - יש להם גישה לכל התחומים אבל לא מוצגים כנותני שירות
      // משתמשי "פרטי חינם" לא מופיעים במפה כנותני שירות - אין להם תחומי עיסוק
      // אבל הם יכולים ליצור בקשות בתשלום כמו כל סוגי המנויים
      // מופיעים במפה כנקודה כחולה:
      // 1. משתמשים עסקיים - עם מנוי פעיל ותחומי עיסוק מתאימים
      // 2. משתמשי אורח - עם תחומי עיסוק מתאימים
      // כולם צריכים: להיות בטווח, לא יוצר הבקשה, עם מיקום
      // לוגיקת מיקום:
      // - מיקום קבוע: אם יש מיקום קבוע בטווח → מופיע במפה
      // - מיקום נייד: אם יש מיקום נייד שמור ב-Firestore (מעודכן כל דקה) בטווח → מופיע במפה
      // - אם יש גם מיקום קבוע וגם מיקום נייד בטווח → מופיעים שני מרקרים
      
      // 2. טעינת משתמשים עסקיים עם מנוי פעיל בקטגוריה הרלוונטית
      final businessUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .get();
      
      for (var doc in businessUsersSnapshot.docs) {
        final userProfile = UserProfile.fromFirestore(doc);
        
        // בדיקה אם זה יוצר הבקשה עצמו
        if (userProfile.userId == request.createdBy) {
          continue;
        }
        
        // מנהלים לא מופיעים במפה - יש להם גישה לכל התחומים אבל לא מוצגים כנותני שירות
        final userData = doc.data() as Map<String, dynamic>?;
        final isAdmin = userProfile.isAdmin == true || 
            userData?['email'] == 'admin@gmail.com' || 
            userData?['email'] == 'haitham.ay82@gmail.com';
        if (isAdmin) {
          continue;
        }
        
        // בדיקת קטגוריות
        bool hasMatchingCategory = false;
        if (userProfile.businessCategories != null) {
          // המרת קטגוריית הבקשה לשם פנימי (enum name)
          String requestCategoryName = request.category.name;
          
          // ✅ Safe fix: businessCategories is typed as List<RequestCategory>, so type check is unnecessary
          for (final cat in userProfile.businessCategories!) {
              // בדיקה ישירה של שם הקטגוריה הפנימי
              if (cat.name == requestCategoryName) {
                hasMatchingCategory = true;
                break;
            }
          }
        }
        
        if (hasMatchingCategory) {
          // בדיקת דירוגים (רק אם הבקשה דורשת)
          bool meetsRatingRequirements = true;
          
          if (request.minRating != null && (userProfile.averageRating == null || userProfile.averageRating! < request.minRating!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minReliability != null && (userProfile.reliability == null || userProfile.reliability! < request.minReliability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAvailability != null && (userProfile.availability == null || userProfile.availability! < request.minAvailability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAttitude != null && (userProfile.attitude == null || userProfile.attitude! < request.minAttitude!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minFairPrice != null && (userProfile.fairPrice == null || userProfile.fairPrice! < request.minFairPrice!)) {
            meetsRatingRequirements = false;
          }
          
          if (!meetsRatingRequirements) {
            continue; // דלג על משתמש זה
          }
          
          // בדיקת מיקום קבוע (אם יש)
          if (userProfile.latitude != null && userProfile.longitude != null) {
            final fixedDistance = LocationService.calculateDistance(
              request.latitude!,
              request.longitude!,
              userProfile.latitude!,
              userProfile.longitude!,
            );
            
            if (fixedDistance <= request.exposureRadius!) {
              helperLocations.add(HelperLocation(
                helper: userProfile,
                latitude: userProfile.latitude!,
                longitude: userProfile.longitude!,
                isFixedLocation: true,
              ));
            }
          }
          
          // בדיקת מיקום נייד (אם יש מיקום נייד שמור ב-Firestore ומעודכן לאחרונה - שירות המיקום פעיל)
          if (userProfile.mobileLatitude != null && userProfile.mobileLongitude != null) {
            // בדיקת תאריך עדכון המיקום הנייד מ-Firestore
            final userData = doc.data() as Map<String, dynamic>?;
            final mobileLocationUpdatedAt = userData?['mobileLocationUpdatedAt'];
            
            // אם יש תאריך עדכון, בודקים אם הוא מעודכן לאחרונה (תוך 90 שניות = 60 שניות עדכון + 30 שניות buffer)
            // המיקום מתעדכן כל 60 שניות, אז אם אין עדכון תוך 90 שניות, שירות המיקום כנראה מבוטל
            bool isLocationServiceActive = false;
            if (mobileLocationUpdatedAt != null) {
              try {
                final updatedAt = (mobileLocationUpdatedAt as Timestamp).toDate();
                final now = DateTime.now();
                final difference = now.difference(updatedAt);
                // אם המיקום מעודכן תוך 90 שניות, שירות המיקום כנראה פעיל
                isLocationServiceActive = difference.inSeconds <= 90;
              } catch (e) {
                // אם לא ניתן לפרסר את התאריך, נניח ששירות המיקום לא פעיל
                isLocationServiceActive = false;
              }
            } else {
              // אם אין תאריך עדכון, נניח ששירות המיקום לא פעיל
              isLocationServiceActive = false;
            }
            
            // רק אם שירות המיקום פעיל, נבדוק את המיקום הנייד
            if (isLocationServiceActive) {
              final mobileDistance = LocationService.calculateDistance(
                request.latitude!,
                request.longitude!,
                userProfile.mobileLatitude!,
                userProfile.mobileLongitude!,
              );
              
              if (mobileDistance <= request.exposureRadius!) {
                helperLocations.add(HelperLocation(
                  helper: userProfile,
                  latitude: userProfile.mobileLatitude!,
                  longitude: userProfile.mobileLongitude!,
                  isFixedLocation: false,
                ));
              }
            }
          }
        }
      }
      
      // 3. טעינת משתמשי אורח בקטגוריה הרלוונטית
      final guestUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'guest')
          .get();
      
      for (var doc in guestUsersSnapshot.docs) {
        final userProfile = UserProfile.fromFirestore(doc);
        
        // בדיקה אם זה יוצר הבקשה עצמו
        if (userProfile.userId == request.createdBy) {
          continue;
        }
        
        // בדיקה אם משתמש אורח בחר תחומי עיסוק
        final hasCategories = userProfile.businessCategories != null && 
                             userProfile.businessCategories!.isNotEmpty;
        
        // משתמש אורח יכול לראות בקשה רק אם בחר תחומי עיסוק
        bool canSeeRequest = false;
        if (hasCategories) {
          // בדיקת קטגוריות
          bool hasMatchingCategory = false;
          if (userProfile.businessCategories != null) {
            // המרת קטגוריית הבקשה לשם פנימי (enum name)
            String requestCategoryName = request.category.name;
            
            // ✅ Safe fix: businessCategories is typed as List<RequestCategory>, so type check is unnecessary
            for (final cat in userProfile.businessCategories!) {
                // בדיקה ישירה של שם הקטגוריה הפנימי
                if (cat.name == requestCategoryName) {
                  hasMatchingCategory = true;
                  break;
              }
            }
          }
          canSeeRequest = hasMatchingCategory;
        }
        
        if (canSeeRequest) {
          // בדיקת דירוגים (רק אם הבקשה דורשת)
          bool meetsRatingRequirements = true;
          
          if (request.minRating != null && (userProfile.averageRating == null || userProfile.averageRating! < request.minRating!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minReliability != null && (userProfile.reliability == null || userProfile.reliability! < request.minReliability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAvailability != null && (userProfile.availability == null || userProfile.availability! < request.minAvailability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAttitude != null && (userProfile.attitude == null || userProfile.attitude! < request.minAttitude!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minFairPrice != null && (userProfile.fairPrice == null || userProfile.fairPrice! < request.minFairPrice!)) {
            meetsRatingRequirements = false;
          }
          
          if (!meetsRatingRequirements) {
            continue; // דלג על משתמש זה
          }
          
          // בדיקת מיקום קבוע (אם יש)
          if (userProfile.latitude != null && userProfile.longitude != null) {
            final fixedDistance = LocationService.calculateDistance(
              request.latitude!,
              request.longitude!,
              userProfile.latitude!,
              userProfile.longitude!,
            );
            
            if (fixedDistance <= request.exposureRadius!) {
              helperLocations.add(HelperLocation(
                helper: userProfile,
                latitude: userProfile.latitude!,
                longitude: userProfile.longitude!,
                isFixedLocation: true,
              ));
            }
          }
          
          // בדיקת מיקום נייד (אם יש מיקום נייד שמור ב-Firestore ומעודכן לאחרונה - שירות המיקום פעיל)
          if (userProfile.mobileLatitude != null && userProfile.mobileLongitude != null) {
            // בדיקת תאריך עדכון המיקום הנייד מ-Firestore
            final userData = doc.data() as Map<String, dynamic>?;
            final mobileLocationUpdatedAt = userData?['mobileLocationUpdatedAt'];
            
            // אם יש תאריך עדכון, בודקים אם הוא מעודכן לאחרונה (תוך 90 שניות = 60 שניות עדכון + 30 שניות buffer)
            // המיקום מתעדכן כל 60 שניות, אז אם אין עדכון תוך 90 שניות, שירות המיקום כנראה מבוטל
            bool isLocationServiceActive = false;
            if (mobileLocationUpdatedAt != null) {
              try {
                final updatedAt = (mobileLocationUpdatedAt as Timestamp).toDate();
                final now = DateTime.now();
                final difference = now.difference(updatedAt);
                // אם המיקום מעודכן תוך 90 שניות, שירות המיקום כנראה פעיל
                isLocationServiceActive = difference.inSeconds <= 90;
              } catch (e) {
                // אם לא ניתן לפרסר את התאריך, נניח ששירות המיקום לא פעיל
                isLocationServiceActive = false;
              }
            } else {
              // אם אין תאריך עדכון, נניח ששירות המיקום לא פעיל
              isLocationServiceActive = false;
            }
            
            // רק אם שירות המיקום פעיל, נבדוק את המיקום הנייד
            if (isLocationServiceActive) {
              final mobileDistance = LocationService.calculateDistance(
                request.latitude!,
                request.longitude!,
                userProfile.mobileLatitude!,
                userProfile.mobileLongitude!,
              );
              
              if (mobileDistance <= request.exposureRadius!) {
                helperLocations.add(HelperLocation(
                  helper: userProfile,
                  latitude: userProfile.mobileLatitude!,
                  longitude: userProfile.mobileLongitude!,
                  isFixedLocation: false,
                ));
              }
            }
          }
        }
      }
      
      // ✅ טעינת נותני שירות מהאיזור אם המשתמש בחר "כן, כל נותני השירות באיזור X"
      if (request.showToProvidersOutsideRange == true && request.latitude != null) {
        final region = getGeographicRegion(request.latitude);
        final mainCategory = request.category.mainCategory;
        
        debugPrint('📍 Loading providers from region: ${region.name}, category: ${mainCategory.name}');
        
        // טעינת כל נותני השירות מהתחום והאיזור (ללא הגבלת טווח)
        final regionProviders = await _loadProvidersFromRegion(mainCategory, region, request);
        helperLocations.addAll(regionProviders);
      }
      
      // הסרת debug prints מיותרים - הפונקציה נקראת כל 10 שניות
      return helperLocations;
      
    } catch (e) {
      debugPrint('Error loading relevant helpers: $e');
      return [];
    }
  }
  
  // ✅ טעינת נותני שירות מהאיזור והתחום הנבחר
  Future<List<HelperLocation>> _loadProvidersFromRegion(
    MainCategory mainCategory,
    GeographicRegion region,
    Request request,
  ) async {
    final helperLocations = <HelperLocation>[];
    
    try {
      // טעינת משתמשים עסקיים עם מנוי פעיל
      final businessUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .get();
      
      for (var doc in businessUsersSnapshot.docs) {
        final userProfile = UserProfile.fromFirestore(doc);
        
        // בדיקה אם זה יוצר הבקשה עצמו
        if (userProfile.userId == request.createdBy) {
          continue;
        }
        
        // מנהלים לא מופיעים במפה
        final userData = doc.data() as Map<String, dynamic>?;
        final isAdmin = userProfile.isAdmin == true || 
            userData?['email'] == 'admin@gmail.com' || 
            userData?['email'] == 'haitham.ay82@gmail.com';
        if (isAdmin) {
          continue;
        }
        
        // בדיקת קטגוריה ראשית
        bool hasMatchingMainCategory = false;
        if (userProfile.businessCategories != null) {
          for (final cat in userProfile.businessCategories!) {
            if (cat.mainCategory == mainCategory) {
              hasMatchingMainCategory = true;
              break;
            }
          }
        }
        
        if (!hasMatchingMainCategory) {
          continue;
        }
        
        // בדיקת איזור - לפי מיקום קבוע או נייד
        bool isInRegion = false;
        double? providerLatitude;
        double? providerLongitude;
        bool isFixedLocation = false;
        
        // בדיקת מיקום קבוע
        if (userProfile.latitude != null && userProfile.longitude != null) {
          final providerRegion = getGeographicRegion(userProfile.latitude);
          if (providerRegion == region) {
            isInRegion = true;
            providerLatitude = userProfile.latitude;
            providerLongitude = userProfile.longitude;
            isFixedLocation = true;
          }
        }
        
        // בדיקת מיקום נייד (אם לא נמצא במיקום קבוע)
        if (!isInRegion && userProfile.mobileLatitude != null && userProfile.mobileLongitude != null) {
          final userData = doc.data() as Map<String, dynamic>?;
          final mobileLocationUpdatedAt = userData?['mobileLocationUpdatedAt'];
          
          bool isLocationServiceActive = false;
          if (mobileLocationUpdatedAt != null) {
            try {
              final updatedAt = (mobileLocationUpdatedAt as Timestamp).toDate();
              final now = DateTime.now();
              final difference = now.difference(updatedAt);
              isLocationServiceActive = difference.inSeconds <= 90;
            } catch (e) {
              isLocationServiceActive = false;
            }
          }
          
          if (isLocationServiceActive) {
            final providerRegion = getGeographicRegion(userProfile.mobileLatitude);
            if (providerRegion == region) {
              isInRegion = true;
              providerLatitude = userProfile.mobileLatitude;
              providerLongitude = userProfile.mobileLongitude;
              isFixedLocation = false;
            }
          }
        }
        
        if (isInRegion && providerLatitude != null && providerLongitude != null) {
          // בדיקת דירוגים (רק אם הבקשה דורשת)
          bool meetsRatingRequirements = true;
          
          if (request.minRating != null && (userProfile.averageRating == null || userProfile.averageRating! < request.minRating!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minReliability != null && (userProfile.reliability == null || userProfile.reliability! < request.minReliability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAvailability != null && (userProfile.availability == null || userProfile.availability! < request.minAvailability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAttitude != null && (userProfile.attitude == null || userProfile.attitude! < request.minAttitude!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minFairPrice != null && (userProfile.fairPrice == null || userProfile.fairPrice! < request.minFairPrice!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements) {
            helperLocations.add(HelperLocation(
              helper: userProfile,
              latitude: providerLatitude,
              longitude: providerLongitude,
              isFixedLocation: isFixedLocation,
            ));
          }
        }
      }
      
      // טעינת משתמשי אורח
      final guestUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'guest')
          .get();
      
      for (var doc in guestUsersSnapshot.docs) {
        final userProfile = UserProfile.fromFirestore(doc);
        
        if (userProfile.userId == request.createdBy) {
          continue;
        }
        
        // בדיקת קטגוריה ראשית
        bool hasMatchingMainCategory = false;
        if (userProfile.businessCategories != null && userProfile.businessCategories!.isNotEmpty) {
          for (final cat in userProfile.businessCategories!) {
            if (cat.mainCategory == mainCategory) {
              hasMatchingMainCategory = true;
              break;
            }
          }
        }
        
        if (!hasMatchingMainCategory) {
          continue;
        }
        
        // בדיקת איזור
        bool isInRegion = false;
        double? providerLatitude;
        double? providerLongitude;
        bool isFixedLocation = false;
        
        if (userProfile.latitude != null && userProfile.longitude != null) {
          final providerRegion = getGeographicRegion(userProfile.latitude);
          if (providerRegion == region) {
            isInRegion = true;
            providerLatitude = userProfile.latitude;
            providerLongitude = userProfile.longitude;
            isFixedLocation = true;
          }
        }
        
        if (!isInRegion && userProfile.mobileLatitude != null && userProfile.mobileLongitude != null) {
          final userData = doc.data() as Map<String, dynamic>?;
          final mobileLocationUpdatedAt = userData?['mobileLocationUpdatedAt'];
          
          bool isLocationServiceActive = false;
          if (mobileLocationUpdatedAt != null) {
            try {
              final updatedAt = (mobileLocationUpdatedAt as Timestamp).toDate();
              final now = DateTime.now();
              final difference = now.difference(updatedAt);
              isLocationServiceActive = difference.inSeconds <= 90;
            } catch (e) {
              isLocationServiceActive = false;
            }
          }
          
          if (isLocationServiceActive) {
            final providerRegion = getGeographicRegion(userProfile.mobileLatitude);
            if (providerRegion == region) {
              isInRegion = true;
              providerLatitude = userProfile.mobileLatitude;
              providerLongitude = userProfile.mobileLongitude;
              isFixedLocation = false;
            }
          }
        }
        
        if (isInRegion && providerLatitude != null && providerLongitude != null) {
          // בדיקת דירוגים
          bool meetsRatingRequirements = true;
          
          if (request.minRating != null && (userProfile.averageRating == null || userProfile.averageRating! < request.minRating!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minReliability != null && (userProfile.reliability == null || userProfile.reliability! < request.minReliability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAvailability != null && (userProfile.availability == null || userProfile.availability! < request.minAvailability!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minAttitude != null && (userProfile.attitude == null || userProfile.attitude! < request.minAttitude!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements && request.minFairPrice != null && (userProfile.fairPrice == null || userProfile.fairPrice! < request.minFairPrice!)) {
            meetsRatingRequirements = false;
          }
          
          if (meetsRatingRequirements) {
            helperLocations.add(HelperLocation(
              helper: userProfile,
              latitude: providerLatitude,
              longitude: providerLongitude,
              isFixedLocation: isFixedLocation,
            ));
          }
        }
      }
      
      debugPrint('📍 Loaded ${helperLocations.length} providers from region ${region.name} for category ${mainCategory.name}');
      return helperLocations;
      
    } catch (e) {
      debugPrint('Error loading providers from region: $e');
      return [];
    }
  }
  
  // יצירת מרקרים למפה
  Set<Circle> _createCirclesForMap(Request request) {
    final circles = <Circle>{};
    
    // עיגול טווח הבקשה אם יש
    if (request.exposureRadius != null && request.exposureRadius! > 0) {
      circles.add(
        Circle(
          circleId: const CircleId('request_range'),
          center: LatLng(request.latitude!, request.longitude!),
          radius: request.exposureRadius! * 1000, // המרה לקילומטרים
          fillColor: Colors.red.withValues(alpha: 0.1),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ),
      );
    }
    
    return circles;
  }

  // יצירת Polygon (מלבן) לסימון האיזור הגיאוגרפי
  Set<Polygon> _createPolygonsForMap(Request request) {
    final polygons = <Polygon>{};
    
    debugPrint('🗺️ ========== _createPolygonsForMap START ==========');
    debugPrint('🗺️ Request title: ${request.title}');
    debugPrint('🗺️ showToProvidersOutsideRange: ${request.showToProvidersOutsideRange}');
    debugPrint('🗺️ latitude: ${request.latitude}');
    debugPrint('🗺️ longitude: ${request.longitude}');
    
    // אם המשתמש בחר "כן, כל נותני השירות באיזור X" או לא בחר (null = ברירת מחדל)
    // רק אם המשתמש בחר במפורש "לא" (false), לא נציג את הפוליגון
    if (request.showToProvidersOutsideRange != false && request.latitude != null) {
      final region = getGeographicRegion(request.latitude);
      debugPrint('🗺️ Region determined: $region');
      
      // יצירת מלבן לפי גבולות האיזור עם קווי הרוחב
      List<LatLng> borderPoints = _getRegionPolygonPoints(region);
      debugPrint('🗺️ Border points count: ${borderPoints.length}');
      
      if (borderPoints.isNotEmpty) {
        debugPrint('🗺️ Creating Polygon with ${borderPoints.length} points');
        debugPrint('🗺️ First point: ${borderPoints.first.latitude}, ${borderPoints.first.longitude}');
        debugPrint('🗺️ Last point: ${borderPoints.last.latitude}, ${borderPoints.last.longitude}');
        
        polygons.add(
          Polygon(
            polygonId: PolygonId('geographic_region'),
            points: borderPoints,
            fillColor: Colors.grey.withValues(alpha: 0.4), // רקע אפור כהה יותר
            strokeColor: Colors.blue, // קו כחול
            strokeWidth: 8, // קו עבה
            geodesic: true, // חשוב ל-Polygon גדול
            zIndex: 1, // מעל העיגול האדום
            visible: true, // וידוא שה-Polygon נראה
          ),
        );
        debugPrint('🗺️ ✅ Polygon created successfully!');
        debugPrint('🗺️ Polygon fill: grey (alpha 0.4), stroke: blue (width 8)');
      } else {
        debugPrint('🗺️ ❌ Border points is empty - cannot create polygon');
      }
    } else {
      debugPrint('🗺️ ⚠️ Conditions not met for polygon creation');
      if (request.showToProvidersOutsideRange == false) {
        debugPrint('🗺️   Reason: showToProvidersOutsideRange is false (user explicitly chose "no")');
      }
      if (request.latitude == null) {
        debugPrint('🗺️   Reason: latitude is null');
      }
    }
    
    debugPrint('🗺️ Total polygons in set: ${polygons.length}');
    debugPrint('🗺️ ========== _createPolygonsForMap END ==========');
    return polygons;
  }

  // קבלת נקודות Polygon של מלבן לפי איזור
  // המלבן מתחום את הגבולות הקיצוניות של המדינה עם קווי הרוחב
  List<LatLng> _getRegionPolygonPoints(GeographicRegion region) {
    switch (region) {
      case GeographicRegion.north:
        return _getNorthRegionPolygon();
      case GeographicRegion.center:
        return _getCenterRegionPolygon();
      case GeographicRegion.south:
        return _getSouthRegionPolygon();
    }
  }

  // מלבן לאיזור הצפון
  // קו אופקי (רוחב) צפון: עובר בנקודה הצפונית ביותר (33.332653)
  // קו אופקי (רוחב) דרום: קו הרוחב 32.4
  // קו אנכי (אורך) מזרח: עובר בנקודה המזרחית ביותר (35.896111)
  // קו אנכי (אורך) מערב: חוף הים (34.2)
  List<LatLng> _getNorthRegionPolygon() {
    final points = [
      LatLng(33.332653, 34.2),      // צפון-מערב (קו רוחב צפון, קו אורך מערב)
      LatLng(33.332653, 35.896111), // צפון-מזרח (קו רוחב צפון, קו אורך מזרח)
      LatLng(32.4, 35.896111),      // דרום-מזרח (קו רוחב דרום, קו אורך מזרח)
      LatLng(32.4, 34.2),           // דרום-מערב (קו רוחב דרום, קו אורך מערב)
      LatLng(33.332653, 34.2),      // סגירה
    ];
    
    debugPrint('   📍 North region rectangle: ${points.length} points');
    debugPrint('   📍 North lat: 33.332653 | South lat: 32.4 | East lng: 35.896111 | West lng: 34.2');
    return points;
  }

  // מלבן לאיזור המרכז
  // מקו הרוחב 32.4 עד 31.75, ממערב (34.2) עד מזרח (35.6)
  List<LatLng> _getCenterRegionPolygon() {
    final points = [
      LatLng(32.4, 34.2),   // צפון-מערב
      LatLng(32.4, 35.6),   // צפון-מזרח
      LatLng(31.75, 35.6),  // דרום-מזרח
      LatLng(31.75, 34.2),  // דרום-מערב
      LatLng(32.4, 34.2),   // סגירה
    ];
    
    debugPrint('   📍 Center region rectangle: ${points.length} points');
    return points;
  }

  // מלבן לאיזור הדרום
  // מקו הרוחב 31.75 עד גבול דרום (29.5), ממערב (34.2) עד מזרח (35.6)
  List<LatLng> _getSouthRegionPolygon() {
    final points = [
      LatLng(31.75, 34.2),  // צפון-מערב
      LatLng(31.75, 35.6),  // צפון-מזרח
      LatLng(29.5, 35.6),   // דרום-מזרח
      LatLng(29.5, 34.2),   // דרום-מערב
      LatLng(31.75, 34.2),  // סגירה
    ];
    
    debugPrint('   📍 South region rectangle: ${points.length} points');
    return points;
  }

  Future<Set<Marker>> _createMarkersForMap(Request request, List<HelperLocation> helperLocations, BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final markers = <Marker>{};
    
    try {
      // מרקר לבקשה
      markers.add(
        Marker(
          markerId: const MarkerId('request'),
          position: LatLng(request.latitude!, request.longitude!),
          infoWindow: InfoWindow(
            title: request.title,
            snippet: l10n.yourRequestLocation,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      
      // מרקרים לנותני שירות
      for (int i = 0; i < helperLocations.length; i++) {
        final helperLocation = helperLocations[i];
        final helper = helperLocation.helper;
      
      // Debug: בדיקת נתוני נותן השירות
      debugPrint('🔍 Creating marker for helper $i: ${helper.displayName} (${helperLocation.isFixedLocation ? "Fixed" : "Mobile"})');
      debugPrint('  - allowPhoneDisplay: ${helper.allowPhoneDisplay}');
      debugPrint('  - phoneNumber: ${helper.phoneNumber}');
      debugPrint('  - phoneNumber isNotEmpty: ${helper.phoneNumber?.isNotEmpty}');
      debugPrint('  - Location: ${helperLocation.latitude}, ${helperLocation.longitude}');
      debugPrint('  - isFixedLocation: ${helperLocation.isFixedLocation}');
      
      // יצירת טקסט מידע על הדירוגים - פורמט מסודר
      List<String> infoParts = [];
      
      // דירוג כללי
      if (helper.averageRating != null && helper.averageRating! > 0) {
        infoParts.add('⭐ דירוג כללי: ${helper.averageRating!.toStringAsFixed(1)}');
      }
      
      // דירוגים מפורטים - כל אחד בשורה נפרדת
      infoParts.add('🔹 אמינות: ${(helper.reliability ?? 0.0).toStringAsFixed(1)}');
      infoParts.add('🔹 זמינות: ${(helper.availability ?? 0.0).toStringAsFixed(1)}');
      infoParts.add('🔹 יחס: ${(helper.attitude ?? 0.0).toStringAsFixed(1)}');
      infoParts.add('🔹 מחיר הוגן: ${(helper.fairPrice ?? 0.0).toStringAsFixed(1)}');
      
      // הוספת מספר טלפון אם המשתמש הסכים
      if (helper.allowPhoneDisplay == true && helper.phoneNumber != null && helper.phoneNumber!.isNotEmpty) {
        infoParts.add('📞 טלפון: ${helper.phoneNumber}');
      }
      
      // הוספת הסט קטן לכל marker כדי שהם לא יהיו בדיוק באותו המיקום
      final offset = i * 0.0001; // הסט של 0.0001 מעלות לכל marker
      final markerLat = helperLocation.latitude + offset;
      final markerLng = helperLocation.longitude + offset;
      
      // יצירת ID ייחודי לכל marker (כולל סוג המיקום)
      final markerId = 'helper_${helper.userId}_${helperLocation.isFixedLocation ? "fixed" : "mobile"}_$i';
      
      // הסרת debug prints מיותרים
      markers.add(
        Marker(
          markerId: MarkerId(markerId),
          position: LatLng(markerLat, markerLng),
          infoWindow: InfoWindow(
            title: helper.displayName,
            snippet: helperLocation.isFixedLocation 
                ? AppLocalizations.of(context).fixedLocationClickForDetails 
                : AppLocalizations.of(context).mobileLocationClickForDetails,
          ),
          onTap: () {
            if (mounted) {
              _showHelperDetailsDialog(context, helperLocation, request);
            }
          },
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    
    return markers;
    } catch (e) {
      debugPrint('Error creating markers for map: $e');
      // החזרת markers ריק במקרה של שגיאה
      return <Marker>{};
    }
  }

  // הצגת פרטים מלאים של נותן השירות בדיאלוג
  void _showHelperDetailsDialog(BuildContext context, HelperLocation helperLocation, Request request) async {
    final helper = helperLocation.helper;
    if (!mounted) return;
    
    debugPrint('🔍 _showHelperDetailsDialog called for helper: ${helper.displayName}');
    debugPrint('🔍 Helper data:');
    debugPrint('  - allowPhoneDisplay: ${helper.allowPhoneDisplay}');
    debugPrint('  - phoneNumber: ${helper.phoneNumber}');
    debugPrint('  - phoneNumber isNotEmpty: ${helper.phoneNumber?.isNotEmpty}');
    
    // ✅ טעינת דירוגים מפורטים מ-detailed_rating_stats לפי קטגוריית הבקשה
    double? detailedReliability;
    double? detailedAvailability;
    double? detailedAttitude;
    double? detailedFairPrice;
    
    try {
      // טעינת דירוגים מפורטים לפי קטגוריית הבקשה
      final categoryName = request.category.name;
      debugPrint('🔍 Loading detailed ratings for category: $categoryName');
      debugPrint('🔍 Helper userId: ${helper.userId}');
      
      final statsDocRef = FirebaseFirestore.instance
          .collection('detailed_rating_stats')
          .doc('${helper.userId}_$categoryName');
      
      final statsDoc = await statsDocRef.get();
      
      if (statsDoc.exists) {
        final statsData = statsDoc.data() as Map<String, dynamic>;
        detailedReliability = (statsData['averageReliability'] as num?)?.toDouble();
        detailedAvailability = (statsData['averageAvailability'] as num?)?.toDouble();
        detailedAttitude = (statsData['averageAttitude'] as num?)?.toDouble();
        detailedFairPrice = (statsData['averageFairPrice'] as num?)?.toDouble();
        
        debugPrint('✅ Loaded detailed ratings from detailed_rating_stats:');
        debugPrint('  - reliability: $detailedReliability');
        debugPrint('  - availability: $detailedAvailability');
        debugPrint('  - attitude: $detailedAttitude');
        debugPrint('  - fairPrice: $detailedFairPrice');
      } else {
        debugPrint('⚠️ No detailed rating stats found for ${helper.userId}_$categoryName');
        
        // ✅ אם אין דירוגים לקטגוריה הספציפית, נטען את כל הדירוגים המפורטים מכל הקטגוריות ונחשב ממוצע
        // המפתח הוא ${userId}_${category}, אז נטען את כל המסמכים שמתחילים ב-${helper.userId}_
        debugPrint('🔍 Trying to load all detailed ratings for user ${helper.userId}...');
        
        // נטען את כל המסמכים ב-detailed_rating_stats ונסנן לפי userId
        final allStatsSnapshot = await FirebaseFirestore.instance
            .collection('detailed_rating_stats')
            .get();
        
        // סינון לפי userId (המפתח הוא ${userId}_${category})
        final userStatsDocs = allStatsSnapshot.docs.where((doc) {
          final docId = doc.id;
          return docId.startsWith('${helper.userId}_');
        }).toList();
        
        if (userStatsDocs.isNotEmpty) {
          debugPrint('✅ Found ${userStatsDocs.length} detailed rating stats for user ${helper.userId}');
          
          // חישוב ממוצע מכל הקטגוריות
          double totalReliability = 0.0;
          double totalAvailability = 0.0;
          double totalAttitude = 0.0;
          double totalFairPrice = 0.0;
          int count = 0;
          
          for (var doc in userStatsDocs) {
            final statsData = doc.data();
            final rel = (statsData['averageReliability'] as num?)?.toDouble();
            final avail = (statsData['averageAvailability'] as num?)?.toDouble();
            final att = (statsData['averageAttitude'] as num?)?.toDouble();
            final fp = (statsData['averageFairPrice'] as num?)?.toDouble();
            
            if (rel != null && avail != null && att != null && fp != null) {
              totalReliability += rel;
              totalAvailability += avail;
              totalAttitude += att;
              totalFairPrice += fp;
              count++;
            }
          }
          
          if (count > 0) {
            detailedReliability = totalReliability / count;
            detailedAvailability = totalAvailability / count;
            detailedAttitude = totalAttitude / count;
            detailedFairPrice = totalFairPrice / count;
            
            debugPrint('✅ Calculated average detailed ratings from all categories:');
            debugPrint('  - reliability: $detailedReliability (from $count categories)');
            debugPrint('  - availability: $detailedAvailability');
            debugPrint('  - attitude: $detailedAttitude');
            debugPrint('  - fairPrice: $detailedFairPrice');
          }
        } else {
          debugPrint('⚠️ No detailed rating stats found for user ${helper.userId} at all');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading detailed ratings: $e');
    }
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // תוכן הדיאלוג
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // מרווח לתמונה הבולטת
                    const SizedBox(height: 40),
                    
                    // שם המשתמש
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        helper.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                
                    // תוכן הדיאלוג
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // זמינות
                          if (helper.availableAllWeek == true || 
                              (helper.weekAvailability != null && 
                               helper.weekAvailability!.days.any((d) => d.isAvailable))) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Theme.of(context).colorScheme.primary),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        l10n.availability,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (helper.availableAllWeek == true) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.availableAllWeek,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (helper.weekAvailability != null && 
                                             helper.weekAvailability!.days.any((d) => d.isAvailable)) ...[
                                    ...helper.weekAvailability!.days
                                        .where((day) => day.isAvailable)
                                        .map((day) {
                                      final timeText = day.startTime != null && day.endTime != null
                                          ? ' (${day.startTime} - ${day.endTime})'
                                          : '';
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.circle, color: Theme.of(context).colorScheme.primary, size: 8),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${l10n.getDayName(day.day)}$timeText',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Theme.of(context).colorScheme.primary
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // דירוג כללי
                          if (helper.averageRating != null && helper.averageRating! > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(context).overallRating(helper.averageRating!.toStringAsFixed(1)),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // דירוגים
                          Text(
                            AppLocalizations.of(context).ratings,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          // ✅ הצגת דירוגים מפורטים מ-detailed_rating_stats אם קיימים, אחרת מ-users
                          _buildRatingRow(AppLocalizations.of(context).reliabilityLabel, detailedReliability ?? helper.reliability),
                          _buildRatingRow(AppLocalizations.of(context).availabilityLabel, detailedAvailability ?? helper.availability),
                          _buildRatingRow(AppLocalizations.of(context).attitudeLabel, detailedAttitude ?? helper.attitude),
                          _buildRatingRow(AppLocalizations.of(context).fairPriceLabel, detailedFairPrice ?? helper.fairPrice),
                          
                          // אייקון Waze לניווט למיקום נותן השירות (אם יש מיקום)
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _openWazeNavigation(helperLocation.latitude, helperLocation.longitude),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Theme.of(context).colorScheme.primary),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/waze.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(context).navigateToServiceProvider,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // מספר טלפון מתחת למחיר הוגן
                          if (helper.allowPhoneDisplay == true && helper.phoneNumber != null && helper.phoneNumber!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                _makePhoneCall(helper.phoneNumber!);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.phone, color: Theme.of(context).colorScheme.primary, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalizations.of(context).phone(helper.phoneNumber ?? ''),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.call, color: Colors.green, size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          // לחצן צ'אט - מופיע תמיד, לא מותנה ב-allowPhoneDisplay
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              await playButtonSound();
                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // סגירת הדיאלוג
                              await _openChatWithHelperFromDialog(request.requestId, helper.userId);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Theme.of(context).colorScheme.primary),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat, color: Theme.of(context).colorScheme.primary, size: 16),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'צ\'אט',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // כפתור סגירה
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await playButtonSound();
                            // Guard context usage after async gap - check context.mounted for builder context
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(AppLocalizations.of(context).close),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // תמונת פרופיל בולטת - חצי מעל הגבול העליון
                Positioned(
                  top: -30, // חצי מעל הגבול העליון
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: helper.profileImageUrl != null && helper.profileImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: helper.profileImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    child: Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // בניית שורת דירוג
  Widget _buildRatingRow(String label, double? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            (value ?? 0.0).toStringAsFixed(1),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // התקשרות לנותן השירות
  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).cannotCallNumber(phoneNumber)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorCalling(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// פותח את אפליקציית Waze לניווט למיקום נותן השירות
  Future<void> _openWazeNavigation(double latitude, double longitude) async {
    try {
      // ניסיון לפתוח את Waze ישירות (אם מותקן)
      final wazeAppUri = Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes');
      
      // ניסיון לפתוח את Waze ישירות
      bool launched = false;
      try {
        launched = await launchUrl(wazeAppUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Waze app not found, trying web URL: $e');
      }
      
      // אם Waze לא מותקן, נפתח את Waze דרך הדפדפן
      if (!launched) {
        final wazeWebUri = Uri.parse('https://waze.com/ul?q=$latitude,$longitude&navigate=yes');
        launched = await launchUrl(wazeWebUri, mode: LaunchMode.externalApplication);
      }
      
      if (!launched) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.wazeNotInstalled),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening Waze: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.errorOpeningWaze}: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // הצגת הודעת הדרכה למסך הבקשות שלי
  // הודעת הדרכה הוסרה - רק במסך הבית

  @override
  Widget build(BuildContext context) {
    // הסרת debug print מיותר
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך הבקשות שלי
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      // הודעת הדרכה הוסרה - רק במסך הבית
      }
    });
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.myRequestsMenu),
        ),
        body: Center(
          child: Text(AppLocalizations.of(context).userNotConnected),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.myRequestsMenu,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('requests')
              .where('createdBy', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context).loadingRequests,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(AppLocalizations.of(context).errorLoading(snapshot.error.toString())),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 64,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noRequestsInMyRequests,
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.createNewRequestToStart,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            final requests = snapshot.data!.docs
                .map((doc) => Request.fromFirestore(doc))
                .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // מיון לפי תאריך - החדשות ביותר בראש

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _buildRequestCard(request, l10n);
              },
            );
          },
        ),
      ),
    );
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageGalleryScreen(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildRequestCard(Request request, AppLocalizations l10n) {
    // אם הבקשה עם סטטוס "טופל", נציג אותה בצורה מכווצת (רק כותרת וסטטוס)
    final isCollapsed = request.status == RequestStatus.completed;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(request.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // אם הבקשה מכווצת (סטטוס "טופל"), לא נציג את שאר הפרטים
            if (!isCollapsed) ...[
            const SizedBox(height: 8),
            Text(
              request.description,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            
            // הצגת תמונות אם יש
            if (request.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _showImageGallery(request.images, index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: request.images[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 80,
                              height: 80,
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                                width: 80,
                                height: 80,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  request.category.categoryDisplayName,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payment, size: 16, color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  request.type.typeDisplayName(l10n),
                  style: TextStyle(
                    color: request.type == RequestType.paid 
                        ? Theme.of(context).colorScheme.primary 
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? Theme.of(context).colorScheme.onSurface 
                            : Theme.of(context).colorScheme.onSurfaceVariant),
                    fontSize: 12,
                    fontWeight: request.type == RequestType.paid ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            // הצגת מחיר (אם יש) - רק לבקשות בתשלום - בשורה חדשה
            if (request.type == RequestType.paid && request.price != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${l10n.willingToPay}: ${request.price!.toStringAsFixed(0)}₪',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  l10n.helpersCount(request.helpers.length),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                // הצגת כמות הלייקים
                StreamBuilder<int>(
                  stream: LikeService.getLikesCountStream(request.requestId),
                  builder: (context, snapshot) {
                    final likesCount = snapshot.data ?? 0;
                    return Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: likesCount > 0 
                              ? Theme.of(context).colorScheme.error 
                              : (Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.onSurface 
                                  : Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.likesCount(likesCount),
                          style: TextStyle(
                            color: likesCount > 0 
                                ? Theme.of(context).colorScheme.error 
                                : (Theme.of(context).brightness == Brightness.dark 
                                    ? Theme.of(context).colorScheme.onSurface 
                                    : Theme.of(context).colorScheme.onSurfaceVariant),
                            fontSize: 12,
                            fontWeight: likesCount > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const Spacer(),
                Text(
                  '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.onSurface 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            // הצגת מיקום אם יש
            if (request.address != null && request.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).colorScheme.onSurface 
                      : Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.address!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, 
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            
            // הצגת תאריך יעד אם יש
            if (request.deadline != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    request.deadline!.isBefore(DateTime.now()) ? Icons.warning : Icons.schedule, 
                    size: 16, 
                    color: request.deadline!.isBefore(DateTime.now()) 
                        ? Theme.of(context).colorScheme.error 
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? Theme.of(context).colorScheme.onSurface 
                            : Theme.of(context).colorScheme.onSurfaceVariant)
                  ),
                  const SizedBox(width: 4),
                  Text(
                    request.deadline!.isBefore(DateTime.now()) 
                        ? l10n.deadlineExpired
                        : l10n.deadlineDate('${request.deadline!.day}/${request.deadline!.month}/${request.deadline!.year}'),
                    style: TextStyle(
                      color: request.deadline!.isBefore(DateTime.now()) 
                          ? Theme.of(context).colorScheme.error 
                          : (Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.onSurface 
                              : Theme.of(context).colorScheme.onSurfaceVariant),
                      fontSize: 12,
                      fontWeight: request.deadline!.isBefore(DateTime.now()) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
            
            // הצגת רמת דחיפות ותגיות דחיפות
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _getUrgencyIcon(request.urgencyLevel),
                  size: 16,
                  color: _getUrgencyColor(request.urgencyLevel),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getUrgencyColor(request.urgencyLevel).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getUrgencyColor(request.urgencyLevel),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    request.urgencyLevel.displayName,
                    style: TextStyle(
                      color: _getUrgencyColor(request.urgencyLevel),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            // הצגת תגיות דחיפות אם יש
            if (request.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: request.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tag.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: tag.color,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tag.displayName(l10n),
                      style: TextStyle(
                        color: tag.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            // הצגת תגית מותאמת אישית אם יש
            if (request.customTag != null && request.customTag!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.purple,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.label,
                      size: 12,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.customTag!,
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // מפה אם יש מיקום וטווח ובקשה בתשלום
            if (request.latitude != null && request.longitude != null && request.exposureRadius != null && 
                request.type == RequestType.paid) ...[
              // כותרת המפה עם כפתור רענון + מסך מלא
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                children: [
                        Icon(Icons.map, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                  const SizedBox(width: 4),
                  Text(
                        l10n.mapOfRelevantHelpers,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                          icon: Icon(Icons.fullscreen, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                    onPressed: () async {
                      // נפתח מפה במסך מלא עם אותם עוזרים
                      final helpers = await _loadRelevantHelpersForMap(request);
                          // Guard context usage after async gap
                          if (!context.mounted) return;
                      _openFullScreenMap(context, request, helpers);
                    },
                    tooltip: AppLocalizations.of(context).openFullScreen,
                  ),
                  IconButton(
                          icon: Icon(Icons.refresh, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                    onPressed: () {
                      // רענון המפה
                      setState(() {});
                    },
                    tooltip: 'רענון מפה',
                  ),
                ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              // הודעה על מספר נותני שירות בטווח
              StreamBuilder<List<HelperLocation>>(
                stream: _getRelevantHelpersStream(request),
                builder: (context, snapshot) {
                  final l10n = AppLocalizations.of(context);
                  final helperLocations = snapshot.data ?? [];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          l10n.helpersInRange(helperLocations.length, request.exposureRadius!.toStringAsFixed(1)),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SafeArea(
                    child: StreamBuilder<List<HelperLocation>>(
                      stream: _getRelevantHelpersStream(request),
                      builder: (context, snapshot) {
                        final l10n = AppLocalizations.of(context);
                        final helperLocations = snapshot.data ?? [];
                        return FutureBuilder<Set<Marker>>(
                          future: _createMarkersForMap(request, helperLocations, context),
                          builder: (context, markersSnapshot) {
                            final markers = markersSnapshot.data ?? <Marker>{};
                        
                        return Stack(
                          children: [
                            GoogleMap(
                          onMapCreated: (GoogleMapController controller) {
                            try {
                              // Map controller is ready
                              debugPrint('Google Map created successfully in MyRequestsScreen');
                            } catch (e) {
                              debugPrint('Error in GoogleMap onMapCreated: $e');
                            }
                          },
                          initialCameraPosition: CameraPosition(
                            target: LatLng(request.latitude!, request.longitude!),
                            zoom: 12.0,
                          ),
                          markers: markers,
                          circles: _createCirclesForMap(request),
                          polygons: _createPolygonsForMap(request),
                          mapType: MapType.normal,
                          onTap: (LatLng position) {
                            // Handle map tap
                          },
                          onCameraMove: (CameraPosition position) {
                            // Handle camera move
                          },
                          onCameraIdle: () {
                            // Handle camera idle
                          },
                        ),
                          // הודעה על עדכון אוטומטי
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.updatesEvery30Seconds,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // מידע על נותני שירות
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.yourRequestLocation,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.subscribedHelpers,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          l10n.rangeKm(request.exposureRadius!.toStringAsFixed(1)),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // מידע על דירוגים מינימליים
                    if (request.minRating != null ||
                        request.minReliability != null ||
                        request.minAvailability != null ||
                        request.minAttitude != null ||
                        request.minFairPrice != null) ...[
                      Text(
                        AppLocalizations.of(context).minimalRatings,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (request.minRating != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                              ),
                              child: Text(
                                AppLocalizations.of(context).generalRating(request.minRating!.toStringAsFixed(1)),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          if (request.minReliability != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Theme.of(context).colorScheme.primary),
                              ),
                              child: Text(
                                AppLocalizations.of(context).reliabilityRating(request.minReliability!.toStringAsFixed(1)),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          if (request.minAvailability != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Theme.of(context).colorScheme.primary),
                              ),
                              child: Text(
                                AppLocalizations.of(context).availabilityRating(request.minAvailability!.toStringAsFixed(1)),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          if (request.minAttitude != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                              ),
                              child: Text(
                                AppLocalizations.of(context).attitudeRating(request.minAttitude!.toStringAsFixed(1)),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          if (request.minFairPrice != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                              ),
                              child: Text(
                                AppLocalizations.of(context).priceRating(request.minFairPrice!.toStringAsFixed(1)),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else if (request.latitude != null && request.longitude != null && request.exposureRadius != null && 
                request.type != RequestType.paid) ...[
              // הודעה עבור בקשות לא בתשלום
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.tertiary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.mapAvailableOnly,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.goToSeeSubscribedHelpers,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            Row(
              children: [
                // הצגת כפתור עריכה תמיד עבור בקשות פתוחות
                if (request.status == RequestStatus.open) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editRequest(request),
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(l10n.editRequest),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteRequest(request),
                    icon: const Icon(Icons.delete, size: 16),
                    label: Text(l10n.deleteRequest),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            // הצגת כפתורי צ'אט עבור עוזרים שהביעו עניין
            if (request.helpers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.helpersWhoShowedInterest,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).colorScheme.onSurface 
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: request.helpers)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    final l10n = AppLocalizations.of(context);
                    return Text(l10n.noHelpersAvailable);
                  }
                  
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: snapshot.data!.docs.map<Widget>((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final helperUid = doc.id;
                      final helperName = userData['displayName'] as String? ?? AppLocalizations.of(context).helper;
                      
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .where('requestId', isEqualTo: request.requestId)
                            .where('participants', arrayContains: helperUid)
                            .snapshots(),
                        builder: (context, chatSnapshot) {
                          if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          
                          // חיפוש הצ'אט הספציפי עם העוזר הזה שלא נמחק
                          // אם יש כמה צ'אטים, נבחר את החדש ביותר (לפי updatedAt)
                          QueryDocumentSnapshot? specificChat;
                          DateTime? latestUpdatedAt;
                          
                          for (var chatDoc in chatSnapshot.data!.docs) {
                            final chatData = chatDoc.data() as Map<String, dynamic>;
                            final participants = List<String>.from(chatData['participants'] ?? []);
                            final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                            
                            if (participants.contains(helperUid) && participants.contains(currentUserId)) {
                              // בדיקה אם יוצר הבקשה מחק את הצ'אט
                              // יוצר הבקשה יכול למחוק את הצ'אט מצדו
                              // אם הצ'אט נמחק, נדלג עליו ונחפש צ'אט חדש
                              if (deletedBy.contains(currentUserId)) {
                                debugPrint('Chat ${chatDoc.id} was deleted by current user $currentUserId, skipping...');
                                continue; // נדלג על צ'אט שנמחק ונחפש צ'אט חדש
                              }
                              
                              // בחירת הצ'אט החדש ביותר (לפי updatedAt)
                              final updatedAt = (chatData['updatedAt'] as Timestamp?)?.toDate();
                              if (updatedAt != null) {
                                if (latestUpdatedAt == null || updatedAt.isAfter(latestUpdatedAt)) {
                                  specificChat = chatDoc;
                                  latestUpdatedAt = updatedAt;
                                }
                              } else if (specificChat == null) {
                                // אם אין updatedAt, נשתמש בצ'אט הראשון שלא נמחק
                                specificChat = chatDoc;
                              }
                            }
                          }
                          
                          // אם לא נמצא צ'אט ספציפי שלא נמחק, לא נציג כפתור
                          if (specificChat == null) {
                            return const SizedBox.shrink();
                          }
                          
                          // בדיקה נוספת אם הצ'אט נמחק על ידי יוצר הבקשה או נותן השירות
                          final chatData = specificChat.data() as Map<String, dynamic>;
                          final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                          final isClosed = chatData['isClosed'] as bool? ?? false;
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                          
                          // אם מבקש השירות מחק את הצ'אט, לא נציג אותו
                          if (deletedBy.contains(currentUserId)) {
                            return const SizedBox.shrink(); // לא להציג את הצ'אט ליוצר הבקשה
                          }
                          
                          // בדיקה אם נותן השירות מחק את הצ'אט
                          // אם כן, הצ'אט יופיע כסגור אבל לא יוסתר
                          final isDeletedByServiceProvider = deletedBy.isNotEmpty && 
                              !deletedBy.contains(currentUserId);
                          final shouldShowAsClosed = isClosed || isDeletedByServiceProvider;
                          
                          return Stack(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _openChat(request.requestId, helperUid),
                                  icon: shouldShowAsClosed 
                                    ? const Icon(Icons.lock, size: 16)
                                    : const Icon(Icons.chat, size: 16),
                                  label: Text(shouldShowAsClosed 
                                    ? l10n.chatClosedWith(helperName)
                                    : l10n.chatWith(helperName)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: shouldShowAsClosed ? Colors.grey : Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              // ספירת הודעות חדשות
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('chats')
                                    .where('requestId', isEqualTo: request.requestId)
                                    .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                                    .snapshots(),
                                builder: (context, chatSnapshot) {
                                  if (chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty) {
                                    // חיפוש הצ'אט הספציפי עם העוזר הזה
                                    QueryDocumentSnapshot? specificChat;
                                    for (var doc in chatSnapshot.data!.docs) {
                                      final chatData = doc.data() as Map<String, dynamic>;
                                      final participants = List<String>.from(chatData['participants'] ?? []);
                                      final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                      
                                      if (participants.contains(helperUid)) {
                                        // בדיקה אם יוצר הבקשה מחק את הצ'אט
                                        // יוצר הבקשה יכול למחוק את הצ'אט מצדו
                                        if (deletedBy.contains(currentUserId)) {
                                          continue; // דלג על צ'אט שנמחק על ידי יוצר הבקשה
                                        }
                                        specificChat = doc;
                                        break;
                                      }
                                    }
                                    
                                    // אם לא נמצא צ'אט ספציפי, לא נציג ספירה
                                    if (specificChat == null) {
                                      return const SizedBox.shrink();
                                    }
                                    
                                    final chatId = specificChat.id;
                                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                    
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .collection('messages')
                                          .snapshots(),
                                      builder: (context, messageSnapshot) {
                                        if (messageSnapshot.hasData) {
                                          // ספירת הודעות שלא נקראו על ידי המשתמש הנוכחי
                                          int unreadCount = 0;
                                          for (var doc in messageSnapshot.data!.docs) {
                                            final messageData = doc.data() as Map<String, dynamic>;
                                            final from = messageData['from'] as String?;
                                            final readBy = messageData['readBy'] as List<dynamic>? ?? [];
                                            debugPrint('Message ${doc.id}: from=$from, readBy=$readBy, currentUserId=$currentUserId');
                                            
                                            // רק הודעות שלא נשלחו על ידי המשתמש הנוכחי
                                            if (from != currentUserId) {
                                            // בדיקה אם המשתמש הנוכחי נמצא בצ'אט
                                            // Note: This is a synchronous check, we'll handle async operations differently
                                            // For now, we'll count all unread messages
                                            if (!readBy.contains(currentUserId)) {
                                              unreadCount++;
                                              debugPrint('Unread message ${doc.id} from $from');
                                            }
                                            }
                                          }
                                          
                                          debugPrint('Total unread count for chat $chatId: $unreadCount');
                                          
                                          if (unreadCount > 0) {
                                            return Positioned(
                                              right: 0,
                                              top: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 16,
                                                  minHeight: 16,
                                                ),
                                                child: Text(
                                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
            // הצגת כפתור "סמן כטופל" אם יש עוזרים או נותני שירות זמינים במפה
            // הלחצן יוצג גם אם הסטטוס הוא "פתוח" או "בטיפול"
            if (request.status == RequestStatus.open || request.status == RequestStatus.inProgress) ...[
              // בדיקה אם יש עוזרים או נותני שירות זמינים במפה
              StreamBuilder<List<HelperLocation>>(
                stream: request.type == RequestType.paid ? _getRelevantHelpersStream(request) : Stream.value([]),
                builder: (context, snapshot) {
                  final helperLocations = snapshot.data ?? [];
                  final hasHelpers = request.helpers.isNotEmpty;
                  final hasMapHelpers = helperLocations.isNotEmpty;
                  
                  // הצג את הלחצן רק אם יש עוזרים או נותני שירות זמינים במפה
                  if (hasHelpers || hasMapHelpers) {
                    return Column(
                      children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsCompleted(request),
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(l10n.markAsCompleted),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            ],
            // כפתור "בטל טופל" ו"מחק בקשה" מוצגים גם אם הבקשה מכווצת
            if (request.status == RequestStatus.completed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsOpen(request),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(l10n.cancelCompleted),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteRequest(request),
                      icon: const Icon(Icons.delete, size: 16),
                      label: Text(l10n.deleteRequest),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ));
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.open:
        return Colors.green;
      case RequestStatus.completed:
        return Colors.blue;
      case RequestStatus.cancelled:
        return Colors.red;
      case RequestStatus.inProgress:
        return Colors.orange;
    }
  }

  String _getStatusText(RequestStatus status) {
    // ✅ Safe: Get AppLocalizations with null check
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (l10n == null) {
      // Fallback to English if localization is not available
    switch (status) {
      case RequestStatus.open:
          return 'Open';
      case RequestStatus.completed:
          return 'Completed';
      case RequestStatus.cancelled:
          return 'Cancelled';
      case RequestStatus.inProgress:
          return 'In Progress';
      }
    }
    // ✅ Safe: All status getters now use _safeGet with fallbacks
    switch (status) {
      case RequestStatus.open:
        return l10n.statusOpen;
      case RequestStatus.completed:
        return l10n.statusCompleted;
      case RequestStatus.cancelled:
        return l10n.statusCancelled;
      case RequestStatus.inProgress:
        return l10n.statusInProgress;
    }
  }

  Future<void> _markAsCompleted(Request request) async {
    if (!mounted) return;
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectHelperForRatingScreen(request: request),
      ),
    );
    
    if (result == true) {
      setState(() {});
    }
  }


  Future<void> _deleteRequestRatings(String requestId) async {
    try {
      debugPrint('🔍 Deleting ratings for request: $requestId');
      
      // חיפוש כל הדירוגים הקשורים לבקשה זו
      final ratingsQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .where('requestId', isEqualTo: requestId)
          .get();
      
      debugPrint('Found ${ratingsQuery.docs.length} ratings for request $requestId');
      
      for (final ratingDoc in ratingsQuery.docs) {
        final ratingData = ratingDoc.data();
        final userId = ratingData['userId'] as String?;
        final category = ratingData['category'] as String?;
        final rating = ratingData['rating'] as num?;
        
        if (userId != null && category != null && rating != null) {
          debugPrint('🔍 Deleting rating: user=$userId, category=$category, rating=$rating');
          
          // מחיקת הדירוג
          await ratingDoc.reference.delete();
          
          // עדכון הסטטיסטיקות של המשתמש
          await _updateUserStatsAfterRatingDeletion(userId, ratingData);
        }
      }
      
      debugPrint('✅ All ratings deleted for request $requestId');
    } catch (e) {
      debugPrint('❌ Error deleting request ratings: $e');
    }
  }


  Future<void> _updateUserStatsAfterRatingDeletion(String userId, Map<String, dynamic> ratingData) async {
    try {
      final category = ratingData['category'] as String?;
      final rating = ratingData['rating'] as num?;
      
      if (category == null || rating == null) return;
      
      debugPrint('🔍 Updating user stats after rating deletion: user=$userId, category=$category, rating=$rating');
      
      // קבלת הסטטיסטיקות הנוכחיות של המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final ratings = Map<String, dynamic>.from(userData['ratings'] ?? {});
      final categoryRatings = List<num>.from(ratings[category] ?? []);
      
      // הסרת הדירוג מהרשימה
      categoryRatings.remove(rating);
      
      // חישוב ממוצע חדש
      double newAverage = 0.0;
      int newCount = categoryRatings.length;
      
      if (newCount > 0) {
        newAverage = categoryRatings.reduce((a, b) => a + b) / newCount;
      }
      
      // עדכון הסטטיסטיקות
      ratings[category] = categoryRatings;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'ratings': ratings,
        'averageRating': newAverage,
        'ratingCount': newCount,
        'updatedAt': DateTime.now(),
      });
      
      debugPrint('✅ User stats updated: newAverage=$newAverage, newCount=$newCount');
    } catch (e) {
      debugPrint('❌ Error updating user stats: $e');
    }
  }

  // פתיחת מחדש של הצ'אטים הסגורים
  Future<void> _reopenClosedChats(String requestId) async {
    try {
      debugPrint('🔓 Reopening closed chats for request: $requestId');
      
      // חיפוש כל הצ'אטים הקשורים לבקשה זו
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .get();
      
      debugPrint('🔓 Found ${chatsQuery.docs.length} chats for request');
      
      for (final chatDoc in chatsQuery.docs) {
        final chatData = chatDoc.data();
        final isClosed = chatData['isClosed'] as bool? ?? false;
        
        if (isClosed) {
          debugPrint('🔓 Reopening chat: ${chatDoc.id}');
          
          // פתיחת הצ'אט מחדש
          await chatDoc.reference.update({
            'isClosed': false,
            'reopenedAt': FieldValue.serverTimestamp(),
            'lastMessage': AppLocalizations.of(context).chatReopened,
            'updatedAt': FieldValue.serverTimestamp(),
            // הסרת כל המשתמשים מרשימת המחיקות כדי שהבקשה תחזור להופיע
            'deletedBy': FieldValue.delete(),
            'deletedAt': FieldValue.delete(),
          });
          
          // שליחת הודעת מערכת על פתיחה מחדש
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatDoc.id)
              .collection('messages')
              .add({
            'from': 'system',
            'text': AppLocalizations.of(context).chatReopenedCanSend,
            'timestamp': FieldValue.serverTimestamp(),
            'isSystemMessage': true,
            'messageType': 'reopened',
          });
          
          debugPrint('✅ Chat ${chatDoc.id} reopened successfully');
        }
      }
    } catch (e) {
      debugPrint('❌ Error reopening closed chats: $e');
    }
  }

  Future<void> _markAsOpen(Request request) async {
    try {
      // פתיחת מחדש של הצ'אטים הסגורים
      await _reopenClosedChats(request.requestId);

      // מחיקת הדירוגים הקשורים לבקשה זו
      await _deleteRequestRatings(request.requestId);

      // עדכון סטטוס הבקשה לפתוח + עדכון תאריך כדי שתופיע בראש הרשימה
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.requestId)
          .update({
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(), // עדכון התאריך לזמן נוכחי
        'updatedAt': FieldValue.serverTimestamp(), // הוספת שדה עדכון
        // לא מאפסים את רשימת העוזרים - שומרים על הצ'אטים הקיימים
      });

      if (!mounted) return;
      
      // עדכון המסך כדי להציג את השינוי
      setState(() {});
      
      // עדכון מונה הבקשות החודשיות בפרופיל
      await _notifyProfileScreenOfRequestDeletion();
      
      // Guard context usage after async gap
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).requestReopenedChatsReopened),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorGeneral(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editRequest(Request request) async {
    if (!mounted) return;
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditRequestScreen(request: request),
      ),
    );
    
    // אם העריכה הצליחה, נעדכן את ה-UI
    if (result == true) {
      setState(() {});
      // עדכון מונה הבקשות החודשיות בפרופיל
      await _notifyProfileScreenOfRequestDeletion();
    }
  }

  Future<void> _deleteRequest(Request request) async {
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteRequestTitle),
        content: Text(AppLocalizations.of(context).deleteRequestConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        // מחיקת תמונות מ-Firebase Storage אם יש
        if (request.images.isNotEmpty) {
          await _deleteImagesFromStorage(request.images);
        }
        
        // מחיקת הבקשה מ-Firestore
        await FirebaseFirestore.instance
            .collection('requests')
            .doc(request.requestId)
            .delete();
        
        // עדכון מונה הבקשות החודשיות בפרופיל
        await _notifyProfileScreenOfRequestDeletion();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).requestDeletedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorDeletingRequest(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// הודעה למסך הפרופיל על מחיקת בקשה
  Future<void> _notifyProfileScreenOfRequestDeletion() async {
    try {
      // עדכון זמן העדכון האחרון ב-SharedPreferences
      // זה יגרום למסך הפרופיל לטעון מחדש את המונה
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_request_deletion', DateTime.now().toIso8601String());
      
      debugPrint('✅ Profile screen notified of request deletion');
    } catch (e) {
      debugPrint('❌ Error notifying profile screen: $e');
    }
  }

  /// מחיקת תמונות מ-Firebase Storage
  Future<void> _deleteImagesFromStorage(List<String> imageUrls) async {
    try {
      debugPrint('🗑️ Starting to delete ${imageUrls.length} images from Storage');
      
      int deletedCount = 0;
      
      for (String imageUrl in imageUrls) {
        try {
          // חילוץ הנתיב מהקישור
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
          deletedCount++;
          debugPrint('✅ Deleted image: ${ref.fullPath}');
        } catch (e) {
          debugPrint('❌ Failed to delete image $imageUrl: $e');
          // נמשיך למחוק תמונות אחרות גם אם אחת נכשלת
        }
      }
      
      debugPrint('🗑️ Successfully deleted $deletedCount out of ${imageUrls.length} images');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).deletedImagesFromStorage(deletedCount)),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting images from Storage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorDeletingImages(e.toString())),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // פתיחת צ'אט מהדיאלוג - פונקציה נפרדת שתעבוד עם הדיאלוג
  Future<void> _openChatWithHelperFromDialog(String requestId, String helperUid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('Opening chat from dialog for request: $requestId, user: $user.uid, helper: $helperUid');

      // קבלת פרטי הבקשה כדי למצוא את יוצר הבקשה
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final requestData = requestDoc.data()!;
      final creatorId = requestData['createdBy'] as String;

      // חיפוש צ'אט קיים עם העוזר הספציפי שלא נמחק
      final chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .where('participants', arrayContains: helperUid)
          .get();

      String? chatId;

      if (chatQuery.docs.isNotEmpty) {
        // חיפוש הצ'אט הספציפי עם שני המשתתפים שלא נמחק
        for (var doc in chatQuery.docs) {
          final chatData = doc.data();
          final participants = List<String>.from(chatData['participants'] ?? []);
          if (participants.contains(creatorId) && participants.contains(helperUid)) {
            // בדיקה אם הצ'אט נמחק על ידי המשתמש הנוכחי
            final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
            if (deletedBy.contains(user.uid)) {
              debugPrint('Found existing chat ${doc.id} but it was deleted by current user ${user.uid}, will create new one');
              continue; // נמשיך לחפש או ליצור צ'אט חדש
            }
            
            chatId = doc.id;
            debugPrint('Found existing chat: $chatId');
            break;
          }
        }
      }

      // אם לא נמצא צ'אט קיים, ניצור צ'אט חדש
      if (chatId == null) {
        debugPrint('No existing chat found, creating new one...');
        
        // הוספת נותן השירות ל-`helpers` array של הבקשה כדי שהבקשה תופיע אצלו במסך "פניות שלי"
        // רק אם הבקשה היא "בתשלום" ונותן השירות הוא אורח/עסקי מנוי (לא מנהל)
        try {
          final requestRef = FirebaseFirestore.instance.collection('requests').doc(requestId);
          final currentRequestDoc = await requestRef.get();
          
          if (currentRequestDoc.exists) {
            final currentRequestData = currentRequestDoc.data()!;
            final requestType = currentRequestData['type'] as String?;
            
            // בדיקה אם הבקשה היא "בתשלום"
            if (requestType != 'paid') {
              debugPrint('ℹ️ Request $requestId is not paid, skipping helper addition');
            } else {
              // בדיקה אם נותן השירות הוא אורח/עסקי מנוי (לא מנהל)
              final helperDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(helperUid)
                  .get();
              
              if (!helperDoc.exists) {
                debugPrint('⚠️ Helper $helperUid not found in users collection');
              } else {
                final helperData = helperDoc.data()!;
                final helperUserType = helperData['userType'] as String?;
                final helperIsAdmin = helperData['isAdmin'] as bool? ?? false;
                final helperEmail = helperData['email'] as String?;
                
                // בדיקה אם נותן השירות הוא אורח/עסקי מנוי (לא מנהל)
                final isGuest = helperUserType == 'guest';
                final isBusinessSubscription = helperUserType == 'business' && 
                    (helperData['isSubscriptionActive'] as bool? ?? false);
                final isAdmin = helperIsAdmin || 
                    helperEmail == 'admin@gmail.com' || 
                    helperEmail == 'haitham.ay82@gmail.com';
                
                // מנהלים לא מתווספים ל-helpers array - הם יכולים לראות את כל הבקשות אבל לא מופיעים ב"פניות שלי"
                if (isAdmin) {
                  debugPrint('ℹ️ Helper $helperUid is admin - skipping helper addition (admins can see all requests but do not appear in "My Requests")');
                } else if (!isGuest && !isBusinessSubscription) {
                  debugPrint('ℹ️ Helper $helperUid is not guest/business subscription, skipping helper addition');
                } else {
                  final helpers = List<String>.from(currentRequestData['helpers'] ?? []);
                  
                  // אם נותן השירות עדיין לא ב-`helpers` array, נוסיף אותו
                  if (!helpers.contains(helperUid)) {
                    final currentStatus = currentRequestData['status'] as String?;
                    
                    // עדכון helpers
                    final updateData = <String, dynamic>{
                      'helpers': FieldValue.arrayUnion([helperUid]),
                      'helpersCount': FieldValue.increment(1),
                    };
                    
                    // אם יש עוזרים והסטטוס הוא "פתוח", עדכן ל-"בטיפול"
                    if (helpers.isEmpty && currentStatus == 'open') {
                      updateData['status'] = 'inProgress';
                      debugPrint('✅ Added helper: Updating status from "open" to "inProgress"');
                    }
                    
                    await requestRef.update(updateData);
                    debugPrint('✅ Added helper $helperUid to request $requestId helpers array');
                    
                    // שמירת זמן ההתעניינות ב-user_interests collection למיון במסך "פניות שלי"
                    try {
                      await FirebaseFirestore.instance
                          .collection('user_interests')
                          .doc('${helperUid}_$requestId')
                          .set({
                        'userId': helperUid,
                        'requestId': requestId,
                        'interestTime': FieldValue.serverTimestamp(),
                      });
                      debugPrint('✅ Saved interest time for helper $helperUid in request $requestId');
                      
                      // המתנה קצרה כדי לוודא שהעדכון ב-Firestore נשמר לפני שהמיון יתבצע
                      // זה מבטיח שהבקשה תופיע בתחילת הרשימה במסך "פניות שלי"
                      await Future.delayed(const Duration(milliseconds: 500));
                    } catch (e) {
                      debugPrint('⚠️ Failed to save interest time: $e');
                    }
                  } else {
                    debugPrint('ℹ️ Helper $helperUid already in request $requestId helpers array');
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to add helper to request: $e');
          // נמשיך ליצור את הצ'אט גם אם ההוספה ל-helpers נכשלה
        }
        
        chatId = await ChatService.createChat(
          requestId: requestId,
          creatorId: creatorId,
          helperId: helperUid,
        );

        if (chatId == null) {
          throw Exception('Failed to create chat');
        }
        debugPrint('Created new chat: $chatId');
      }

      if (!mounted) return;

      // עדכון מצב המשתמש - נכנס לצ'אט
      await AppStateService.enterChat(chatId);

      // סימון הודעות כנקראות (אם יש)
      await ChatService.markMessagesAsRead(chatId);

      // Guard context usage after async gap
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId!,
            requestTitle: requestData['title'] as String? ?? l10n.request,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat from dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorOpeningChat(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openChat(String requestId, String helperUid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('Opening chat for request: $requestId, user: ${user.uid}, helper: $helperUid');

      // חיפוש צ'אט קיים עם העוזר הספציפי
      final chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .where('participants', arrayContains: helperUid)
          .get();

      debugPrint('Found ${chatQuery.docs.length} chats for request $requestId with helper $helperUid');

      if (chatQuery.docs.isNotEmpty) {
        // חיפוש הצ'אט הספציפי עם שני המשתתפים שלא נמחק
        QueryDocumentSnapshot? specificChat;
        for (var doc in chatQuery.docs) {
          final chatData = doc.data();
          final participants = List<String>.from(chatData['participants'] ?? []);
          if (participants.contains(user.uid) && participants.contains(helperUid)) {
            // בדיקה אם הצ'אט נמחק על ידי המשתמש הנוכחי
            final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
            if (deletedBy.contains(user.uid)) {
              debugPrint('Found existing chat ${doc.id} but it was deleted by current user ${user.uid}, will create new one');
              continue; // נמשיך לחפש או ליצור צ'אט חדש
            }
            
            specificChat = doc;
            break;
          }
        }
        
        if (specificChat != null) {
          final chatId = specificChat.id;
          debugPrint('Found existing chat: $chatId');
          
          if (!mounted) return;
          
          // עדכון מצב המשתמש - נכנס לצ'אט
          await AppStateService.enterChat(chatId);
          
          // סימון הודעות כנקראות (אם יש)
          await ChatService.markMessagesAsRead(chatId);

          // Guard context usage after async gap
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                requestTitle: l10n.request, // TODO: קבלת כותרת הבקשה
              ),
            ),
          );
        } else {
          // לא נמצא צ'אט עם שני המשתתפים - ניצור צ'אט חדש
          debugPrint('No chat found with both participants, creating new one...');
          
          // קבלת פרטי הבקשה כדי למצוא את יוצר הבקשה
          final requestDoc = await FirebaseFirestore.instance
              .collection('requests')
              .doc(requestId)
              .get();
          
          if (requestDoc.exists) {
            final requestData = requestDoc.data()!;
            final creatorId = requestData['createdBy'] as String;
            
            // הוספת נותן השירות ל-`helpers` array של הבקשה כדי שהבקשה תופיע אצלו במסך "פניות שלי"
            // רק אם הבקשה היא "בתשלום" ונותן השירות הוא אורח/עסקי מנוי/מנהל
            try {
              final requestRef = FirebaseFirestore.instance.collection('requests').doc(requestId);
              final currentRequestData = requestDoc.data()!;
              final requestType = currentRequestData['type'] as String?;
              
              // בדיקה אם הבקשה היא "בתשלום"
              if (requestType != 'paid') {
                debugPrint('ℹ️ Request $requestId is not paid, skipping helper addition');
              } else {
                // בדיקה אם נותן השירות הוא אורח/עסקי מנוי/מנהל
                final helperDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(helperUid)
                    .get();
                
                if (!helperDoc.exists) {
                  debugPrint('⚠️ Helper $helperUid not found in users collection');
                } else {
                  final helperData = helperDoc.data()!;
                  final helperUserType = helperData['userType'] as String?;
                  final helperIsAdmin = helperData['isAdmin'] as bool? ?? false;
                  final helperEmail = helperData['email'] as String?;
                  
                  // בדיקה אם נותן השירות הוא אורח/עסקי מנוי (לא מנהל)
                  final isGuest = helperUserType == 'guest';
                  final isBusinessSubscription = helperUserType == 'business' && 
                      (helperData['isSubscriptionActive'] as bool? ?? false);
                  final isAdmin = helperIsAdmin || 
                      helperEmail == 'admin@gmail.com' || 
                      helperEmail == 'haitham.ay82@gmail.com';
                  
                  // מנהלים לא מתווספים ל-helpers array - הם יכולים לראות את כל הבקשות אבל לא מופיעים ב"פניות שלי"
                  if (isAdmin) {
                    debugPrint('ℹ️ Helper $helperUid is admin - skipping helper addition (admins can see all requests but do not appear in "My Requests")');
                  } else if (!isGuest && !isBusinessSubscription) {
                    debugPrint('ℹ️ Helper $helperUid is not guest/business subscription, skipping helper addition');
                  } else {
                    final helpers = List<String>.from(currentRequestData['helpers'] ?? []);
                    
                    // אם נותן השירות עדיין לא ב-`helpers` array, נוסיף אותו
                    if (!helpers.contains(helperUid)) {
                      final currentStatus = currentRequestData['status'] as String?;
                      
                      // עדכון helpers
                      final updateData = <String, dynamic>{
                        'helpers': FieldValue.arrayUnion([helperUid]),
                        'helpersCount': FieldValue.increment(1),
                      };
                      
                      // אם יש עוזרים והסטטוס הוא "פתוח", עדכן ל-"בטיפול"
                      if (helpers.isEmpty && currentStatus == 'open') {
                        updateData['status'] = 'inProgress';
                        debugPrint('✅ Added helper: Updating status from "open" to "inProgress"');
                      }
                      
                      await requestRef.update(updateData);
                      debugPrint('✅ Added helper $helperUid to request $requestId helpers array');
                      
                      // שמירת זמן ההתעניינות ב-user_interests collection למיון במסך "פניות שלי"
                      try {
                        await FirebaseFirestore.instance
                            .collection('user_interests')
                            .doc('${helperUid}_$requestId')
                            .set({
                          'userId': helperUid,
                          'requestId': requestId,
                          'interestTime': FieldValue.serverTimestamp(),
                        });
                        debugPrint('✅ Saved interest time for helper $helperUid in request $requestId');
                        
                        // המתנה קצרה כדי לוודא שהעדכון ב-Firestore נשמר לפני שהמיון יתבצע
                        // זה מבטיח שהבקשה תופיע בתחילת הרשימה במסך "פניות שלי"
                        await Future.delayed(const Duration(milliseconds: 500));
                      } catch (e) {
                        debugPrint('⚠️ Failed to save interest time: $e');
                      }
                    } else {
                      debugPrint('ℹ️ Helper $helperUid already in request $requestId helpers array');
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('⚠️ Failed to add helper to request: $e');
              // נמשיך ליצור את הצ'אט גם אם ההוספה ל-helpers נכשלה
            }
            
            // יצירת צ'אט חדש באמצעות ChatService
            final chatId = await ChatService.createChat(
              requestId: requestId,
              creatorId: creatorId,
              helperId: helperUid,
            );
            
            if (chatId != null) {
              debugPrint('Created new chat: $chatId');

              if (!mounted) return;

              // עדכון מצב המשתמש - נכנס לצ'אט
              await AppStateService.enterChat(chatId);
              
              // סימון הודעות כנקראות (אם יש)
              await ChatService.markMessagesAsRead(chatId);

              // Guard context usage after async gap
              if (!mounted) return;
              final l10n = AppLocalizations.of(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chatId,
                    requestTitle: l10n.request, // TODO: קבלת כותרת הבקשה
                  ),
                ),
              );
            } else {
              throw Exception('Failed to create chat');
            }
          } else {
            throw Exception('Request not found');
          }
        }
      } else {
        debugPrint('No existing chat found, creating new one...');
        
        // קבלת פרטי הבקשה כדי למצוא את יוצר הבקשה
        final requestDoc = await FirebaseFirestore.instance
            .collection('requests')
            .doc(requestId)
            .get();
        
        if (requestDoc.exists) {
          final requestData = requestDoc.data()!;
          final creatorId = requestData['createdBy'] as String;
          
          // הוספת נותן השירות ל-`helpers` array של הבקשה כדי שהבקשה תופיע אצלו במסך "פניות שלי"
          // רק אם הבקשה היא "בתשלום" ונותן השירות הוא אורח/עסקי מנוי/מנהל
          try {
            final requestRef = FirebaseFirestore.instance.collection('requests').doc(requestId);
            final currentRequestData = requestDoc.data()!;
            final requestType = currentRequestData['type'] as String?;
            
            // בדיקה אם הבקשה היא "בתשלום"
            if (requestType != 'paid') {
              debugPrint('ℹ️ Request $requestId is not paid, skipping helper addition');
            } else {
              // בדיקה אם נותן השירות הוא אורח/עסקי מנוי/מנהל
              final helperDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(helperUid)
                  .get();
              
              if (!helperDoc.exists) {
                debugPrint('⚠️ Helper $helperUid not found in users collection');
              } else {
                final helperData = helperDoc.data()!;
                final helperUserType = helperData['userType'] as String?;
                final helperIsAdmin = helperData['isAdmin'] as bool? ?? false;
                final helperEmail = helperData['email'] as String?;
                
                // בדיקה אם נותן השירות הוא אורח/עסקי מנוי (לא מנהל)
                final isGuest = helperUserType == 'guest';
                final isBusinessSubscription = helperUserType == 'business' && 
                    (helperData['isSubscriptionActive'] as bool? ?? false);
                final isAdmin = helperIsAdmin || 
                    helperEmail == 'admin@gmail.com' || 
                    helperEmail == 'haitham.ay82@gmail.com';
                
                // מנהלים לא מתווספים ל-helpers array - הם יכולים לראות את כל הבקשות אבל לא מופיעים ב"פניות שלי"
                if (isAdmin) {
                  debugPrint('ℹ️ Helper $helperUid is admin - skipping helper addition (admins can see all requests but do not appear in "My Requests")');
                } else if (!isGuest && !isBusinessSubscription) {
                  debugPrint('ℹ️ Helper $helperUid is not guest/business subscription, skipping helper addition');
                } else {
                  final helpers = List<String>.from(currentRequestData['helpers'] ?? []);
                  
                  // אם נותן השירות עדיין לא ב-`helpers` array, נוסיף אותו
                  if (!helpers.contains(helperUid)) {
                    final currentStatus = currentRequestData['status'] as String?;
                    
                    // עדכון helpers
                    final updateData = <String, dynamic>{
                      'helpers': FieldValue.arrayUnion([helperUid]),
                      'helpersCount': FieldValue.increment(1),
                    };
                    
                    // אם יש עוזרים והסטטוס הוא "פתוח", עדכן ל-"בטיפול"
                    if (helpers.isEmpty && currentStatus == 'open') {
                      updateData['status'] = 'inProgress';
                      debugPrint('✅ Added helper: Updating status from "open" to "inProgress"');
                    }
                    
                    await requestRef.update(updateData);
                    debugPrint('✅ Added helper $helperUid to request $requestId helpers array');
                    
                    // שמירת זמן ההתעניינות ב-user_interests collection למיון במסך "פניות שלי"
                    try {
                      await FirebaseFirestore.instance
                          .collection('user_interests')
                          .doc('${helperUid}_$requestId')
                          .set({
                        'userId': helperUid,
                        'requestId': requestId,
                        'interestTime': FieldValue.serverTimestamp(),
                      });
                      debugPrint('✅ Saved interest time for helper $helperUid in request $requestId');
                      
                      // המתנה קצרה כדי לוודא שהעדכון ב-Firestore נשמר לפני שהמיון יתבצע
                      // זה מבטיח שהבקשה תופיע בתחילת הרשימה במסך "פניות שלי"
                      await Future.delayed(const Duration(milliseconds: 500));
                    } catch (e) {
                      debugPrint('⚠️ Failed to save interest time: $e');
                    }
                  } else {
                    debugPrint('ℹ️ Helper $helperUid already in request $requestId helpers array');
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to add helper to request: $e');
            // נמשיך ליצור את הצ'אט גם אם ההוספה ל-helpers נכשלה
          }
          
          // יצירת צ'אט חדש באמצעות ChatService
          final chatId = await ChatService.createChat(
            requestId: requestId,
            creatorId: creatorId,
            helperId: helperUid,
          );
          
          if (chatId != null) {
            debugPrint('Created new chat: $chatId');

            if (!mounted) return;

            // עדכון מצב המשתמש - נכנס לצ'אט
            await AppStateService.enterChat(chatId);
            
            // סימון הודעות כנקראות (אם יש)
            await ChatService.markMessagesAsRead(chatId);

            // Guard context usage after async gap
            if (!mounted) return;
            final l10n = AppLocalizations.of(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  requestTitle: l10n.request, // TODO: קבלת כותרת הבקשה
                ),
              ),
            );
          } else {
            throw Exception('Failed to create chat');
          }
        } else {
          throw Exception('Request not found');
        }
      }
    } catch (e) {
      debugPrint('Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorOpeningChat(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // פונקציות עזר להצגת דחיפות
  IconData _getUrgencyIcon(UrgencyLevel urgencyLevel) {
    switch (urgencyLevel) {
      case UrgencyLevel.normal:
        return Icons.schedule;
      case UrgencyLevel.urgent24h:
        return Icons.warning;
      case UrgencyLevel.emergency:
        return Icons.priority_high;
    }
  }

  Color _getUrgencyColor(UrgencyLevel urgencyLevel) {
    switch (urgencyLevel) {
      case UrgencyLevel.normal:
        return Colors.green;
      case UrgencyLevel.urgent24h:
        return Colors.orange;
      case UrgencyLevel.emergency:
        return Colors.red;
    }
  }
}
