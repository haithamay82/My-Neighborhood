import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
  Stream<List<UserProfile>> _getRelevantHelpersStream(Request request) {
    return Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => _loadRelevantHelpersForMap(request));
  }

  // פתיחת מפה במסך מלא עם אותם סימונים
  void _openFullScreenMap(BuildContext context, Request request, List<UserProfile> helpers) {
    final markers = _createMarkersForMap(request, helpers);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('מפה - מסך מלא'),
          ),
          body: SafeArea(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(request.latitude!, request.longitude!),
                zoom: 12.0,
              ),
              markers: markers,
              circles: _createCirclesForMap(request),
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
  Future<List<UserProfile>> _loadRelevantHelpersForMap(Request request) async {
    debugPrint('🗺️ ===== LOADING RELEVANT HELPERS FOR MAP =====');
    debugPrint('🗺️ Request: ${request.title}');
    debugPrint('🗺️ Request category: ${request.category}');
    debugPrint('🗺️ Request location: ${request.latitude}, ${request.longitude}');
    debugPrint('🗺️ Request radius: ${request.exposureRadius}');
    debugPrint('🗺️ Request type: ${request.type}');
    debugPrint('🗺️ Request minRating: ${request.minRating}');
    
    if (request.latitude == null || request.longitude == null || request.exposureRadius == null) {
      debugPrint('🗺️ Request missing location or radius data');
      return [];
    }
    
    // רק עבור בקשות בתשלום
    if (request.type != RequestType.paid) {
      debugPrint('🗺️ Request is not paid type');
      return [];
    }
    
    try {
      final helpers = <UserProfile>[];
      
      // 1. טעינת מנהלים (אם יש) - בדרך כלל מעטים
      debugPrint('🗺️ Querying admins...');
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();
      
      for (var doc in adminsSnapshot.docs) {
        final userProfile = UserProfile.fromFirestore(doc);
        if (userProfile.userId != request.createdBy) {
        // מנהל תמיד מופיע במפה ללא קשר לקטגוריה - יש לו גישה לכל התחומים
        // בדיקת מיקום - פעיל או קבוע
        double? helperLat, helperLng;
        bool isActiveLocation = false;
        
        // מיקום פעיל (אם יש)
        if (userProfile.latitude != null && userProfile.longitude != null) {
          helperLat = userProfile.latitude;
          helperLng = userProfile.longitude;
          isActiveLocation = true;
        }
        
        if (helperLat != null && helperLng != null) {
          final distance = LocationService.calculateDistance(
            request.latitude!,
            request.longitude!,
            helperLat,
            helperLng,
          );
            
            if (distance <= request.exposureRadius!) {
              debugPrint('🗺️ Admin ${userProfile.displayName} is within range - adding to map (admin has access to all categories)');
              helpers.add(userProfile);
            } else {
              debugPrint('🗺️ Admin ${userProfile.displayName} is outside range (${distance.toStringAsFixed(2)} km > ${request.exposureRadius} km)');
            }
          } else {
            debugPrint('🗺️ Admin ${userProfile.displayName} has no location data');
          }
        }
      }
      
      // 2. טעינת משתמשים עסקיים עם מנוי פעיל בקטגוריה הרלוונטית
      debugPrint('🗺️ Querying business users with active subscription...');
      final businessUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .get();
      
      debugPrint('🗺️ Found ${businessUsersSnapshot.docs.length} business users');
      
      for (var doc in businessUsersSnapshot.docs) {
        final userProfile = UserProfile.fromFirestore(doc);
        
        // בדיקה אם זה יוצר הבקשה עצמו
        if (userProfile.userId == request.createdBy) {
          continue;
        }
        
        // בדיקת קטגוריות
        bool hasMatchingCategory = false;
        if (userProfile.businessCategories != null) {
          final requestCatString = request.category.toString();
          for (final cat in userProfile.businessCategories!) {
            final catStr = cat.toString();
            if (cat == request.category || catStr == requestCatString) {
              hasMatchingCategory = true;
              break;
            }
            if (cat is String) {
              final reqName = request.category.toString().split('.').last;
              if (cat == reqName) {
                hasMatchingCategory = true;
                break;
              }
            }
          }
        }
        
        if (hasMatchingCategory) {
          // בדיקת מיקום - פעיל או קבוע
          double? helperLat, helperLng;
          bool isActiveLocation = false;
          
          // מיקום פעיל (אם יש)
          if (userProfile.latitude != null && userProfile.longitude != null) {
            helperLat = userProfile.latitude;
            helperLng = userProfile.longitude;
            isActiveLocation = true;
          }
          
          if (helperLat != null && helperLng != null) {
            final distance = LocationService.calculateDistance(
              request.latitude!,
              request.longitude!,
              helperLat,
              helperLng,
            );
          
          if (distance <= request.exposureRadius!) {
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
              debugPrint('🗺️ Business user ${userProfile.displayName} meets all requirements - adding to map');
              helpers.add(userProfile);
            }
          }
        }
      }
      
      // 3. טעינת משתמשי אורח בקטגוריה הרלוונטית
      debugPrint('🗺️ Querying guest users...');
      final guestUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'guest')
          .get();
      
      debugPrint('🗺️ Found ${guestUsersSnapshot.docs.length} guest users');
      
      for (var doc in guestUsersSnapshot.docs) {
        final userProfile = UserProfile.fromFirestore(doc);
        
        // בדיקה אם זה יוצר הבקשה עצמו
        if (userProfile.userId == request.createdBy) {
          continue;
        }
        
        // בדיקה אם משתמש אורח נמצא בשבוע הראשון או בחר תחומי עיסוק
        final now = DateTime.now();
        final trialStart = userProfile.guestTrialStartDate ?? now;
        final daysSinceStart = now.difference(trialStart).inDays;
        final isFirstWeek = daysSinceStart < 7;
        final hasCategories = userProfile.businessCategories != null && 
                             userProfile.businessCategories!.isNotEmpty;
        
        debugPrint('🗺️ Guest user ${userProfile.displayName}: first week: $isFirstWeek, has categories: $hasCategories');
        
        // שבוע ראשון - רואה כל הבקשות, או אחרי שבוע + בחר תחומי עיסוק
        bool canSeeRequest = false;
        if (isFirstWeek) {
          canSeeRequest = true;
          debugPrint('🗺️ Guest user ${userProfile.displayName} can see all requests (first week)');
        } else if (hasCategories) {
          // בדיקת קטגוריות
          bool hasMatchingCategory = false;
          if (userProfile.businessCategories != null) {
            final requestCatString = request.category.toString();
            for (final cat in userProfile.businessCategories!) {
              final catStr = cat.toString();
              if (cat == request.category || catStr == requestCatString) {
                hasMatchingCategory = true;
                break;
              }
              if (cat is String) {
                final reqName = request.category.toString().split('.').last;
                if (cat == reqName) {
                  hasMatchingCategory = true;
                  break;
                }
              }
            }
          }
          canSeeRequest = hasMatchingCategory;
          debugPrint('🗺️ Guest user ${userProfile.displayName} category match: $hasMatchingCategory');
        }
        
        if (canSeeRequest) {
          // בדיקת מיקום - פעיל או קבוע
          double? helperLat, helperLng;
          bool isActiveLocation = false;
          
          // מיקום פעיל (אם יש)
          if (userProfile.latitude != null && userProfile.longitude != null) {
            helperLat = userProfile.latitude;
            helperLng = userProfile.longitude;
            isActiveLocation = true;
          }
          
          if (helperLat != null && helperLng != null) {
            final distance = LocationService.calculateDistance(
              request.latitude!,
              request.longitude!,
              helperLat,
              helperLng,
            );
          
          if (distance <= request.exposureRadius!) {
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
              debugPrint('🗺️ Guest user ${userProfile.displayName} meets all requirements - adding to map');
              helpers.add(userProfile);
            }
          } else {
            debugPrint('🗺️ Guest user ${userProfile.displayName} is outside range (${distance.toStringAsFixed(2)} km > ${request.exposureRadius} km)');
          }
        } else if (!canSeeRequest) {
          debugPrint('🗺️ Guest user ${userProfile.displayName} cannot see this request (no categories or not first week)');
        } else {
          debugPrint('🗺️ Guest user ${userProfile.displayName} has no location data');
        }
      }
      
      debugPrint('🗺️ ===== FINAL RESULT =====');
      debugPrint('🗺️ Final helpers count: ${helpers.length}');
      for (var helper in helpers) {
        String helperType = 'Unknown';
        if (helper.isAdmin == true) {
          helperType = 'Admin';
        } else if (helper.userType == UserType.business) {
          helperType = 'Business Subscriber';
        } else if (helper.userType == UserType.guest) {
          helperType = 'Guest';
        }
        debugPrint('🗺️ Helper: ${helper.displayName} ($helperType)');
      }
      debugPrint('🗺️ ===== END LOADING HELPERS =====');
      return helpers;
      
    } catch (e) {
      debugPrint('Error loading relevant helpers: $e');
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
          fillColor: Colors.red.withOpacity(0.1),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ),
      );
    }
    
    return circles;
  }

  Set<Marker> _createMarkersForMap(Request request, List<UserProfile> helpers) {
    final markers = <Marker>{};
    
    // מרקר לבקשה
    markers.add(
      Marker(
        markerId: const MarkerId('request'),
        position: LatLng(request.latitude!, request.longitude!),
        infoWindow: InfoWindow(
          title: request.title,
          snippet: 'מיקום הבקשה שלך',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    
    // מרקרים לנותני שירות
    for (int i = 0; i < helpers.length; i++) {
      final helper = helpers[i];
      
      // Debug: בדיקת נתוני נותן השירות
      debugPrint('🔍 Creating marker for helper $i: ${helper.displayName}');
      debugPrint('  - allowPhoneDisplay: ${helper.allowPhoneDisplay}');
      debugPrint('  - phoneNumber: ${helper.phoneNumber}');
      debugPrint('  - phoneNumber isNotEmpty: ${helper.phoneNumber?.isNotEmpty}');
      
      // בחירת מיקום - פעיל או קבוע
      double? markerLat, markerLng;
      bool isActiveLocation = false;
      
      // מיקום פעיל (אם יש)
      if (helper.latitude != null && helper.longitude != null) {
        markerLat = helper.latitude;
        markerLng = helper.longitude;
        isActiveLocation = true;
      }
      
      if (markerLat != null && markerLng != null) {
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
        
        // הוספת מידע על סוג המיקום
        if (isActiveLocation) {
          infoParts.add('📍 מיקום פעיל');
        } else {
          infoParts.add('📍 מיקום קבוע');
        }
        
        markers.add(
          Marker(
            markerId: MarkerId('helper_$i'),
            position: LatLng(markerLat, markerLng),
            infoWindow: InfoWindow(
              title: helper.displayName,
              snippet: 'לחץ לפרטים מלאים',
            ),
            onTap: () {
              if (mounted) {
                _showHelperDetailsDialog(context, helper);
              }
            },
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      }
    }
    
    return markers;
  }

  // הצגת פרטים מלאים של נותן השירות בדיאלוג
  void _showHelperDetailsDialog(BuildContext context, UserProfile helper) {
    if (!mounted) return;
    
    debugPrint('🔍 _showHelperDetailsDialog called for helper: ${helper.displayName}');
    debugPrint('🔍 Helper data:');
    debugPrint('  - allowPhoneDisplay: ${helper.allowPhoneDisplay}');
    debugPrint('  - phoneNumber: ${helper.phoneNumber}');
    debugPrint('  - phoneNumber isNotEmpty: ${helper.phoneNumber?.isNotEmpty}');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                          // דירוג כללי
                          if (helper.averageRating != null && helper.averageRating! > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'דירוג כללי: ${helper.averageRating!.toStringAsFixed(1)}',
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
                          const Text(
                            'דירוגים:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          _buildRatingRow('אמינות', helper.reliability),
                          _buildRatingRow('זמינות', helper.availability),
                          _buildRatingRow('יחס', helper.attitude),
                          _buildRatingRow('מחיר הוגן', helper.fairPrice),
                          
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
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green[300]!),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.phone, color: Colors.green, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'טלפון: ${helper.phoneNumber}',
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
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('סגור'),
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
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: helper.profileImageUrl != null && helper.profileImageUrl!.isNotEmpty
                            ? Image.network(
                                helper.profileImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.blue[100],
                                    child: Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Colors.blue[600],
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.blue[100],
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.blue[600],
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
              content: Text('לא ניתן להתקשר למספר: $phoneNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתקשרות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // הצגת הודעת הדרכה למסך הבקשות שלי
  // הודעת הדרכה הוסרה - רק במסך הבית

  @override
  Widget build(BuildContext context) {
    debugPrint('🗺️ ===== MY REQUESTS SCREEN BUILD =====');
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך הבקשות שלי
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // הודעת הדרכה הוסרה - רק במסך הבית
    });
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.myRequests),
        ),
        body: const Center(
          child: Text('משתמש לא מחובר'),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.myRequests,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
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
                            color: Colors.black.withOpacity(0.1),
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
                            'טוען בקשות...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.grey[700],
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
                child: Text('שגיאה: ${snapshot.error}'),
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
                          : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'אין בקשות',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'צור בקשה חדשה כדי להתחיל',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.grey[500],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.blue[300]!,
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue[200]!,
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
            const SizedBox(height: 8),
            Text(
              request.description,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.grey[600],
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
                          child: Image.network(
                            request.images[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
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
                    ? Colors.white 
                    : Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  request.category.categoryDisplayName,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payment, size: 16, color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  request.type.typeDisplayName(l10n),
                  style: TextStyle(
                    color: request.type == RequestType.paid 
                        ? Colors.green[700] 
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.grey[600]),
                    fontSize: 12,
                    fontWeight: request.type == RequestType.paid ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'עוזרים: ${request.helpers.length}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.grey[600],
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
                              ? Colors.red[400] 
                              : (Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Colors.grey[400]),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'לייקים: $likesCount',
                          style: TextStyle(
                            color: likesCount > 0 
                                ? Colors.red[600] 
                                : (Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Colors.grey[600]),
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
                    ? Colors.white 
                    : Colors.grey[600],
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
                      ? Colors.white 
                      : Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.address!,
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : Colors.grey[600], 
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
                        ? Colors.red[700] 
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.grey[600])
                  ),
                  const SizedBox(width: 4),
                  Text(
                    request.deadline!.isBefore(DateTime.now()) 
                        ? 'תאריך יעד: פג תוקף'
                        : 'תאריך יעד: ${request.deadline!.day}/${request.deadline!.month}/${request.deadline!.year}',
                    style: TextStyle(
                      color: request.deadline!.isBefore(DateTime.now()) 
                          ? Colors.red[700] 
                          : (Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : Colors.grey[600]),
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
                    color: _getUrgencyColor(request.urgencyLevel).withOpacity(0.1),
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
                      color: tag.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: tag.color,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tag.displayName,
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
                  color: Colors.purple.withOpacity(0.1),
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
            // לוגים לבדיקת נתוני הבקשה
            Builder(
              builder: (context) {
                debugPrint('🗺️ Checking request ${request.title} for map display:');
                debugPrint('🗺️ - latitude: ${request.latitude}');
                debugPrint('🗺️ - longitude: ${request.longitude}');
                debugPrint('🗺️ - exposureRadius: ${request.exposureRadius}');
                debugPrint('🗺️ - type: ${request.type}');
                debugPrint('🗺️ - Should show map: ${request.latitude != null && request.longitude != null && request.exposureRadius != null && request.type == RequestType.paid}');
                return const SizedBox.shrink();
              },
            ),
            if (request.latitude != null && request.longitude != null && request.exposureRadius != null && 
                request.type == RequestType.paid) ...[
              // כותרת המפה עם כפתור רענון + מסך מלא
              Row(
                children: [
                  Icon(Icons.map, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    'מפת נותני שירות רלוונטיים',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[600],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.fullscreen, size: 16, color: Colors.blue[600]),
                    onPressed: () async {
                      // נפתח מפה במסך מלא עם אותם עוזרים
                      final helpers = await _loadRelevantHelpersForMap(request);
                      _openFullScreenMap(context, request, helpers);
                    },
                    tooltip: 'פתח מסך מלא',
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 16, color: Colors.blue[600]),
                    onPressed: () {
                      // רענון המפה
                      setState(() {});
                    },
                    tooltip: 'רענון מפה',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // הודעה על מספר נותני שירות בטווח
              StreamBuilder<List<UserProfile>>(
                stream: _getRelevantHelpersStream(request),
                builder: (context, snapshot) {
                  final helpers = snapshot.data ?? [];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 20, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Text(
                          'יש ${helpers.length} נותני שירות מתאימים בטווח של ${request.exposureRadius} ק״מ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700],
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
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SafeArea(
                    child: StreamBuilder<List<UserProfile>>(
                      stream: _getRelevantHelpersStream(request),
                      builder: (context, snapshot) {
                        final helpers = snapshot.data ?? [];
                        final markers = _createMarkersForMap(request, helpers);
                        
                        return Stack(
                          children: [
                            GoogleMap(
                          onMapCreated: (GoogleMapController controller) {
                            // Map controller is ready
                          },
                          initialCameraPosition: CameraPosition(
                            target: LatLng(request.latitude!, request.longitude!),
                            zoom: 12.0,
                          ),
                          markers: markers,
                          circles: _createCirclesForMap(request),
                          mapType: MapType.normal,
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
                                    'מתעדכן כל 30 שניות',
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
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // מידע על נותני שירות
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
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
                            const Text('מיקום הבקשה שלך'),
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
                            const Text('נותני שירות מנויים'),
                          ],
                        ),
                        Text(
                          'טווח: ${request.exposureRadius!.toStringAsFixed(1)} ק״מ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
                        'דירוגים מינימליים:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
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
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber[300]!),
                              ),
                              child: Text(
                                'כללי: ${request.minRating!.toStringAsFixed(1)}+',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ),
                          if (request.minReliability != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[300]!),
                              ),
                              child: Text(
                                'אמינות: ${request.minReliability!.toStringAsFixed(1)}+',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          if (request.minAvailability != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: Text(
                                'זמינות: ${request.minAvailability!.toStringAsFixed(1)}+',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          if (request.minAttitude != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange[300]!),
                              ),
                              child: Text(
                                'יחס: ${request.minAttitude!.toStringAsFixed(1)}+',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          if (request.minFairPrice != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple[300]!),
                              ),
                              child: Text(
                                'מחיר: ${request.minFairPrice!.toStringAsFixed(1)}+',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.purple[800],
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
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'מפה זמינה רק לבקשות בתשלום',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'עבור לראות נותני שירות מנויים באזור',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
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
                'עוזרים שהביעו עניין:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.grey[700],
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
                    return const Text('אין עוזרים זמינים');
                  }
                  
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: snapshot.data!.docs.map<Widget>((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final helperUid = doc.id;
                      final helperName = userData['displayName'] as String? ?? 'עוזר';
                      
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
                          
                          // חיפוש הצ'אט הספציפי עם העוזר הזה
                          QueryDocumentSnapshot? specificChat;
                          for (var chatDoc in chatSnapshot.data!.docs) {
                            final chatData = chatDoc.data() as Map<String, dynamic>;
                            final participants = List<String>.from(chatData['participants'] ?? []);
                            final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                            
                            if (participants.contains(helperUid) && participants.contains(currentUserId)) {
                              // בדיקה אם יוצר הבקשה מחק את הצ'אט
                              // יוצר הבקשה יכול למחוק את הצ'אט מצדו
                              if (deletedBy.contains(currentUserId)) {
                                return const SizedBox.shrink(); // לא להציג את הצ'אט ליוצר הבקשה
                              }
                              specificChat = chatDoc;
                              break;
                            }
                          }
                          
                          // אם לא נמצא צ'אט ספציפי או שהוא נמחק, לא נציג כפתור
                          if (specificChat == null) {
                            return const SizedBox.shrink();
                          }
                          
                          // בדיקה נוספת אם הצ'אט נמחק על ידי יוצר הבקשה
                          final chatData = specificChat.data() as Map<String, dynamic>;
                          final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                          final isClosed = chatData['isClosed'] as bool? ?? false;
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                          if (deletedBy.contains(currentUserId)) {
                            return const SizedBox.shrink(); // לא להציג את הצ'אט ליוצר הבקשה
                          }
                          
                          return Stack(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _openChat(request.requestId, helperUid),
                                  icon: isClosed 
                                    ? const Icon(Icons.lock, size: 16)
                                    : const Icon(Icons.chat, size: 16),
                                  label: Text(isClosed 
                                    ? 'צ\'אט סגור עם $helperName'
                                    : 'צ\'אט עם $helperName'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isClosed ? Colors.orange : Colors.blue,
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
            // הצגת כפתור "סמן כטופל" רק אם יש עוזרים (helpers count > 0)
            if (request.status == RequestStatus.open && request.helpers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsCompleted(request),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('סמן כטופל'),
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
            if (request.status == RequestStatus.completed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsOpen(request),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('בטל טופל'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
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
      ),
    );
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
    switch (status) {
      case RequestStatus.open:
        return 'פתוח';
      case RequestStatus.completed:
        return 'טופל';
      case RequestStatus.cancelled:
        return 'בוטל';
      case RequestStatus.inProgress:
        return 'בטיפול';
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
            'lastMessage': 'הצ\'אט נפתח מחדש',
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
            'text': 'הצ\'אט נפתח מחדש - ניתן לשלוח הודעות',
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הבקשה חזרה למצב פתוח והצ\'אטים נפתחו מחדש'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה: $e'),
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
        title: const Text('מחיקת בקשה'),
        content: const Text('האם אתה בטוח שברצונך למחוק את הבקשה? פעולה זו לא ניתנת לביטול.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('מחק'),
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
          const SnackBar(
            content: Text('הבקשה נמחקה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה במחיקת הבקשה: $e'),
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
            content: Text('נמחקו $deletedCount תמונות מ-Storage'),
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
            content: Text('שגיאה במחיקת תמונות: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
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
        // חיפוש הצ'אט הספציפי עם שני המשתתפים
        QueryDocumentSnapshot? specificChat;
        for (var doc in chatQuery.docs) {
          final chatData = doc.data();
          final participants = List<String>.from(chatData['participants'] ?? []);
          if (participants.contains(user.uid) && participants.contains(helperUid)) {
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

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                requestTitle: 'בקשה', // TODO: קבלת כותרת הבקשה
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

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chatId,
                    requestTitle: 'בקשה', // TODO: קבלת כותרת הבקשה
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

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  requestTitle: 'בקשה', // TODO: קבלת כותרת הבקשה
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
            content: Text('שגיאה בפתיחת הצ\'אט: $e'),
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
