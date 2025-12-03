import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/request.dart';
import '../models/user_profile.dart';
import '../models/week_availability.dart';
import '../models/appointment.dart';
import '../models/order.dart' as order_model;
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/notification_service_local.dart';
import '../services/cloud_function_service.dart';
import '../services/app_state_service.dart';
import '../services/location_service.dart';
import '../services/admin_auth_service.dart';
import '../services/network_service.dart';
import '../services/tutorial_service.dart';
import '../services/like_service.dart';
import '../models/notification_preferences.dart';
import '../services/notification_preferences_service.dart';
import '../services/share_service.dart';
import '../services/audio_service.dart';
import '../services/app_sharing_service.dart';
import '../services/auto_login_service.dart';
import '../services/permission_service.dart';
// ✅ Safe fix: Imports only used in commented-out code
import '../models/filter_preferences.dart';
import '../services/filter_preferences_service.dart';
import 'chat_screen.dart';
import 'image_gallery_screen.dart';
import 'profile_screen.dart';
import 'location_picker_screen.dart';
import 'tutorial_center_screen.dart';
import 'my_requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// enum לסינון דחיפות
enum UrgencyFilter {
  all,           // כל הבקשות
  normal,        // רגיל
  urgent24h,     // תוך 24 שעות
  emergency,     // עכשיו
  urgentAndEmergency, // תוך 24 שעות וגם עכשיו
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, NetworkMixin, AutomaticKeepAliveClientMixin, AudioMixin, TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  
  _HomeScreenState() {
    debugPrint('🏠 HomeScreen constructor called');
  }
  late AnimationController _blinkingController;
  // הסרת סינון מיקום - לא רלוונטי יותר
  RequestCategory? _selectedCategory;
  UserProfile? _userProfile;
  List<RequestCategory>? _previousBusinessCategories; // לשמירת קטגוריות קודמות לזיהוי שינויים
  
  // סינון בקשות
  RequestType? _selectedRequestType;
  UrgencyFilter? _selectedUrgency;
  double? _maxDistance;
  bool _useFixedLocationAndRadius = false;
  bool _useMobileLocationAndRadius = false;
  Timer? _mobileLocationTimer;
  
  // קטגוריות לסינון - בחירה מרובה
  Set<String> _selectedMainCategories = {};
  Set<RequestCategory> _selectedSubCategories = {};
  
  // קטגוריה ראשית שנבחרה מהעיגולים
  MainCategory? _selectedMainCategoryFromCircles;
  
  
  // מיקום המשתמש (מיקום נייד - נוכחי)
  double? _userLatitude;
  double? _userLongitude;
  
  // מיקום נוסף (נבחר במפה) - נשמר בנפרד
  double? _additionalLocationLatitude;
  double? _additionalLocationLongitude;
  double? _additionalLocationRadius;
  bool _useAdditionalLocation = false; // צ'יקבוקס למיקום נוסף - אם מסומן, המיקום הנוסף נלקח בחשבון בסינון
  
  // בקשות שהמשתמש לחץ "אני מעוניין"
  Set<String> _interestedRequests = {};
  NotificationPreferences? _notificationPrefs;
  bool? _receiveNewRequests; // שמירת מצב צ'קבוקס "קבל התראות"
  FilterPreferences? _filterPreferencesFromFirestore; // סינון מ-Firestore (להתראות)
  
  // מעקב אחרי הצגת הדיאלוג במהלך הפעלה זו
  bool _tutorialShown = false;
  
  // מעקב אחר מצב ההרחבה של כל בקשה
  final Set<String> _expandedRequests = {};
  
  // משתנים לניהול Pagination
  static const int _requestsPerPage = 10; // Load 10 requests per page
  bool _isLoadingInitial = false; // Loading initial requests
  bool _isLoadingMore = false; // Loading more requests
  bool _hasMoreRequests = true; // האם יש עוד בקשות לטעינה
  DateTime? _lastLoadTime; // זמן הטעינה האחרונה (למניעת טעינות כפולות)
  List<Request> _allRequests = []; // שמירת כל הבקשות שכבר טענו (cache)
  List<UserProfile> _serviceProviders = []; // שמירת כל נותני השירות שכבר טענו
  bool _isLoadingServiceProviders = false; // מצב טעינה עבור נותני שירות
  bool _hasMoreServiceProviders = true; // האם יש עוד נותני שירות לטעינה
  
  // משתנים לסינון נותני שירות
  MainCategory? _selectedMainCategoryFromCirclesForProviders; // קטגוריה ראשית מהעיגולים
  Set<String> _selectedProviderMainCategories = {}; // קטגוריות ראשיות בדיאלוג
  Set<RequestCategory> _selectedProviderSubCategories = {}; // תת-קטגוריות בדיאלוג
  GeographicRegion? _selectedProviderRegion; // איזור (צפון/מרכז/דרום)
  bool _filterProvidersByMyLocation = false; // סנן נותני שירות בטווח 5 ק"מ מהמיקום הנוכחי
  
  // ספירת כל הבקשות במערכת
  int _totalRequestsCount = 0; // מספר כל הבקשות במערכת
  int _openRequestsCount = 0; // מספר בקשות פתוחות (status='open' עם helpers=0)
  int _animatedOpenCount = 0; // מספר הבקשות הפתוחות המוצג באנימציה
  int _myRequestsCount = 0; // מספר בקשות של המשתמש במצב "פתוח" או "בטיפול"
  int _myInProgressRequestsCount = 0; // מספר בקשות שהמשתמש מטפל בהן (helper) במצב "בטיפול"
  AnimationController? _countAnimationController;
  bool _isAnimationRunning = false; // האם האנימציה רצה כרגע
  DateTime? _lastAnimationTime; // זמן האנימציה האחרונה
  DocumentSnapshot? _lastDocumentSnapshot; // snapshot של הבקשה האחרונה לטעינת הבא
  final Map<String, StreamSubscription<DocumentSnapshot>> _requestSubscriptions = {}; // Individual subscriptions for diff updates
  final Map<String, Timer> _debounceTimers = {}; // ⬇️ Added for debounced diff updates - timers per requestId
  final Map<String, DocumentSnapshot?> _pendingUpdates = {}; // ⬇️ Added for debounced diff updates - pending updates per requestId
  final Map<String, Request> _requestCache = {}; // ✅ Client-side cache - stores full Request objects by requestId
  final Set<String> _loadingFullDetails = {}; // ✅ Tracks which requests are currently loading full details
  Timer? _setStateDebounceTimer; // ✅ Debounce timer for setState during initial scroll
  String? _loadingError; // Error message if loading fails
  StreamSubscription<QuerySnapshot>? _newRequestsSubscription; // ✅ Listener for new requests created by other users
  
  
  // דירוגים של המשתמש לפי קטגוריה
  final Map<String, double> _userRatingsByCategory = {};
  
  
  
  // בקר גלילה לרשימת הבקשות
  final ScrollController _scrollController = ScrollController();
  
  // מצב סינון הבקשות
  bool _showMyRequests = false; // true = בקשות שפניתי אליהם, false = כל הבקשות
  bool _showServiceProviders = false; // true = נותני שירות, false = בקשות
  bool _isLoadingMyRequests = false; // מצב טעינה עבור "בקשות בטיפול שלי"
  
  // מערכת בונוסים לטווח בקשות
  final int _maxRequestsPerMonth = 1; // מקסימום בקשות בחודש
  final double _maxSearchRadius = 10.0; // מקסימום רדיוס חיפוש בק"מ
  
  // טווח עדכני עם בונוסים
  double? _currentMaxRadius;
  
  
  
  // Stream subscription for real-time profile updates
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  
  
  // Filter persistence
  static const String _filterKey = 'saved_filters';

  /// חישוב הטווח העדכני עם בונוסים
  Future<void> _calculateCurrentMaxRadius() async {
    if (_userProfile == null) return;
    
    try {
      // חישוב הטווח במטרים והמרה לקילומטרים
      final maxRadiusMeters = LocationService.calculateMaxRadiusForUser(
        userType: _userProfile!.userType.name,
        isSubscriptionActive: _userProfile!.isSubscriptionActive,
        recommendationsCount: _userProfile!.recommendationsCount ?? 0,
        averageRating: _userProfile!.averageRating ?? 0.0,
        isAdmin: AdminAuthService.isCurrentUserAdmin(),
      );
      _currentMaxRadius = maxRadiusMeters / 1000; // המרה ממטרים לקילומטרים
      
      debugPrint('🎯 Current max radius calculated: $_currentMaxRadius km');
    } catch (e) {
      debugPrint('❌ Error calculating current max radius: $e');
      _currentMaxRadius = _maxSearchRadius; // fallback to base radius
    }
  }

  /// הצגת דיאלוג מידע על הטווח
  void _showRadiusInfoDialog(UserProfile? userProfile) {
    if (userProfile == null) return;

    final currentRadius = _currentMaxRadius ?? _maxSearchRadius;
    
    // חישוב הטווח הבסיסי לפי סוג המשתמש (קבועים חדשים)
    double baseRadius = 3.0; // ברירת מחדל - פרטי חינם
    String userTypeText = 'פרטי חינם';
    
    if (userProfile.userType == UserType.personal) {
      if (userProfile.isSubscriptionActive) {
        baseRadius = 5.0; // פרטי מנוי
        userTypeText = 'פרטי מנוי';
      } else {
        baseRadius = 3.0; // פרטי חינם
        userTypeText = 'פרטי חינם';
      }
    } else if (userProfile.userType == UserType.business) {
      if (userProfile.isSubscriptionActive) {
        baseRadius = 8.0; // עסקי מנוי
        userTypeText = 'עסקי מנוי';
      } else {
        baseRadius = 1.0; // עסקי ללא מנוי (לא אמור לקרות)
        userTypeText = 'עסקי ללא מנוי';
      }
    } else if (AdminAuthService.isCurrentUserAdmin()) {
      baseRadius = 250.0; // מנהל
      userTypeText = 'מנהל';
    }
    
    final bonusRadius = 0.0; // אין בונוסים במודל החדש
    final String bonusDetails = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'מידע על הטווח שלך',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'הטווח הנוכחי שלך: ${currentRadius.toStringAsFixed(1)} ק"מ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'סוג מנוי: $userTypeText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (bonusRadius > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'טווח בסיסי: ${baseRadius.toStringAsFixed(1)} ק"מ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      'בונוסים: +${bonusRadius.toStringAsFixed(1)} ק"מ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bonusDetails.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'פירוט הבונוסים:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        bonusDetails.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'איך לשפר את הטווח:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🎉 המלץ על האפליקציה לחברים (+0.2 ק"מ לכל המלצה)\n'
                    '⭐ קבל דירוגים גבוהים (+0.5-1.5 ק"מ)\n'
                    '💎 שדרג למנוי (טווח בסיסי גדול יותר)',
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).understood),
          ),
        ],
      ),
    );
  }

  /// קבלת זמן ההתעניינות האחרונה בבקשה
  Future<DateTime?> _getLastInterestTime(String requestId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return null;

      final interestDoc = await FirebaseFirestore.instance
          .collection('user_interests')
          .doc('${currentUserId}_$requestId')
          .get();

      if (interestDoc.exists) {
        final data = interestDoc.data()!;
        final timestamp = data['interestedAt'];
        if (timestamp != null) {
          final dateTime = (timestamp as Timestamp).toDate();
          debugPrint('📅 Got interest time for ${requestId.substring(0, 8)}...: $dateTime');
          return dateTime;
        } else {
          debugPrint('⚠️ Document exists but interestedAt is null for ${requestId.substring(0, 8)}...');
        }
      } else {
        debugPrint('⚠️ No interest document found for ${requestId.substring(0, 8)}...');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting last interest time for ${requestId.substring(0, 8)}...: $e');
      return null;
    }
  }

  /// מיון מחדש של רשימת הבקשות במסך "פניות שלי" לפי זמן ההתעניינות
  Future<void> _sortAndUpdateRequestsList() async {
    if (!_showMyRequests || _allRequests.isEmpty) return;
    
    try {
      // המתנה קצרה כדי לוודא שהעדכונים ב-Firestore נשמרו
      // חשוב: Firestore צריך זמן לשמור את הנתונים לפני הקריאה
      // הגדלנו את הזמן כדי לוודא שהזמן נשמר ב-Firestore לפני המיון
      // חשוב: צריך להמתין מספיק זמן כדי ש-Firestore ישמור את הזמן ויהיה זמין לקריאה
      await Future.delayed(const Duration(milliseconds: 800));
      
      debugPrint('🔄 Starting re-sort for ${_allRequests.length} requests in "My Requests" view');
      
      // ✅ יצירת עותק של הרשימה כדי למנוע concurrent modification
      // חשוב: לא לעבוד ישירות על _allRequests כדי למנוע שגיאות של שינוי בו-זמני
      final requestsCopy = List<Request>.from(_allRequests);
      
      // קריאה מחדש של כל הזמנים מ-Firestore כדי לוודא שיש לנו את הנתונים העדכניים ביותר
      final sortedRequests = await _sortRequestsByInterestTime(requestsCopy);
      
      if (mounted) {
        setState(() {
          _allRequests = sortedRequests;
        });
        debugPrint('✅ Re-sorted ${sortedRequests.length} requests in "My Requests" view');
        // Debug: הדפסת סדר הבקשות אחרי המיון עם הזמנים
        for (int i = 0; i < sortedRequests.length && i < 5; i++) {
          final req = sortedRequests[i];
          final time = await _getLastInterestTime(req.requestId);
          debugPrint('  ${i + 1}. ${req.requestId.substring(0, 8)}... (time: ${time ?? "null"})');
        }
      }
    } catch (e) {
      debugPrint('❌ Error re-sorting requests: $e');
    }
  }


  /// סידור בקשות לפי זמן ההתעניינות האחרונה
  /// הבקשה שהתעניינו בה לאחרונה תופיע ראשונה ברשימה (למעלה)
  /// ✅ אופטימיזציה: טוען את כל זמני ההתעניינות בבת אחת במקום קריאות נפרדות
  Future<List<Request>> _sortRequestsByInterestTime(List<Request> requests) async {
    final List<MapEntry<Request, DateTime?>> requestTimes = [];

      debugPrint('🔄 _sortRequestsByInterestTime: Sorting ${requests.length} requests');
    
    // ✅ אופטימיזציה: טעינת כל זמני ההתעניינות בבת אחת במקום N קריאות נפרדות
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null && requests.isNotEmpty) {
      try {
        // טעינת כל ה-user_interests בבת אחת
        final requestIds = requests.map((r) => r.requestId).toList();
        final interestDocs = await Future.wait(
          requestIds.map((requestId) => 
            FirebaseFirestore.instance
              .collection('user_interests')
              .doc('${currentUserId}_$requestId')
              .get()
          )
        );
        
        // יצירת Map של requestId -> interestTime
        final interestTimeMap = <String, DateTime?>{};
        for (int i = 0; i < requestIds.length; i++) {
          final doc = interestDocs[i];
          if (doc.exists) {
            final data = doc.data()!;
            final timestamp = data['interestedAt'];
            if (timestamp != null) {
              interestTimeMap[requestIds[i]] = (timestamp as Timestamp).toDate();
            } else {
              interestTimeMap[requestIds[i]] = null;
            }
          } else {
            interestTimeMap[requestIds[i]] = null;
          }
        }
        
        // שימוש ב-Map לטעינה מהירה
    for (final request in requests) {
          final interestTime = interestTimeMap[request.requestId];
        requestTimes.add(MapEntry(request, interestTime));
        final requestTitle = request.title.isNotEmpty ? request.title : 'no title';
        debugPrint('📅 Request ${request.requestId.substring(0, 8)}... ($requestTitle): interestTime=${interestTime ?? "null"}');
        }
      } catch (e) {
        debugPrint('❌ Error loading interest times in batch: $e, falling back to individual queries');
        // Fallback: טעינה נפרדת במקרה של שגיאה
        for (final request in requests) {
          final interestTime = await _getLastInterestTime(request.requestId);
          requestTimes.add(MapEntry(request, interestTime));
        }
      }
    } else {
      // אם אין משתמש או אין בקשות, אין צורך בטעינה
      for (final request in requests) {
        requestTimes.add(MapEntry(request, null));
      }
      }

    // סידור לפי זמן ההתעניינות בסדר יורד (החדש ביותר - המאוחר ביותר - ראשון)
    // בקשות עם זמן התעניינות תמיד יופיעו לפני אלה שאין להן זמן התעניינות
    requestTimes.sort((a, b) {
      final aInterestTime = a.value;
      final bInterestTime = b.value;
      
      // אם לשניהם יש זמן התעניינות, נמיין לפי הזמן (המאוחר יותר ראשון)
      // bInterestTime.compareTo(aInterestTime) מחזיר:
      // - מספר חיובי אם b מאוחר יותר מ-a → b יופיע לפני a (נכון!)
      // - מספר שלילי אם b מוקדם יותר מ-a → a יופיע לפני b
      if (aInterestTime != null && bInterestTime != null) {
        final comparison = bInterestTime.compareTo(aInterestTime);
        debugPrint('🔄 Both have interest time: ${a.key.requestId.substring(0, 8)}... (${aInterestTime}) vs ${b.key.requestId.substring(0, 8)}... (${bInterestTime}) → ${comparison > 0 ? "b first (correct)" : comparison < 0 ? "a first" : "equal"}');
        return comparison;
    }

      // אם רק ל-a יש זמן התעניינות, a יופיע ראשון
      if (aInterestTime != null && bInterestTime == null) {
        debugPrint('🔄 Only a has interest time: ${a.key.requestId.substring(0, 8)}... comes first');
        return -1; // a לפני b
      }
      
      // אם רק ל-b יש זמן התעניינות, b יופיע ראשון
      if (aInterestTime == null && bInterestTime != null) {
        debugPrint('🔄 Only b has interest time: ${b.key.requestId.substring(0, 8)}... comes first');
        return 1; // b לפני a
      }
      
      // אם לשניהם אין זמן התעניינות, נמיין לפי תאריך יצירה (החדש ביותר ראשון)
      final aCreatedAt = a.key.createdAt;
      final bCreatedAt = b.key.createdAt;
      final comparison = bCreatedAt.compareTo(aCreatedAt);
      debugPrint('🔄 Neither has interest time, using createdAt: ${a.key.requestId.substring(0, 8)}... (${aCreatedAt}) vs ${b.key.requestId.substring(0, 8)}... (${bCreatedAt}) → ${comparison > 0 ? "b first" : comparison < 0 ? "a first" : "equal"}');
      return comparison;
    });

    final sortedRequests = requestTimes.map((entry) => entry.key).toList();
    debugPrint('✅ Sorted ${sortedRequests.length} requests by interest time');
    // הדפסת סדר הבקשות אחרי המיון (5 הראשונות)
    for (int i = 0; i < sortedRequests.length && i < 5; i++) {
      final req = sortedRequests[i];
      final time = requestTimes.firstWhere((e) => e.key.requestId == req.requestId).value;
      debugPrint('  ${i + 1}. ${req.requestId.substring(0, 8)}... (time: ${time ?? "null"})');
    }
    return sortedRequests;
  }

  /// בניית רשימת הבקשות
  Widget _buildRequestsList(List<Request> requests, AppLocalizations l10n) {
    // ✅ אם אין עוד בקשות לטעינה, נאפס את _isLoadingMore מיד כדי שלא יוצגו skeleton cards
    // ✅ נשתמש ב-setState מיד (לא debounced) כדי לוודא שה-widget יתעדכן מיד
    if (!_hasMoreRequests && _isLoadingMore) {
      // אפס מיד (לא רק ב-postFrameCallback) כדי שה-childCount יחושב נכון
      _isLoadingMore = false;
      // ✅ גם נשתמש ב-setState כדי לוודא שה-widget יתעדכן מיד
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasMoreRequests && _isLoadingMore == false) {
          // ✅ אם _isLoadingMore כבר false, נדאג שה-widget יתעדכן
          setState(() {
            // כבר false, אבל setState יעדכן את ה-widget
          });
        }
      });
    }
    
    // בדיקות למשתמשים עסקיים
    final isBusinessUserWithoutSubscription = _userProfile != null && 
        _userProfile!.userType == UserType.business && 
        !_userProfile!.isSubscriptionActive &&
        !AdminAuthService.isCurrentUserAdmin();
    final isBusinessUserWithSubscriptionButNoCategories = _userProfile != null && 
        _userProfile!.userType == UserType.business && 
        _userProfile!.isSubscriptionActive &&
        (_userProfile!.businessCategories == null || _userProfile!.businessCategories!.isEmpty) &&
        !AdminAuthService.isCurrentUserAdmin();
    final hasRestrictedCategoryFilter = _selectedCategory != null && 
        _userProfile != null && 
        _userProfile!.userType == UserType.business && 
        _userProfile!.isSubscriptionActive &&
        _userProfile!.businessCategories != null && 
        _userProfile!.businessCategories!.isNotEmpty &&
        !_userProfile!.businessCategories!.contains(_selectedCategory!);
    final hasRestrictedCategoryMessage = hasRestrictedCategoryFilter && 
        (_selectedRequestType == null || _selectedRequestType == RequestType.free) && 
        requests.isNotEmpty;

    // ✅ דיאלוג טעינה עבור "בקשות בטיפול שלי"
    if (_showMyRequests && _isLoadingMyRequests) {
      return SliverToBoxAdapter(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'טוען בקשות...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // הודעה מיוחדת למצב "פניות שלי" כשאין פניות
    if (_showMyRequests && requests.isEmpty && !_isLoadingMyRequests) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.noInterestedRequests,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.clickInterestedOnRequests,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.howItWorks,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.howItWorksSteps,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.tertiary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await playButtonSound();
                  setState(() {
                    _showMyRequests = false; // מעבר ל"כל הבקשות"
                  });
                },
                icon: const Icon(Icons.grid_view),
                label: Text(l10n.goToAllRequests),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Lazy Rendering + List Optimization - Use itemExtent for better scroll performance
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // הודעה למשתמשים עסקיים שאין להם מנוי פעיל
          if (index == 0 && isBusinessUserWithoutSubscription) {
            return Card(
              margin: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'מנוי נדרש',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'כדי לראות בקשות בתשלום, אנא הפעל את המנוי שלך',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await playButtonSound();
                        _navigateToProfile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('הפעל מנוי'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // הודעה למשתמשים עסקיים עם מנוי פעיל אבל ללא תחומי עיסוק
          if (index == 0 && isBusinessUserWithSubscriptionButNoCategories) {
            return Card(
              margin: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'תחומי עיסוק נדרשים',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'כדי לראות בקשות בתשלום, אנא בחר תחומי עיסוק בפרופיל',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await playButtonSound();
                        _navigateToProfile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('עדכן פרופיל'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // הודעה למשתמש עסקי שבוחר קטגוריה שאין לו בתחומי עיסוק
          if (index == 0 && hasRestrictedCategoryMessage) {
            return Card(
              margin: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'הגבלת קטגוריה',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'תחום העיסוק "${_selectedCategory!.categoryDisplayName}" שבחרת אינו אחד מתחומי העיסוק שלך. במידה ותרצה לראות בקשות בתשלום בקטגוריה זו, עדכן את תחומי העיסוק שלך בפרופיל.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await playButtonSound();
                        _navigateToProfile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('עדכן פרופיל'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // ⬇️ Check for skeleton loading cards first (before request index calculation)
          final baseOffset = (isBusinessUserWithoutSubscription ? 1 : 0) +
              (isBusinessUserWithSubscriptionButNoCategories ? 1 : 0) +
              (hasRestrictedCategoryMessage ? 1 : 0);
          final loadingSkeletonStartIndex = requests.length + baseOffset;
          
          // Show skeleton cards during pagination loading (show 3 skeleton cards)
          // רק אם יש עוד בקשות לטעינה - לא נציג skeleton אם אין עוד בקשות
          // בדיקה נוספת: אם אין עוד בקשות, לא נציג skeleton גם אם _isLoadingMore הוא true
          if (_isLoadingMore && _hasMoreRequests) {
            final skeletonIndex = index - loadingSkeletonStartIndex;
            if (skeletonIndex >= 0 && skeletonIndex < 3) {
              return _buildSkeletonCard();
            }
          }
          
          // אם אין עוד בקשות, לא נציג skeleton גם אם הגענו לאינדקס הזה בטעות
          if (!_hasMoreRequests && index >= loadingSkeletonStartIndex) {
            // אם אין עוד בקשות, נחזיר widget ריק במקום skeleton
            return const SizedBox.shrink();
          }
          
          
          // התאמת אינדקס לבקשות
          int requestIndex = index;
          if (isBusinessUserWithoutSubscription) {
            requestIndex = index - 1;
          } else if (isBusinessUserWithSubscriptionButNoCategories) {
            requestIndex = index - 1;
          } else if (hasRestrictedCategoryMessage) {
            requestIndex = index - 1;
          }
          
          if (requestIndex < 0 || requestIndex >= requests.length) {
            return const SizedBox.shrink();
          }
          
          final request = requests[requestIndex];
          
          // בדיקה אם המשתמש הנוכחי מחק צ'אט סגור עבור בקשה זו
          if (request.helpers.contains(FirebaseAuth.instance.currentUser?.uid)) {
            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('chats')
                  .where('requestId', isEqualTo: request.requestId)
                  .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.hasError) {
                  // ✅ Lazy Rendering + List Optimization - Wrap with RepaintBoundary
                  return RepaintBoundary(
                    key: ValueKey('request_${request.requestId}'),
                    child: KeyedSubtree(
                      key: ValueKey('request_${request.requestId}'),
                      child: _buildRequestCard(request, l10n),
                    ),
                  );
                }
                
                // במסך "פניות שלי", לא נסתיר בקשות גם אם הצ'אט נמחק על ידי המשתמש
                // הבקשה תישאר ב"פניות שלי" גם אם נותן השירות מחק את הצ'אט
                if (!_showMyRequests && chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty) {
                  final chatData = chatSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  
                  // במסך "כל הבקשות", נסתיר בקשות שהצ'אט שלהן נמחק על ידי המשתמש
                  // במסך "פניות שלי", הבקשה תישאר גם אם הצ'אט נמחק
                  if (deletedBy.contains(currentUserId)) {
                    return const SizedBox.shrink();
                  }
                }
                
                // ✅ Lazy Rendering + List Optimization - Wrap with RepaintBoundary
                return RepaintBoundary(
                  key: ValueKey('request_${request.requestId}'),
                  child: KeyedSubtree(
                    key: ValueKey('request_${request.requestId}'),
                    child: _buildRequestCard(request, l10n),
                  ),
                );
              },
            );
          }
          
          // הודעה שאין עוד בקשות
          final endOfListIndex = requests.length + baseOffset +
              (_isLoadingMore && _hasMoreRequests ? 3 : 0);
          if (index == endOfListIndex &&
              !_hasMoreRequests && requests.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 32,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'הגעת לסוף הרשימה',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'אין עוד בקשות זמינות',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // ✅ Lazy Rendering + List Optimization - Wrap with RepaintBoundary for isolated rebuilds
          return RepaintBoundary(
            key: ValueKey('request_${request.requestId}'),
            child: KeyedSubtree(
              key: ValueKey('request_${request.requestId}'),
              child: _buildRequestCard(request, l10n),
            ),
          );
        },
        childCount: requests.length + 
            (isBusinessUserWithoutSubscription ? 1 : 0) +
            (isBusinessUserWithSubscriptionButNoCategories ? 1 : 0) +
            (hasRestrictedCategoryMessage ? 1 : 0) +
            // ⬇️ Show 3 skeleton cards during pagination loading - רק אם יש עוד בקשות
            // (אחרי שהאפסתי את _isLoadingMore בתחילת הפונקציה אם אין עוד בקשות)
            (_isLoadingMore && _hasMoreRequests ? 3 : 0) +
            (!_hasMoreRequests && requests.isNotEmpty ? 1 : 0), // הודעה שאין עוד בקשות
        // ✅ Lazy Rendering + List Optimization - Add itemExtent for consistent item heights (estimated ~260px per card)
        addAutomaticKeepAlives: false, // Don't keep alive off-screen items
        addRepaintBoundaries: false, // We manually added RepaintBoundary
      ),
    );
  }

  Widget _buildInterestButton(Request request, AppLocalizations l10n) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isInterested = request.helpers.contains(currentUserId);
    
    return ElevatedButton.icon(
      onPressed: () async {
        await playButtonSound(); // הוספת צליל
        if (isInterested) {
          await _showUnhelpConfirmationDialog(request);
        } else {
          await _helpWithRequest(request.requestId);
        }
      },
      icon: Icon(isInterested ? Icons.cancel : Icons.favorite, size: 24),
      label: Text(isInterested ? l10n.iAmNotInterested : l10n.iAmInterested),
      style: ElevatedButton.styleFrom(
        backgroundColor: isInterested ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
        foregroundColor: isInterested ? Theme.of(context).colorScheme.onError : Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  // ✅ Debounced setState - reduces rebuilds during initial scroll (150ms debounce)
  void _debouncedSetState(VoidCallback fn) {
    if (!mounted) return;
    _setStateDebounceTimer?.cancel();
    _setStateDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        fn(); // Execute the callback
        setState(() {}); // Trigger rebuild with updated state
      }
    });
  }

  // ✅ Load full details for a request on demand (when expanded)
  Future<void> _loadFullRequestDetails(String requestId) async {
    // Skip if already loading or if full details are already cached
    if (_loadingFullDetails.contains(requestId)) return;
    
    final cachedRequest = _requestCache[requestId];
    // Check if already fully loaded (has phoneNumber, targetAudience, etc.)
    if (cachedRequest?.phoneNumber != null || 
        (cachedRequest?.targetAudience != null && cachedRequest!.targetAudience != TargetAudience.all)) {
      return; // Already fully loaded
    }
    
    _loadingFullDetails.add(requestId);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (doc.exists && mounted) {
        final fullRequest = Request.fromFirestore(doc);
        _requestCache[requestId] = fullRequest; // ✅ Update cache with full details
        
        // Update in list if present
        if (mounted) {
          // ✅ Use immediate setState for user-initiated expansion (needs immediate feedback)
          // ✅ Find index again inside setState to ensure it's still valid
          setState(() {
            final index = _allRequests.indexWhere((r) => r.requestId == requestId);
            if (index >= 0 && index < _allRequests.length) {
              // Verify index is still valid before updating
              _allRequests[index] = fullRequest;
            } else {
              // If request not found in list, it might have been removed or list was sorted
              // Try to add it if it's in "My Requests" view
              if (_showMyRequests && !_allRequests.any((r) => r.requestId == requestId)) {
                _allRequests.add(fullRequest);
              }
            }
          });
          debugPrint('📦 Loaded full details for request $requestId');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading full details for $requestId: $e');
    } finally {
      _loadingFullDetails.remove(requestId);
    }
  }

  // ⬇️ Updated for prefetch pagination - trigger at 70% scroll extent
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // אם אין עוד בקשות לטעינה, לא ננסה לטעון
    if (!_hasMoreRequests) return;
    
    // במסך "פניות שלי", אם יש רק בקשות שמותאמות לסינון, לא נטען עוד
    // (כי אין דרך לדעת כמה בקשות שמותאמות לסינון יש במסד הנתונים)
    if (_showMyRequests) {
      // במסך "פניות שלי", לא נטען עוד בקשות - רק הבקשות שכבר טענו
      return;
    }
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Trigger pagination at 70% of scroll extent (prefetch behavior)
    final threshold = maxScroll * 0.7;
    
    if (currentScroll >= threshold && _hasMoreRequests && !_isLoadingMore && !_isLoadingInitial) {
        _loadMoreRequests();
      }
    }

  // פונקציה לטעינת הבקשות הראשונות (טעינה ראשונית)
  Future<void> _loadInitialRequests({bool forceReload = false}) async {
    // במסך "פניות שלי", לא נטען בקשות ראשוניות - נשתמש ב-_loadAllInterestedRequests() במקום
    if (_showMyRequests) {
      return;
    }
    
    // ✅ אם forceReload == true, נטען מחדש גם אם יש בקשות קיימות
    if (!forceReload && (_isLoadingInitial || _allRequests.isNotEmpty)) return;
    
    // ✅ Use regular setState for loading flag (needs immediate update)
    setState(() {
      _isLoadingInitial = true;
      _loadingError = null;
    });
    
    try {
      debugPrint('📥 Loading initial $_requestsPerPage requests...');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .limit(_requestsPerPage)
          .get();
      
      // ✅ Firestore Query Optimization - Use lightweight factory for initial load
      final isAdmin = AdminAuthService.isCurrentUserAdmin();
      final userType = _userProfile?.userType;
      final isSubscriptionActive = _userProfile?.isSubscriptionActive ?? false;
      // משתמשים אורחים (זמניים או רגילים) ועסקי מנוי רואים גם בקשות "בטיפול"
      final canSeeInProgress = isAdmin || 
          userType == UserType.guest || 
          (userType == UserType.business && isSubscriptionActive);
      
      final newRequests = querySnapshot.docs
          .map((doc) {
            // Check cache first
            if (_requestCache.containsKey(doc.id)) {
              return _requestCache[doc.id]!;
            }
            // Use lightweight factory for faster initial load
            final lightweightRequest = Request.fromFirestoreLightweight(doc);
            _requestCache[doc.id] = lightweightRequest; // Cache the lightweight version
            return lightweightRequest;
          })
          .where((request) {
            // בדיקת סטטוס
            bool statusMatches = false;
            if (canSeeInProgress) {
              statusMatches = request.status == RequestStatus.open || request.status == RequestStatus.inProgress;
            } else {
              statusMatches = request.status == RequestStatus.open;
            }
            
            if (!statusMatches) return false;
            
            // ✅ סינון לפי showToAllUsers
            // אם showToAllUsers == true → הבקשה תופיע לכל המשתמשים (כולל עסקי מנוי)
            // אם showToAllUsers == false → הבקשה תופיע רק לנותני שירות מתחום X
            if (request.showToAllUsers == false) {
              // הבקשה מיועדת רק לנותני שירות מתחום X
              // בודקים אם המשתמש הנוכחי הוא נותן שירות (business או guest עם businessCategories) עם הקטגוריה הזו
              
              // אם הפרופיל עדיין לא נטען, נציג את הבקשה (היא תוסתר אחרי שהפרופיל ייטען)
              if (_userProfile == null) {
                debugPrint('🔍 Filtering request ${request.requestId}: showToAllUsers=false, but userProfile is null - showing request temporarily');
                return true;
              }
              
              // משתמש עסקי מנוי (עם או בלי תחומי עיסוק) - צריך לבדוק התאמת תחום
              if (userType == UserType.business && isSubscriptionActive) {
                // אם אין תחומי עיסוק מוגדרים → לא יראה בקשות עם showToAllUsers=false
                if (_userProfile?.businessCategories == null || _userProfile!.businessCategories!.isEmpty) {
                  debugPrint('🔍 Filtering request ${request.requestId}: showToAllUsers=false, business user with no categories - hiding request');
                  return false;
                }
                
                // בודקים אם יש למשתמש את הקטגוריה של הבקשה
                final hasMatchingCategory = _userProfile!.businessCategories!.any(
                  (category) => category == request.category
                );
                debugPrint('🔍 Filtering request ${request.requestId}: showToAllUsers=false, business user, hasMatchingCategory=$hasMatchingCategory');
                debugPrint('   Request category: ${request.category.name}');
                debugPrint('   User categories: ${_userProfile?.businessCategories?.map((c) => c.name).toList()}');
                return hasMatchingCategory;
              }
              
              // משתמש אורח עם businessCategories - צריך לבדוק התאמת תחום
              if (userType == UserType.guest && _userProfile?.businessCategories != null && _userProfile!.businessCategories!.isNotEmpty) {
                final hasMatchingCategory = _userProfile!.businessCategories!.any(
                  (category) => category == request.category
                );
                debugPrint('🔍 Filtering request ${request.requestId}: showToAllUsers=false, guest user with categories, hasMatchingCategory=$hasMatchingCategory');
                return hasMatchingCategory;
              }
              
              // אם המשתמש לא נותן שירות או אין לו את הקטגוריה → לא יראה את הבקשה
              debugPrint('🔍 Filtering request ${request.requestId}: showToAllUsers=false, user is not a service provider or has no matching category - hiding request');
              return false;
            }
            
            // אם showToAllUsers == true או null → הבקשה תופיע לכל המשתמשים (כולל עסקי מנוי)
            return true;
          })
          .toList();
      
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocumentSnapshot = querySnapshot.docs.last;
      }
      
      // Set up individual subscriptions for real-time updates on loaded requests
      for (final request in newRequests) {
        _setupRequestSubscription(request.requestId);
      }
      
      // ✅ Use debounced setState for initial load to reduce rebuilds during scroll
      _debouncedSetState(() {
        _allRequests = newRequests;
        _hasMoreRequests = newRequests.length == _requestsPerPage;
        _isLoadingInitial = false;
      });
      
      debugPrint('✅ Loaded ${newRequests.length} initial requests. Total: $_allRequests.length');
    } catch (e) {
      debugPrint('❌ Error loading initial requests: $e');
      // ✅ Use regular setState for error (needs immediate update)
      if (!context.mounted) return;
      final l10nError = AppLocalizations.of(context);
      setState(() {
        _loadingError = '${l10nError.loadingRequestsError}: $e';
        _isLoadingInitial = false;
      });
    }
  }

  // פונקציה לטעינת נותני שירות ראשוניים
  Future<void> _loadInitialServiceProviders() async {
    if (!_showServiceProviders) return;
    if (_isLoadingServiceProviders) return;
    
    setState(() {
      _isLoadingServiceProviders = true;
    });
    
    try {
      debugPrint('📥 Loading initial service providers...');
      
      // טעינת משתמשי אורח (guest) - ללא orderBy כדי לא לדרוש אינדקס
      // הקטנת ה-limit כדי למנוע חסימה ארוכה
      final guestQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'guest')
          .limit(20) // הקטנה מ-50 ל-20 כדי למנוע חסימה
          .get();
      
      // טעינת משתמשים עסקיים עם מנוי פעיל - ללא orderBy כדי לא לדרוש אינדקס
      final businessQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .limit(20) // הקטנה מ-50 ל-20 כדי למנוע חסימה
          .get();
      
      // איחוד התוצאות
      final allDocs = [...guestQuery.docs, ...businessQuery.docs];
      
      // המרה ל-UserProfile - עם error handling
      final allProviders = <UserProfile>[];
      for (final doc in allDocs) {
        try {
          final provider = UserProfile.fromFirestore(doc);
          
          // סינון: לא להציג משתמשים זמניים
          if (provider.isTemporaryGuest == true) {
            debugPrint('⚠️ Skipping temporary guest user: ${provider.userId}');
            continue;
          }
          
          // סינון: עבור משתמשי אורח - רק כאלה שהגדירו תחומי עיסוק
          if (provider.userType == UserType.guest) {
            if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
              debugPrint('⚠️ Skipping guest user without business categories: ${provider.userId}');
              continue;
            }
          }
          
          // סינון: עבור משתמשים עסקיים - לא להציג מנהלים
          if (provider.userType == UserType.business) {
            if (provider.isAdmin == true) {
              debugPrint('⚠️ Skipping admin user: ${provider.userId}');
              continue;
            }
          }
          
          allProviders.add(provider);
        } catch (e) {
          debugPrint('⚠️ Error converting user ${doc.id} to UserProfile: $e');
          // דילוג על משתמשים עם שגיאות
        }
      }
      
      // מיון לפי תאריך יצירה (החדשים ביותר ראשון) בצד הלקוח
      // רק אם יש תוצאות
      if (allProviders.isNotEmpty) {
        allProviders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      // לקיחת 10 הראשונים
      final newProviders = allProviders.take(10).toList();
      
      setState(() {
        _serviceProviders = newProviders;
        _hasMoreServiceProviders = newProviders.length >= 10;
        _isLoadingServiceProviders = false;
      });
      
      debugPrint('✅ Loaded ${newProviders.length} service providers');
    } catch (e) {
      debugPrint('❌ Error loading service providers: $e');
      if (mounted) {
        setState(() {
          _isLoadingServiceProviders = false;
        });
      }
    }
  }

  // פונקציה לטעינת עוד נותני שירות (pagination)
  Future<void> _loadMoreServiceProviders() async {
    if (_isLoadingServiceProviders || !_hasMoreServiceProviders) return;
    if (!_showServiceProviders) return;
    
    setState(() {
      _isLoadingServiceProviders = true;
    });
    
    try {
      debugPrint('📥 Loading more service providers...');
      
      // טעינת משתמשי אורח (guest) - ללא orderBy כדי לא לדרוש אינדקס
      // הקטנת ה-limit כדי למנוע חסימה ארוכה
      final guestQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'guest')
          .limit(20) // הקטנה מ-50 ל-20 כדי למנוע חסימה
          .get();
      
      // טעינת משתמשים עסקיים עם מנוי פעיל - ללא orderBy כדי לא לדרוש אינדקס
      final businessQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .limit(20) // הקטנה מ-50 ל-20 כדי למנוע חסימה
          .get();
      
      // איחוד התוצאות
      final allDocs = [...guestQuery.docs, ...businessQuery.docs];
      
      if (allDocs.isEmpty) {
        setState(() {
          _hasMoreServiceProviders = false;
          _isLoadingServiceProviders = false;
        });
        debugPrint('📄 No more service providers available');
        return;
      }
      
      // המרה ל-UserProfile - עם error handling
      final allProviders = <UserProfile>[];
      for (final doc in allDocs) {
        try {
          final provider = UserProfile.fromFirestore(doc);
          
          // סינון: לא להציג משתמשים זמניים
          if (provider.isTemporaryGuest == true) {
            debugPrint('⚠️ Skipping temporary guest user: ${provider.userId}');
            continue;
          }
          
          // סינון: עבור משתמשי אורח - רק כאלה שהגדירו תחומי עיסוק
          if (provider.userType == UserType.guest) {
            if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
              debugPrint('⚠️ Skipping guest user without business categories: ${provider.userId}');
              continue;
            }
          }
          
          // סינון: עבור משתמשים עסקיים - לא להציג מנהלים
          if (provider.userType == UserType.business) {
            if (provider.isAdmin == true) {
              debugPrint('⚠️ Skipping admin user: ${provider.userId}');
              continue;
            }
          }
          
          allProviders.add(provider);
        } catch (e) {
          debugPrint('⚠️ Error converting user ${doc.id} to UserProfile: $e');
          // דילוג על משתמשים עם שגיאות
        }
      }
      
      // מיון לפי תאריך יצירה (החדשים ביותר ראשון) בצד הלקוח
      // רק אם יש תוצאות
      if (allProviders.isNotEmpty) {
        allProviders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      // סינון - רק נותני שירות שלא כבר ברשימה
      final existingIds = _serviceProviders.map((p) => p.userId).toSet();
      final newProviders = allProviders
          .where((p) => !existingIds.contains(p.userId))
          .take(10)
          .toList();
      
      setState(() {
        _serviceProviders.addAll(newProviders);
        _hasMoreServiceProviders = newProviders.length >= 10;
        _isLoadingServiceProviders = false;
      });
      
      debugPrint('✅ Loaded ${newProviders.length} more service providers. Total: ${_serviceProviders.length}');
    } catch (e) {
      debugPrint('❌ Error loading more service providers: $e');
      if (mounted) {
        setState(() {
          _isLoadingServiceProviders = false;
        });
      }
    }
  }

  // פונקציה לטעינת עוד בקשות (pagination)
  Future<void> _loadMoreRequests() async {
    if (_isLoadingMore || !_hasMoreRequests || _isLoadingInitial) return;
    
    // במסך "פניות שלי", לא נטען עוד בקשות - רק הבקשות שכבר טענו
    if (_showMyRequests) {
      debugPrint('⏸️ Skipping load more requests in "My Requests" view');
      return;
    }
    
    // מניעת טעינות כפולות - אם הייתה טעינה בפחות מ-500ms, דילוג
    if (_lastLoadTime != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
      if (timeSinceLastLoad.inMilliseconds < 500) {
        debugPrint('⏸️ Skipping duplicate load request (${timeSinceLastLoad.inMilliseconds}ms ago)');
        return;
      }
    }
    
    _lastLoadTime = DateTime.now();
    // ✅ Use regular setState for loading flag (needs immediate update)
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      debugPrint('📥 Loading next $_requestsPerPage requests...');
      
      Query query = FirebaseFirestore.instance
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .limit(_requestsPerPage);
      
      // אם יש snapshot של הבקשה האחרונה, נשתמש בו ל-pagination
      if (_lastDocumentSnapshot != null) {
        query = query.startAfterDocument(_lastDocumentSnapshot!);
      }
      
      final nextBatch = await query.get();
      
      if (nextBatch.docs.isEmpty) {
        // אין עוד בקשות
        // ✅ נשתמש ב-setState מיד (לא debounced) כדי לוודא שה-skeleton cards ייעלמו מיד
        if (mounted) {
        setState(() {
          _hasMoreRequests = false;
            _isLoadingMore = false;
        });
        }
        debugPrint('📄 No more requests available');
      } else {
        // ✅ Firestore Query Optimization - Use lightweight factory for pagination
        final isAdmin = AdminAuthService.isCurrentUserAdmin();
        final userType = _userProfile?.userType;
        final isSubscriptionActive = _userProfile?.isSubscriptionActive ?? false;
        // משתמשים אורחים (זמניים או רגילים) ועסקי מנוי רואים גם בקשות "בטיפול"
        final canSeeInProgress = isAdmin || 
            userType == UserType.guest || 
            (userType == UserType.business && isSubscriptionActive);
        
        final newRequests = nextBatch.docs
            .map((doc) {
              // Check cache first
              if (_requestCache.containsKey(doc.id)) {
                return _requestCache[doc.id]!;
              }
              // Use lightweight factory for faster pagination
              final lightweightRequest = Request.fromFirestoreLightweight(doc);
              _requestCache[doc.id] = lightweightRequest; // Cache the lightweight version
              return lightweightRequest;
            })
            .where((request) {
              // בדיקת סטטוס
              bool statusMatches = false;
              if (canSeeInProgress) {
                statusMatches = request.status == RequestStatus.open || request.status == RequestStatus.inProgress;
              } else {
                statusMatches = request.status == RequestStatus.open;
              }
              
              if (!statusMatches) return false;
              
              // ✅ סינון לפי showToAllUsers
              // אם showToAllUsers == true → הבקשה תופיע לכל המשתמשים (כולל עסקי מנוי)
              // אם showToAllUsers == false → הבקשה תופיע רק לנותני שירות מתחום X
              if (request.showToAllUsers == false) {
                // הבקשה מיועדת רק לנותני שירות מתחום X
                // בודקים אם המשתמש הנוכחי הוא נותן שירות (business או guest עם businessCategories) עם הקטגוריה הזו
                
                // אם הפרופיל עדיין לא נטען, נציג את הבקשה (היא תוסתר אחרי שהפרופיל ייטען)
                if (_userProfile == null) {
                  debugPrint('🔍 Filtering request ${request.requestId}: showToAllUsers=false, but userProfile is null - showing request temporarily');
                  return true;
                }
                
                // משתמש עסקי מנוי (עם או בלי תחומי עיסוק) - צריך לבדוק התאמת תחום
                if (userType == UserType.business && isSubscriptionActive) {
                  // אם אין תחומי עיסוק מוגדרים → לא יראה בקשות עם showToAllUsers=false
                  if (_userProfile?.businessCategories == null || _userProfile!.businessCategories!.isEmpty) {
                    return false;
                  }
                  
                  // בודקים אם יש למשתמש את הקטגוריה של הבקשה
                  final hasMatchingCategory = _userProfile!.businessCategories!.any(
                    (category) => category == request.category
                  );
                  return hasMatchingCategory;
                }
                
                // משתמש אורח עם businessCategories - צריך לבדוק התאמת תחום
                if (userType == UserType.guest && _userProfile?.businessCategories != null && _userProfile!.businessCategories!.isNotEmpty) {
                  final hasMatchingCategory = _userProfile!.businessCategories!.any(
                    (category) => category == request.category
                  );
                  return hasMatchingCategory;
                }
                
                // אם המשתמש לא נותן שירות או אין לו את הקטגוריה → לא יראה את הבקשה
                return false;
              }
              
              // אם showToAllUsers == true או null → הבקשה תופיע לכל המשתמשים
              return true;
            })
            .toList();
        
        // שמירת snapshot של הבקשה האחרונה לטעינה הבאה
        _lastDocumentSnapshot = nextBatch.docs.last;
        
        // Set up individual subscriptions for real-time updates on new requests
        for (final request in newRequests) {
          _setupRequestSubscription(request.requestId);
        }
        
        // ✅ Use debounced setState for pagination to reduce rebuilds during scroll
        _debouncedSetState(() {
          _allRequests.addAll(newRequests);
          _hasMoreRequests = newRequests.length == _requestsPerPage;
          _isLoadingMore = false;
        });
        
        debugPrint('✅ Loaded ${newRequests.length} more requests. Total cached: $_allRequests.length');
      }
    } catch (e) {
      debugPrint('❌ Error loading more requests: $e');
      // ✅ Use regular setState for error (needs immediate update)
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  // ✅ Set up listener for new requests created by other users
  void _setupNewRequestsListener() {
    // Cancel existing subscription if any
    _newRequestsSubscription?.cancel();
    
    // Listen for new requests with status 'open' ordered by createdAt descending
    // This will catch new requests created by other users
    _newRequestsSubscription = FirebaseFirestore.instance
        .collection('requests')
        .where('status', isEqualTo: RequestStatus.open.name)
        .orderBy('createdAt', descending: true)
        .limit(1) // Only listen to the most recent request
        .snapshots()
        .listen(
      (querySnapshot) {
        if (!mounted || _showMyRequests || _showServiceProviders) return;
        
        for (final change in querySnapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final newRequest = Request.fromFirestore(change.doc);
            final requestId = newRequest.requestId;
            
            // Skip if request already in list
            if (_allRequests.any((r) => r.requestId == requestId)) {
              continue;
            }
            
            // Skip if request is from current user (they already see it)
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            if (newRequest.createdBy == currentUserId) {
              continue;
            }
            
            // Apply the same filtering logic as in _loadInitialRequests
            final userType = _userProfile?.userType;
            final isAdmin = AdminAuthService.isCurrentUserAdmin();
            final canSeeInProgress = isAdmin;
            
            // Check status
            bool statusMatches = false;
            if (canSeeInProgress) {
              statusMatches = newRequest.status == RequestStatus.open || newRequest.status == RequestStatus.inProgress;
            } else {
              statusMatches = newRequest.status == RequestStatus.open;
            }
            
            if (!statusMatches) continue;
            
            // ✅ Apply showToAllUsers filtering
            bool shouldShowRequest = false;
            
            if (newRequest.showToAllUsers == false) {
              // הבקשה מיועדת רק לנותני שירות מתחום X
              // בודקים אם המשתמש הנוכחי הוא נותן שירות (business או guest עם businessCategories) עם הקטגוריה הזו
              
              // אם הפרופיל עדיין לא נטען, נציג את הבקשה (היא תוסתר אחרי שהפרופיל ייטען)
              if (_userProfile == null) {
                debugPrint('🔍 New request listener: requestId=$requestId, showToAllUsers=false, but userProfile is null - showing request temporarily');
                shouldShowRequest = true;
              } else {
                final isSubscriptionActive = _userProfile?.isSubscriptionActive ?? false;
                
                // משתמש עסקי מנוי (עם או בלי תחומי עיסוק) - צריך לבדוק התאמת תחום
                if (userType == UserType.business && isSubscriptionActive) {
                  // אם אין תחומי עיסוק מוגדרים → לא יראה בקשות עם showToAllUsers=false
                  if (_userProfile?.businessCategories == null || _userProfile!.businessCategories!.isEmpty) {
                    debugPrint('🔍 New request listener: requestId=$requestId, showToAllUsers=false, business user with no categories - hiding request');
                    shouldShowRequest = false;
                  } else {
                    // בודקים אם יש למשתמש את הקטגוריה של הבקשה
                    final hasMatchingCategory = _userProfile!.businessCategories!.any(
                      (category) => category == newRequest.category
                    );
                    debugPrint('🔍 New request listener: requestId=$requestId, showToAllUsers=false, business user, hasMatchingCategory=$hasMatchingCategory');
                    debugPrint('   Request category: ${newRequest.category.name}');
                    debugPrint('   User categories: ${_userProfile?.businessCategories?.map((c) => c.name).toList()}');
                    shouldShowRequest = hasMatchingCategory;
                  }
                } else if (userType == UserType.guest && _userProfile?.businessCategories != null && _userProfile!.businessCategories!.isNotEmpty) {
                  // משתמש אורח עם businessCategories - צריך לבדוק התאמת תחום
                  final hasMatchingCategory = _userProfile!.businessCategories!.any(
                    (category) => category == newRequest.category
                  );
                  debugPrint('🔍 New request listener: requestId=$requestId, showToAllUsers=false, guest user with categories, hasMatchingCategory=$hasMatchingCategory');
                  shouldShowRequest = hasMatchingCategory;
                } else {
                  debugPrint('🔍 New request listener: requestId=$requestId, showToAllUsers=false, user is not a service provider or has no matching category - hiding request');
                  shouldShowRequest = false;
                }
              }
            } else {
              // אם showToAllUsers == true או null → הבקשה תופיע לכל המשתמשים
              shouldShowRequest = true;
            }
            
            if (shouldShowRequest) {
              debugPrint('✅ Adding new request $requestId to list (created by another user)');
              _requestCache[requestId] = newRequest;
              _debouncedSetState(() {
                _allRequests.insert(0, newRequest); // Add at the beginning
                _allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by createdAt
              });
              _setupRequestSubscription(requestId); // Set up subscription for real-time updates
            } else {
              debugPrint('❌ New request $requestId filtered out (does not match user criteria)');
            }
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Error in new requests listener: $error');
      },
    );
  }

  // ✅ Set up individual subscription for a specific request with debounced diff updates
  void _setupRequestSubscription(String requestId) {
    // Cancel existing subscription and debounce timer if any
    _requestSubscriptions[requestId]?.cancel();
    _debounceTimers[requestId]?.cancel();
    _debounceTimers.remove(requestId);
    _pendingUpdates.remove(requestId);
    
    // Create new subscription for this request
    _requestSubscriptions[requestId] = FirebaseFirestore.instance
        .collection('requests')
        .doc(requestId)
        .snapshots()
        .listen(
      (docSnapshot) {
        if (!mounted) return;
        
        // ✅ Handle deletions immediately (no debounce)
        if (!docSnapshot.exists) {
          // Request was deleted, remove it immediately
          _requestCache.remove(requestId); // ✅ Remove from cache
          _debouncedSetState(() {
            _allRequests.removeWhere((r) => r.requestId == requestId);
          });
          _requestSubscriptions[requestId]?.cancel();
          _requestSubscriptions.remove(requestId);
          _debounceTimers[requestId]?.cancel();
          _debounceTimers.remove(requestId);
          _pendingUpdates.remove(requestId);
          debugPrint('🗑️ Removed deleted request $requestId (immediate)');
          return;
        }
        
        // ✅ Debounced update for modifications: Store the latest snapshot and schedule update
        _pendingUpdates[requestId] = docSnapshot;
        
        // Cancel existing timer for this request
        _debounceTimers[requestId]?.cancel();
        
        // Create new debounce timer (500ms delay)
        _debounceTimers[requestId] = Timer(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          
          final pendingSnapshot = _pendingUpdates[requestId];
          if (pendingSnapshot == null) return; // Already processed
          
          _pendingUpdates.remove(requestId);
          _debounceTimers.remove(requestId);
          
          if (pendingSnapshot.exists) {
            // Request updated - apply the latest update (merged from multiple updates within 500ms)
            final updatedRequest = Request.fromFirestore(pendingSnapshot);
            
            // ✅ Update cache with full details
            _requestCache[requestId] = updatedRequest;
            
            // Update only this specific request in the list (diff update)
            // ✅ Use debounced setState to reduce rebuilds during rapid updates
            // ✅ Find index again inside setState to ensure it's still valid
            _debouncedSetState(() {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              final isUserInHelpers = currentUserId != null && 
                  updatedRequest.helpers.contains(currentUserId);
              
              // אם המשתמש נוסף ל-helpers array, נוסיף את הבקשה ל-_interestedRequests
              if (isUserInHelpers && !_interestedRequests.contains(requestId)) {
                _interestedRequests.add(requestId);
                debugPrint('✅ Added request $requestId to _interestedRequests (user added to helpers)');
              }
              
              final index = _allRequests.indexWhere((r) => r.requestId == requestId);
              if (index >= 0 && index < _allRequests.length) {
                // Verify index is still valid before updating
                _allRequests[index] = updatedRequest;
                
                // אם המשתמש נוסף ל-helpers array והבקשה במסך "כל הבקשות", נסיר אותה
                // כי היא צריכה להופיע רק ב"פניות שלי"
                // במסך "פניות שלי", הבקשה תישאר גם אם הצ'אט נמחק
                if (isUserInHelpers && !_showMyRequests) {
                  _allRequests.removeAt(index);
                  debugPrint('✅ Removed request $requestId from "All Requests" (should appear in "My Requests")');
                }
                // במסך "פניות שלי", הבקשה תישאר גם אם הצ'אט נמחק
                // לא נסיר אותה מ-_allRequests במסך "פניות שלי"
                
                // ✅ עדכון מספר "בקשות שלי" אם הבקשה שייכת למשתמש והסטטוס שלה השתנה
                final isMyRequest = updatedRequest.createdBy == currentUserId;
                if (isMyRequest && 
                    (updatedRequest.status == RequestStatus.open || 
                     updatedRequest.status == RequestStatus.inProgress)) {
                  // עדכון המספר (debounced כדי לא לעדכן יותר מדי פעמים)
                  _loadMyRequestsCount();
                }
              } else {
                // If request not found in list, it might have been removed or list was sorted
                // Try to add it if it's in "My Requests" view OR if status changed to "open" or "inProgress"
                // OR if the current user was added to helpers array
                if (!_allRequests.any((r) => r.requestId == requestId)) {
                  final isAdmin = AdminAuthService.isCurrentUserAdmin();
                  final userType = _userProfile?.userType;
                  
                  // ✅ בדיקת סינון לפי showToAllUsers
                  bool shouldShowRequest = false;
                  
                  if (_showMyRequests || isUserInHelpers) {
                    // במסך "פניות שלי" או אם המשתמש ב-helpers → תמיד להציג
                    shouldShowRequest = true;
                  } else if (updatedRequest.status == RequestStatus.open || 
                            (isAdmin && updatedRequest.status == RequestStatus.inProgress)) {
                    // בדיקת סינון לפי showToAllUsers
                    if (updatedRequest.showToAllUsers == false) {
                      // הבקשה מיועדת רק לנותני שירות מתחום X
                      // בודקים אם המשתמש הנוכחי הוא נותן שירות (business או guest עם businessCategories) עם הקטגוריה הזו
                      
                      // אם הפרופיל עדיין לא נטען, נציג את הבקשה (היא תוסתר אחרי שהפרופיל ייטען)
                      if (_userProfile == null) {
                        debugPrint('🔍 Request subscription: requestId=$requestId, showToAllUsers=false, but userProfile is null - showing request temporarily');
                        shouldShowRequest = true;
                      } else {
                        final isSubscriptionActive = _userProfile?.isSubscriptionActive ?? false;
                        
                        // משתמש עסקי מנוי (עם או בלי תחומי עיסוק) - צריך לבדוק התאמת תחום
                        if (userType == UserType.business && isSubscriptionActive) {
                          // אם אין תחומי עיסוק מוגדרים → לא יראה בקשות עם showToAllUsers=false
                          if (_userProfile?.businessCategories == null || _userProfile!.businessCategories!.isEmpty) {
                            shouldShowRequest = false;
                          } else {
                            // בודקים אם יש למשתמש את הקטגוריה של הבקשה
                            final hasMatchingCategory = _userProfile!.businessCategories!.any(
                              (category) => category == updatedRequest.category
                            );
                            shouldShowRequest = hasMatchingCategory;
                          }
                        } else if (userType == UserType.guest && _userProfile?.businessCategories != null && _userProfile!.businessCategories!.isNotEmpty) {
                          // משתמש אורח עם businessCategories - צריך לבדוק התאמת תחום
                          final hasMatchingCategory = _userProfile!.businessCategories!.any(
                            (category) => category == updatedRequest.category
                          );
                          shouldShowRequest = hasMatchingCategory;
                        } else {
                          shouldShowRequest = false;
                        }
                      }
                    } else {
                      // אם showToAllUsers == true או null → הבקשה תופיע לכל המשתמשים
                      shouldShowRequest = true;
                    }
                  }
                  
                  // Add if should show
                  if (shouldShowRequest) {
                    // במסך "פניות שלי", הבקשה תישאר גם אם הצ'אט נמחק
                    _allRequests.add(updatedRequest);
                    // In "My Requests" view, sort by interest time (newest first)
                    // In "All Requests" view, sort by createdAt (newest first)
                    if (_showMyRequests || isUserInHelpers) {
                      // Will be sorted by _sortAndUpdateRequestsList below
                    } else {
                      // Sort by createdAt descending to show newest first
                      _allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    }
                    // Ensure subscription exists for this request
                    if (!_requestSubscriptions.containsKey(requestId)) {
                      _setupRequestSubscription(requestId);
                      debugPrint('✅ Set up subscription for request $requestId that changed to open');
                    }
                  }
                }
              }
              
              // אם המשתמש נוסף ל-helpers array והבקשה לא ב-_allRequests, נוסיף אותה
              // כך שכאשר המשתמש יעבור למסך "פניות שלי", הבקשה תופיע שם
              if (isUserInHelpers && !_allRequests.any((r) => r.requestId == requestId)) {
                _allRequests.add(updatedRequest);
                debugPrint('✅ Added request $requestId to _allRequests (user added to helpers, will appear in "My Requests")');
                
                // Set up subscription for real-time updates
                if (!_requestSubscriptions.containsKey(requestId)) {
                  _setupRequestSubscription(requestId);
                }
              }
            });
            
            // במסך "פניות שלי", נמיין מחדש את הרשימה כדי שהבקשה שהתעניינו בה לאחרונה תופיע ראשונה
            // גם אם המשתמש נוסף ל-helpers array, נמיין מחדש את הרשימה
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isUserInHelpers = currentUserId != null && 
                updatedRequest.helpers.contains(currentUserId);
            
            // אם המשתמש נוסף ל-helpers array, נוסיף את הבקשה לרשימה ב"פניות שלי" גם אם המשתמש לא במסך "פניות שלי" כרגע
            if (isUserInHelpers && !_showMyRequests) {
              // נוסיף את הבקשה לרשימה ב"פניות שלי" גם אם המשתמש לא במסך "פניות שלי" כרגע
              // כאשר המשתמש יעבור למסך "פניות שלי", הבקשה תופיע שם
              debugPrint('✅ User added to helpers, request will appear in "My Requests" when user switches to that view');
            } else if (_showMyRequests) {
              // אם המשתמש במסך "פניות שלי", נמיין מחדש את הרשימה
              await _sortAndUpdateRequestsList();
            }
            
            debugPrint('🔄 Updated request $requestId (debounced diff update)');
          }
        });
      },
      onError: (error) {
        debugPrint('❌ Error in request snapshot for $requestId: $error');
        // Cancel subscription on error to prevent infinite retries
        _requestSubscriptions[requestId]?.cancel();
        _requestSubscriptions.remove(requestId);
        _debounceTimers[requestId]?.cancel();
        _debounceTimers.remove(requestId);
        _pendingUpdates.remove(requestId);
      },
    );
  }

  Future<void> _helpWithRequest(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // בדיקה אם המשתמש הוא אורח זמני
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final isTemporaryGuest = userData['isTemporaryGuest'] ?? false;
          
          if (isTemporaryGuest) {
            if (mounted) {
              final l10n = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.pleaseRegisterFirst),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Error checking temporary guest status: $e');
      }

      // קבלת פרטי הבקשה
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) return;
      
      final requestData = requestDoc.data()!;
      final creatorId = requestData['createdBy'] as String;
      final requestType = requestData['type'] as String?;
      final category = requestData['category'] as String?;
      
      // קבלת פרטי המשתמש לבדיקת תחומי עיסוק
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final userType = userData['userType'] as String?;
        final businessCategories = userData['businessCategories'] as List<dynamic>? ?? [];
        final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
        
        // בדיקה אם המשתמש הוא עסקי מנוי עם תחומי עיסוק
        if (userType == 'business' && isSubscriptionActive && businessCategories.isNotEmpty) {
          // בדיקה אם התחום של הבקשה מתאים לתחומי העיסוק של המשתמש
          final requestCategory = category; // קוד פנימי של enum (למשל 'plumbing')
          final requestCategoryHeb = _getCategoryDisplayName(category ?? '');
          final hasMatchingCategory = businessCategories.any((catRaw) {
            final cat = catRaw.toString();
            return cat == requestCategory || cat == requestCategoryHeb;
          });
          
          if (!hasMatchingCategory) {
            // התחום לא מתאים - הצג דיאלוג עדכון תחומי עיסוק
            debugPrint('❌ Business user category mismatch: request category="$requestCategory" (heb: "$requestCategoryHeb"), user categories=$businessCategories');
            await _showCategoryMismatchDialog(category ?? 'לא ידוע');
            return;
          }
        }
        
        // בדיקה אם המשתמש הוא אורח ובקשה בתשלום
        if (requestType == 'paid' && userType == 'guest') {
          // אם אין תחומי עיסוק כלל
          if (businessCategories.isEmpty) {
            await _showGuestCategoryDialog(category ?? 'לא ידוע');
            return;
          }
          
          // אם יש תחומי עיסוק אבל לא מתאימים לקטגוריית הבקשה
          final requestCategory = category; // קוד פנימי של enum (למשל 'plumbing')
          final requestCategoryHeb = _getCategoryDisplayName(category ?? '');
          final hasMatchingCategory = businessCategories.any((catRaw) {
            final cat = catRaw.toString();
            return cat == requestCategory || cat == requestCategoryHeb;
          });
          
          if (!hasMatchingCategory) {
            await _showCategoryMismatchDialog(category ?? 'לא ידוע');
            return;
          }
        }
      }

      // הוספת המשתמש לרשימת העוזרים ועדכון מספר העוזרים
      debugPrint('🔧 _helpWithRequest: Updating helpersCount for request $requestId');
      
      // בדיקת הסטטוס הנוכחי מה-requestData שכבר נטען
      final currentHelpers = List<String>.from(requestData['helpers'] ?? []);
      final currentStatus = requestData['status'] as String?;
      
      // עדכון helpers
      final updateData = <String, dynamic>{
        'helpers': FieldValue.arrayUnion([user.uid]),
        'helpersCount': FieldValue.increment(1),
      };
      
      // אם יש עוזרים והסטטוס הוא "פתוח", עדכן ל-"בטיפול"
      if (currentHelpers.isEmpty && currentStatus == 'open') {
        updateData['status'] = 'inProgress';
        debugPrint('✅ _helpWithRequest: Updating status from "open" to "inProgress"');
      }
      
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update(updateData);
      debugPrint('✅ _helpWithRequest: helpersCount incremented by 1');

      // שמירת זמן ההתעניינות ב-user_interests collection למיון במסך "פניות שלי"
      final now = DateTime.now();
      final interestDocId = '${user.uid}_$requestId';
      debugPrint('💾 _helpWithRequest: Saving interest time ${now} for request $requestId (doc: $interestDocId)');
      await FirebaseFirestore.instance
          .collection('user_interests')
          .doc(interestDocId)
          .set({
        'userId': user.uid,
        'requestId': requestId,
        'interestedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      debugPrint('✅ _helpWithRequest: Saved interest time ${now} for request $requestId (doc: $interestDocId)');
      
      // עדכון מספר הבקשות שהמשתמש מטפל בהן
      _loadMyInProgressRequestsCount();
      
      // ✅ וידוא שהזמן נשמר - קריאה מחדש מיד אחרי השמירה
      final verifyDoc = await FirebaseFirestore.instance
          .collection('user_interests')
          .doc(interestDocId)
          .get();
      if (verifyDoc.exists) {
        final verifyData = verifyDoc.data()!;
        final verifyTimestamp = verifyData['interestedAt'] as Timestamp?;
        if (verifyTimestamp != null) {
          debugPrint('✅ _helpWithRequest: Verified interest time saved: ${verifyTimestamp.toDate()}');
        } else {
          debugPrint('⚠️ _helpWithRequest: Interest time not found in saved document!');
        }
      } else {
        debugPrint('⚠️ _helpWithRequest: Interest document not found after save!');
      }

      // הוספת הבקשה לרשימת הבקשות שהמשתמש מעוניין בהן
      setState(() {
        _interestedRequests.add(requestId);
        _showMyRequests = true; // מעבר אוטומטי למצב "בקשות שפניתי אליהם"
      });
      
      // במסך "פניות שלי", נוודא שהבקשה החדשה ב-_allRequests ואז נמיין מחדש
      if (_showMyRequests) {
        // בדיקה אם הבקשה כבר ב-_allRequests
        final existingRequestIndex = _allRequests.indexWhere((r) => r.requestId == requestId);
        
        if (existingRequestIndex < 0) {
          // הבקשה לא ב-_allRequests, נוסיף אותה
          Request? newRequest;
          
          // ננסה למצוא אותה ב-cache
          if (_requestCache.containsKey(requestId)) {
            newRequest = _requestCache[requestId];
          } else {
            // נטען אותה מ-Firestore
            newRequest = Request.fromFirestore(requestDoc);
            _requestCache[requestId] = newRequest;
          }
          
          if (newRequest != null) {
            // ✅ הוספת הבקשה החדשה לתחילת הרשימה - תמיד תופיע ראשונה
            setState(() {
              _allRequests.insert(0, newRequest!);
            });
            
            // Set up subscription for real-time updates
            _setupRequestSubscription(requestId);
            
            debugPrint('✅ Added new request $requestId to the BEGINNING of _allRequests in "My Requests" view');
          }
        } else {
          // הבקשה כבר ב-_allRequests - נעביר אותה לתחילת הרשימה
          final existingRequest = _allRequests[existingRequestIndex];
          setState(() {
            _allRequests.removeAt(existingRequestIndex);
            _allRequests.insert(0, existingRequest);
          });
          
          // נוודא שיש לה subscription
          if (!_requestSubscriptions.containsKey(requestId)) {
            _setupRequestSubscription(requestId);
            debugPrint('✅ Set up subscription for existing request $requestId in "My Requests" view');
          }
          debugPrint('✅ Moved existing request $requestId to the BEGINNING of _allRequests in "My Requests" view');
        }
        
        // ✅ הבקשה החדשה כבר נוספה לתחילת הרשימה (insert(0, ...))
        // ✅ לא צריך למיין עכשיו - המיון יתבצע בטעינה הבאה לפי זמני הלחיצה מ-Firestore
        debugPrint('✅ New request $requestId added to beginning of list. Will be sorted by interest time on next load.');
      }
      
      // יצירת צ'אט עבור כל עוזר (לא רק הראשון)
      debugPrint('Creating chat for request: $requestId, creator: $creatorId, helper: ${user.uid}');
      final chatId = await ChatService.createChat(
        requestId: requestId,
        creatorId: creatorId,
        helperId: user.uid,
      );
      
      debugPrint('Chat created with ID: $chatId');
      
      if (chatId != null) {
        // יצירת הודעה אוטומטית בצ'אט עם דירוג המשתמש
        if (!context.mounted) return;
        final l10nForMessage = AppLocalizations.of(context);
        await _sendAutoMessageWithRating(chatId, user.uid, requestData['category'] ?? 'other', l10nForMessage);
        
        // יצירת התראה למבקש
        await NotificationService.notifyHelpOffered(
          requestCreatorId: creatorId,
          helperName: user.displayName ?? 'משתמש',
          requestTitle: requestData['title'] ?? l10nForMessage.request,
        );
        
        // שליחת push notification למבקש הבקשה
        await CloudFunctionService.sendHelpOfferNotification(
          requestCreatorId: creatorId,
          helperName: user.displayName ?? 'משתמש',
          requestTitle: requestData['title'] ?? l10nForMessage.request,
        );
        
        debugPrint('Help notification sent to creator: $creatorId');
      }

      // שליחת התראה מקומית למשתמש הנוכחי (אישור שההצעת עזרה נשלחה)
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      await NotificationServiceLocal.showNotification(
        id: 100,
        title: l10n.helpSent,
        body: l10n.helpSent,
        payload: 'help_sent',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.helpSent,
            style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
          ),
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorMessage(e.toString())),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// הצגת דיאלוג אישור לביטול עניין
  Future<void> _showUnhelpConfirmationDialog(Request request) async {
    // הוספת צליל לדיאלוג
    await playButtonSound();
    
    // Guard context usage after async gap
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final l10nDialog = AppLocalizations.of(context);
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text(l10nDialog.confirmCancelInterest),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10nDialog.unhelpConfirmation,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10nDialog.requestLabel}: ${request.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10nDialog.categoryLabel}: ${request.category.categoryDisplayName}',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (request.type == RequestType.paid) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10nDialog.typeLabel}: ${l10nDialog.paidType}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10nDialog.afterCancelNoChat,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await playButtonSound();
                // Guard context usage after async gap - check context.mounted for builder context
                if (!context.mounted) return;
                Navigator.of(context).pop(false);
              },
              child: Text(
                l10nDialog.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await playButtonSound();
                // Guard context usage after async gap - check context.mounted for builder context
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(l10nDialog.yesCancelInterest),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _unhelpWithRequest(request.requestId);
    }
  }

  /// הסרת בקשה ממסך "פניות שלי" (לא מוחק את הבקשה עצמה, רק מסיר אותה מהרשימה)
  Future<void> _removeRequestFromMyRequests(String requestId) async {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteRequest),
        content: Text('האם אתה בטוח שברצונך להסיר את הבקשה ממסך "${l10n.myRequests}"? הבקשה לא תימחק, רק תוסר מהרשימה.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.deleteRequest),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        // הסרת הבקשה מרשימת הבקשות שהמשתמש מעוניין בהן
        setState(() {
          _interestedRequests.remove(requestId);
          _allRequests.removeWhere((r) => r.requestId == requestId);
          _requestCache.remove(requestId);
          _expandedRequests.remove(requestId);
          _loadingFullDetails.remove(requestId);
        });
        
        // ביטול המנוי לבקשה אם קיים
        _requestSubscriptions[requestId]?.cancel();
        _requestSubscriptions.remove(requestId);
        _debounceTimers[requestId]?.cancel();
        _debounceTimers.remove(requestId);
        _pendingUpdates.remove(requestId);
        
        debugPrint('✅ Request removed from my requests: $requestId');
        
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('הבקשה הוסרה ממסך "${l10n.myRequests}"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        debugPrint('❌ Error removing request from my requests: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהסרת הבקשה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unhelpWithRequest(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('🔍 User unhelping with request: $requestId');
      debugPrint('🔍 User UID: ${user.uid}');

      // הסרת המשתמש מרשימת העוזרים ועדכון מספר העוזרים
      debugPrint('🔧 _unhelpWithRequest: Updating helpersCount for request $requestId');
      
      // קבלת הבקשה הנוכחית כדי לבדוק את הסטטוס
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        debugPrint('⚠️ Request $requestId does not exist');
        return;
      }
      
      final requestData = requestDoc.data()!;
      final currentHelpers = List<String>.from(requestData['helpers'] ?? []);
      final currentStatus = requestData['status'] as String?;
      
      // עדכון helpers
      final updateData = <String, dynamic>{
        'helpers': FieldValue.arrayRemove([user.uid]),
        'helpersCount': FieldValue.increment(-1),
      };
      
      // אם אין עוזרים והסטטוס הוא "בטיפול", עדכן ל-"פתוח"
      if (currentHelpers.length == 1 && currentStatus == 'inProgress') {
        updateData['status'] = 'open';
        debugPrint('✅ _unhelpWithRequest: Updating status from "inProgress" to "open"');
      }
      
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update(updateData);
      debugPrint('✅ _unhelpWithRequest: helpersCount decremented by 1');

      debugPrint('✅ User removed from helpers list');

      // עדכון מספר הבקשות שהמשתמש מטפל בהן
      _loadMyInProgressRequestsCount();
      
      // הסרת הבקשה מרשימת הבקשות שהמשתמש מעוניין בהן
      setState(() {
        _interestedRequests.remove(requestId);
        
        // אם אנחנו במסך "פניות שלי", נסיר את הבקשה מ-_allRequests
        if (_showMyRequests) {
          _allRequests.removeWhere((r) => r.requestId == requestId);
          debugPrint('✅ Removed request $requestId from _allRequests in "My Requests" view');
        }
        
        // נשאר במצב הנוכחי - לא משנים את _showMyRequests
      });

      debugPrint('✅ Request removed from interested requests');

      // מחיקת הצ'אט אם קיים
      await _deleteChatForRequest(requestId);
      
      debugPrint('✅ Chat deletion completed');
      
      // עדכון המסך כדי להסתיר את כפתור הצ'אט
      if (mounted) {
        setState(() {});
        debugPrint('✅ UI updated after unhelping');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ביטלת את העניין שלך בבקשה'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorMessage(e.toString())),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<String?> _getUserProfileImageFromFirestore(String uid) async {
    try {
      debugPrint('=== GETTING USER PROFILE IMAGE FROM FIRESTORE ===');
      debugPrint('User ID: $uid');
      
      // ננסה לקבל מידע מ-user_profiles
      final userProfilesDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      debugPrint('user_profiles exists: ${userProfilesDoc.exists}');
      
      if (userProfilesDoc.exists) {
        final userData = userProfilesDoc.data()!;
        final profileImageUrl = userData['profileImageUrl'];
        
        debugPrint('Profile image URL: $profileImageUrl');
        return profileImageUrl;
      }
      
      debugPrint('No profile image found');
      return null;
    } catch (e) {
      debugPrint('Error getting user profile image: $e');
      return null;
    }
  }

  Stream<String?> _getUserNameFromFirestore(String uid) {
    return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 'משתמש';
      
      final userData = snapshot.data()!;
        final name = userData['name'];
        final displayName = userData['displayName'];
        final email = userData['email'];
        
        final result = name ?? 
               displayName ?? 
             email?.split('@')[0] ?? 
             'משתמש';
             
      return result;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    debugPrint('=== PHONE CALL FUNCTION CALLED ===');
    debugPrint('Phone number received: $phoneNumber');
    try {
      // ניקוי מספר הטלפון (הסרת תווים לא רלוונטיים)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      debugPrint('Attempting to call: $cleanNumber');
      
      // יצירת URI להתקשרות
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
      debugPrint('Phone URI: $phoneUri');
      
      // ניסיון להתקשר ישירות ללא בדיקת הרשאות
      try {
        debugPrint('Trying to launch URL: $phoneUri');
        
        // ננסה עם כל ה-modes האפשריים
        final List<LaunchMode> modes = [
          LaunchMode.externalApplication,
          LaunchMode.platformDefault,
          LaunchMode.externalNonBrowserApplication,
        ];
        
        bool launched = false;
        for (final mode in modes) {
          try {
            debugPrint('Trying mode: $mode');
            launched = await launchUrl(phoneUri, mode: mode);
            debugPrint('Launch result with $mode: $launched');
            if (launched) break;
          } catch (e) {
            debugPrint('Error with mode $mode: $e');
          }
        }
        
        if (!launched) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא ניתן להתקשר למספר זה'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          debugPrint('Successfully launched phone call');
        }
      } catch (launchError) {
        debugPrint('Launch error: $launchError');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתקשרות: $launchError'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Phone call error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בהתקשרות: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// הצגת דיאלוג עם מפה שמציגה את מיקום הבקשה
  void _showRequestLocationDialog(BuildContext context, Request request) {
    if (request.latitude == null || request.longitude == null) return;
    
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // כותרת הדיאלוג
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.address ?? l10n.locationNotSpecified,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // מפה
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(request.latitude!, request.longitude!),
                      zoom: 15.0,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('request_location'),
                        position: LatLng(request.latitude!, request.longitude!),
                        infoWindow: InfoWindow(
                          title: request.title,
                          snippet: request.address ?? l10n.locationNotSpecified,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                    },
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // כפתור לפתיחת Waze
              if (request.latitude != null && request.longitude != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openWazeNavigation(request.latitude!, request.longitude!);
                  },
                  icon: Image.asset(
                    'assets/images/waze.png',
                    width: 24,
                    height: 24,
                  ),
                  label: const Text('פתח ב-Waze'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// הצגת דיאלוג עם מפה שמציגה את מיקום נותן השירות
  void _showProviderLocationDialog(BuildContext context, UserProfile provider) {
    final latitude = provider.latitude ?? provider.mobileLatitude;
    final longitude = provider.longitude ?? provider.mobileLongitude;
    
    if (latitude == null || longitude == null) return;
    
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // כותרת הדיאלוג
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.village ?? provider.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // מפה
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(latitude, longitude),
                      zoom: 15.0,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('provider_location'),
                        position: LatLng(latitude, longitude),
                        infoWindow: InfoWindow(
                          title: provider.displayName,
                          snippet: provider.village ?? l10n.locationNotSpecified,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                      ),
                    },
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // כפתור לפתיחת Waze
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openWazeNavigation(latitude, longitude);
                },
                icon: Image.asset(
                  'assets/images/waze.png',
                  width: 24,
                  height: 24,
                ),
                label: const Text('פתח ב-Waze'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// פותח את אפליקציית Waze לניווט למיקום המבוקש
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

  Future<void> _sendAutoMessageWithRating(String chatId, String helperId, String category, AppLocalizations l10n) async {
    try {
      debugPrint('🔍 Sending auto message with rating for chat: $chatId, helper: $helperId, category: $category');
      
      // קבלת פרטי המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(helperId)
          .get();
      
      if (!userDoc.exists) {
        debugPrint('❌ User document not found');
        return;
      }
      
      final userData = userDoc.data()!;
      final displayName = userData['displayName'] ?? 'משתמש';
      final averageRating = (userData['averageRating'] as num?)?.toDouble() ?? 0.0;
      final ratingCount = (userData['ratingCount'] as num?)?.toInt() ?? 0;
      
      // בדיקה אם המשתמש הוא מומחה בתחום
      final isExpert = averageRating >= 4.5 && ratingCount >= 3;
      final expertBadge = isExpert ? ' 🏆 מומחה' : '';
      
      // יצירת הודעה עם דירוג
      String message = l10n.helloIAm(displayName, expertBadge);
      
      // ✅ תמיד מוסיפים "מתחום X"
      message += ' ${l10n.newInField(_getCategoryDisplayName(category))}';
      
      // אם יש דירוגים, מוסיפים גם את הדירוג
      if (ratingCount > 0) {
        message += ' (${averageRating.toStringAsFixed(1)}⭐ ב${_getCategoryDisplayName(category)})';
      }
      
      message += ' ${l10n.interestedInHelping}';
      
      debugPrint('🔍 Auto message: $message');
      
      // שליחת ההודעה
      await ChatService.sendMessage(
        chatId: chatId,
        text: message,
      );
      
      debugPrint('✅ Auto message sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending auto message: $e');
    }
  }

  String _getCategoryDisplayName(String category) {
    // אם הקטגוריה כבר בעברית, החזר אותה
    if (category.contains('ריצוף') || category.contains('צבע') || category.contains('אינסטלציה') || 
        category.contains('חשמל') || category.contains('נגרות') || category.contains('גגות') ||
        category.contains('מעליות') || category.contains('תיקון רכב') || category.contains('שירותי רכב') ||
        category.contains('הובלה') || category.contains('הסעות') || category.contains('אופניים') ||
        category.contains('כלי רכב') || category.contains('שמרטפות') || category.contains('שיעורים') ||
        category.contains('פעילויות') || category.contains('בריאות') || category.contains('לידה') ||
        category.contains('חינוך') || category.contains('שירותי משרד') || category.contains('שיווק') ||
        category.contains('ייעוץ') || category.contains('אירועים') || category.contains('ניקיון') ||
        category.contains('אבטחה') || category.contains('ציור') || category.contains('מלאכת') ||
        category.contains('מוזיקה') || category.contains('צילום') || category.contains('עיצוב') ||
        category.contains('אומנויות') || category.contains('פיזיותרפיה') || category.contains('יוגה') ||
        category.contains('תזונה') || category.contains('בריאות הנפש') || category.contains('רפואה') ||
        category.contains('קוסמטיקה') || category.contains('מחשבים') || category.contains('חשמל ואלקטרוניקה') ||
        category.contains('אינטרנט') || category.contains('אפליקציות') || category.contains('מערכות') ||
        category.contains('מכשור') || category.contains('שפות') || category.contains('מקצועות') ||
        category.contains('כישורי') || category.contains('לימודים') || category.contains('הכשרה') ||
        category.contains('בידור') || category.contains('ספורט') || category.contains('תיירות') ||
        category.contains('מסיבות') || category.contains('צילום ווידאו') || category.contains('גינון') ||
        category.contains('ניקיון סביבתי') || category.contains('איכות') || category.contains('בעלי חיים') ||
        category.contains('תחזוקה') || category.contains('בישול') || category.contains('מזון בריא') ||
        category.contains('אירועי מזון') || category.contains('אוכל מהיר') || category.contains('מסעדות') ||
        category.contains('מאפים') || category.contains('ייעוץ תזונתי') || category.contains('אימונים') ||
        category.contains('ספורט קבוצתי') || category.contains('אומנויות לחימה') || category.contains('ריקוד') ||
        category.contains('ספורט אתגרי') || category.contains('שיקום')) {
      return category;
    }
    
    // נסה למצוא את הקטגוריה ב-enum
    try {
      final requestCategory = RequestCategory.values.firstWhere(
        (cat) => cat.name == category,
        orElse: () => RequestCategory.plumbing,
      );
      return requestCategory.categoryDisplayName;
    } catch (e) {
      // אם לא נמצא, החזר את השם המקורי
      return category;
    }
  }

  Future<void> _deleteChatForRequest(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('🔍 Deleting chat for request: $requestId');
      debugPrint('🔍 User UID: ${user.uid}');

      // חיפוש הצ'אט עבור הבקשה
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .get();

      debugPrint('🔍 Found ${chatsQuery.docs.length} chats for request');

      for (final chatDoc in chatsQuery.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);
        
        debugPrint('🔍 Chat participants: $participants');
        
        // בדיקה אם המשתמש הנוכחי הוא חלק מהצ'אט
        if (participants.contains(user.uid)) {
          // מחיקת הצ'אט
          await chatDoc.reference.delete();
          debugPrint('✅ Chat deleted for request: $requestId');
        } else {
          debugPrint('ℹ️ User not in chat participants, skipping deletion');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting chat for request: $e');
    }
  }

  Future<void> _openChat(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('Opening chat for request: $requestId, user: ${user.uid}');
      
      // שמירת מיקום הבקשה הנוכחית

      // חיפוש צ'אט קיים
      final chatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('requestId', isEqualTo: requestId)
          .where('participants', arrayContains: user.uid)
          .get();

      debugPrint('Found ${chatQuery.docs.length} chats for request $requestId');

      if (chatQuery.docs.isNotEmpty) {
        // Find the correct chat for this specific user
        String? correctChatId;
        for (var doc in chatQuery.docs) {
          final chatData = doc.data();
          final participants = List<String>.from(chatData['participants'] ?? []);
          // Check if this chat contains exactly 2 participants and includes the current user
          if (participants.length == 2 && participants.contains(user.uid)) {
            correctChatId = doc.id;
            debugPrint('Found correct chat: $correctChatId, participants: $participants');
            break;
          }
        }
        
        if (correctChatId != null) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: correctChatId!,
                requestTitle: l10n.request, // TODO: קבלת כותרת הבקשה
              ),
            ),
          );
          
          // חזרה מהצ'אט
          debugPrint('🔍 Chat return - result: $result');
        } else {
          debugPrint('No valid chat found for user ${user.uid}');
          // Create a new chat if no valid one found
          await _createNewChatForRequest(requestId, user.uid);
        }
      } else {
        debugPrint('No chat found for request $requestId with user ${user.uid}');
        
        // בדיקה אם יש צ'אט בכלל עבור הבקשה
        final allChatsQuery = await FirebaseFirestore.instance
            .collection('chats')
            .where('requestId', isEqualTo: requestId)
            .get();
        
        debugPrint('Total chats for request $requestId: ${allChatsQuery.docs.length}');
        for (var doc in allChatsQuery.docs) {
          debugPrint('Chat ${doc.id}: participants = ${doc.data()['participants']}');
        }
        
        // בדיקה אם יש צ'אט קיים עם המשתמש הנוכחי
        final userChatQuery = await FirebaseFirestore.instance
            .collection('chats')
            .where('requestId', isEqualTo: requestId)
            .where('participants', arrayContains: user.uid)
            .get();
        
        if (userChatQuery.docs.isNotEmpty) {
          // המשתמש כבר נמצא בצ'אט - נפתח את הצ'אט הקיים
          final existingChat = userChatQuery.docs.first;
          final chatId = existingChat.id;
          final chatData = existingChat.data();
          final participants = List<String>.from(chatData['participants'] ?? []);
          
          debugPrint('Found existing chat for user: $chatId with participants: $participants');
          
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                requestTitle: l10n.request, // TODO: קבלת כותרת הבקשה
              ),
            ),
          );
          
          // חזרה מהצ'אט
          debugPrint('🔍 Chat return - result: $result');
          return;
        }
        
        // אם אין צ'אט קיים עם המשתמש, ניצור צ'אט חדש
        debugPrint('No existing chat found for user, creating new one...');
        await _createNewChatForRequest(requestId, user.uid);
      }
    } catch (e) {
      debugPrint('Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בפתיחת הצ\'אט: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _createNewChatForRequest(String requestId, String userId) async {
    try {
      // Get request details to find the creator
      final requestDoc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .get();
      
      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;
        final creatorId = requestData['createdBy'] as String;
        
        // Create a new chat using ChatService
        final chatId = await ChatService.createChat(
          requestId: requestId,
          creatorId: creatorId,
          helperId: userId,
        );
        
        if (chatId != null) {
          debugPrint('Created new chat: $chatId');
          
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                requestTitle: l10n.request, // TODO: Get request title
              ),
            ),
          );
          
          // חזרה מהצ'אט
          debugPrint('🔍 Chat return - result: $result');
        } else {
          throw Exception('Failed to create chat');
        }
      } else {
        throw Exception('Request not found');
      }
    } catch (e) {
      debugPrint('Error creating new chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת צ\'אט: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// ✅ פונקציה לבחירת כיוון טקסט בחיפוש
  TextDirection _getTextDirection(String text) {
    final rtlRegex = RegExp(r'[\u0590-\u05FF\u0600-\u06FF]'); // עברית/ערבית
    if (rtlRegex.hasMatch(text)) {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 HomeScreen initState() called');
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() => setState(() {}));
    
    // אתחול NetworkService
    NetworkService.initialize();
    
    // אתחול אנימציית ההבהוב
    _blinkingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    
    // אתחול אנימציית הספירה - משך האנימציה יוגדר דינמית לפי מספר הבקשות
    _countAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // ברירת מחדל - יוחלף דינמית
      vsync: this,
    );
    
    // הוספת Listener לגלילה לטעינת עוד בקשות
    _scrollController.addListener(_onScroll);
    
    _loadUserProfile();
    _loadNotificationPrefs();
    _loadSavedFilters(); // טעינת סינון שמור
    _loadFilterPreferencesFromFirestore(); // טעינת סינון מ-Firestore (להתראות)
    _loadInterestedRequests(); // טעינת בקשות שהמשתמש מעוניין בהן
    _loadUserRatings(); // טעינת דירוגים של המשתמש
    _checkForNewNotifications();
    _startLocationTracking(); // התחלת מעקב מיקום
    _loadTotalRequestsCount(); // טעינת ספירת כל הבקשות במערכת
    // טעינת בקשות ראשוניות - רק אם לא במסך "פניות שלי" או "נותני שירות"
    // (במסך "פניות שלי" נטען את כל הבקשות שהמשתמש התעניין בהן כשעוברים למסך)
    if (!_showMyRequests && !_showServiceProviders) {
      _loadInitialRequests(); // טעינת בקשות ראשוניות (manual pagination)
      _setupNewRequestsListener(); // ✅ האזנה לבקשות חדשות שנוצרות על ידי משתמשים אחרים
    } else if (_showServiceProviders) {
      _loadInitialServiceProviders(); // טעינת נותני שירות ראשוניים
    }
    
    // הצגת הודעות למשתמש אורח - רק פעם אחת
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      _showGuestStatusMessage(_userProfile);
      _showLocationReminderMessage(_userProfile);
      _showTutorialIfNeeded(); // הוספת הטוטוריאל כאן
      }
    });
    
    // בדיקת הגדלת טווח
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      LocationService.checkAndShowRadiusIncreaseNotification(context);
      }
    });
    
    // עדכון המצב - המשתמש יצא מכל הצ'אטים
    AppStateService.exitAllChats();
    
    // בדיקה נוספת אחרי 2 שניות
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
      _checkForNewNotifications();
      }
    });
    
    // בדיקה נוספת אחרי 5 שניות
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
      _checkForNewNotificationsDelayed();
      }
    });
  }
  Future<void> _loadNotificationPrefs() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final prefs = await NotificationPreferencesService.getNotificationPreferencesWithDefaults(uid);
      if (mounted) {
        setState(() => _notificationPrefs = prefs);
      }
      
      // ✅ שמירת העדפות ב-SharedPreferences כדי שנוכל לבדוק אותן ב-WorkManager/BroadcastReceiver
      // גם כאשר האפליקציה סגורה לחלוטין
      final sharedPrefs = await SharedPreferences.getInstance();
      await sharedPrefs.setBool('user_use_mobile_location', prefs.newRequestsUseMobileLocation);
      await sharedPrefs.setBool('user_use_both_locations', prefs.newRequestsUseBothLocations);
      // ✅ שמירת userId ב-SharedPreferences כדי שנוכל לשלוח התראה דרך FCM
      await sharedPrefs.setString('current_user_id', uid);
      debugPrint('✅ Loaded and saved notification preferences to SharedPreferences: useMobile=${prefs.newRequestsUseMobileLocation}, useBoth=${prefs.newRequestsUseBothLocations}, userId=$uid');
    } catch (e) {
      debugPrint('❌ Error loading notification preferences: $e');
    }
  }

  // טעינת סינון מ-Firestore (להתראות)
  Future<void> _loadFilterPreferencesFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final filterPrefs = await FilterPreferencesService.getFilterPreferences(uid);
      if (mounted) {
        setState(() => _filterPreferencesFromFirestore = filterPrefs);
      }
      
      if (filterPrefs != null) {
        debugPrint('✅ Loaded filter preferences from Firestore: isEnabled=${filterPrefs.isEnabled}, useAdditionalLocation=${filterPrefs.useAdditionalLocation}');
      } else {
        debugPrint('ℹ️ No filter preferences found in Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error loading filter preferences from Firestore: $e');
    }
  }

  // הצגת הודעת הדרכה למשתמשים חדשים - רק למסך הבית
  Future<void> _showTutorialIfNeeded() async {
    debugPrint('🏠 HOME SCREEN - _showTutorialIfNeeded called');
    
    // בדיקה אם כבר הוצג הדיאלוג במהלך הפעלה זו
    if (_tutorialShown) {
      debugPrint('🏠 HOME SCREEN - Tutorial already shown in this session, returning');
      return;
    }
    
    // המתן קצת כדי שהמסך יטען
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) {
      debugPrint('🏠 HOME SCREEN - Not mounted, returning');
      return;
    }
    
    final hasSeenTutorial = await TutorialService.hasSeenTutorial(TutorialService.homeScreenTutorial);
    debugPrint('🏠 HOME SCREEN - Has seen tutorial: $hasSeenTutorial');
    if (hasSeenTutorial) return;
    
    // בדיקה אם המשתמש הוא חדש (פחות מ-7 ימים)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('🏠 HOME SCREEN - No user, returning');
      return;
    }
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) {
      debugPrint('🏠 HOME SCREEN - User doc does not exist, returning');
      return;
    }
    
    final userData = userDoc.data()!;
    final createdAt = userData['createdAt'] as Timestamp?;
    if (createdAt == null) {
      debugPrint('🏠 HOME SCREEN - No createdAt, returning');
      return;
    }
    
    final daysSinceCreation = DateTime.now().difference(createdAt.toDate()).inDays;
    debugPrint('🏠 HOME SCREEN - Days since creation: $daysSinceCreation');
    if (daysSinceCreation > 3) {
      debugPrint('🏠 HOME SCREEN - User is not new (more than 3 days), returning');
      return; // רק למשתמשים חדשים מאוד
    }
    
    // הודעת הדרכה מינימלית
    _showMinimalTutorial();
    
    // סימון שהדיאלוג הוצג
    _tutorialShown = true;
  }
  
  // הודעת הדרכה מינימלית
  void _showMinimalTutorial() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.waving_hand, color: Colors.orange[600]),
            const SizedBox(width: 8),
            Text(
              l10n.welcomeMessage,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.welcomeToApp,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tutorialHint,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              TutorialService.markTutorialAsSeen(TutorialService.homeScreenTutorial);
            },
            child: Text(
              l10n.understood,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              TutorialService.markTutorialAsSeen(TutorialService.homeScreenTutorial);
              // פתיחת המדריך המרכזי
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TutorialCenterScreen(),
                ),
              );
            },
            child: Text(l10n.openTutorial),
          ),
        ],
      ),
    );
  }
  
  /// בניית כפתור סינון מודרני
  Widget _buildModernFilterButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isActive ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: isActive ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    key: ValueKey('$icon-$isActive'),
                    size: 14,
                    color: isActive ? Colors.white : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Badge עם מספר הבקשות - באמצע למעלה
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              top: -10,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// פורמט תאריך ושעה בצורה חכמה
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final requestDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (requestDate == today) {
      // היום - רק שעה
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (requestDate == yesterday) {
      // אתמול - "אתמול" + שעה
      return 'אתמול ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // לפני יותר מיום - תאריך + שעה
      return '${dateTime.day}/${dateTime.month}/${dateTime.year.toString().substring(2)} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }




  // טעינת דירוגים של המשתמש לפי קטגוריה
  Future<void> _loadUserRatings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('🔄 Loading user ratings...');
      
      // טעינת כל הדירוגים של המשתמש
      final ratingsQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .where('ratedUserId', isEqualTo: user.uid)
          .get();

      debugPrint('📊 Found ${ratingsQuery.docs.length} ratings for user');
      
      // חישוב דירוג ממוצע לכל קטגוריה
      final categoryRatings = <String, List<int>>{};
      
      for (final doc in ratingsQuery.docs) {
        final data = doc.data();
        final category = data['category'] as String?;
        final rating = data['rating'] as int?;
        
        debugPrint('🔍 Found rating: category=$category, rating=$rating');
        
        if (category != null && rating != null) {
          categoryRatings.putIfAbsent(category, () => []).add(rating);
        }
      }
      
      // חישוב ממוצע לכל קטגוריה
      _userRatingsByCategory.clear();
      for (final entry in categoryRatings.entries) {
        final category = entry.key;
        final ratings = entry.value;
        final average = ratings.reduce((a, b) => a + b) / ratings.length;
        _userRatingsByCategory[category] = average;
        debugPrint('📊 User rating in $category: $average (from ${ratings.length} ratings)');
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error loading user ratings: $e');
    }
  }

  Future<void> _loadInterestedRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // טעינת בקשות שהמשתמש מעוניין בהן
      final requestsQuery = await FirebaseFirestore.instance
          .collection('requests')
          .where('helpers', arrayContains: user.uid)
          .get();

      final interestedRequestIds = requestsQuery.docs
          .map((doc) => doc.id)
          .toSet();

      setState(() {
        _interestedRequests = interestedRequestIds;
      });

      debugPrint('Loaded ${_interestedRequests.length} interested requests');
    } catch (e) {
      debugPrint('Error loading interested requests: $e');
    }
  }

  // טעינת כל הבקשות שהמשתמש התעניין בהן למסך "פניות שלי"
  Future<void> _loadAllInterestedRequests() async {
    if (mounted) {
      setState(() {
        _isLoadingMyRequests = true;
      });
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoadingMyRequests = false;
          });
        }
        return;
      }

      debugPrint('📥 Loading all interested requests for "My Requests" view...');
      debugPrint('📥 User UID: ${user.uid}');

      // טעינת כל הבקשות שהמשתמש התעניין בהן (ללא הגבלה)
      // ✅ כולל בקשות עם סטטוס "טופל" ו-"בטיפול" כדי שהמשתמש יוכל למחוק אותן ב-"פניות שלי"
      final requestsQuery = await FirebaseFirestore.instance
          .collection('requests')
          .where('helpers', arrayContains: user.uid)
          .where('status', whereIn: [RequestStatus.open.name, RequestStatus.inProgress.name, RequestStatus.completed.name])
          .get();
      
      debugPrint('📥 Found ${requestsQuery.docs.length} requests in Firestore for user ${user.uid}');

      // ✅ Firestore Query Optimization - Use lightweight factory
      final interestedRequests = requestsQuery.docs
          .map((doc) {
            // Check cache first
            if (_requestCache.containsKey(doc.id)) {
              return _requestCache[doc.id]!;
            }
            // Use lightweight factory
            final lightweightRequest = Request.fromFirestoreLightweight(doc);
            _requestCache[doc.id] = lightweightRequest;
            return lightweightRequest;
          })
          .toList();

      // Set up individual subscriptions for real-time updates
      for (final request in interestedRequests) {
        _setupRequestSubscription(request.requestId);
      }

      // מיון הבקשות לפי זמן ההתעניינות לפני הצגתן
      // כך שהבקשה שהתעניינו בה לאחרונה תופיע ראשונה כבר מהטעינה הראשונית
      final sortedRequests = await _sortRequestsByInterestTime(interestedRequests);
      debugPrint('✅ Sorted ${sortedRequests.length} requests by interest time during initial load');

      // עדכון רשימת הבקשות שהמשתמש התעניין בהן
      final interestedRequestIds = sortedRequests
          .map((request) => request.requestId)
          .toSet();

      if (mounted) {
        setState(() {
          _allRequests = sortedRequests; // שמירת הבקשות המסודרות
          _interestedRequests = interestedRequestIds;
          _isLoadingInitial = false; // במסך "פניות שלי" אין דיאלוג טעינה
          _isLoadingMyRequests = false; // סיום טעינה
        });
        debugPrint('✅ Loaded ${sortedRequests.length} interested requests for "My Requests" view (already sorted)');
      }
    } catch (e) {
      debugPrint('❌ Error loading all interested requests: $e');
      if (mounted) {
        setState(() {
          _isLoadingMyRequests = false; // סיום טעינה גם במקרה של שגיאה
          _isLoadingInitial = false;
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ _loadUserProfile: No user found');
        return;
      }

      debugPrint('✅ _loadUserProfile: User found - ${user.uid}');
      debugPrint('✅ _loadUserProfile: User email - ${user.email}');
      debugPrint('✅ _loadUserProfile: User is anonymous - ${user.isAnonymous}');

      // Listen to real-time profile changes
      _profileSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
        (snapshot) {
        if (snapshot.exists && mounted) {
          final newProfile = UserProfile.fromFirestore(snapshot);
          final newBusinessCategories = newProfile.businessCategories;
          
          // אתחול ראשוני של _previousBusinessCategories אם עדיין לא הוגדר
          if (_previousBusinessCategories == null) {
            _previousBusinessCategories = _userProfile?.businessCategories ?? newBusinessCategories;
          }
          
          // ✅ בדיקה אם תחומי העיסוק השתנו מהפרופיל הנוכחי (לפני setState)
          final currentCategories = _userProfile?.businessCategories;
          final hasChangedFromCurrent = !_areCategoriesEqual(currentCategories, newBusinessCategories);
          
          // בדיקה אם תחומי העיסוק השתנו - השוואה ישירה בין הקטגוריות הקודמות לחדשות
          final businessCategoriesChanged = !_areCategoriesEqual(_previousBusinessCategories, newBusinessCategories);
          
          if (businessCategoriesChanged || hasChangedFromCurrent) {
            debugPrint('🔄 Business categories changed!');
            debugPrint('   Previous: ${_previousBusinessCategories?.map((c) => c.name).toList()}');
            debugPrint('   Current: ${currentCategories?.map((c) => c.name).toList()}');
            debugPrint('   New: ${newBusinessCategories?.map((c) => c.name).toList()}');
            debugPrint('   businessCategoriesChanged: $businessCategoriesChanged');
            debugPrint('   hasChangedFromCurrent: $hasChangedFromCurrent');
          }
          
          setState(() {
            _userProfile = newProfile;
            debugPrint('🔄 Real-time profile update - business categories: ${_userProfile?.businessCategories?.map((c) => c.name).toList()}');
          });
          
          // אם תחומי העיסוק השתנו (מהקטגוריות הקודמות או מהפרופיל הנוכחי), טען מחדש את הבקשות
          if (businessCategoriesChanged || hasChangedFromCurrent) {
            debugPrint('🔄 Business categories changed - reloading requests...');
            _reloadRequestsForUpdatedCategories();
          }
          
          // עדכון הקטגוריות הקודמות (אחרי הבדיקה)
          _previousBusinessCategories = newBusinessCategories;
          
          // חישוב הטווח העדכני
          _calculateCurrentMaxRadius();
          // ניקוי התראות כפולות קיימות
          _cleanupDuplicateNotifications();
        }
        },
        onError: (error) {
          debugPrint('❌ Error in profile snapshot: $error');
          // לא להתרסק - המשך לעבוד ללא עדכון פרופיל בזמן אמת
        },
      );
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// בדיקה אם שתי רשימות קטגוריות שוות
  bool _areCategoriesEqual(List<RequestCategory>? list1, List<RequestCategory>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;
    
    final set1 = list1.toSet();
    final set2 = list2.toSet();
    return set1.length == set2.length && set1.every((cat) => set2.contains(cat));
  }

  /// טעינה מחדש של הבקשות לאחר עדכון תחומי העיסוק
  Future<void> _reloadRequestsForUpdatedCategories() async {
    if (!mounted) return;
    
    try {
      debugPrint('🔄 Reloading requests after business categories update...');
      
      setState(() {
        // איפוס הבקשות והתחלה מחדש
        _allRequests.clear();
        _lastDocumentSnapshot = null;
        _hasMoreRequests = true;
        _isLoadingInitial = true;
        
        // Cancel all subscriptions and debounce timers
        for (final subscription in _requestSubscriptions.values) {
          subscription.cancel();
        }
        _requestSubscriptions.clear();
        
        // Cancel all debounce timers
        for (final timer in _debounceTimers.values) {
          timer.cancel();
        }
        _debounceTimers.clear();
        _pendingUpdates.clear();
        
        // Clear cache when reloading
        _requestCache.clear();
      });
      
      // טעינה מחדש של הבקשות הראשוניות
      if (!_showMyRequests && !_showServiceProviders) {
        await _loadInitialRequests(forceReload: true);
      } else if (_showServiceProviders) {
        await _loadInitialServiceProviders();
      }
      
      debugPrint('✅ Requests reloaded after business categories update');
    } catch (e) {
      debugPrint('❌ Error reloading requests after categories update: $e');
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
        });
      }
    }
  }

  // שמירת סינון נוכחי
  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterData = {
        'selectedCategory': _selectedCategory?.name,
        'selectedMainCategories': _selectedMainCategories.toList(),
        'selectedSubCategories': _selectedSubCategories.map((c) => c.name).toList(),
        'selectedRequestType': _selectedRequestType?.name,
        'selectedUrgency': _selectedUrgency?.name,
        'maxDistance': _maxDistance,
        'userLatitude': _userLatitude,
        'userLongitude': _userLongitude,
        // מיקום נוסף (נבחר במפה) - נשמר בנפרד
        'additionalLocationLatitude': _additionalLocationLatitude,
        'additionalLocationLongitude': _additionalLocationLongitude,
        'additionalLocationRadius': _additionalLocationRadius,
        'useAdditionalLocation': _useAdditionalLocation, // צ'יקבוקס למיקום נוסף
        // צ'קבוקסים של סינון לפי מיקום
        'useFixedLocationAndRadius': _useFixedLocationAndRadius,
        'useMobileLocationAndRadius': _useMobileLocationAndRadius,
        'receiveNewRequests': _receiveNewRequests,
        // ✅ לא שומרים את העיגולים - הם מתבטלים כששומרים סינון
      };
      
      // שמירה כ-JSON
      final jsonString = jsonEncode(filterData);
      await prefs.setString(_filterKey, jsonString);
      debugPrint('💾 Filters saved: $filterData');
    } catch (e) {
      debugPrint('Error saving filters: $e');
    }
  }

  // טעינת סינון שמור
  Future<void> _loadSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilters = prefs.getString(_filterKey);
      
      if (savedFilters != null && savedFilters.isNotEmpty) {
        // Parse the saved filters (simplified parsing)
        debugPrint('📂 Loading saved filters: $savedFilters');
        
        // For now, we'll show a dialog asking if user wants to restore filters
        if (mounted) {
          _showRestoreFiltersDialog();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved filters: $e');
    }
  }

  // דיאלוג שחזור סינון
  Future<void> _showRestoreFiltersDialog() async {
    // דיליי קצר כדי לתת למסך להיטען
    await Future.delayed(const Duration(milliseconds: 800));
    
    // בדיקה אם המסך עדיין פעיל
    if (!mounted) return;
    
    // בדיקה אם מגיעים מהתראות - אם כן, לא נציג את דיאלוג הסינון
    if (AppStateService.isFromNotification()) {
      debugPrint('⚠️ Skipping restore filters dialog - coming from notification');
      AppStateService.clearFromNotification(); // איפוס הסמן
      return;
    }
    
    // בדיקה אם יש route אחר פעיל (כמו דיאלוג אחר) - אם יש, לא נציג את דיאלוג הסינון
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null && !modalRoute.isCurrent) {
      // יש route אחר פעיל, לא נציג את דיאלוג הסינון
      return;
    }
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).savedFilter),
          content: Text(AppLocalizations.of(context).savedFilterFound),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).no),
              onPressed: () {
                Navigator.of(context).pop();
                // הסרת הסינון השמור, ניקוי מ-Firestore, ועדכון UI
                _performClearFilters();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).yes),
              onPressed: () {
                Navigator.of(context).pop();
                // טעינת הסינון השמור והחלתו
                _restoreFilters();
              },
            ),
          ],
        );
      },
    );
  }

  // שחזור סינון
  Future<void> _restoreFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilters = prefs.getString(_filterKey);
      
      if (savedFilters != null && savedFilters.isNotEmpty) {
        final filterData = jsonDecode(savedFilters) as Map<String, dynamic>;
        debugPrint('🔄 Restoring filters: $filterData');
        
        if (mounted) {
          setState(() {
            // שחזור קטגוריה (תמיכה לאחור)
            if (filterData['selectedCategory'] != null) {
              _selectedCategory = RequestCategory.values.firstWhere(
                (cat) => cat.name == filterData['selectedCategory'],
                orElse: () => _selectedCategory ?? RequestCategory.values.first,
              );
            }
            // שחזור תחומים ראשיים (נשמרים כ-List<String>)
            if (filterData['selectedMainCategories'] != null) {
              final mainCategoriesList = filterData['selectedMainCategories'] as List<dynamic>?;
              if (mainCategoriesList != null) {
                _selectedMainCategories = mainCategoriesList.map((c) => c.toString()).toSet();
              }
            }
            // שחזור תת-תחומים (נשמרים כ-List<String> של שמות)
            if (filterData['selectedSubCategories'] != null) {
              final subCategoriesList = filterData['selectedSubCategories'] as List<dynamic>?;
              if (subCategoriesList != null) {
                _selectedSubCategories = subCategoriesList
                    .map((name) => RequestCategory.values.firstWhere(
                          (c) => c.name == name.toString(),
                          orElse: () => RequestCategory.plumbing,
                        ))
                    .toSet();
              }
            }
            
            // ✅ לא טוענים את העיגולים כשטוענים סינון שמור - העיגולים מתבטלים כששומרים סינון
            _selectedMainCategoryFromCircles = null;
            
            // שחזור סוג בקשה
            if (filterData['selectedRequestType'] != null) {
              _selectedRequestType = RequestType.values.firstWhere(
                (type) => type.name == filterData['selectedRequestType'],
                orElse: () => RequestType.values.first,
              );
            }
            
            // שחזור דחיפות
            if (filterData['selectedUrgency'] != null) {
              _selectedUrgency = UrgencyFilter.values.firstWhere(
                (e) => e.name == filterData['selectedUrgency'],
                orElse: () => UrgencyFilter.normal,
              );
            }
            
            
            // שחזור מרחק מקסימלי (למיקום נייד)
            if (filterData['maxDistance'] != null) {
              _maxDistance = filterData['maxDistance'] as double;
            }
            
            // שחזור מיקום משתמש (מיקום נייד - נוכחי)
            if (filterData['userLatitude'] != null) {
              _userLatitude = filterData['userLatitude'] as double;
            }
            if (filterData['userLongitude'] != null) {
              _userLongitude = filterData['userLongitude'] as double;
            }
            
            // שחזור מיקום נוסף (נבחר במפה) - נשמר בנפרד
            if (filterData['additionalLocationLatitude'] != null) {
              _additionalLocationLatitude = filterData['additionalLocationLatitude'] as double;
            }
            if (filterData['additionalLocationLongitude'] != null) {
              _additionalLocationLongitude = filterData['additionalLocationLongitude'] as double;
            }
            if (filterData['additionalLocationRadius'] != null) {
              _additionalLocationRadius = filterData['additionalLocationRadius'] as double;
            }
            if (filterData.containsKey('useAdditionalLocation')) {
              _useAdditionalLocation = (filterData['useAdditionalLocation'] as bool?) ?? false;
            }

            // שחזור צ'קבוקסים של סינון לפי מיקום
            if (filterData.containsKey('useFixedLocationAndRadius')) {
              _useFixedLocationAndRadius = (filterData['useFixedLocationAndRadius'] as bool?) ?? false;
            }
            if (filterData.containsKey('useMobileLocationAndRadius')) {
              _useMobileLocationAndRadius = (filterData['useMobileLocationAndRadius'] as bool?) ?? false;
            }
            if (filterData.containsKey('receiveNewRequests')) {
              _receiveNewRequests = filterData['receiveNewRequests'] as bool?;
            }
          });
          
          // הצגת הודעה למשתמש
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('הסינון השמור הוחזר בהצלחה'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
          
          // הפעלת הסינון בזמן אמת
          debugPrint('🔄 Filters restored, triggering UI update');
          debugPrint('🔄 Restored filters:');
          debugPrint('  - Category: $_selectedCategory');
          debugPrint('  - Request type: $_selectedRequestType');
          debugPrint('  - Urgency: $_selectedUrgency');
          debugPrint('  - Max distance: $_maxDistance');
          
          // ✅ טעינה מחדש של FilterPreferences מ-Firestore (אם יש סינון שמור עם התראות)
          await _loadFilterPreferencesFromFirestore();
          
          // ✅ טעינה מחדש של הבקשות כדי להחיל את הסינון
          if (mounted) {
            setState(() {
              // איפוס הבקשות והתחלה מחדש
              _allRequests.clear();
              _lastDocumentSnapshot = null;
              _hasMoreRequests = true;
              // Cancel all subscriptions and debounce timers
              for (final subscription in _requestSubscriptions.values) {
                subscription.cancel();
              }
              _requestSubscriptions.clear();
              // ✅ Cancel all debounce timers
              for (final timer in _debounceTimers.values) {
                timer.cancel();
              }
              _debounceTimers.clear();
              _pendingUpdates.clear();
              // ✅ Clear cache when restoring filters
              _requestCache.clear();
            });
            
            // טעינה מחדש של הבקשות הראשוניות
            if (!_showMyRequests) {
              await _loadInitialRequests();
            } else {
              // במסך "פניות שלי", נטען את כל הבקשות שהמשתמש התעניין בהן
              await _loadAllInterestedRequests();
            }
          }
          
          // כפיית עדכון UI נוסף
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                debugPrint('🔄 Forcing UI update after filter restoration');
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error restoring filters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשחזור הסינון: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // מחיקת סינון שמור
  Future<void> _clearSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filterKey);
      debugPrint('🗑️ Saved filters cleared');
    } catch (e) {
      debugPrint('Error clearing saved filters: $e');
    }
  }

  // ניווט למסך פרופיל
  void _navigateToProfile() {
    // הצגת הודעה למשתמש לעבור למסך פרופיל
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('אנא עבור למסך פרופיל דרך התפריט התחתון כדי להפעיל מנוי'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }


  // התחלת מעקב מיקום אוטומטי
  void _startLocationTracking() {
    // מעקב מיקום כל 30 שניות
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateLocationAndRefresh();
    });
  }

  // עדכון מיקום ורענון תוצאות
  Future<void> _updateLocationAndRefresh() async {
    try {
      // במסך "פניות שלי", לא נעדכן את המיקום ולא נטען בקשות מחדש
      if (_showMyRequests) {
        return;
      }
      
      // בדיקה אם יש הרשאות מיקום
      bool hasPermission = await LocationService.checkLocationPermission();
      if (!hasPermission) return;

      // קבלת מיקום נוכחי
      Position? position = await LocationService.getCurrentPosition();
      if (position == null) {
        // ✅ בדיקה והצגת דיאלוג אם שירות המיקום מבוטל
        if (mounted) {
          await LocationService.checkAndShowLocationServiceDialog(context);
        }
        return;
      }

      // בדיקה אם המיקום השתנה משמעותית (יותר מ-100 מטר)
      if (_userLatitude != null && _userLongitude != null) {
        double distance = _userLatitude != null && _userLongitude != null
            ? LocationService.calculateDistance(
          _userLatitude!,
          _userLongitude!,
          position.latitude,
          position.longitude,
              )
            : 0.0;
        
        // אם המיקום השתנה פחות מ-100 מטר, לא נעדכן
        if (distance < 0.1) return; // 100 מטר = 0.1 קילומטר
      }

      // עדכון המיקום
      if (mounted) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
        });
        
        // רענון התוצאות אם יש סינון לפי מרחק - רק אם יש עוד בקשות לטעינה
        if (_maxDistance != null && _hasMoreRequests) {
          setState(() {}); // רענון המסך כדי לעדכן את הסינון
        }
        
        // עדכון מיקום בסינונים הפעילים
        await _updateFilterNotificationsLocation(position.latitude, position.longitude);
        
        debugPrint('📍 Location updated: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  // עדכון מיקום בסינונים הפעילים
  Future<void> _updateFilterNotificationsLocation(double latitude, double longitude) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationKeys = prefs.getStringList('filter_notification_keys') ?? [];
      
      for (String key in notificationKeys) {
        try {
          final filterDataString = prefs.getString(key);
          if (filterDataString == null) continue;
          
          // פענוח נתוני הסינון
          final filterData = _parseFilterData(filterDataString);
          if (filterData == null) continue;
          
          // עדכון המיקום
          filterData['userLatitude'] = latitude;
          filterData['userLongitude'] = longitude;
          filterData['lastLocationUpdate'] = DateTime.now().toIso8601String();
          
          // שמירה מחדש
          await prefs.setString(key, filterData.toString());
          
          debugPrint('📍 Updated location for filter notification: $key');
        } catch (e) {
          debugPrint('Error updating location for filter $key: $e');
        }
      }

      // בנוסף: שמירת מיקום נייד נוכחי במסמך המשתמש כדי שמחולל ההתראות יוכל להשתמש בו
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'mobileLatitude': latitude,
            'mobileLongitude': longitude,
            'mobileLocationUpdatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('📍 Saved mobile location to Firestore for notifications');
        }
      } catch (e) {
        debugPrint('⚠️ Failed saving mobile location to Firestore: $e');
      }
    } catch (e) {
      debugPrint('Error updating filter notifications location: $e');
    }
  }


  // פענוח נתוני הסינון (העתקה מהקובץ new_request_screen.dart)
  Map<String, dynamic>? _parseFilterData(String filterDataString) {
    try {
      // הסרת סוגריים ותווים מיותרים
      String cleanData = filterDataString
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll(' ', '');
      
      Map<String, dynamic> result = {};
      
      // פיצול לפי פסיקים
      List<String> pairs = cleanData.split(',');
      
      for (String pair in pairs) {
        List<String> keyValue = pair.split(':');
        if (keyValue.length == 2) {
          String key = keyValue[0].trim();
          String value = keyValue[1].trim();
          
          // המרת ערכים
          if (value == 'null') {
            result[key] = null;
          } else if (value == 'true') {
            result[key] = true;
          } else if (value == 'false') {
            result[key] = false;
          } else if (value.contains('.')) {
            result[key] = double.tryParse(value);
          } else {
            result[key] = value;
          }
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('Error parsing filter data: $e');
      return null;
    }
  }


  // הצגת דיאלוג בחירת טווח בקשות
  void _showDistancePickerDialog(StateSetter setDialogState) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('בחירת טווח בקשות'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Column(
              children: [
                // הודעת הגבלות משתמש
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Theme.of(context).colorScheme.tertiary, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'הטווח המקסימלי שלך: ${(_currentMaxRadius ?? _maxSearchRadius).toStringAsFixed(1)} ק"מ\n'
                          'בקשות בחודש: $_maxRequestsPerMonth בקשות',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.tertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // כפתור בחירת מיקום במפה
                ElevatedButton.icon(
                  onPressed: () async {
                    await playButtonSound();
                    if (!mounted || !context.mounted) return;
                    // פתיחת מסך בחירת מיקום נוסף
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          initialLatitude: _additionalLocationLatitude ?? _userLatitude,
                          initialLongitude: _additionalLocationLongitude ?? _userLongitude,
                          initialAddress: 'מיקום נוכחי',
                          initialExposureRadius: _additionalLocationRadius ?? _maxDistance,
                          maxExposureRadius: _currentMaxRadius ?? _maxSearchRadius,
                          showExposureCircle: true,
                        ),
                      ),
                    );
                    
                    if (!mounted || !context.mounted) return;
                    if (result != null) {
                      setState(() {
                        // ✅ שמירת מיקום נוסף בנפרד (לא משנה את המיקום הנייד)
                        _additionalLocationLatitude = result['latitude'];
                        _additionalLocationLongitude = result['longitude'];
                        _additionalLocationRadius = result['exposureRadius'] ?? 10.0;
                        // ✅ סמן אוטומטית את הצ'יקבוקס למיקום נוסף לאחר בחירת מיקום וטווח
                        _useAdditionalLocation = true;
                      });
                      // ✅ סמן אוטומטית את הצ'קבוקס "קבל התראות על בקשות חדשות" לאחר בחירת מיקום וטווח חשיפה
                      setDialogState(() {
                        _receiveNewRequests = true;
                      });
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('בחר מיקום וטווח במפה'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // הצגת מיקום נוסף נבחר (אם נבחר במפה) + צ'יקבוקס
                if (_additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        // ✅ צ'יקבוקס למיקום נוסף
                        CheckboxListTile(
                          title: Text(
                            'סנן בקשות על פי המיקום הנוסף',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            ),
                          ),
                          value: _useAdditionalLocation,
                          onChanged: (value) {
                            setDialogState(() {
                              _useAdditionalLocation = value ?? false;
                              final atLeastOne = _useFixedLocationAndRadius || _useMobileLocationAndRadius || _useAdditionalLocation;
                              if (atLeastOne) {
                                _receiveNewRequests ??= true;
                              } else {
                                _receiveNewRequests = false;
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        Row(
                      children: [
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.tertiary, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                                'מיקום נוסף נבחר: ${_additionalLocationLatitude?.toStringAsFixed(4) ?? 'N/A'}, ${_additionalLocationLongitude?.toStringAsFixed(4) ?? 'N/A'}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                              fontSize: 12,
                                  fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.radio_button_checked, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                        Text(
                              'טווח: ${_additionalLocationRadius!.toStringAsFixed(1)} ק"מ',
                          style: TextStyle(
                            color: Colors.blue[700],
                                fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 24),
                        const SizedBox(width: 8),
                            Expanded(
                          child: Text(
                            'לחץ על "בחר מיקום וטווח במפה" כדי לבחור מיקום וטווח',
                          style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark 
                            ? Theme.of(context).colorScheme.onPrimary 
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: (_useAdditionalLocation && _additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null) ||
                         (_useMobileLocationAndRadius && _userLatitude != null && _userLongitude != null && _maxDistance != null) ||
                         (_useFixedLocationAndRadius && _userProfile != null && _userProfile!.latitude != null && _userProfile!.longitude != null)
                  ? () {
                      // ✅ סמן אוטומטית את הצ'קבוקס "קבל התראות על בקשות חדשות" לאחר בחירת מיקום וטווח חשיפה
                      setDialogState(() {
                        _receiveNewRequests = true;
                      });
                      Navigator.pop(context);
                    }
                  : null,
              child: Text(AppLocalizations.of(context).ok),
            ),
          ],
        ),
      ),
    );
  }




  Future<void> _checkForNewNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in, skipping notification check');
        return;
      }

      // בדיקה נוספת שהמשתמש עדיין מחובר
      if (!mounted) {
        debugPrint('Widget unmounted, skipping notification check');
        return;
      }

      debugPrint('Checking notifications for user: ${user.uid}');

      // בדיקת התראות חדשות למשתמש הנוכחי (ללא orderBy כדי למנוע צורך באינדקס)
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .limit(1)
          .get();

      debugPrint('Found ${notificationsQuery.docs.length} unread notifications');

      if (notificationsQuery.docs.isNotEmpty) {
        final notification = notificationsQuery.docs.first.data();
        final message = notification['message'] as String?;
        final createdAt = notification['createdAt'] as Timestamp?;
        
        if (message != null && message.isNotEmpty && createdAt != null) {
          // בדיקה שההתראה חדשה (פחות מ-60 שניות)
          final now = DateTime.now();
          final notificationTime = createdAt.toDate();
          final timeDiff = now.difference(notificationTime).inSeconds;
          
          debugPrint('Notification time diff: $timeDiff seconds');
          
          if (timeDiff <= 60) { // התראה חדשה
            // הצגת התראה מקומית
            final title = notification['title'] as String? ?? 'התראה חדשה!';
            await NotificationServiceLocal.showNotification(
              id: 200,
              title: title,
              body: message,
              payload: 'new_notification',
            );
            
            debugPrint('Initial notification check - shown: $title - $message');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
      // Don't show error to user, just log it
    }
  }

  // פונקציה נוספת לבדיקת התראות חדשות
  Future<void> _checkForNewNotificationsDelayed() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in for delayed notification check');
        return;
      }

      // המתן קצת לפני הבדיקה
      await Future.delayed(const Duration(seconds: 3));

      // בדיקה אם ה-widget עדיין mounted
      if (!mounted) {
        debugPrint('Widget unmounted, skipping delayed notification check');
        return;
      }

      // בדיקה נוספת שהמשתמש עדיין מחובר
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('User logged out during delayed check');
        return;
      }

      debugPrint('Performing delayed notification check for user: ${currentUser.uid}');

      // בדיקת התראות חדשות למשתמש הנוכחי (ללא orderBy כדי למנוע צורך באינדקס)
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: currentUser.uid)
          .where('read', isEqualTo: false)
          .limit(1)
          .get();

      debugPrint('Delayed check found ${notificationsQuery.docs.length} unread notifications');

      if (notificationsQuery.docs.isNotEmpty) {
        final notification = notificationsQuery.docs.first.data();
        final message = notification['message'] as String?;
        final createdAt = notification['createdAt'] as Timestamp?;
        
        if (message != null && message.isNotEmpty && createdAt != null) {
          // בדיקה שההתראה חדשה (פחות מ-120 שניות)
          final now = DateTime.now();
          final notificationTime = createdAt.toDate();
          final timeDiff = now.difference(notificationTime).inSeconds;
          
          debugPrint('Delayed notification time diff: $timeDiff seconds');
          
          if (timeDiff <= 120) { // התראה חדשה
            // הצגת התראה מקומית
            final title = notification['title'] as String? ?? 'התראה חדשה!';
            await NotificationServiceLocal.showNotification(
              id: 201,
              title: title,
              body: message,
              payload: 'new_notification_delayed',
            );
            
            debugPrint('Delayed notification check - shown: $title - $message');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking delayed notifications: $e');
      // Don't show error to user, just log it
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Profile is now loaded via real-time StreamBuilder
    debugPrint('🔄 didChangeDependencies called - profile loaded via StreamBuilder');
    // כשהמשתמש חוזר למסך הבית, התחל אנימציה מחדש
    _checkAndStartAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Profile is now loaded via real-time StreamBuilder
      debugPrint('🔄 didChangeAppLifecycleState - app resumed, profile loaded via StreamBuilder');
      // טעינת ספירת הבקשות כל פעם שהמשתמש חוזר למסך
      _loadTotalRequestsCount();
    }
  }

  // הפעלת חיפוש בזמן אמת
  void _performSearch() {
    // החיפוש מתבצע אוטומטית ב-StreamBuilder
    // הפונקציה הזו רק מבטיחה שה-setState נקרא
    if (mounted) {
      setState(() {});
    }
  }

  // בדיקה אם משתמש אורח בחר תחומי עיסוק
  bool _hasGuestSelectedCategories(UserProfile? userProfile) {
    if (userProfile?.userType != UserType.guest) return false;
    return userProfile?.businessCategories != null && 
           userProfile!.businessCategories!.isNotEmpty;
  }

  // הצגת הודעה למשתמש אורח על מצב הגישה שלו (כהתראה חד-פעמית)
  void _showGuestStatusMessage(UserProfile? userProfile) async {
    if (userProfile?.userType != UserType.guest) return;
    
    final hasCategories = _hasGuestSelectedCategories(userProfile);
    
    // קביעת סוג ההתראה על בסיס המצב
    String notificationType;
    if (hasCategories) {
      notificationType = 'guest_with_categories';
    } else {
      // אורחים ללא הגבלת זמן - אין התראה על סיום תקופה
      return; // לא נשלח התראה על סיום תקופה כי אין הגבלת זמן
    }
    
    // בדיקה אם כבר נשלחה התראה מסוג זה למשתמש הזה
    final prefs = await SharedPreferences.getInstance();
    final notificationKey = 'guest_notification_${notificationType}_${userProfile?.userId}';
    final hasBeenSent = prefs.getBool(notificationKey) ?? false;
    
    if (hasBeenSent) {
      debugPrint('Guest notification already sent: $notificationType for user: ${userProfile?.userId}');
      return;
    }
    
    debugPrint('Sending guest status notification: $notificationType for user: ${userProfile?.userId}');
    
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    String title;
    String message;
    if (hasCategories) {
      title = l10n.guestModeWithCategories;
      message = l10n.seeMoreSelectFields;
    } else {
      title = l10n.trialPeriodEnded;
      message = l10n.selectBusinessFieldsInProfile;
    }
    
    // שליחת התראה למסך התראות
    await NotificationService.sendNotification(
      toUserId: userProfile?.userId ?? '',
      title: title,
      message: message,
    );
    
    // סימון שההתראה נשלחה
    await prefs.setBool(notificationKey, true);
    
    debugPrint('✅ Guest status notification sent: $notificationType for user: ${userProfile?.userId}');
  }

  // הצגת הודעה למשתמשים שלא הגדירו מיקום קבוע (כהתראה חד-פעמית)
  void _showLocationReminderMessage(UserProfile? userProfile) async {
    if (userProfile?.latitude != null && userProfile?.longitude != null) return;
    
    // בדיקה אם כבר נשלחה התראה למשתמש הזה
    final prefs = await SharedPreferences.getInstance();
    final notificationKey = 'location_reminder_${userProfile?.userId}';
    final hasBeenSent = prefs.getBool(notificationKey) ?? false;
    
    if (hasBeenSent) {
      debugPrint('Location reminder notification already sent for user: ${userProfile?.userId}');
      return;
    }
    
    debugPrint('Sending location reminder notification for user: ${userProfile?.userId}');
    
    // שליחת התראה למסך התראות
    await NotificationService.sendNotification(
      toUserId: userProfile?.userId ?? '',
      title: 'הגדר מיקום קבוע בפרופיל',
      message: 'כנותן שירות, הגדרת מיקום קבוע חיונית כדי להופיע במפות של בקשות גם כששירות המיקום כובה בטלפון',
    );
    
    // סימון שההתראה נשלחה
    await prefs.setBool(notificationKey, true);
    
    debugPrint('✅ Location reminder notification sent for user: ${userProfile?.userId}');
  }

  // פונקציה למחיקת התראות כפולות קיימות
  Future<void> _cleanupDuplicateNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // מחיקת התראות כפולות של "ברוכים הבאים"
      final l10n = AppLocalizations.of(context);
      final welcomeNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: user.uid)
          .where('title', isEqualTo: l10n.guestPeriodStarted)
          .get();

      if (welcomeNotifications.docs.length > 1) {
        // שמירה על ההתראה הראשונה, מחיקת השאר
        final notificationsToDelete = welcomeNotifications.docs.skip(1);
        for (final doc in notificationsToDelete) {
          await doc.reference.delete();
          debugPrint('Deleted duplicate welcome notification: ${doc.id}');
        }
      }

      // מחיקת התראות כפולות של "הגדר מיקום קבוע"
      final locationNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: user.uid)
          .where('title', isEqualTo: 'הגדר מיקום קבוע בפרופיל')
          .get();

      if (locationNotifications.docs.length > 1) {
        // שמירה על ההתראה הראשונה, מחיקת השאר
        final notificationsToDelete = locationNotifications.docs.skip(1);
        for (final doc in notificationsToDelete) {
          await doc.reference.delete();
          debugPrint('Deleted duplicate location notification: ${doc.id}');
        }
      }

      debugPrint('✅ Duplicate notifications cleanup completed');
    } catch (e) {
      debugPrint('❌ Error cleaning up duplicate notifications: $e');
    }
  }

  @override
  void dispose() {
    _mobileLocationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    _blinkingController.dispose();
    // הסרת Listener לפני dispose
    _countAnimationController?.removeListener(_onAnimationUpdate);
    _countAnimationController?.dispose();
    _profileSubscription?.cancel();
    // ✅ Cancel new requests listener
    _newRequestsSubscription?.cancel();
    // Cancel all individual request subscriptions
    for (final subscription in _requestSubscriptions.values) {
      subscription.cancel();
    }
    _requestSubscriptions.clear();
    // ✅ Cancel all debounce timers to prevent memory leaks
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingUpdates.clear();
    // ✅ Cancel setState debounce timer
    _setStateDebounceTimer?.cancel();
    _requestCache.clear(); // Clear cache on dispose
    super.dispose();
  }
  
  // טעינת ספירת כל הבקשות במערכת - נקרא כל פעם שהמשתמש נכנס לדף הבית
  Future<void> _loadTotalRequestsCount() async {
    debugPrint('🚀 _loadTotalRequestsCount() CALLED - Starting function execution');
    try {
      debugPrint('📊 Loading total requests count...');
      
      // ספירת בקשות במצב "פתוח" ו"בטיפול"
      // "בקשות פתוחות לטיפול" = כל הבקשות עם status='open' (לא כולל אלו שהמשתמש יצר)
      // + כל הבקשות במצב "בטיפול" שנוצרו על ידי משתמשים אחרים (לא המשתמש המחובר)
      // לא במצב "טופל" ולא במצב "נמחק"
      int openCount = 0;
      
      // קבלת המשתמש המחובר לבדיקה
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // משתנה לשימוש כגיבוי אם השאילתה נכשלת
      int manualOpenCount = 0;
      
      // נסה קודם לבדוק כמה בקשות יש בכלל במערכת
      try {
        final allRequestsSample = await FirebaseFirestore.instance
            .collection('requests')
            .limit(50)
            .get();
        
        debugPrint('📊 Sample of all requests: ${allRequestsSample.docs.length}');
        
        // בדיקה ידנית של הסטטוסים (לשימוש כגיבוי אם השאילתה נכשלת)
        for (var doc in allRequestsSample.docs) {
          final data = doc.data();
          final status = data['status'] as String?;
          final isDeleted = data['isDeleted'] as bool? ?? false;
          final createdBy = data['createdBy'] as String?;
          
          if (isDeleted) continue;
          if (status == RequestStatus.completed.name) continue; // לא לספור בקשות "טופל"
          
          // ✅ סופרים את כל הבקשות הפתוחות (לא כולל אלו שהמשתמש יצר)
          if (status == RequestStatus.open.name) {
            if (currentUserId != null && createdBy == currentUserId) {
              continue; // דלג על בקשות שהמשתמש יצר
            }
            manualOpenCount++;
          }
          // ✅ סופרים גם את הבקשות במצב "בטיפול" שנוצרו על ידי משתמשים אחרים (לא המשתמש המחובר)
          else if (status == RequestStatus.inProgress.name) {
            if (currentUserId != null && createdBy == currentUserId) {
              continue; // דלג על בקשות שהמשתמש יצר
            }
            manualOpenCount++;
          }
        }
        debugPrint('📊 Manual count from sample - Open + Other users\' inProgress (excluding user\'s own): $manualOpenCount');
      } catch (e) {
        debugPrint('❌ Error getting sample: $e');
      }
      
      // נשתמש בשאילתה אחת ל-status='open'
      try {
        // ספירת כל הבקשות עם status='open' - בלי isDeleted
        // ✅ לא כולל בקשות שהמשתמש המחובר יצר (רק בקשות של משתמשים אחרים)
        final openQuery = await FirebaseFirestore.instance
            .collection('requests')
            .where('status', isEqualTo: RequestStatus.open.name)
            .get();
        
        // ספירת כל הבקשות הפתוחות (לא כולל אלו שהמשתמש יצר)
        for (var doc in openQuery.docs) {
          final data = doc.data();
          final isDeleted = data['isDeleted'] as bool? ?? false;
          if (isDeleted) continue;
          
          // ✅ לא סופרים בקשות שהמשתמש יצר
          final createdBy = data['createdBy'] as String?;
          if (currentUserId != null && createdBy == currentUserId) {
            continue; // דלג על בקשות שהמשתמש יצר
          }
          
          openCount++;
        }
        debugPrint('📊 Open requests query result (status=open, excluding user\'s own requests): $openCount');
        
        // ✅ ספירת בקשות במצב "בטיפול" שנוצרו על ידי משתמשים אחרים (לא המשתמש המחובר)
        if (currentUserId != null) {
          // נטען את כל הבקשות במצב "בטיפול" ונסנן רק את אלו שנוצרו על ידי משתמשים אחרים
          final inProgressQuery = await FirebaseFirestore.instance
              .collection('requests')
              .where('status', isEqualTo: RequestStatus.inProgress.name)
              .get();
          
          int otherUsersInProgressCount = 0;
          for (var doc in inProgressQuery.docs) {
            final data = doc.data();
            final isDeleted = data['isDeleted'] as bool? ?? false;
            if (isDeleted) continue;
            
            // ✅ לא סופרים בקשות שהמשתמש יצר
            final createdBy = data['createdBy'] as String?;
            if (createdBy == currentUserId) {
              continue; // דלג על בקשות שהמשתמש יצר
            }
            
            otherUsersInProgressCount++;
          }
          
          openCount += otherUsersInProgressCount;
          debugPrint('📊 Other users\' inProgress requests: $otherUsersInProgressCount, Total: $openCount');
        }
      } catch (e) {
        debugPrint('❌ Error querying open requests: $e');
        // אם השאילתה נכשלה, נשתמש בספירה הידנית מה-sample
        if (manualOpenCount > 0) {
          openCount = manualOpenCount;
          debugPrint('📊 Using manual count from sample for open: $openCount');
        }
      }
      
      debugPrint('📊 Total open requests: $openCount');
      
      // ✅ טעינת מספר הבקשות של המשתמש במצב "פתוח" או "בטיפול"
      await _loadMyRequestsCount();
      // ✅ טעינת מספר הבקשות שהמשתמש מטפל בהן (בטיפול)
      await _loadMyInProgressRequestsCount();
      
      if (mounted) {
        // אם המספר לא השתנה, אל תתחיל אנימציה מחדש
        if (_openRequestsCount == openCount && _isAnimationRunning) {
          debugPrint('📊 Count unchanged (open=$openCount) and animation already running - skipping');
          return;
        }
        
        // אם יש אנימציה רצה, עצור אותה קודם
        if (_isAnimationRunning) {
          debugPrint('📊 Stopping current animation before starting new one');
          _countAnimationController?.stop();
          _countAnimationController?.removeListener(_onAnimationUpdate);
        }
        
        setState(() {
          _totalRequestsCount = openCount;
          _openRequestsCount = openCount;
          _animatedOpenCount = 0; // התחל מ-0 לאנימציה
          _isAnimationRunning = false; // אפס את הסטטוס
        });
        
        debugPrint('📊 Setting count - Open: $openCount');
        
        // עדכון משך האנימציה - מקסימום 2 שניות
        final animationDuration = _calculateAnimationDuration(openCount);
        _countAnimationController?.duration = animationDuration;
        
        // התחל אנימציה - המספר יעלה מ-0 עד למספר האמיתי
        if (openCount > 0) {
          _startCountAnimation();
        } else {
          // אם אין בקשות, עדכן ישירות ללא אנימציה
          setState(() {
            _animatedOpenCount = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading total requests count: $e');
      // במקרה של שגיאה, הצג 0
      if (mounted) {
        setState(() {
          _totalRequestsCount = 0;
          _openRequestsCount = 0;
          _animatedOpenCount = 0;
          _isAnimationRunning = false;
        });
      }
    }
  }
  
  // בדיקה והתחלת אנימציה כל פעם שהמשתמש מבקר בדף הבית
  void _checkAndStartAnimation() {
    // אם יש אנימציה רצה, אל תתחיל אחת חדשה
    if (_isAnimationRunning) {
      debugPrint('🔄 Animation already running - skipping _checkAndStartAnimation');
      return;
    }
    
    // אם יש מספר בקשות ויש צורך להתחיל אנימציה מחדש
    if (_totalRequestsCount > 0) {
      // בדוק אם עבר מספיק זמן מהאנימציה האחרונה (למניעת אנימציות מרובות)
      final now = DateTime.now();
      if (_lastAnimationTime == null || 
          now.difference(_lastAnimationTime!).inSeconds > 2) {
        debugPrint('🔄 Starting count animation on screen visit');
        setState(() {
          _animatedOpenCount = 0; // התחל מ-0 לאנימציה
        });
        _startCountAnimation();
        _lastAnimationTime = now;
      } else {
        debugPrint('🔄 Too soon since last animation - skipping');
      }
    }
  }
  
  // חישוב משך האנימציה לפי מספר הבקשות - מקסימום 2 שניות
  Duration _calculateAnimationDuration(int totalCount) {
    if (totalCount == 0) {
      return const Duration(milliseconds: 500); // אם אין בקשות, אנימציה קצרה
    } else if (totalCount <= 100) {
      return const Duration(milliseconds: 1000); // עד 100 בקשות - שנייה אחת
    } else if (totalCount <= 1000) {
      return const Duration(milliseconds: 1500); // עד 1000 בקשות - 1.5 שניות
    } else {
      return const Duration(milliseconds: 2000); // מעל 1000 בקשות - 2 שניות (מהיר במיוחד)
    }
  }
  
  // התחלת אנימציית הספירה - מהירה במיוחד
  void _startCountAnimation() {
    if (_countAnimationController == null || !mounted) {
      debugPrint('❌ Cannot start animation: controller=${_countAnimationController == null}, mounted=$mounted');
      return;
    }
    
    debugPrint('🎬 Starting count animation: _totalRequestsCount=$_totalRequestsCount, duration=${_countAnimationController!.duration}');
    
    setState(() {
      _isAnimationRunning = true;
    });
    
    _countAnimationController!.reset();
    
    // הסרת Listener קודם אם קיים (למניעת כפילויות)
    _countAnimationController!.removeListener(_onAnimationUpdate);
    _countAnimationController!.addListener(_onAnimationUpdate);
    
    _countAnimationController!.forward().then((_) {
      // כשהאנימציה מסתיימת
      if (mounted) {
        debugPrint('✅ Animation completed: setting final count - open=$_openRequestsCount');
        setState(() {
          _isAnimationRunning = false;
          _animatedOpenCount = _openRequestsCount; // ודא שהמספר הסופי מוצג
        });
      }
    });
  }
  
  // טעינת מספר הבקשות של המשתמש במצב "פתוח" או "בטיפול"
  Future<void> _loadMyRequestsCount() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        if (mounted) {
          setState(() {
            _myRequestsCount = 0;
          });
        }
        return;
      }
      
      int myCount = 0;
      
      // ספירת בקשות שהמשתמש יצר במצב "פתוח"
      try {
        final openQuery = await FirebaseFirestore.instance
            .collection('requests')
            .where('createdBy', isEqualTo: currentUserId)
            .where('status', isEqualTo: RequestStatus.open.name)
            .get();
        
        for (var doc in openQuery.docs) {
          final data = doc.data();
          final isDeleted = data['isDeleted'] as bool? ?? false;
          if (isDeleted) continue;
          myCount++;
        }
        debugPrint('📊 User\'s open requests: $myCount');
      } catch (e) {
        debugPrint('❌ Error querying user\'s open requests: $e');
      }
      
      // ספירת בקשות שהמשתמש יצר במצב "בטיפול"
      try {
        final inProgressQuery = await FirebaseFirestore.instance
            .collection('requests')
            .where('createdBy', isEqualTo: currentUserId)
            .where('status', isEqualTo: RequestStatus.inProgress.name)
            .get();
        
        int inProgressCount = 0;
        for (var doc in inProgressQuery.docs) {
          final data = doc.data();
          final isDeleted = data['isDeleted'] as bool? ?? false;
          if (isDeleted) continue;
          inProgressCount++;
        }
        
        myCount += inProgressCount;
        debugPrint('📊 User\'s inProgress requests: $inProgressCount, Total my requests: $myCount');
      } catch (e) {
        debugPrint('❌ Error querying user\'s inProgress requests: $e');
      }
      
      if (mounted) {
        setState(() {
          _myRequestsCount = myCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading my requests count: $e');
      if (mounted) {
        setState(() {
          _myRequestsCount = 0;
        });
      }
    }
  }

  // טעינת מספר הבקשות שהמשתמש מטפל בהן (בטיפול)
  Future<void> _loadMyInProgressRequestsCount() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        if (mounted) {
          setState(() {
            _myInProgressRequestsCount = 0;
          });
        }
        return;
      }
      
      // ספירת בקשות שהמשתמש הוא helper בהן במצב "בטיפול"
      try {
        final inProgressQuery = await FirebaseFirestore.instance
            .collection('requests')
            .where('helpers', arrayContains: currentUserId)
            .where('status', isEqualTo: RequestStatus.inProgress.name)
            .get();
        
        int count = 0;
        for (var doc in inProgressQuery.docs) {
          final data = doc.data();
          final isDeleted = data['isDeleted'] as bool? ?? false;
          if (isDeleted) continue;
          count++;
        }
        
        debugPrint('📊 User\'s in-progress requests (as helper): $count');
        
        if (mounted) {
          setState(() {
            _myInProgressRequestsCount = count;
          });
        }
      } catch (e) {
        debugPrint('❌ Error querying user\'s in-progress requests: $e');
        if (mounted) {
          setState(() {
            _myInProgressRequestsCount = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading my in-progress requests count: $e');
      if (mounted) {
        setState(() {
          _myInProgressRequestsCount = 0;
        });
      }
    }
  }
  
  // עדכון המספרים במהלך האנימציה
  void _onAnimationUpdate() {
    if (!mounted) return;
    
    final animatedValue = _countAnimationController!.value;
    final targetOpenCount = _openRequestsCount;
    final currentOpenCount = (animatedValue * targetOpenCount).round();
    
    // Debug רק כל 10 עדכונים כדי לא לזהם את הלוגים
    if (currentOpenCount % 10 == 0 || currentOpenCount == targetOpenCount) {
      debugPrint('📊 Animation update: value=$animatedValue, open=$currentOpenCount/$targetOpenCount');
    }
    
    setState(() {
      _animatedOpenCount = currentOpenCount;
    });
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    debugPrint('🏠 HOME SCREEN - build() called');
    final l10n = AppLocalizations.of(context);
    
    // בדיקה אם המשתמש חזר למסך הבית - התחל אנימציה מחדש
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final route = ModalRoute.of(context);
        if (route != null && route.isCurrent) {
          debugPrint('🔄 PostFrameCallback: Route is current');
          // טעינת ספירת הבקשות כל פעם שהמשתמש נכנס למסך
          // אבל רק אם אין אנימציה רצה (למניעת לופ אינסופי)
          // וגם רק אם המספר עדיין 0 (כי אם כבר יש מספר, אין צורך לטעון שוב)
          if (!_isAnimationRunning && _totalRequestsCount == 0) {
            _loadTotalRequestsCount();
          } else {
            debugPrint('🔄 Skipping _loadTotalRequestsCount: animationRunning=$_isAnimationRunning, count=$_totalRequestsCount');
          }
        }
      }
    });
    
    // הטוטוריאל הועבר ל-initState כדי שיופיע רק פעם אחת

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
                toolbarHeight: 80, // הגדלת גובה ה-AppBar כדי למנוע חיתוך
                title: Padding(
                  padding: const EdgeInsets.only(top: 8.0), // הוספת padding מלמעלה
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
              Row(
                            children: [
                              Icon(
                    Icons.handshake,
                                color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.requestsFromAdvertisers,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final displayName = userData['displayName'] ?? 
                                          userData['name'] ?? 
                                          userData['email']?.split('@')[0];
                        final isTemporaryGuest = userData['isTemporaryGuest'] ?? false;
                        
                        if (displayName != null && displayName.isNotEmpty) {
                          final l10n = AppLocalizations.of(context);
                          
                          // אם זה אורח זמני - הצג כפתור "הירשם"
                          if (isTemporaryGuest == true) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.helloName(displayName),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      // מחיקת כל נתוני האורח והתנתקות
                                      await AutoLoginService.logout();
                                      
                                      // מעבר למסך התחברות
                                      if (mounted) {
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/auth',
                                          (route) => false,
                                        );
                                      }
                                    } catch (e) {
                                      debugPrint('Error during registration logout: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('שגיאה בהתנתקות: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    minimumSize: const Size(0, 24),
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: const BorderSide(color: Colors.white, width: 1),
                                    ),
                                  ),
                                  child: const Text(
                                    'הירשם',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          
                          // משתמש רגיל - הצג רק את הטקסט
                          return Text(
                            l10n.helloName(displayName),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const Spacer(), // דוחף את האייקון "מחובר" לצד השמאלי
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                            Text(
                          isConnected ? l10n.connected : l10n.notConnected,
                              style: const TextStyle(
                                color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                    ),
                  ),
                ],
              ),
            ],
                  ),
                ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
          ),
        body: CustomScrollView(
            controller: _scrollController,
            key: const PageStorageKey('home_screen_list'),
          slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Notifications are now handled in initState() and background
                  // שדה חיפוש
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _searchController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      textDirection: _getTextDirection(_searchController.text.isNotEmpty ? _searchController.text : l10n.searchHint),
                      textAlign: _getTextDirection(_searchController.text.isNotEmpty ? _searchController.text : l10n.searchHint) == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  if (mounted) {
                                  setState(() {});
                                  }
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainer,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {});
                        // הפעלת החיפוש בזמן אמת
                        _performSearch();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // כפתורי סינון מודרניים
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // כפתור פניות שלי
                        Expanded(
                          flex: 1,
                          child: _buildModernFilterButton(
                            icon: Icons.favorite,
                            label: l10n.myRequests,
                            isActive: _showMyRequests && !_showServiceProviders,
                            activeColor: Colors.pink,
                            badgeCount: _myInProgressRequestsCount,
                            onTap: () async {
                              setState(() {
                                _showMyRequests = true;
                                _showServiceProviders = false;
                                // במסך "פניות שלי", נטען את כל הבקשות שהמשתמש התעניין בהן
                                _allRequests.clear();
                                _lastDocumentSnapshot = null;
                                _hasMoreRequests = false; // אין עוד בקשות לטעינה במסך "פניות שלי"
                                _isLoadingInitial = false; // במסך "פניות שלי" אין דיאלוג טעינה
                                // Cancel all subscriptions and debounce timers
                                for (final subscription in _requestSubscriptions.values) {
                                  subscription.cancel();
                                }
                                _requestSubscriptions.clear();
                                // ✅ Cancel all debounce timers
                                for (final timer in _debounceTimers.values) {
                                  timer.cancel();
                                }
                                _debounceTimers.clear();
                                _pendingUpdates.clear();
                                // ✅ Clear cache when switching views
                                _requestCache.clear();
                              });
                              
                              // טעינת כל הבקשות שהמשתמש התעניין בהן
                              await _loadAllInterestedRequests();
                            },
                          ),
                        ),
                        // כפתור כל הבקשות
                        Expanded(
                          flex: 1,
                          child: _buildModernFilterButton(
                            icon: Icons.grid_view,
                            label: l10n.allRequests,
                            isActive: !_showMyRequests && !_showServiceProviders,
                            activeColor: Colors.blue,
                            onTap: () {
                              setState(() {
                                _showMyRequests = false;
                                _showServiceProviders = false;
                                // Reload initial requests when switching view
                                _allRequests.clear();
                                _lastDocumentSnapshot = null;
                                _hasMoreRequests = true;
                                // Cancel all subscriptions and debounce timers
                                for (final subscription in _requestSubscriptions.values) {
                                  subscription.cancel();
                                }
                                _requestSubscriptions.clear();
                                // ✅ Cancel all debounce timers
                                for (final timer in _debounceTimers.values) {
                                  timer.cancel();
                                }
                                _debounceTimers.clear();
                                _pendingUpdates.clear();
                                // ✅ Clear cache when switching views
                                _requestCache.clear();
                                // Reload initial requests - רק אם לא במסך "פניות שלי"
                                if (!_showMyRequests && !_showServiceProviders) {
                                  _loadInitialRequests();
                                }
                              });
                            },
                          ),
                        ),
                        // כפתור נותני שירות
                        Expanded(
                          flex: 1,
                          child: _buildModernFilterButton(
                            icon: Icons.people,
                            label: l10n.serviceProviders,
                            isActive: _showServiceProviders,
                            activeColor: Colors.green,
                            onTap: () {
                              setState(() {
                                _showMyRequests = false;
                                _showServiceProviders = true;
                                // Clear requests cache when switching to service providers
                                _allRequests.clear();
                                _lastDocumentSnapshot = null;
                                _hasMoreRequests = false;
                                _isLoadingInitial = false;
                                // Clear service providers cache to reload
                                _serviceProviders.clear();
                                _hasMoreServiceProviders = true;
                                _isLoadingServiceProviders = false;
                                // Cancel all subscriptions and debounce timers
                                for (final subscription in _requestSubscriptions.values) {
                                  subscription.cancel();
                                }
                                _requestSubscriptions.clear();
                                for (final timer in _debounceTimers.values) {
                                  timer.cancel();
                                }
                                _debounceTimers.clear();
                                _pendingUpdates.clear();
                                _requestCache.clear();
                              });
                              // טעינת נותני שירות
                              _loadInitialServiceProviders();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // ✅ שורת עיגולי קטגוריות - מוצגת ב"כל הבקשות" וב"נותני שירות"
                  if (!_showMyRequests) ...[
                    if (_showServiceProviders)
                      _buildCategoryCirclesRowForProviders()
                    else
                      _buildCategoryCirclesRow(),
                    const SizedBox(height: 6),
                  ],
                  
                  // ✅ כפתור סינון - מוצג ב"כל הבקשות" וב"נותני שירות"
                  if (!_showMyRequests) ...[
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // שורה עם הלחצנים משני הצדדים
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // חלק 1: בקשות פתוחות ובטיפול / מספר נותני שירות - מצד ימין (RTL)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end, // יישור לימין
                                  children: [
                                if (_showServiceProviders) ...[
                                  // מספר נותני שירות במסך נותני שירות
                                  Builder(
                                    builder: (context) {
                                      // חישוב מספר נותני השירות המסוננים
                                      final filteredCount = _serviceProviders.where((provider) {
                                        // סינון לפי קטגוריה ראשית מהעיגולים
                                        if (_selectedMainCategoryFromCirclesForProviders != null) {
                                          if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
                                            return false;
                                          }
                                          final hasMatchingCategory = provider.businessCategories!.any((cat) {
                                            return cat.mainCategory == _selectedMainCategoryFromCirclesForProviders;
                                          });
                                          if (!hasMatchingCategory) {
                                            return false;
                                          }
                                        }
                                        
                                        // סינון לפי קטגוריות בדיאלוג
                                        if (_selectedProviderMainCategories.isNotEmpty) {
                                          if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
                                            return false;
                                          }
                                          final hasMatchingMainCategory = provider.businessCategories!.any((cat) {
                                            return _selectedProviderMainCategories.contains(cat.mainCategory.displayName);
                                          });
                                          if (!hasMatchingMainCategory) {
                                            return false;
                                          }
                                        }
                                        
                                        // סינון לפי תת-קטגוריות
                                        if (_selectedProviderSubCategories.isNotEmpty) {
                                          if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
                                            return false;
                                          }
                                          final hasMatchingSubCategory = provider.businessCategories!.any((cat) {
                                            return _selectedProviderSubCategories.contains(cat);
                                          });
                                          if (!hasMatchingSubCategory) {
                                            return false;
                                          }
                                        }
                                        
                                        // סינון לפי איזור
                                        if (_selectedProviderRegion != null) {
                                          final providerLat = provider.latitude ?? provider.mobileLatitude;
                                          if (providerLat == null) {
                                            return false;
                                          }
                                          final providerRegion = getGeographicRegion(providerLat);
                                          if (providerRegion != _selectedProviderRegion) {
                                            return false;
                                          }
                                        }
                                        
                                        // סינון לפי מיקום וטווח (5 ק"מ מהמיקום הנוכחי)
                                        if (_filterProvidersByMyLocation) {
                                          final currentUserLat = _userProfile?.mobileLatitude ?? _userProfile?.latitude;
                                          final currentUserLng = _userProfile?.mobileLongitude ?? _userProfile?.longitude;
                                          if (currentUserLat != null && currentUserLng != null) {
                                            final providerLat = provider.latitude ?? provider.mobileLatitude;
                                            final providerLng = provider.longitude ?? provider.mobileLongitude;
                                            if (providerLat == null || providerLng == null) {
                                              return false;
                                            }
                                            const maxDistance = 5.0; // 5 ק"מ
                                            if (!LocationService.isLocationInRange(
                                              currentUserLat,
                                              currentUserLng,
                                              providerLat,
                                              providerLng,
                                              maxDistance,
                                            )) {
                                              return false;
                                            }
                                          } else {
                                            return false;
                                          }
                                        }
                                        
                                        return true;
                                      }).length;
                                      
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'מספר נותני שירות',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                              ),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$filteredCount',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ] else ...[
                                  // בקשות פתוחות לטיפול במסך כל הבקשות
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          l10n.openRequestsForTreatment,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                          ),
                                          textAlign: TextAlign.right,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Builder(
                                        builder: (context) {
                                          return Text(
                                            '$_animatedOpenCount',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            textAlign: TextAlign.right,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  // ✅ קישור "בקשות שלי" - מוצג רק אם יש בקשות
                                  if (_myRequestsCount > 0) ...[
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () async {
                                        await playButtonSound();
                                        // ✅ פתיחת מסך "בקשות שלי" הנפרד (לא "בקשות בטיפול שלי")
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const MyRequestsScreen(),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end, // ✅ הצמדה לימין
                                        children: [
                                          Flexible(
                                            child: Text(
                                              l10n.myRequestsMenu,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                              ),
                                              textAlign: TextAlign.right,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$_myRequestsCount',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.secondary,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                        // חלק 2: לחצן רענן ונקה סינון - מצד שמאל (RTL)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ✅ לחצן רענן
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  color: Theme.of(context).colorScheme.primary,
                                  onPressed: () async {
                                    await playButtonSound();
                                    if (_showServiceProviders) {
                                      // רענון נותני שירות
                                      setState(() {
                                        _serviceProviders.clear();
                                        _hasMoreServiceProviders = true;
                                      });
                                      await _loadInitialServiceProviders();
                                    } else {
                                      // רענון בקשות
                                      setState(() {
                                        _allRequests.clear();
                                        _lastDocumentSnapshot = null;
                                        _hasMoreRequests = true;
                                        // Cancel all subscriptions and debounce timers
                                        for (final subscription in _requestSubscriptions.values) {
                                          subscription.cancel();
                                        }
                                        _requestSubscriptions.clear();
                                        for (final timer in _debounceTimers.values) {
                                          timer.cancel();
                                        }
                                        _debounceTimers.clear();
                                        _pendingUpdates.clear();
                                        _requestCache.clear();
                                      });
                                      await _loadInitialRequests(forceReload: true);
                                    }
                                  },
                                  tooltip: l10n.refresh,
                                ),
                                // חלק 3: נקה סינון
                                _showServiceProviders
                                    ? (_hasActiveProviderFilters()
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_all),
                                            color: Colors.red,
                                            onPressed: () async {
                                              await playButtonSound();
                                              _clearProviderFilters();
                                            },
                                            tooltip: 'נקה סינון',
                                          )
                                        : const SizedBox.shrink())
                                    : (_hasActiveFilters()
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_all),
                                            color: Colors.red,
                                            onPressed: () async {
                                              await playButtonSound();
                                              _clearFilters();
                                            },
                                            tooltip: 'נקה סינון',
                                          )
                                        : const SizedBox.shrink()), // אם אין סינון פעיל, השאר ריק
                              ],
                            ),
                          ),
                        ),
                      ],
                        ),
                        // ✅ לחצן סינון - במרכז אבסולוטי
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              if (_showServiceProviders) {
                                _showServiceProvidersFilterDialog(_userProfile);
                              } else {
                                _showAdvancedFilterDialog(_userProfile);
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  _showServiceProviders ? l10n.filterServiceProviders : l10n.filter,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Image.asset(
                                  'assets/images/filter.png',
                                  width: 32,
                                  height: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
          // Manual Pagination - Using _allRequests cache instead of StreamBuilder
          Builder(
            builder: (context) {
              final currentUser = FirebaseAuth.instance.currentUser;
              
              // ⬇️ Show skeleton cards on initial load - רק אם לא במסך "פניות שלי" או "נותני שירות"
              if (_isLoadingInitial && !_showMyRequests && !_showServiceProviders) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildSkeletonCard(),
                    childCount: _requestsPerPage, // Show skeleton cards for expected page size
                  ),
                );
              }
              
              // Show error message if loading failed
              if (_loadingError != null) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final l10nError = AppLocalizations.of(context);
                              return Column(
                                children: [
                          Text(
                                    l10nError.errorLoadingData,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                                    _loadingError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                                      setState(() {
                                        _loadingError = null;
                                        _allRequests.clear();
                                        _lastDocumentSnapshot = null;
                                        _hasMoreRequests = true;
                                      });
                                      // Reload initial requests - רק אם לא במסך "פניות שלי"
                                      if (!_showMyRequests) {
                                        _loadInitialRequests();
                                      } else {
                                        // במסך "פניות שלי", נטען את כל הבקשות שהמשתמש התעניין בהן
                                        _loadAllInterestedRequests();
                                      }
                                    },
                                    child: Text(l10nError.tryAgain),
                                  ),
                                ],
                              );
                            },
                              ),
                            ],
                          ),
                    ),
                  ),
                );
              }

              // Check if user is logged in
              if (currentUser == null) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.person_off, size: 64, color: Theme.of(context).colorScheme.tertiary),
                            const SizedBox(height: 16),
                            Text(
                          l10n.notConnected,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.tertiary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'אנא התחבר כדי לראות בקשות',
                              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.tertiary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

              // הצגת נותני שירות אם במסך "נותני שירות"
              if (_showServiceProviders) {
                // טעינת נותני שירות ראשוניים אם עדיין לא נטענו
                if (_serviceProviders.isEmpty && !_isLoadingServiceProviders) {
                  _loadInitialServiceProviders();
                }
                
                // סינון נותני שירות לפי הקטגוריות והמיקום
                final filteredProviders = _serviceProviders.where((provider) {
                  // סינון לפי קטגוריה ראשית מהעיגולים
                  if (_selectedMainCategoryFromCirclesForProviders != null) {
                    if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
                      return false;
                    }
                    final hasMatchingCategory = provider.businessCategories!.any((cat) {
                      return cat.mainCategory == _selectedMainCategoryFromCirclesForProviders;
                    });
                    if (!hasMatchingCategory) {
                      return false;
                    }
                  }
                  
                  // סינון לפי קטגוריות בדיאלוג
                  if (_selectedProviderMainCategories.isNotEmpty) {
                    if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
                      return false;
                    }
                    final hasMatchingMainCategory = provider.businessCategories!.any((cat) {
                      return _selectedProviderMainCategories.contains(cat.mainCategory.displayName);
                    });
                    if (!hasMatchingMainCategory) {
                      return false;
                    }
                  }
                  
                  // סינון לפי תת-קטגוריות
                  if (_selectedProviderSubCategories.isNotEmpty) {
                    if (provider.businessCategories == null || provider.businessCategories!.isEmpty) {
                      return false;
                    }
                    final hasMatchingSubCategory = provider.businessCategories!.any((cat) {
                      return _selectedProviderSubCategories.contains(cat);
                    });
                    if (!hasMatchingSubCategory) {
                      return false;
                    }
                  }
                  
                  // סינון לפי איזור
                  if (_selectedProviderRegion != null) {
                    final providerLat = provider.latitude ?? provider.mobileLatitude;
                    if (providerLat == null) {
                      return false;
                    }
                    final providerRegion = getGeographicRegion(providerLat);
                    if (providerRegion != _selectedProviderRegion) {
                      return false;
                    }
                  }
                  
                  // סינון לפי מיקום וטווח (5 ק"מ מהמיקום הנוכחי)
                  if (_filterProvidersByMyLocation) {
                    final currentUserLat = _userProfile?.mobileLatitude ?? _userProfile?.latitude;
                    final currentUserLng = _userProfile?.mobileLongitude ?? _userProfile?.longitude;
                    if (currentUserLat != null && currentUserLng != null) {
                      final providerLat = provider.latitude ?? provider.mobileLatitude;
                      final providerLng = provider.longitude ?? provider.mobileLongitude;
                      if (providerLat == null || providerLng == null) {
                        return false;
                      }
                      const maxDistance = 5.0; // 5 ק"מ
                      if (!LocationService.isLocationInRange(
                        currentUserLat,
                        currentUserLng,
                        providerLat,
                        providerLng,
                        maxDistance,
                      )) {
                        return false;
                      }
                    } else {
                      // אם אין מיקום נוכחי, לא נסנן לפי מיקום
                      return false;
                    }
                  }
                  
                  return true;
                }).toList();
                
                // הצגת skeleton cards בעת טעינה ראשונית
                if (_isLoadingServiceProviders && _serviceProviders.isEmpty) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildServiceProviderSkeletonCard(),
                      childCount: 5,
                    ),
                  );
                }
                
                // ✅ בדיקה ראשונה: אם אין נותני שירות מתאימים לסינון - הצג הודעה עם לחצנים
                // זה חייב להיות לפני כל הבדיקות האחרות כדי למנוע הצגת רשימה ריקה
                if (filteredProviders.isEmpty && !_isLoadingServiceProviders) {
                  // אם יש סינון פעיל, הצג הודעה עם לחצנים
                  if (_hasActiveProviderFilters()) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_alt_off, size: 64, color: Theme.of(context).colorScheme.tertiary),
                            const SizedBox(height: 16),
                            Text(
                              'אין נותני שירות מתאימים לסינון הנבחר',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.tertiary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            // לחצנים
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await playButtonSound();
                                    _clearProviderFilters();
                                  },
                                  icon: const Icon(Icons.clear_all, size: 18),
                                  label: const Text('נקה סינון'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await playButtonSound();
                                    _showServiceProvidersFilterDialog(_userProfile);
                                  },
                                  icon: const Icon(Icons.filter_alt, size: 18),
                                  label: const Text('שנה סינון'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // לחצן שיתוף
                            ElevatedButton.icon(
                              onPressed: () async {
                                await playButtonSound();
                                _shareAppToProviders();
                              },
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text('שתף האפליקציה לנותני שירות שאתה מכיר'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  // אם אין סינון פעיל ואין נותני שירות כלל, הצג הודעה רגילה
                  if (_serviceProviders.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'אין נותני שירות זמינים',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
                
                // אם יש נותני שירות מסוננים, הצג אותם
                if (filteredProviders.isNotEmpty) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // טעינת עוד נותני שירות כשמגיעים לסוף הרשימה
                        if (index == filteredProviders.length - 3 && _hasMoreServiceProviders && !_isLoadingServiceProviders) {
                          _loadMoreServiceProviders();
                        }
                        
                        if (index < filteredProviders.length) {
                          return _buildServiceProviderCard(filteredProviders[index], l10n);
                        } else if (index == filteredProviders.length && _isLoadingServiceProviders) {
                          return _buildServiceProviderSkeletonCard();
                        } else {
                          return null;
                        }
                      },
                      childCount: filteredProviders.length + (_isLoadingServiceProviders ? 1 : 0),
                    ),
                  );
                }
                
                // fallback - לא אמור להגיע לכאן
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'אין נותני שירות זמינים',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Use cached requests from _allRequests
              final allRequests = List<Request>.from(_allRequests);
              
              // ✅ במסך "פניות שלי" לא נמיין לפי createdAt - המיון יתבצע לפי זמן ההתעניינות
              // ✅ במסך "כל הבקשות" נמיין לפי createdAt - החדשות ביותר בראש
              if (!_showMyRequests) {
                // Sort by date - newest first (רק במסך "כל הבקשות")
                allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }
              // במסך "פניות שלי" - נשאיר את הסדר כמו שהוא ב-_allRequests (כבר ממוין ב-_loadAllInterestedRequests)
              
              debugPrint('📊 Total requests in cache: ${_allRequests.length}');
              debugPrint('User profile loaded: ${_userProfile != null}');
              if (_userProfile != null) {
                debugPrint('User type: ${_userProfile!.userType.name}');
                debugPrint('Is subscription active: ${_userProfile!.isSubscriptionActive}');
                              }
              
              // Show empty state if no requests loaded - רק אם לא במסך "פניות שלי"
              // במסך "פניות שלי" ההודעה הריקה מוצגת ב-_buildRequestsList (שורה 484)
              if (allRequests.isEmpty && !_showMyRequests && !_isLoadingInitial) {
                return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'אין בקשות זמינות',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'עדיין לא נוצרו בקשות במערכת. תוכל להיות הראשון ליצור בקשה!',
                      style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Theme.of(context).colorScheme.tertiary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'השתמש בכפתור "בקשה חדשה" למטה כדי ליצור בקשה ראשונה',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                );
              }
              
              // סינון הבקשות - לוגיקה פשוטה וברורה
              final isAdmin = AdminAuthService.isCurrentUserAdmin();
              final hasActiveFilter = _hasActiveFilters();
              
              debugPrint('🔵 [FILTER START] Total requests: ${allRequests.length}, _selectedMainCategoryFromCircles: ${_selectedMainCategoryFromCircles?.name ?? "null"}, hasActiveFilter: $hasActiveFilter, _showMyRequests: $_showMyRequests');
              
              final requests = allRequests.where((request) {
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                final isMyRequest = request.createdBy == currentUserId;
                
                // ✅ סינון לפי קטגוריה ראשית מהעיגולים - צריך להתבצע לפני כל הבדיקות האחרות (כולל מנהל)
                // ✅ חשוב: סינון העיגולים תמיד נכבד, גם למנהל!
                if (!_showMyRequests && _selectedMainCategoryFromCircles != null) {
                  final requestMainCategory = request.category.mainCategory;
                  debugPrint('🔵 [CIRCLES FILTER] Checking request "${request.title}": request.mainCategory=${requestMainCategory.name}, selected=${_selectedMainCategoryFromCircles!.name}, request.category=${request.category.name}, status=${request.status.name}, createdBy=${request.createdBy}, currentUserId=$currentUserId');
                  
                  // בדיקת קטגוריה
                  if (requestMainCategory != _selectedMainCategoryFromCircles) {
                    debugPrint('❌ [CIRCLES FILTER] Request "${request.title}" filtered out by main category from circles: request.mainCategory=${requestMainCategory.name}, selected=${_selectedMainCategoryFromCircles!.name}');
                    return false;
                  }
                  
                  // ✅ בדיקת סטטוס: רק בקשות "פתוח" או "בטיפול" שנוצרו על ידי משתמשים אחרים (לא המשתמש המחובר)
                  if (request.status == RequestStatus.open) {
                    // בקשות פתוחות - רק אם נוצרו על ידי משתמשים אחרים
                    if (isMyRequest) {
                      debugPrint('❌ [CIRCLES FILTER] Request "${request.title}" filtered out - status=open but created by current user');
                      return false;
                    }
                    debugPrint('✅ [CIRCLES FILTER] Request "${request.title}" passed - status=open, created by other user');
                  } else if (request.status == RequestStatus.inProgress) {
                    // בקשות "בטיפול" - רק אם נוצרו על ידי משתמשים אחרים
                    if (isMyRequest) {
                      debugPrint('❌ [CIRCLES FILTER] Request "${request.title}" filtered out - status=inProgress but created by current user');
                      return false;
                    }
                    debugPrint('✅ [CIRCLES FILTER] Request "${request.title}" passed - status=inProgress, created by other user');
                  } else {
                    // סטטוס אחר - לא להציג
                    debugPrint('❌ [CIRCLES FILTER] Request "${request.title}" filtered out - status=${request.status.name} (not open or inProgress)');
                    return false;
                  }
                  
                  debugPrint('✅ [CIRCLES FILTER] Request "${request.title}" passed all filters: category=${requestMainCategory.name}, status=${request.status.name}');
                  
                  // ✅ אם הבקשה עברה את כל הבדיקות של סינון העיגולים (קטגוריה, סטטוס, מי יצר),
                  // היא לא צריכה לעבור עוד סינונים נוספים - נחזיר true מיד!
                  debugPrint('✅ [CIRCLES FILTER] Request "${request.title}" passed all circle filters - returning true immediately');
                  return true;
                }
                
                // בקשות שלי לא יוצגו במסך "כל הבקשות" - לכל המשתמשים (כולל מנהל)
                // ✅ אבל רק אם אין סינון מהעיגולים (כי סינון העיגולים כבר מטפל בזה)
                if (!_showMyRequests && isMyRequest && _selectedMainCategoryFromCircles == null) {
                  return false;
                }
                
                // מנהל רואה את כל הבקשות (חינמיות ובתשלום) ללא סינונים - נחזיר true מיד
                // רק אם אין סינון מקומי פעיל ובמסך "כל הבקשות"
                // ✅ חשוב: אם יש סינון מהעיגולים, לא נעקף אותו!
                if (!_showMyRequests && isAdmin && !hasActiveFilter && _selectedMainCategoryFromCircles == null) {
                  // מנהל רואה בקשות פתוחות ובטיפול (כולל חינמיות ובתשלום)
                  // כשאין סינון פעיל - כל הבקשות "פתוח" ו"בטיפול" יוצגו
                  if (request.status == RequestStatus.open || request.status == RequestStatus.inProgress) {
                    debugPrint('✅ [ADMIN] Showing request "${request.title}" (type: ${request.type.name}, status: ${request.status.name}) - admin bypass');
                    return true;
                  } else {
                    return false;
                  }
                }
                
                // ✅ סינון בקשות עם סטטוס "טופל" - לא יוצגו במסך "כל הבקשות" ולא בתוצאות הסינון
                // אבל יוצגו ב-"פניות שלי" עם אפשרות למחיקה
                if (!_showMyRequests && request.status == RequestStatus.completed) {
                  return false;
                }
                
                // סינון לפי מצב "בקשות שפניתי אליהם" או "כל הבקשות"
                if (_showMyRequests) {
                  // מצב "בקשות שפניתי אליהם" - הצג רק בקשות שהמשתמש לחץ "אני מעוניין"
                  final isInterested = _interestedRequests.contains(request.requestId);
                  if (!isInterested) {
                    return false;
                  }
                } else {
                  // מצב "כל הבקשות" - הצג רק בקשות שהמשתמש לא לחץ "אני מעוניין"
                  final isInterested = _interestedRequests.contains(request.requestId);
                  if (isInterested) {
                    return false;
                  }
                }
                
                // בקשות שלי כבר נבדקו בתחילת הפונקציה - דלג כאן
                // (הבדיקה כבר בוצעה בשורות 4758-4761)
                
                // בדיקה אם המשתמש הנוכחי מחק צ'אט סגור עבור בקשה זו
                // אם כן, נסתיר את הבקשה ממסך הבית שלו
                // (currentUserId כבר הוגדר בתחילת הפונקציה בשורה 4755)
                if (request.helpers.contains(currentUserId)) {
                  // נבדוק אם יש צ'אט שנמחק על ידי המשתמש הנוכחי
                  // זה יבוצע בצורה אסינכרונית, אז נחזיר true כרגע ונבדוק אחר כך
                  // TODO: Add async check for deleted chats
                }
                
                  // בדיקת סוג הבקשה
                  // 1. סינון בקשות (חיפוש, סוג בקשה, קטגוריה, דחיפות, כפר, מרחק)
                
                // סינון בקשות שפג תוקף - בקשות שפג תוקף לא יוצגו במסך "כל הבקשות" אבל יוצגו ב"בקשות שלי"
                if (!_showMyRequests && _isRequestDeadlineExpired(request)) {
                  return false;
                }
                
                // ✅ במסך "כל הבקשות": בדיקה אם יש סינון בקשות פעיל
                // (hasActiveFilter כבר הוגדר בתחילת הפונקציה)
                
                if (!_showMyRequests) {
                  // אם אין סינון בקשות פעיל
                  if (!hasActiveFilter) {
                    // מנהל רואה את כל הבקשות (חינמיות ובתשלום, פתוחות ובטיפול)
                    if (isAdmin) {
                      // מנהל רואה בקשות פתוחות ובטיפול (כולל חינמיות ובתשלום)
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      final isCurrentUserHelper = currentUserId != null && request.helpers.contains(currentUserId);
                      
                      if (request.status == RequestStatus.open) {
                        return true; // בקשות פתוחות - תמיד להציג
                      } else if (request.status == RequestStatus.inProgress) {
                        if (!isCurrentUserHelper) {
                          // בקשות בטיפול על ידי משתמשים אחרים - להציג
                          return true;
                        } else {
                          // המשתמש המחובר (מנהל) הוא helper - בדיקה אם יש helpers נוספים
                          final hasOtherHelpers = request.helpers.length > 1;
                          if (hasOtherHelpers) {
                            return true; // בקשות בטיפול עם משתמשים אחרים - להציג
                          } else {
                            return false; // בקשות בטיפול רק על ידי המנהל - לא להציג (במסך "בקשות בטיפול שלי")
                          }
                      }
                    } else {
                        return false; // סטטוס אחר
                      }
                    }
                    
                    // משתמשים רגילים - לפי סוג המשתמש
                    if (!isAdmin) {
                      // משתמשים רגילים - לפי סוג המשתמש
                      final userType = _userProfile?.userType;
                      final isSubscriptionActive = _userProfile?.isSubscriptionActive ?? false;
                      
                      // משתמשים מסוג "אורח", "עסקי מנוי" - כל הבקשות (חינם ובתשלום)
                      if (userType == UserType.guest || 
                          (userType == UserType.business && isSubscriptionActive)) {
                        // כל הבקשות (חינם ובתשלום) - בקשות פתוחות ובטיפול
                        // כשאין סינון פעיל - כל הבקשות "פתוח" ו"בטיפול" יוצגו
                        if (request.status == RequestStatus.open || request.status == RequestStatus.inProgress) {
                          return true; // בקשות פתוחות ובטיפול - תמיד להציג
                        } else {
                          return false; // סטטוס אחר
                        }
                      } else if (userType == UserType.personal) {
                        // משתמשים מסוג "פרטי חינם" או "פרטי מנוי" - רק בקשות חינם
                        // בקשות חינם פתוחות ובטיפול
                        if (request.type != RequestType.free) {
                          return false;
                        }
                        // כשאין סינון פעיל - כל הבקשות חינם "פתוח" ו"בטיפול" יוצגו
                        if (request.status == RequestStatus.open || request.status == RequestStatus.inProgress) {
                          return true; // בקשות חינם פתוחות ובטיפול - תמיד להציג
                        } else {
                          return false; // סטטוס אחר
                        }
                      } else {
                        // ברירת מחדל - רק בקשות בתשלום עם סטטוס "פתוח" או "בטיפול"
                        if (request.type != RequestType.paid) {
                          return false;
                        }
                        // כשאין סינון פעיל - כל הבקשות בתשלום "פתוח" ו"בטיפול" יוצגו
                        if (request.status == RequestStatus.open || request.status == RequestStatus.inProgress) {
                          return true;
                        } else {
                          return false;
                        }
                      }
                    }
                  } else {
                    // יש סינון בקשות פעיל - החל את הסינון
                    if (isAdmin) {
                      // מנהל - אם יש סינון לפי סוג בקשה, נכבד אותו (מקומי או Firestore)
                      // אבל אם אין סינון לפי סוג בקשה, מנהל רואה את כל הבקשות (חינמיות ובתשלום)
                      final requestTypeFilter = _selectedRequestType ?? 
                        (_filterPreferencesFromFirestore?.isEnabled == true && _filterPreferencesFromFirestore?.requestType != null
                          ? (_filterPreferencesFromFirestore!.requestType == 'free' ? RequestType.free : RequestType.paid)
                          : null);
                      // רק אם יש סינון מפורש לפי סוג בקשה, נסנן לפי זה
                      // אם אין סינון לפי סוג בקשה, מנהל רואה את כל הבקשות
                      if (requestTypeFilter != null && request.type != requestTypeFilter) {
                        return false;
                      }
                      // מנהל רואה בקשות פתוחות ובטיפול
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      final isCurrentUserHelper = currentUserId != null && request.helpers.contains(currentUserId);
                      
                      if (request.status == RequestStatus.open) {
                        // בקשות פתוחות - תמיד להציג
                      } else if (request.status == RequestStatus.inProgress) {
                        if (!isCurrentUserHelper) {
                          // בקשות בטיפול על ידי משתמשים אחרים - להציג
                        } else {
                          // המשתמש המחובר (מנהל) הוא helper - בדיקה אם יש helpers נוספים
                          final hasOtherHelpers = request.helpers.length > 1;
                          if (!hasOtherHelpers) {
                            return false; // בקשות בטיפול רק על ידי המנהל - לא להציג (במסך "בקשות בטיפול שלי")
                          }
                          // בקשות בטיפול עם משתמשים אחרים - להציג
                        }
                      } else {
                        return false; // סטטוס אחר
                      }
                    } else {
                      // משתמשים רגילים - החל את הסינון (מקומי או Firestore)
                      final userType = _userProfile?.userType;
                      final isSubscriptionActive = _userProfile?.isSubscriptionActive ?? false;
                      
                      // בדיקה אם המשתמש הנוכחי הוא helper (מטפל בבקשה)
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      final isCurrentUserHelper = currentUserId != null && request.helpers.contains(currentUserId);
                      
                      final requestTypeFilter = _selectedRequestType ?? 
                        (_filterPreferencesFromFirestore?.isEnabled == true && _filterPreferencesFromFirestore?.requestType != null
                          ? (_filterPreferencesFromFirestore!.requestType == 'free' ? RequestType.free : RequestType.paid)
                          : null);
                      if (requestTypeFilter != null && request.type != requestTypeFilter) {
                        return false;
                      }
                      
                      // עבור אורח/עסקי מנוי - בקשות פתוחות או בטיפול על ידי משתמשים אחרים
                      // ✅ אם יש סינון מהעיגולים, הבקשה כבר עברה את כל הבדיקות הבסיסיות (קטגוריה, סטטוס, מי יצר)
                      // אז היא צריכה לעבור רק את הסינונים האחרים (מיקום, דחיפות, סוג בקשה)
                      if (userType == UserType.guest || 
                          (userType == UserType.business && isSubscriptionActive)) {
                        if (request.status == RequestStatus.open) {
                          // בקשות פתוחות - תמיד להציג (אבל נמשיך לבדוק סינונים אחרים)
                          // אם יש סינון מהעיגולים, הבקשה כבר עברה את כל הבדיקות הבסיסיות
                        } else if (request.status == RequestStatus.inProgress) {
                          if (!isCurrentUserHelper) {
                            // בקשות בטיפול על ידי משתמשים אחרים - להציג כפתוחות
                          } else {
                            // המשתמש המחובר הוא helper - בדיקה אם יש helpers נוספים
                            final hasOtherHelpers = request.helpers.length > 1;
                            if (hasOtherHelpers) {
                              // בקשות בטיפול עם משתמשים אחרים - להציג כפתוחות
                            } else {
                              return false; // בקשות בטיפול רק על ידי המשתמש המחובר - לא להציג (במסך "בקשות בטיפול שלי")
                            }
                          }
                        } else {
                          return false; // סטטוס אחר
                        }
                      } else if (userType == UserType.personal) {
                        // עבור פרטי חינם/פרטי מנוי - רק בקשות חינם
                        // בקשות חינם פתוחות או בטיפול על ידי משתמשים אחרים (לא המשתמש המחובר)
                        if (request.type != RequestType.free) {
                        return false;
                        }
                        if (request.status == RequestStatus.open) {
                          // בקשות חינם פתוחות - תמיד להציג
                        } else if (request.status == RequestStatus.inProgress) {
                          if (!isCurrentUserHelper) {
                            // בקשות חינם בטיפול על ידי משתמשים אחרים - להציג
                          } else {
                            // המשתמש המחובר הוא helper - בדיקה אם יש helpers נוספים
                            final hasOtherHelpers = request.helpers.length > 1;
                            if (hasOtherHelpers) {
                              // בקשות חינם בטיפול עם משתמשים אחרים - להציג
                            } else {
                              return false; // בקשות חינם בטיפול רק על ידי המשתמש המחובר - לא להציג (במסך "בקשות בטיפול שלי")
                            }
                          }
                        } else {
                          return false; // סטטוס אחר
                        }
                      } else {
                        // ברירת מחדל - רק בקשות בתשלום עם סטטוס "פתוח"
                        if (request.type != RequestType.paid || request.status != RequestStatus.open) {
                          return false;
                        }
                      }
                    }
                  }
                } else {
                  // במסך "פניות שלי" - החל את הסינון אם יש (מקומי או Firestore)
                  final requestTypeFilter = _selectedRequestType ?? 
                    (_filterPreferencesFromFirestore?.isEnabled == true && _filterPreferencesFromFirestore?.requestType != null
                      ? (_filterPreferencesFromFirestore!.requestType == 'free' ? RequestType.free : RequestType.paid)
                      : null);
                  if (requestTypeFilter != null && request.type != requestTypeFilter) {
                    return false;
                  }
                }
                
                // סינון לפי קטגוריה (תחום ראשי ותת-תחום) - מקומי או Firestore
                // מנהל רואה את כל הבקשות ללא סינון לפי קטגוריה (אם אין סינון מקומי פעיל)
                // ✅ ללא סינון בקשות פעיל - לא נסנן לפי קטגוריה
                // ✅ אם יש סינון מהעיגולים, לא נבדוק את הסינונים האחרים
                final hasCategoryFilter = hasActiveFilter && 
                  _selectedMainCategoryFromCircles == null && // ✅ לא נבדוק אם יש עיגול נבחר
                  (_selectedMainCategories.isNotEmpty || 
                  _selectedSubCategories.isNotEmpty ||
                  (_filterPreferencesFromFirestore?.isEnabled == true && 
                   _filterPreferencesFromFirestore!.categories.isNotEmpty));
                
                if (hasCategoryFilter && !(isAdmin && !hasActiveFilter)) {
                  bool categoryMatches = false;
                  
                  // ✅ בדיקה ראשונה: סינון מקומי
                  // אם נבחרו תת-תחומים ספציפיים, בודקים רק אותם (לא את כל הקטגוריה הראשית)
                  if (_selectedSubCategories.isNotEmpty) {
                    categoryMatches = _selectedSubCategories.contains(request.category);
                    debugPrint('🔍 [FILTER] Category check (local sub): request.category=${request.category.name}, _selectedSubCategories=${_selectedSubCategories.map((c) => c.name).toList()}, matches=$categoryMatches');
                    // ✅ אם יש תת-תחומים נבחרים, נבדוק רק אותם ולא נמשיך לבדיקות אחרות
                    if (!categoryMatches) {
                      debugPrint('❌ [FILTER] Request "${request.title}" filtered out by category (sub): request.category=${request.category.name}');
                      return false;
                    }
                    // אם categoryMatches == true, נמשיך לבדיקות הבאות (דחיפות, מיקום וכו')
                  } else if (_selectedMainCategories.isNotEmpty) {
                    // ✅ רק אם אין תת-תחומים נבחרים, בודקים את התחומים הראשיים
                    // בודק אם הקטגוריה שייכת לאחד מהתחומים הראשיים שנבחרו
                    categoryMatches = _selectedMainCategories.any((mainCat) => 
                      _isCategoryInMainCategory(request.category, mainCat));
                    debugPrint('🔍 [FILTER] Category check (local main): request.category=${request.category.name}, _selectedMainCategories=$_selectedMainCategories, matches=$categoryMatches');
                    
                    // בדיקה שנייה: סינון מ-Firestore (רק אם אין תת-תחומים נבחרים מקומית)
                    if (!categoryMatches && _filterPreferencesFromFirestore?.isEnabled == true && 
                        _filterPreferencesFromFirestore!.categories.isNotEmpty) {
                      // ✅ FilterPreferences.categories הוא List<String>, אז נמיר את request.category (enum) למחרוזת
                      final requestCategoryName = request.category.name;
                      categoryMatches = _filterPreferencesFromFirestore!.categories.contains(requestCategoryName);
                      debugPrint('🔍 [FILTER] Category check (Firestore): request.category=${request.category.name}, filterCategories=${_filterPreferencesFromFirestore!.categories}, matches=$categoryMatches');
                    }
                    
                    if (!categoryMatches) {
                      debugPrint('❌ [FILTER] Request "${request.title}" filtered out by category: request.category=${request.category.name}');
                      return false;
                    }
                  } else {
                    // אין סינון מקומי - נבדוק רק Firestore
                    if (_filterPreferencesFromFirestore?.isEnabled == true && 
                        _filterPreferencesFromFirestore!.categories.isNotEmpty) {
                      final requestCategoryName = request.category.name;
                      categoryMatches = _filterPreferencesFromFirestore!.categories.contains(requestCategoryName);
                      debugPrint('🔍 [FILTER] Category check (Firestore only): request.category=${request.category.name}, filterCategories=${_filterPreferencesFromFirestore!.categories}, matches=$categoryMatches');
                      
                      if (!categoryMatches) {
                        debugPrint('❌ [FILTER] Request "${request.title}" filtered out by category (Firestore): request.category=${request.category.name}');
                        return false;
                      }
                    }
                  }
                }
                
                // סינון לפי רמת דחיפות (אם נבחר) - מקומי או Firestore
                // ✅ תיקון: סינון דחיפות מקומי תמיד נכבד (גם למנהל) - רק אם יש סינון בקשות פעיל
                // סינון מ-Firestore נכבד רק אם אין סינון מקומי פעיל - רק אם יש סינון בקשות פעיל
                // ✅ ללא סינון בקשות פעיל - לא נסנן לפי דחיפות
                final hasLocalUrgencyFilter = hasActiveFilter && _selectedUrgency != null;
                final hasFirestoreUrgencyFilter = hasActiveFilter && _filterPreferencesFromFirestore?.isEnabled == true && 
                  _filterPreferencesFromFirestore!.urgency != null;
                
                // ✅ אם יש סינון מקומי, תמיד נכבד אותו (גם למנהל)
                if (hasLocalUrgencyFilter) {
                  bool shouldShow = false;
                    switch (_selectedUrgency!) {
                      case UrgencyFilter.all:
                        shouldShow = true;
                        break;
                      case UrgencyFilter.normal:
                        shouldShow = request.urgencyLevel == UrgencyLevel.normal;
                        break;
                      case UrgencyFilter.urgent24h:
                        shouldShow = request.urgencyLevel == UrgencyLevel.urgent24h;
                        break;
                      case UrgencyFilter.emergency:
                        shouldShow = request.urgencyLevel == UrgencyLevel.emergency;
                        break;
                      case UrgencyFilter.urgentAndEmergency:
                        shouldShow = request.urgencyLevel == UrgencyLevel.urgent24h || 
                                     request.urgencyLevel == UrgencyLevel.emergency;
                        break;
                    }
                  debugPrint('🔍 [FILTER] Urgency check (local): request.urgencyLevel=${request.urgencyLevel.name}, _selectedUrgency=${_selectedUrgency!.name}, shouldShow=$shouldShow');
                  
                  if (!shouldShow) {
                    debugPrint('❌ [FILTER] Request "${request.title}" filtered out by urgency: request.urgencyLevel=${request.urgencyLevel.name}');
                    return false;
                  }
                } 
                // ✅ אם אין סינון מקומי אבל יש סינון מ-Firestore, נכבד אותו (רק אם לא מנהל או שיש סינון פעיל אחר)
                else if (hasFirestoreUrgencyFilter && !(isAdmin && !hasActiveFilter)) {
                  bool shouldShow = false;
                    final urgencyFilter = _filterPreferencesFromFirestore!.urgency;
                    switch (urgencyFilter) {
                      case 'normal':
                        shouldShow = request.urgencyLevel == UrgencyLevel.normal;
                        break;
                      case 'urgent24h':
                        shouldShow = request.urgencyLevel == UrgencyLevel.urgent24h;
                        break;
                      case 'emergency':
                        shouldShow = request.urgencyLevel == UrgencyLevel.emergency;
                        break;
                      case 'urgentAndEmergency':
                        shouldShow = request.urgencyLevel == UrgencyLevel.urgent24h || 
                                     request.urgencyLevel == UrgencyLevel.emergency;
                        break;
                      default:
                        shouldShow = true; // 'all' or unknown
                        break;
                    }
                  debugPrint('🔍 [FILTER] Urgency check (Firestore): request.urgencyLevel=${request.urgencyLevel.name}, urgencyFilter=$urgencyFilter, shouldShow=$shouldShow');
                  
                  if (!shouldShow) {
                    debugPrint('❌ [FILTER] Request "${request.title}" filtered out by urgency (Firestore): request.urgencyLevel=${request.urgencyLevel.name}');
                    return false;
                  }
                }
                
                // לוגיקת OR: קבוע / נייד / מקום אחר - רק אם יש סינון פעיל
                // מנהל רואה את כל הבקשות ללא סינון לפי מיקום (אם אין סינון מקומי פעיל)
                // אם מנהל ואין סינון מקומי פעיל, דלג על סינון המיקום
                if (hasActiveFilter && !(isAdmin && !hasActiveFilter) && request.latitude != null && request.longitude != null) {
                  // הבקשה חייבת להיות בישראל
                  if (!LocationService.isLocationInIsrael(request.latitude!, request.longitude!)) {
                      return false;
                    }
                    
                  bool inRange = false;

                  // ✅ לוגיקה חדשה: כאשר בוחרים את כל סוגי הסינונים, יוצגו בקשות שנמצאות באחד מהטווחים (איחוד - UNION)
                  // לא רק בקשות שנמצאות בכל הטווחים (חיתוך - INTERSECTION)

                  // מיקום נוסף (נבחר במפה בדיאלוג) - נשמר בנפרד - רק אם הצ'יקבוקס מסומן
                  // ✅ בדיקה ראשונה: מיקום נוסף מהמשתנים המקומיים (SharedPreferences)
                  if (_useAdditionalLocation && _additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null) {
                    if (LocationService.isLocationInRange(_additionalLocationLatitude!, _additionalLocationLongitude!, request.latitude!, request.longitude!, _additionalLocationRadius!)) {
                      inRange = true;
                      debugPrint('✅ [FILTER] Request "${request.title}" - in range of additional location (local)');
                    }
                  }
                  
                  // ✅ בדיקה שנייה: מיקום נוסף מ-Firestore (אם יש סינון פעיל עם התראות)
                  if (!inRange && _filterPreferencesFromFirestore != null && 
                      _filterPreferencesFromFirestore!.isEnabled && 
                      _filterPreferencesFromFirestore!.useAdditionalLocation &&
                      _filterPreferencesFromFirestore!.additionalLocationLatitude != null &&
                      _filterPreferencesFromFirestore!.additionalLocationLongitude != null &&
                      _filterPreferencesFromFirestore!.additionalLocationRadius != null) {
                    if (LocationService.isLocationInRange(
                      _filterPreferencesFromFirestore!.additionalLocationLatitude!,
                      _filterPreferencesFromFirestore!.additionalLocationLongitude!,
                      request.latitude!,
                      request.longitude!,
                      _filterPreferencesFromFirestore!.additionalLocationRadius!
                    )) {
                      inRange = true;
                      debugPrint('✅ [FILTER] Request "${request.title}" - in range of additional location (Firestore)');
                    }
                  }

                  // מיקום נייד (אם מסומן) - משתמש במיקום הנוכחי
                  if (_useMobileLocationAndRadius && _userLatitude != null && _userLongitude != null && _maxDistance != null) {
                    if (LocationService.isLocationInRange(_userLatitude!, _userLongitude!, request.latitude!, request.longitude!, _maxDistance!)) {
                      inRange = true;
                    }
                  }

                  // מיקום קבוע (אם מסומן ויש נתונים בפרופיל)
                  if (_useFixedLocationAndRadius && _userProfile != null && _userProfile!.latitude != null && _userProfile!.longitude != null) {
                    final fixedRadiusKm = _userProfile!.maxRadius;
                    if (LocationService.isLocationInRange(_userProfile!.latitude!, _userProfile!.longitude!, request.latitude!, request.longitude!, fixedRadiusKm)) {
                      inRange = true;
                    }
                  }

                  // ✅ לוגיקת סינון לנותני שירות (עסקיים) לפי showToProvidersOutsideRange
                  // בדיקה אם המשתמש הוא נותן שירות (עסקי) עם סינון פעיל (מקומי או Firestore)
                  final hasLocationFilter = _useFixedLocationAndRadius || 
                      _useMobileLocationAndRadius || 
                      (_useAdditionalLocation && _additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null) ||
                      (_filterPreferencesFromFirestore?.isEnabled == true && 
                       _filterPreferencesFromFirestore!.useAdditionalLocation &&
                       _filterPreferencesFromFirestore!.additionalLocationLatitude != null &&
                       _filterPreferencesFromFirestore!.additionalLocationLongitude != null &&
                       _filterPreferencesFromFirestore!.additionalLocationRadius != null);
                  
                  final isBusinessUserWithLocationFilter = _userProfile != null && 
                      _userProfile!.userType == UserType.business && 
                      hasLocationFilter;
                  
                  if (isBusinessUserWithLocationFilter && request.latitude != null && request.longitude != null) {
                    // אם יש הגדרה של showToProvidersOutsideRange
                    if (request.showToProvidersOutsideRange != null) {
                      debugPrint('🔍 [FILTER] Request "${request.title}" - showToProvidersOutsideRange: ${request.showToProvidersOutsideRange}, inRange: $inRange');
                      
                      if (request.showToProvidersOutsideRange == true) {
                        // ✅ המשתמש בחר "כן" - להציג את הבקשה אם מיקום הבקשה בטווח נותן השירות
                        // הלוגיקה כבר נבדקה ב-inRange למעלה
                        if (!inRange) {
                          debugPrint('❌ [FILTER] Request "${request.title}" - NOT showing (request location NOT in provider range, showToProvidersOutsideRange=true)');
                      return false;
                    }
                        debugPrint('✅ [FILTER] Request "${request.title}" - showing (request location in provider range, showToProvidersOutsideRange=true)');
                      } else {
                        // ✅ המשתמש בחר "לא" - לא להציג את הבקשה אם מיקום הבקשה בטווח נותן השירות
                        // אבל כן להציג אותה אם מיקום נותן השירות בטווח הבקשה
                        if (inRange) {
                          // מיקום הבקשה בטווח נותן השירות - לא להציג
                          debugPrint('❌ [FILTER] Request "${request.title}" - NOT showing (request location in provider range, showToProvidersOutsideRange=false)');
                          return false;
                        }
                        // בדיקה אם מיקום נותן השירות בטווח הבקשה
                        if (request.exposureRadius != null) {
                          bool providerInRequestRange = false;
                          
                          // מיקום קבוע של נותן השירות
                          if (_useFixedLocationAndRadius && _userProfile!.latitude != null && _userProfile!.longitude != null) {
                            if (LocationService.isLocationInRange(
                              request.latitude!, 
                              request.longitude!, 
                              _userProfile!.latitude!, 
                              _userProfile!.longitude!, 
                              request.exposureRadius!
                            )) {
                              providerInRequestRange = true;
                              debugPrint('✅ [FILTER] Request "${request.title}" - provider fixed location in request range');
                            }
                          }
                          
                          // מיקום נייד של נותן השירות
                          if (!providerInRequestRange && _useMobileLocationAndRadius && _userLatitude != null && _userLongitude != null) {
                            if (LocationService.isLocationInRange(
                              request.latitude!, 
                              request.longitude!, 
                              _userLatitude!, 
                              _userLongitude!, 
                              request.exposureRadius!
                            )) {
                              providerInRequestRange = true;
                              debugPrint('✅ [FILTER] Request "${request.title}" - provider mobile location in request range');
                            }
                          }
                          
                          // מיקום נוסף (נבחר במפה) של נותן השירות - מקומי או Firestore
                          if (!providerInRequestRange && _useAdditionalLocation && _additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null) {
                            if (LocationService.isLocationInRange(
                              request.latitude!, 
                              request.longitude!, 
                              _additionalLocationLatitude!, 
                              _additionalLocationLongitude!, 
                              request.exposureRadius!
                            )) {
                              providerInRequestRange = true;
                              debugPrint('✅ [FILTER] Request "${request.title}" - provider additional location (local) in request range');
                            }
                          }
                          
                          // מיקום נוסף מ-Firestore
                          if (!providerInRequestRange && _filterPreferencesFromFirestore?.isEnabled == true && 
                              _filterPreferencesFromFirestore!.useAdditionalLocation &&
                              _filterPreferencesFromFirestore!.additionalLocationLatitude != null &&
                              _filterPreferencesFromFirestore!.additionalLocationLongitude != null &&
                              _filterPreferencesFromFirestore!.additionalLocationRadius != null) {
                            if (LocationService.isLocationInRange(
                              request.latitude!, 
                              request.longitude!, 
                              _filterPreferencesFromFirestore!.additionalLocationLatitude!,
                              _filterPreferencesFromFirestore!.additionalLocationLongitude!,
                              request.exposureRadius!
                            )) {
                              providerInRequestRange = true;
                              debugPrint('✅ [FILTER] Request "${request.title}" - provider additional location (Firestore) in request range');
                            }
                          }
                          
                          // אם מיקום נותן השירות לא בטווח הבקשה - לא להציג
                          if (!providerInRequestRange) {
                            debugPrint('❌ [FILTER] Request "${request.title}" - NOT showing (provider location NOT in request range, showToProvidersOutsideRange=false)');
                      return false;
                          }
                          debugPrint('✅ [FILTER] Request "${request.title}" - showing (provider location in request range, showToProvidersOutsideRange=false)');
                        } else {
                          // אין רדיוס חשיפה לבקשה - לא להציג
                          debugPrint('❌ [FILTER] Request "${request.title}" - NOT showing (no exposure radius, showToProvidersOutsideRange=false)');
                          return false;
                        }
                      }
                    } else {
                      // אם אין הגדרה של showToProvidersOutsideRange, נשתמש בלוגיקה הקיימת
                      if (!inRange && hasLocationFilter) {
                        return false; // ביקש סינון לפי מרחק אך לא בטווח באף מקור
                      }
                    }
                  } else {
                    // אם המשתמש לא עסקי או אין סינון פעיל, נשתמש בלוגיקה הקיימת
                    if (!inRange && hasLocationFilter) {
                      return false; // ביקש סינון לפי מרחק אך לא בטווח באף מקור
                    }
                  }
                }
                
                final searchQuery = _searchController.text.trim();
                if (searchQuery.isNotEmpty) {
                  if (!request.title.toLowerCase().contains(searchQuery.toLowerCase()) &&
                      !request.description.toLowerCase().contains(searchQuery.toLowerCase())) {
                    return false;
                  }
                }
                
                // 2. בדיקת סוג הבקשה לפי סוג המשתמש - רק אם אין סינון פעיל
                // אם יש סינון פעיל, הסינון כבר מטפל בסוג הבקשה
                if (!hasActiveFilter) {
                  // מנהל רואה את כל הבקשות (חינמיות ובתשלום) - נחזיר true מיד
                  if (isAdmin) {
                    return true;
                  }
                  
                  // בקשות חינמיות - כל המשתמשים רואים אותן
                  if (request.type == RequestType.free) {
                    return true;
                  }
                  
                  // בקשות בתשלום - בדיקה לפי סוג המשתמש
                  if (request.type == RequestType.paid) {
                    // בדיקה אם המשתמש הגדיר שלא הוא נותן שירותים בתשלום
                    if (_userProfile?.noPaidServices == true) {
                      return false;
                    }
                    
                    // בדיקה אם המשתמש הוא פרטי - לא יראה בקשות בתשלום
                    if (_userProfile?.userType == UserType.personal) {
                      return false;
                    }
                    
                    // בדיקה אם המשתמש הוא עסקי מנוי
                    if (_userProfile?.userType == UserType.business && _userProfile?.isSubscriptionActive == true) {
                      // בדיקה אם הקטגוריה של הבקשה היא אחת מתחומי העיסוק של המשתמש
                      if (_userProfile?.businessCategories != null && 
                          _userProfile!.businessCategories!.any((category) => category == request.category)) {
                        return true;
                      } else {
                        return false;
                      }
                    }
                    
                    // בדיקה אם המשתמש הוא אורח
                    if (_userProfile?.userType == UserType.guest) {
                      // משתמש אורח רואה כל הבקשות בתשלום במשך כל תקופת הניסיון
                      return true;
                    }
                    
                    // משתמשים פרטיים (חינם או מנוי) לא רואים בקשות בתשלום
                    return false;
                  }
                } else {
                  // יש סינון פעיל - בדיקה בסיסית של סוג הבקשה
                  // מנהל רואה את כל הבקשות (חינמיות ובתשלום) - אבל רק אם אין סינון מפורש לפי סוג בקשה
                  // אם יש סינון לפי סוג בקשה, הסינון כבר טיפל בזה בשורות 4795-4803
                  final requestTypeFilter = _selectedRequestType ?? 
                    (_filterPreferencesFromFirestore?.isEnabled == true && _filterPreferencesFromFirestore?.requestType != null
                      ? (_filterPreferencesFromFirestore!.requestType == 'free' ? RequestType.free : RequestType.paid)
                      : null);
                  
                  if (isAdmin && requestTypeFilter == null) {
                    // מנהל ללא סינון לפי סוג בקשה - רואה את כל הבקשות
                    return true;
                  }
                  
                  // בקשות חינמיות - כל המשתמשים רואים אותן (אם עברו את הסינון)
                  if (request.type == RequestType.free) {
                    return true;
                  }
                  
                  // בקשות בתשלום - בדיקה בסיסית לפי סוג המשתמש
                  if (request.type == RequestType.paid) {
                    // בדיקה אם המשתמש הגדיר שלא הוא נותן שירותים בתשלום
                    if (_userProfile?.noPaidServices == true) {
                      return false;
                    }
                    
                    // בדיקה אם המשתמש הוא פרטי - לא יראה בקשות בתשלום
                    if (_userProfile?.userType == UserType.personal) {
                      return false;
                    }
                    
                    // עסקי מנוי, אורח - יכולים לראות בקשות בתשלום (אם עברו את הסינון)
                    return true;
                  }
                }
                
                // בדיקת דירוגים מותאמים אישית - מנהל ומשתמש אורח זמני רואים את כל הבקשות ללא סינון לפי דירוגים
                final isTemporaryGuest = _userProfile?.isTemporaryGuest == true;
                if (!isAdmin && !isTemporaryGuest && (request.minReliability != null || request.minAvailability != null || 
                    request.minAttitude != null || request.minFairPrice != null)) {
                  
                  // רשימת דרישות דירוג שנבחרו
                  List<String> selectedRequirements = [];
                  List<String> failedRequirements = [];
                  
                  // בדיקת דירוג אמינות
                  if (request.minReliability != null) {
                    selectedRequirements.add('אמינות: ${request.minReliability!.toStringAsFixed(1)}');
                    final userReliability = _userProfile?.reliability ?? 0.0;
                    if (userReliability < request.minReliability!) {
                      failedRequirements.add('אמינות: $userReliability < ${request.minReliability!.toStringAsFixed(1)}');
                    }
                  }
                  
                  // בדיקת דירוג זמינות
                  if (request.minAvailability != null) {
                    selectedRequirements.add('זמינות: ${request.minAvailability!.toStringAsFixed(1)}');
                    final userAvailability = _userProfile?.availability ?? 0.0;
                    if (userAvailability < request.minAvailability!) {
                      failedRequirements.add('זמינות: $userAvailability < ${request.minAvailability!.toStringAsFixed(1)}');
                    }
                  }
                  
                  // בדיקת דירוג יחס
                  if (request.minAttitude != null) {
                    selectedRequirements.add('יחס: ${request.minAttitude!.toStringAsFixed(1)}');
                    final userAttitude = _userProfile?.attitude ?? 0.0;
                    if (userAttitude < request.minAttitude!) {
                      failedRequirements.add('יחס: $userAttitude < ${request.minAttitude!.toStringAsFixed(1)}');
                    }
                  }
                  
                  // בדיקת דירוג מחיר הוגן
                  if (request.minFairPrice != null) {
                    selectedRequirements.add('מחיר הוגן: ${request.minFairPrice!.toStringAsFixed(1)}');
                    final userFairPrice = _userProfile?.fairPrice ?? 0.0;
                    if (userFairPrice < request.minFairPrice!) {
                      failedRequirements.add('מחיר הוגן: $userFairPrice < ${request.minFairPrice!.toStringAsFixed(1)}');
                    }
                  }
                  
                  // אם יש דרישות שנכשלו - הסתר את הבקשה
                  if (failedRequirements.isNotEmpty) {
                    return false;
                  }
                  
                  // אם אין דרישות שנכשלו - הצג את הבקשה
                  return true;
                }
                
                // בקשות עם דירוג מינימלי פשוט (לשמירת תאימות)
                // מנהל ומשתמש אורח זמני רואים את כל הבקשות ללא סינון לפי דירוג
                if (!isAdmin && !isTemporaryGuest && request.minRating != null) {
                  final userRating = _userProfile?.averageRating ?? 0.0;
                  if (userRating < request.minRating!) {
                    return false;
                  }
                }
                return true;
              }).toList();

              // ✅ עדכון מספר "בקשות פתוחות לטיפול" לפי הסינון
              // אם יש סינון פעיל, המספר ישקף את הבקשות המסוננות
              // אם אין סינון פעיל, המספר ישקף את המספר הכולל (שנשמר ב-_openRequestsCount)
              // ✅ משתמשים ב-addPostFrameCallback כדי להימנע מ-setState במהלך build
              if (mounted && !_showMyRequests) {
                final hasActiveFilter = _hasActiveFilters();
                if (hasActiveFilter) {
                  // יש סינון פעיל - הצג את מספר הבקשות המסוננות
                  final filteredCount = requests.length;
                  if (_animatedOpenCount != filteredCount) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _animatedOpenCount = filteredCount;
                        });
                      }
                    });
                  }
                } else {
                  // אין סינון פעיל - הצג את המספר הכולל (שנשמר ב-_openRequestsCount)
                  // המספר כבר מתעדכן ב-_loadTotalRequestsCount()
                }
              }

              // אם הגענו מהתראה עם בקשה ספציפית לפתיחה – נפתח/נגלול אליה
              final pendingRequestId = AppStateService.consumePendingRequestToOpen();
              if (pendingRequestId != null) {
                final index = requests.indexWhere((r) => r.requestId == pendingRequestId);
                if (index >= 0) {
                  _expandedRequests.add(pendingRequestId);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      // ניסיון גלילה משוער – על בסיס גובה כרטיס ממוצע
                      final estimatedItemHeight = 260.0;
                      final offset = (index * estimatedItemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
                      _scrollController.animateTo(
                        offset,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    } catch (_) {}
                  });
                }
              }

              // מיון הבקשות
              // ✅ בדיקה אם יש סינון פעיל ואין תוצאות - רק במסך "כל הבקשות" (לא במסך "בקשות בטיפול שלי")
              // במסך "בקשות בטיפול שלי", ההודעה הריקה מוצגת ב-_buildRequestsList (שורה 592)
              if (requests.isEmpty && _hasActiveFilters() && !_showMyRequests) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 80,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'אין בקשות מתאימות לסינון הנבחר',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'נסה לשנות את הסינון או לנקות אותו כדי לראות יותר בקשות',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // ✅ כפתורי סינון - מוצגים רק ב"כל הבקשות", לא ב"פניות שלי"
                        if (!_showMyRequests) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await playButtonSound();
                                  _clearFilters();
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('נקה סינון'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await playButtonSound();
                                  _showAdvancedFilterDialog(_userProfile);
                                },
                                icon: const Icon(Icons.tune),
                                label: const Text('שנה סינון'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              if (_showMyRequests) {
                // במצב "בקשות שפניתי אליהם" - נמיין את הבקשות לפי זמן ההתעניינות
                // ✅ נשתמש ב-FutureBuilder כדי למיין את הבקשות לפי זמן ההתעניינות
                return FutureBuilder<List<Request>>(
                  future: _sortRequestsByInterestTime(requests),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // בזמן המיון, נציג את הבקשות כמו שהן (לפי הסדר ב-_allRequests)
                      return _buildRequestsList(requests, l10n);
                    }
                    if (snapshot.hasData) {
                      return _buildRequestsList(snapshot.data!, l10n);
                    }
                    // אם יש שגיאה, נציג את הבקשות כמו שהן
                    return _buildRequestsList(requests, l10n);
                  },
                );
              } else {
                // במצב "כל הבקשות" - סידור לפי תאריך יצירה (החדשות ביותר בראש)
                requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return _buildRequestsList(requests, l10n);
              }
              
            },
          ),
        ],
        ),
      ),
    );
  }

  // ⬇️ Skeleton loading widget resembling request card with shimmer animation
  Widget _buildSkeletonCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title skeleton
            Row(
              children: [
                Expanded(
                  child: _buildShimmerContainer(
                    height: 20,
                    width: double.infinity,
                  ),
                ),
                const SizedBox(width: 8),
                _buildShimmerContainer(
                  height: 24,
                  width: 24,
                  isCircle: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description skeleton - 3 lines
            _buildShimmerContainer(height: 14, width: double.infinity),
            const SizedBox(height: 8),
            _buildShimmerContainer(height: 14, width: double.infinity * 0.85),
            const SizedBox(height: 8),
            _buildShimmerContainer(height: 14, width: double.infinity * 0.7),
            const SizedBox(height: 16),
            // Category and type skeleton
            Row(
              children: [
                _buildShimmerContainer(height: 16, width: 80),
                const SizedBox(width: 12),
                _buildShimmerContainer(height: 16, width: 60),
              ],
            ),
            const SizedBox(height: 12),
            // Actions skeleton
            Row(
              children: [
                _buildShimmerContainer(height: 32, width: 40),
                const SizedBox(width: 8),
                _buildShimmerContainer(height: 32, width: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ⬇️ Helper to build shimmer animated container
  Widget _buildShimmerContainer({
    required double height,
    required double width,
    bool isCircle = false,
  }) {
    return AnimatedBuilder(
      animation: _blinkingController,
      builder: (context, child) {
        final opacity = 0.3 + (0.4 * (math.sin(_blinkingController.value * 2 * math.pi) + 1) / 2);
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.grey[300]!.withValues(alpha: opacity),
            borderRadius: isCircle ? null : BorderRadius.circular(4),
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          ),
        );
      },
    );
  }

  // ✅ Lazy Rendering + List Optimization - Use const where possible and RepaintBoundary
  Widget _buildRequestCard(Request request, AppLocalizations l10n) {
    final isOwnRequest = request.createdBy == FirebaseAuth.instance.currentUser?.uid;
    final isUrgent = request.urgencyLevel == UrgencyLevel.emergency;
    
    // ✅ Wrap card in RepaintBoundary for isolated rebuilds (already done in _buildRequestsList)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      child: isUrgent ? _buildUrgentCard(request, isOwnRequest) : _buildNormalCard(request, isOwnRequest),
    );
  }
  
  Widget _buildUrgentCard(Request request, bool isOwnRequest) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
    return Card(
      margin: const EdgeInsets.all(8),
          color: isOwnRequest ? Colors.blue[50] : Colors.red[50],
          elevation: isOwnRequest ? 8 : 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isOwnRequest ? Colors.blue[300]! : Colors.red[400]!,
              width: 3,
            ),
          ),
          child: _buildCardContent(request, isOwnRequest),
        );
      },
    );
  }
  
  Widget _buildNormalCard(Request request, bool isOwnRequest) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: isOwnRequest ? Colors.blue[50] : null,
      elevation: isOwnRequest ? 6 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOwnRequest ? Colors.blue[300]! : Colors.grey[600]!,
          width: 2,
        ),
      ),
      child: _buildCardContent(request, isOwnRequest),
    );
  }

  // פונקציה לבניית תגית דחיפות מהבהבת
  Widget _buildBlinkingUrgencyTag(UrgencyLevel urgencyLevel) {
    return AnimatedBuilder(
      animation: _blinkingController,
      builder: (context, child) {
        final value = (1.0 + math.sin(_blinkingController.value * 2 * math.pi)) / 2;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: urgencyLevel.color.withValues(alpha: 0.3 + (value * 0.7)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: urgencyLevel.color.withValues(alpha: value * 0.8),
                blurRadius: 8 + (value * 4),
                spreadRadius: 2 + (value * 2),
              ),
            ],
          ),
          child: Text(
            urgencyLevel.displayName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildCardContent(Request request, bool isOwnRequest) {
    return Builder(
      builder: (outerContext) {
        // ✅ Safe fix: Get AppLocalizations from outer context to ensure Localizations are available
        final l10n = Localizations.of<AppLocalizations>(outerContext, AppLocalizations);
        if (l10n == null) {
          // Fallback if localization is not available (should not happen in MaterialApp context)
          return const SizedBox.shrink();
        }
        // ✅ Store l10n in a variable accessible to StatefulBuilder
        final cardL10n = l10n;
    return StatefulBuilder(
      builder: (context, setCardState) {
        final isExpanded = _expandedRequests.contains(request.requestId);
        // אם הבקשה עם סטטוס "טופל" ואנחנו במסך "פניות שלי", נציג אותה בצורה מכווצת (רק כותרת וסטטוס)
        final isCollapsed = _showMyRequests && request.status == RequestStatus.completed;
        
        // בדיקה אם המשתמש הנוכחי הוא helper (מטפל בבקשה)
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final isCurrentUserHelper = currentUserId != null && request.helpers.contains(currentUserId);
        
        // אם הבקשה במצב "בטיפול" והמשתמש לא helper ובמסך "כל הבקשות" - נציג כ"פתוח"
        // כדי שמשתמשים אחרים יוכלו גם לפנות למבקש השירות
        final displayStatus = (!_showMyRequests && 
                              request.status == RequestStatus.inProgress && 
                              !isCurrentUserHelper && 
                              !isOwnRequest) 
                              ? RequestStatus.open 
                              : request.status;
        
        return GestureDetector(
          onTap: () {
            // אם הבקשה מכווצת (סטטוס "טופל" במסך "פניות שלי"), לא נאפשר הרחבה
            if (isCollapsed) return;
            
            // עדכון רק של הכרטיס הספציפי
            if (isExpanded) {
              _expandedRequests.remove(request.requestId);
            } else {
              _expandedRequests.add(request.requestId);
              // ✅ Firestore Query Optimization - Load full details on demand when expanded
              _loadFullRequestDetails(request.requestId);
            }
            setCardState(() {});
          },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOwnRequest ? Colors.blue[200]! : Colors.grey[500]!,
            width: 1,
          ),
        ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // כותרת עם כפתור הרחבה
                Row(
          children: [
            if (isOwnRequest) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'שלי',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
                    Expanded(child: Text(
                      request.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: request.urgencyLevel == UrgencyLevel.emergency 
                            ? (Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.black87)  // טקסט כהה יותר לבקשות דחופות
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    )),
                    // הצגת סטטוס הבקשה (פתוח/בטיפול/טופל) - כמו במסך "בקשות שלי"
                    // אם הבקשה "בטיפול" והמשתמש לא helper - נציג כ"פתוח" כדי שמשתמשים אחרים יוכלו לפנות
                    if (displayStatus == RequestStatus.open || 
                        displayStatus == RequestStatus.inProgress || 
                        displayStatus == RequestStatus.completed) ...[
                      const SizedBox(width: 8),
              Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                          color: _getStatusColor(displayStatus),
                          borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                          _getStatusText(displayStatus, cardL10n),
                  style: const TextStyle(
                    color: Colors.white,
                            fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
                    // אם הבקשה מכווצת, לא נציג את אייקון ההרחבה
                    if (!isCollapsed)
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                
              // ✅ אם הבקשה מכווצת (סטטוס "טופל" במסך "בקשות בטיפול שלי"), נציג רק:
              // - כותרת
              // - מיקום
              // - מספר הפונים
              // - פורסם על ידי
              // - צ'אט סגור
              // - מחק בקשה
              if (isCollapsed) ...[
                // מיקום
                if (request.address != null && request.address!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.address!,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color, 
                            fontSize: 12
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                
                // מספר פונים
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      cardL10n.interestedCallers(request.helpers.length),
                      style: TextStyle(
                        color: request.helpers.isNotEmpty ? Colors.blue[600] : Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                        fontWeight: request.helpers.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                
                // פורסם על ידי
                if (!isOwnRequest) ...[
                  const SizedBox(height: 8),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(request.createdBy)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData = snapshot.data!.data() as Map<String, dynamic>;
                        final name = userData['name'];
                        final displayName = userData['displayName'];
                        final email = userData['email'];
                        
                        final userName = (name != null && name.isNotEmpty) ? name :
                                        (displayName != null && displayName.isNotEmpty) ? displayName :
                                        (email != null) ? email.split('@')[0] :
                                        'משתמש';
                                
                        return Row(
                          children: [
                            Icon(Icons.person, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              cardL10n.publishedBy(userName),
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodySmall?.color, 
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Icon(Icons.person, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            cardL10n.publishedByUser,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color, 
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                
                // צ'אט סגור (אבל לא להציג "פתח צ'אט מחדש" בתפריט)
                if (request.helpers.contains(FirebaseAuth.instance.currentUser?.uid)) ...[
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .where('requestId', isEqualTo: request.requestId)
                        .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, chatSnapshot) {
                      if (chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty) {
                        QueryDocumentSnapshot? activeChat;
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        final isRequestCreator = request.createdBy == currentUserId;
                        
                        for (var chatDoc in chatSnapshot.data!.docs) {
                          final chatData = chatDoc.data() as Map<String, dynamic>;
                          final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                          
                          if (isRequestCreator && deletedBy.contains(currentUserId)) {
                            continue;
                          }
                          if (!isRequestCreator && deletedBy.contains(currentUserId)) {
                            continue;
                          }
                          
                          activeChat = chatDoc;
                          break;
                        }
                        
                        if (activeChat != null) {
                          final chatData = activeChat.data() as Map<String, dynamic>;
                          final isClosed = chatData['isClosed'] as bool? ?? false;
                          
                          return ElevatedButton.icon(
                            onPressed: () async {
                              await playButtonSound();
                              // פתיחת הצ'אט - אבל לא להציג "פתח צ'אט מחדש" בתפריט
                              if (!context.mounted) return;
                              final l10n = AppLocalizations.of(context);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatId: activeChat!.id,
                                    requestTitle: l10n.request,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(isClosed ? Icons.lock : Icons.chat, size: 20),
                            label: Text(isClosed ? cardL10n.chatClosedButton : cardL10n.chatButton),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isClosed ? Colors.grey : Colors.green,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
                
                // כפתור "מחק בקשה" במסך "פניות שלי" לבקשות עם סטטוס "טופל"
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _removeRequestFromMyRequests(request.requestId),
                        icon: const Icon(Icons.delete, size: 16),
                        label: Text(cardL10n.deleteRequest),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
              // אם הבקשה לא מכווצת, נציג את כל הפרטים
              const SizedBox(height: 8),
                
                // תיאור
                Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: request.urgencyLevel == UrgencyLevel.emergency 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.black87)  // טקסט כהה יותר לבקשות דחופות
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // תמונות
                if (request.images.isNotEmpty) ...[
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
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
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
                  const SizedBox(height: 8),
                ],
                
                // קטגוריה, סוג בקשה, מיקום, דחיפות
                Row(
                  children: [
                    Icon(Icons.category, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      request.category.categoryDisplayName,
                      style: TextStyle(
                        color: request.urgencyLevel == UrgencyLevel.emergency 
                            ? (Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.black87)  // טקסט כהה יותר לבקשות דחופות
                            : Theme.of(context).textTheme.bodySmall?.color, 
                        fontSize: 12
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.payment, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      request.type.typeDisplayName(cardL10n),
                      style: TextStyle(
                        color: request.urgencyLevel == UrgencyLevel.emergency 
                            ? (request.type == RequestType.paid 
                                ? Colors.green[800] 
                                : (Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Colors.black87))  // טקסט כהה יותר לבקשות דחופות
                            : (request.type == RequestType.paid ? Colors.green[600] : Theme.of(context).textTheme.bodySmall?.color),
                        fontSize: 12,
                        fontWeight: request.type == RequestType.paid ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                
                // הצגת מחיר (אם יש) - רק לבקשות בתשלום - בשורה חדשה
                if (request.type == RequestType.paid && request.price != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${cardL10n.willingToPay}: ${request.price!.toStringAsFixed(0)}₪',
                        style: TextStyle(
                          color: request.urgencyLevel == UrgencyLevel.emergency 
                              ? Colors.green[800]
                              : Colors.green[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                
              const SizedBox(height: 4),
                
                Row(
                  children: [
                    if (request.address != null && request.address!.isNotEmpty) ...[
                      Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (request.latitude != null && request.longitude != null) {
                              _showRequestLocationDialog(context, request);
                            }
                          },
                          child: Text(
                            request.address!,
                            style: TextStyle(
                              color: request.urgencyLevel == UrgencyLevel.emergency 
                                  ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                                  : Theme.of(context).textTheme.bodySmall?.color, 
                              fontSize: 12,
                              decoration: request.latitude != null && request.longitude != null 
                                  ? TextDecoration.underline 
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                      // אייקון Waze לניווט (אם יש קואורדינטות)
                      if (request.latitude != null && request.longitude != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _openWazeNavigation(request.latitude!, request.longitude!),
                          child: Image.asset(
                            'assets/images/waze.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ],
                    const Spacer(),
                    // תגיות דחיפות (רמת דחיפות + תגיות)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // תגית רמת דחיפות (רק אם לא רגיל)
                        if (request.urgencyLevel != UrgencyLevel.normal)
                          request.urgencyLevel == UrgencyLevel.emergency
                              ? _buildBlinkingUrgencyTag(request.urgencyLevel)
                              : Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: request.urgencyLevel.color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    request.urgencyLevel.displayName,
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                        // תגיות דחיפות ספציפיות
                        if (request.tags.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: request.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tag.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: tag.color,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  tag.displayName(l10n),
                                  style: TextStyle(
                                    color: tag.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        // תגית מותאמת אישית
                        if (request.customTag != null && request.customTag!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.purple,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '🏷️ ${request.customTag}',
                              style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                
                // מרחק אם יש קואורדינטות
                if (_userLatitude != null && _userLongitude != null && 
                    request.latitude != null && request.longitude != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.straighten, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${LocationService.calculateDistance(_userLatitude!, _userLongitude!, request.latitude!, request.longitude!).toStringAsFixed(1)} ק״מ',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color, 
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ],
                
                // הצגת נקודת מקור המיקום שבה זוהתה ההתראה (ב"בקשות שלי")
                if (_showMyRequests && _notificationPrefs != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_notificationPrefs!.newRequestsUseFixedLocation || _notificationPrefs!.newRequestsUseBothLocations) ...[
                        Icon(Icons.location_on, color: Colors.blue[600], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'מיקום קבוע',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (_notificationPrefs!.newRequestsUseMobileLocation || _notificationPrefs!.newRequestsUseBothLocations) ...[
                        Icon(Icons.my_location, color: Colors.blue[600], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'מיקום נייד',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                
                // כפתורי LIKE ו-SHARE (תמיד גלויים)
                const SizedBox(height: 8),
                Row(
                  children: [
                    // כפתור LIKE
                    StreamBuilder<bool>(
                      stream: LikeService.isLikedByCurrentUserStream(request.requestId),
                      builder: (context, isLikedSnapshot) {
                        final isLiked = isLikedSnapshot.data ?? false;
                        return StreamBuilder<int>(
                          stream: LikeService.getLikesCountStream(request.requestId),
                          builder: (context, likesCountSnapshot) {
                            final likesCount = likesCountSnapshot.data ?? 0;
                            return Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    await playButtonSound();
                                    final result = await LikeService.likeRequest(request.requestId);
                                    // Guard context usage after async gap - check context.mounted for builder context
                                    if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(result ? 'הוספת לייק! ❤️' : 'הסרת לייק'),
                                          duration: const Duration(seconds: 2),
                                          backgroundColor: result ? Colors.pink : Colors.grey,
                                        ),
                                      );
                                  },
                                  icon: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? Colors.pink : Colors.grey[600],
                                    size: 24,
                                  ),
                                ),
                                Text(
                                  '$likesCount',
                                  style: TextStyle(
                                    color: request.urgencyLevel == UrgencyLevel.emergency 
                                        ? (Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.white 
                                            : Colors.black87)  // טקסט כהה יותר לבקשות דחופות
                                        : (Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.white 
                                            : Colors.grey[600]),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // כפתור SHARE
                    IconButton(
                      onPressed: () => _showShareDialog(request),
                      icon: Icon(
                        Icons.share,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                    ),
                    
                    const Spacer(),
                  ],
                ),
                ],
                
                // מידע מורחב (רק אם הבקשה מורחבת)
                if (isExpanded) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // ✅ Loading indicator when loading full details
                  if (_loadingFullDetails.contains(request.requestId)) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                  
                  // מספר טלפון
                  if (request.createdBy != FirebaseAuth.instance.currentUser?.uid) ...[
              Builder(
                builder: (context) {
                  final formattedPhone = request.formattedPhoneNumber;
                  debugPrint('📞 Home Screen - Request: ${request.title}');
                  debugPrint('📞 Home Screen - phoneNumber: ${request.phoneNumber}');
                  debugPrint('📞 Home Screen - formattedPhoneNumber: $formattedPhone');
                  debugPrint('📞 Home Screen - formattedPhoneNumber != null: ${formattedPhone != null}');
                  debugPrint('📞 Home Screen - formattedPhoneNumber!.isNotEmpty: ${formattedPhone != null && formattedPhone.isNotEmpty}');
                  
                  if (formattedPhone != null && formattedPhone.isNotEmpty) {
                    if (_interestedRequests.contains(request.requestId)) {
                      // המשתמש לחץ "אני מעוניין" - הצג את מספר הטלפון
                      return GestureDetector(
                        onTap: () {
                          debugPrint('=== PHONE NUMBER TAPPED ===');
                          debugPrint('Phone number: $formattedPhone');
                          _makePhoneCall(formattedPhone);
                        },
                        child: Row(
                          children: [
                            Icon(Icons.phone, size: 20, color: Colors.blue[600]),
                            const SizedBox(width: 4),
                            Text(
                              formattedPhone,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary, 
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // המשתמש לא לחץ "אני מעוניין" - הצג הודעה
                      return Row(
                        children: [
                          Icon(Icons.phone_locked, size: 20, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            cardL10n.clickIAmInterestedToShowPhone,
                            style: TextStyle(
                              color: request.urgencyLevel == UrgencyLevel.emergency 
                                  ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                                  : Theme.of(context).textTheme.bodySmall?.color, 
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      );
                    }
                  } else {
                    // אין מספר טלפון - הצג הודעה
                    debugPrint('📞 Home Screen - Showing "בקשה ללא מספר טלפון" for request: ${request.title}');
                    return Row(
                      children: [
                        Icon(Icons.phone_disabled, size: 20, color: Colors.orange[600]),
                        const SizedBox(width: 4),
                        Text(
                          cardL10n.requestWithoutPhone,
                          style: TextStyle(
                            color: Colors.orange[600], 
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
                    const SizedBox(height: 8),
            ],
                  
                  // תאריך יעד
                  if (request.deadline != null) ...[
            Row(
              children: [
                        Icon(Icons.schedule, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    cardL10n.deadlineDateHome('${request.deadline!.day}/${request.deadline!.month}/${request.deadline!.year}'),
                  style: TextStyle(
                            color: request.urgencyLevel == UrgencyLevel.emergency 
                                ? (request.deadline!.isBefore(DateTime.now()) 
                                    ? Colors.red[800]  // כהה יותר לבקשות דחופות
                                    : (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white 
                                        : Colors.black87))  // טקסט כהה יותר לבקשות דחופות
                                : (request.deadline!.isBefore(DateTime.now()) 
                                    ? Colors.red[600] 
                                    : Theme.of(context).textTheme.bodySmall?.color),
                      fontSize: 12,
                      fontWeight: request.deadline!.isBefore(DateTime.now()) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // מספר פונים
            Row(
              children: [
                      Icon(Icons.people, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  cardL10n.interestedCallers(request.helpers.length),
                  style: TextStyle(
                            color: request.urgencyLevel == UrgencyLevel.emergency 
                                ? (request.helpers.isNotEmpty 
                                    ? Colors.blue[800] 
                                    : (Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white 
                                        : Colors.black87))  // טקסט כהה יותר לבקשות דחופות
                                : (request.helpers.isNotEmpty ? Colors.blue[600] : Theme.of(context).textTheme.bodySmall?.color),
                    fontSize: 12,
                    fontWeight: request.helpers.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (request.helpers.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${request.helpers.length}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
                  
            const SizedBox(height: 8),
                  
                  // שם מפרסם הבקשה
            if (!isOwnRequest)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(request.createdBy)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                          return Row(
              children: [
                              Icon(Icons.person, size: 20, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          const Text(
                            'טוען...',
                            style: TextStyle(
                              color: Colors.grey, 
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                    );
                  }
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    final name = userData['name'];
                    final displayName = userData['displayName'];
                    final email = userData['email'];
                    
                    final userName = (name != null && name.isNotEmpty) ? name :
                                    (displayName != null && displayName.isNotEmpty) ? displayName :
                                    (email != null) ? email.split('@')[0] :
                                    'משתמש';
                          
                          return Row(
                        children: [
                          FutureBuilder<String?>(
                            future: _getUserProfileImageFromFirestore(request.createdBy),
                            builder: (context, imageSnapshot) {
                              if (imageSnapshot.hasData && imageSnapshot.data != null) {
                                return CircleAvatar(
                                      radius: 12,
                                  backgroundColor: Colors.grey[300],
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: imageSnapshot.data!,
                                          width: 24,
                                          height: 24,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Icon(Icons.person, size: 16, color: Colors.grey),
                                      errorWidget: (context, url, error) => const Icon(Icons.person, size: 16, color: Colors.grey),
                                    ),
                                  ),
                                );
                              }
                                  return Icon(Icons.person, size: 20, color: Colors.grey[600]);
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cardL10n.publishedBy(userName),
                            style: TextStyle(
                                  color: request.urgencyLevel == UrgencyLevel.emergency 
                                      ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                                      : Theme.of(context).textTheme.bodySmall?.color, 
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                          );
                        }
                        
                        return StreamBuilder<String?>(
                          stream: _getUserNameFromFirestore(request.createdBy),
                    builder: (context, authSnapshot) {
                      if (authSnapshot.hasData && authSnapshot.data != null) {
                        final userName = authSnapshot.data!;
                              return Row(
                            children: [
                              FutureBuilder<String?>(
                                future: _getUserProfileImageFromFirestore(request.createdBy),
                                builder: (context, imageSnapshot) {
                                if (imageSnapshot.hasData && imageSnapshot.data != null) {
                                  return CircleAvatar(
                                          radius: 12,
                                    backgroundColor: Colors.grey[300],
                                    child: ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: imageSnapshot.data!,
                                              width: 24,
                                              height: 24,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Icon(Icons.person, size: 16, color: Colors.grey),
                                        errorWidget: (context, url, error) => const Icon(Icons.person, size: 16, color: Colors.grey),
                                      ),
                                    ),
                                  );
                                }
                                      return Icon(Icons.person, size: 20, color: Colors.grey[600]);
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'פורסם על ידי: $userName',
                                style: TextStyle(
                                      color: request.urgencyLevel == UrgencyLevel.emergency 
                                          ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                                          : Theme.of(context).textTheme.bodySmall?.color, 
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                        );
                      }
                      
                            return Row(
                          children: [
                                Icon(Icons.person, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              cardL10n.publishedByUser,
                              style: TextStyle(
                                    color: request.urgencyLevel == UrgencyLevel.emergency 
                                        ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                                        : Theme.of(context).textTheme.bodySmall?.color, 
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                      );
                    },
                  );
                },
              ),
                  
                  const SizedBox(height: 8),
                  
                  // כפתור "אני מעוניין" - במסך "כל הבקשות"
                  // גם בקשות "בטיפול" יוצגו כ"פתוח" למשתמשים שאינם helpers, כך שגם הם יוכלו לפנות
                if (!_showMyRequests && 
                    request.createdBy != FirebaseAuth.instance.currentUser?.uid && 
                    (displayStatus == RequestStatus.open || 
                     (request.status == RequestStatus.inProgress && !isCurrentUserHelper))) ...[
                  _buildInterestButton(request, cardL10n),
                    const SizedBox(height: 8),
                ],
                  
                  // כפתור "אני לא מעוניין" - במסך "פניות שלי"
                if (_showMyRequests && request.createdBy != FirebaseAuth.instance.currentUser?.uid && request.helpers.contains(FirebaseAuth.instance.currentUser?.uid)) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      await playButtonSound();
                      await _showUnhelpConfirmationDialog(request);
                    },
                    icon: const Icon(Icons.cancel, size: 24),
                    label: Text(cardL10n.iAmNotInterested),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                  
                  // כפתור צ'אט אם המשתמש לחץ "אני מעוניין"
                if (request.helpers.contains(FirebaseAuth.instance.currentUser?.uid))
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .where('requestId', isEqualTo: request.requestId)
                        .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, chatSnapshot) {
                      // ✅ Safe: Use cardL10n from outer scope instead of creating new one
                      final l10nChat = cardL10n;
                      if (chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty) {
                        // חיפוש הצ'אט שלא נמחק (אם יש צ'אט חדש אחרי מחיקה)
                        // אם יש כמה צ'אטים, נבחר את החדש ביותר (לפי updatedAt)
                        QueryDocumentSnapshot? activeChat;
                        DateTime? latestUpdatedAt;
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        final isRequestCreator = request.createdBy == currentUserId;
                        
                        for (var chatDoc in chatSnapshot.data!.docs) {
                          final chatData = chatDoc.data() as Map<String, dynamic>;
                          final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                          
                          // אם זה יוצר הבקשה, נדלג על צ'אט שנמחק על ידו
                          if (isRequestCreator && deletedBy.contains(currentUserId)) {
                            debugPrint('Chat ${chatDoc.id} was deleted by request creator $currentUserId, skipping...');
                            continue; // נדלג על צ'אט שנמחק ונחפש צ'אט חדש
                          }
                          
                          // אם זה נותן השירות, נדלג על צ'אט שנמחק על ידו
                          // אבל אם מבקש השירות מחק את הצ'אט, נותן השירות יראה אותו כסגור
                          if (!isRequestCreator && deletedBy.contains(currentUserId)) {
                            debugPrint('Chat ${chatDoc.id} was deleted by service provider $currentUserId, skipping...');
                            continue; // נדלג על צ'אט שנמחק על ידי נותן השירות ונחפש צ'אט חדש
                          }
                          
                          // אם מבקש השירות מחק את הצ'אט, נותן השירות יראה אותו כסגור
                          // אבל לא נדלג עליו - נציג אותו כסגור
                          
                          // בחירת הצ'אט החדש ביותר (לפי updatedAt)
                          final updatedAt = (chatData['updatedAt'] as Timestamp?)?.toDate();
                          if (updatedAt != null) {
                            if (latestUpdatedAt == null || updatedAt.isAfter(latestUpdatedAt)) {
                              activeChat = chatDoc;
                              latestUpdatedAt = updatedAt;
                            }
                          } else if (activeChat == null) {
                            // אם אין updatedAt, נשתמש בצ'אט הראשון שלא נמחק על ידי המשתמש הנוכחי
                            activeChat = chatDoc;
                          }
                        }
                        
                        if (activeChat == null) {
                          return const SizedBox.shrink();
                        }
                        
                        final chatData = activeChat.data() as Map<String, dynamic>;
                        final isClosed = chatData['isClosed'] as bool? ?? false;
                        final activeChatId = activeChat.id;
                        
                        return Stack(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                  await playButtonSound();
                                _openChat(request.requestId);
                              },
                                icon: Icon(isClosed ? Icons.lock : Icons.chat, size: 20),
                              label: Text(isClosed ? l10nChat.chatClosedButton : l10nChat.chatButton),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isClosed ? Colors.grey : Colors.green,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                            ),
                            // ספירת הודעות חדשות
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(activeChatId)
                                  .collection('messages')
                                  .snapshots(),
                              builder: (context, messageSnapshot) {
                                if (messageSnapshot.hasData) {
                                  int unreadCount = 0;
                                  final chatId = activeChatId;
                                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                  
                                  for (var doc in messageSnapshot.data!.docs) {
                                    final messageData = doc.data() as Map<String, dynamic>;
                                    final from = messageData['from'] as String?;
                                    final readBy = messageData['readBy'] as List<dynamic>? ?? [];
                                    
                                    if (from != currentUserId) {
                                      if (AppStateService.isInChat(chatId)) {
                                        continue;
                                      }
                                      
                                      if (readBy.isEmpty || !readBy.contains(currentUserId)) {
                                        unreadCount++;
                                      }
                                    }
                                  }
                                  
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
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // תאריך פרסום הבקשה
                  Row(
                    children: [
                const Spacer(),
                Text(
                  _formatDateTime(request.createdAt),
                        style: TextStyle(
                          color: request.urgencyLevel == UrgencyLevel.emergency 
                              ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                              : Theme.of(context).textTheme.bodySmall?.color, 
                          fontSize: 12
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
          },
        );
      },
    );
  }

  /// הצגת דיאלוג למשתמש אורח שלא עדכן תחומי עיסוק
  // דיאלוג למקרה של אי התאמה בין תחומי העיסוק לקטגוריית הבקשה
  Future<void> _showCategoryMismatchDialog(String category) async {
    // המרת שם הקטגוריה לעברית
    final hebrewCategory = _getCategoryDisplayName(category);
    final l10n = AppLocalizations.of(context);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.businessFieldsNotMatch),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.requestFromCategory(hebrewCategory),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.updateBusinessFieldsHint,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // מעבר לפרופיל לעריכת תחומי עיסוק
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.editBusinessCategories),
          ),
        ],
      ),
    );
  }

  Future<void> _showGuestCategoryDialog(String category) async {
    // המרת שם הקטגוריה לעברית
    final hebrewCategory = _getCategoryDisplayName(category);
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final l10nDialog = AppLocalizations.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[700], size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10nDialog.updateBusinessFieldsTitle,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10nDialog.requestFromField(hebrewCategory),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  l10nDialog.updateFieldsToContact,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10nDialog.afterUpdateCanContact,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
            ),
          ],
        ),
        ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                // Guard context usage after async gap - check context.mounted for builder context
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: Text(l10nDialog.understood),
            ),
            ElevatedButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
                // Guard context usage after async gap - check context.mounted for builder context
                if (!context.mounted) return;
                Navigator.of(context).pop();
                // ניווט למסך פרופיל
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('עדכן פרופיל'),
            ),
          ],
        );
      },
    );
  }

  /// הצגת דיאלוג שיתוף
  void _showShareDialog(Request request) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // כותרת
            Text(
              'שתף בקשה',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            
            // כפתורי שיתוף
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // WhatsApp
                _buildShareButton(
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    ShareService.shareViaWhatsApp(request);
                  },
                ),
                
                // SMS
                _buildShareButton(
                  icon: Icons.sms,
                  label: 'SMS',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    ShareService.shareViaSMS(request);
                  },
                ),
                
                // שיתוף כללי
                _buildShareButton(
                  icon: Icons.share,
                  label: 'שיתוף',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    ShareService.shareGeneral(request);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// בניית כפתור שיתוף
  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    // בדיקה של משתנים מקומיים
    final hasLocalFilters = _selectedMainCategories.isNotEmpty ||
           _selectedSubCategories.isNotEmpty ||
           _selectedRequestType != null ||
           _selectedUrgency != null ||
           _maxDistance != null ||
           _useFixedLocationAndRadius ||
           _useMobileLocationAndRadius ||
           (_useAdditionalLocation && _additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null) ||
           _searchController.text.trim().isNotEmpty ||
           _selectedMainCategoryFromCircles != null; // ✅ כולל סינון מהעיגולים
    
    // בדיקה של FilterPreferences מ-Firestore (אם יש סינון פעיל עם התראות)
    final hasFirestoreFilters = _filterPreferencesFromFirestore != null && 
           _filterPreferencesFromFirestore!.isEnabled &&
           (_filterPreferencesFromFirestore!.categories.isNotEmpty ||
            _filterPreferencesFromFirestore!.maxRadius != null ||
            _filterPreferencesFromFirestore!.urgency != null ||
            _filterPreferencesFromFirestore!.requestType != null ||
            (_filterPreferencesFromFirestore!.useAdditionalLocation && 
             _filterPreferencesFromFirestore!.additionalLocationLatitude != null &&
             _filterPreferencesFromFirestore!.additionalLocationLongitude != null &&
             _filterPreferencesFromFirestore!.additionalLocationRadius != null));
    
    return hasLocalFilters || hasFirestoreFilters;
  }

  // בדיקה אם יש סינון פעיל לנותני שירות
  bool _hasActiveProviderFilters() {
    return _selectedMainCategoryFromCirclesForProviders != null ||
           _selectedProviderMainCategories.isNotEmpty ||
           _selectedProviderSubCategories.isNotEmpty ||
           _selectedProviderRegion != null ||
           _filterProvidersByMyLocation;
  }

  // ניקוי סינון נותני שירות
  void _clearProviderFilters() {
    if (mounted) {
      setState(() {
        _selectedMainCategoryFromCirclesForProviders = null;
        _selectedProviderMainCategories.clear();
        _selectedProviderSubCategories.clear();
        _selectedProviderRegion = null;
        _filterProvidersByMyLocation = false;
      });
    }
  }

  void _clearFilters() {
    // ניקוי מיידי של הסינון ללא דיאלוג שמירה
      _performClearFilters();
  }

  // ביצוע ניקוי הסינון
  void _performClearFilters() {
    if (mounted) {
      setState(() {
        _selectedMainCategories.clear();
        _selectedSubCategories.clear();
        _selectedRequestType = null;
        _selectedUrgency = null;
        _maxDistance = null;
        // ✅ איפוס קטגוריה ראשית מהעיגולים
        _selectedMainCategoryFromCircles = null;
        // ✅ איפוס מיקום נוסף כאשר מנקים את הסינון
        _additionalLocationLatitude = null;
        _additionalLocationLongitude = null;
        _additionalLocationRadius = null;
        _useAdditionalLocation = false;
        // ✅ איפוס מיקום קבוע ונייד
        _useFixedLocationAndRadius = false;
        _useMobileLocationAndRadius = false;
        // ✅ בטל קבלת התראות כאשר מנקים את הסינון
        _receiveNewRequests = null;
        // ✅ איפוס FilterPreferences מ-Firestore
        _filterPreferencesFromFirestore = null;
        // ✅ איפוס שדה החיפוש
        _searchController.clear();
        // ✅ עדכון מספר "בקשות פתוחות לטיפול" חזרה למספר הכולל
        _animatedOpenCount = _openRequestsCount;
        // Reload initial requests when clearing filters
        _allRequests.clear();
        _lastDocumentSnapshot = null;
        _hasMoreRequests = true;
        // Cancel all subscriptions and debounce timers
        for (final subscription in _requestSubscriptions.values) {
          subscription.cancel();
        }
        _requestSubscriptions.clear();
        // ✅ Cancel all debounce timers
        for (final timer in _debounceTimers.values) {
          timer.cancel();
        }
        _debounceTimers.clear();
        _pendingUpdates.clear();
        // ✅ Clear cache when clearing filters
        _requestCache.clear();
        // Reload initial requests - רק אם לא במסך "פניות שלי"
        if (!_showMyRequests) {
          _loadInitialRequests();
          // ✅ טען מחדש את המספר הכולל של "בקשות פתוחות לטיפול"
          _loadTotalRequestsCount();
        } else {
          // במסך "פניות שלי", נטען את כל הבקשות שהמשתמש התעניין בהן
          _loadAllInterestedRequests();
        }
      });
      
      // ✅ בטל קבלת התראות ב-Firestore כאשר מנקים את הסינון
      _disableNotificationPreferences();
      
      // ✅ בטל FilterPreferences ב-Firestore כאשר מנקים את הסינון
      _disableFilterPreferences();
      
      // ✅ נקה את הסינון השמור ב-SharedPreferences
      _clearSavedFilters();
    }
  }
  
  // ✅ בטל FilterPreferences ב-Firestore
  Future<void> _disableFilterPreferences() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // עדכון FilterPreferences ב-Firestore - הגדרת isEnabled ל-false
        await FilterPreferencesService.saveFilterPreferences(
          FilterPreferences(
            userId: uid,
            isEnabled: false,
            categories: const [],
            maxRadius: null,
            urgency: null,
            requestType: null,
            minRating: null,
            additionalLocationLatitude: null,
            additionalLocationLongitude: null,
            additionalLocationRadius: null,
            useAdditionalLocation: false,
          ),
        );
        
        // עדכון המשתנה המקומי
        if (mounted) {
          setState(() {
            _filterPreferencesFromFirestore = null;
          });
        }
        
        debugPrint('✅ Disabled filter preferences after clearing filters');
      }
    } catch (e) {
      debugPrint('❌ Failed to disable filter preferences: $e');
    }
  }
  
  // ✅ בטל קבלת התראות ב-Firestore
  Future<void> _disableNotificationPreferences() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await NotificationPreferencesService.updateNotificationPreference(
          userId: uid,
          preferenceKey: 'newRequestsUseFixedLocation',
          value: false,
        );
        await NotificationPreferencesService.updateNotificationPreference(
          userId: uid,
          preferenceKey: 'newRequestsUseMobileLocation',
          value: false,
        );
        await NotificationPreferencesService.updateNotificationPreference(
          userId: uid,
          preferenceKey: 'newRequestsUseBothLocations',
          value: false,
        );
        debugPrint('✅ Disabled notification preferences after clearing filters');
      }
    } catch (e) {
      debugPrint('❌ Failed to disable notification preferences: $e');
    }
  }


  // ✅ Safe fix: Unused method removed (no references found in codebase)
  // This method was likely replaced by the "Save Filter" button in _showAdvancedFilterDialog
  // Keeping commented for reference - can be removed if confirmed unused
  /*
  Future<void> _showSaveFilterAfterApplyDialog() async {
    bool saveFilter = false;
    bool enableNotifications = false;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('אפשרויות סינון'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // אופציה 1: שמירת סינון
                  CheckboxListTile(
                    title: const Text('שמור את הסינון לפעם הבאה'),
                    subtitle: const Text('הסינון יישמר ויוחל אוטומטית בכניסה הבאה'),
                    value: saveFilter,
                    onChanged: (value) {
                      setDialogState(() {
                        saveFilter = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  // אופציה 2: התראות
                  CheckboxListTile(
                    title: const Text('קבל התראות לבקשות חדשות'),
                    subtitle: const Text('תקבל התראה כאשר מתפרסמת בקשה חדשה המתאימה לסינון'),
                    value: enableNotifications,
                    onChanged: (value) {
                      setDialogState(() {
                        enableNotifications = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
          actions: <Widget>[
            TextButton(
                  child: Text(AppLocalizations.of(context).cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
                ElevatedButton(
                  child: const Text('המשך'),
              onPressed: () {
                Navigator.of(context).pop();
                    
                    // שמירת סינון אם נבחר
                    if (saveFilter) {
                _saveFilters();
                    }
                    
                    // הגדרת התראות אם נבחר
                    if (enableNotifications) {
                      _setupFilterNotifications();
                    }
              },
            ),
          ],
            );
          },
        );
      },
    );
  }
  */

  // הגדרת התראות לסינון
  Future<void> _setupFilterNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      // יצירת העדפות סינון
      final filterPreferences = FilterPreferences(
        userId: user.uid,
        isEnabled: true,
        categories: _getSelectedCategories(),
        maxRadius: _maxDistance,
        urgency: _selectedUrgency?.toString(),
        requestType: _selectedRequestType?.toString(),
        minRating: null, // ניתן להוסיף בעתיד
        additionalLocationLatitude: _additionalLocationLatitude,
        additionalLocationLongitude: _additionalLocationLongitude,
        additionalLocationRadius: _additionalLocationRadius,
        useAdditionalLocation: _useAdditionalLocation,
      );

      // שמירת העדפות ב-Firestore
      await FilterPreferencesService.saveFilterPreferences(filterPreferences);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 התראות הוגדרו בהצלחה! תקבל התראות לבקשות חדשות המתאימות לסינון'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      debugPrint('🔔 Filter notifications setup completed for user: ${user.uid}');
      debugPrint('🔔 Filter preferences: ${filterPreferences.toMap()}');
    } catch (e) {
      debugPrint('Error setting up filter notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהגדרת התראות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// קבלת קטגוריות נבחרות
  List<String> _getSelectedCategories() {
    List<String> categories = [];
    
    // ✅ הוספת קטגוריה ראשית מהעיגולים (אם נבחרה)
    if (_selectedMainCategoryFromCircles != null) {
      // אם יש בחירה מהעיגולים, נוסיף את כל התת-קטגוריות של הקטגוריה הזו
      final subCats = RequestCategory.values
          .where((cat) => cat.mainCategory == _selectedMainCategoryFromCircles)
          .map((c) => c.name)
          .toList();
      categories.addAll(subCats);
    }
    
    // הוספת כל התחומים הראשיים שנבחרו
    categories.addAll(_selectedMainCategories);
    
    // הוספת כל התת-תחומים שנבחרו (כשמות enum)
    categories.addAll(_selectedSubCategories.map((c) => c.name));
    
    return categories;
  }

  void _showAdvancedFilterDialog(UserProfile? userProfile) {
    bool isDialogOpen = true;
    
    // ✅ ביטול בחירה מהעיגולים כאשר פותחים את דיאלוג הסינון
    if (_selectedMainCategoryFromCircles != null) {
      setState(() {
        _selectedMainCategoryFromCircles = null;
      });
    }
    
    // ✅ טעינת requestType מ-Firestore אם יש סינון שמור ולא נטען ל-_selectedRequestType
    if (_selectedRequestType == null && _filterPreferencesFromFirestore?.isEnabled == true && _filterPreferencesFromFirestore?.requestType != null) {
      setState(() {
        _selectedRequestType = _filterPreferencesFromFirestore!.requestType == 'free' ? RequestType.free : RequestType.paid;
      });
    }
    
    showDialog(
      context: context,
      builder: (context) {
        // ✅ Safe fix: AppLocalizations.of(context) is guaranteed non-null in MaterialApp context
        final l10n = AppLocalizations.of(context);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // ✅ Removed unused dialogStateSetter variable
            
            return Material(
          child: AlertDialog(
            title: Text(l10n.advancedFilter),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // סוג בקשה - לפי סוג המשתמש
                const SizedBox(height: 8), // ✅ הוספת spacing כדי למנוע חיתוך הטקסט מלמעלה
                _buildRequestTypeFilter(userProfile, setDialogState, l10n),

        // קטגוריה - מבנה של תחום ראשי ותת-תחומים
        _buildCategoryFilter(userProfile, setDialogState, l10n),
                const SizedBox(height: 16),

                // דחיפות
                DropdownButtonFormField<UrgencyFilter?>(
                  initialValue: _selectedUrgency,
                  decoration: InputDecoration(
                    labelText: l10n.urgency,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<UrgencyFilter?>(
                      value: null,
                      child: Text(l10n.allRequests),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.normal,
                      child: Text('🕓 ${l10n.normal}'),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.urgent24h,
                      child: Text('⏰ ${l10n.within24Hours}'),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.emergency,
                      child: Text('🚨 ${l10n.now}'),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.urgentAndEmergency,
                      child: Text('⏰🚨 ${l10n.within24HoursAndNow}'),
                    ),
                  ],
                  onChanged: (value) {
                    debugPrint('🔧 Urgency filter changed to: ${value?.name ?? 'null'}');
                    setDialogState(() {
                      _selectedUrgency = value;
                    });
                  },
                ),
                const SizedBox(height: 16),


                // הודעה על טווח מקסימלי
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showRadiusInfoDialog(userProfile),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${l10n.requestRange}: 0.1-${(_currentMaxRadius ?? _maxSearchRadius).toStringAsFixed(1)} ${l10n.km}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // צ'קבוקס "השתמש במיקום הקבוע וטווח החשיפה שלי" - רק למשתמשים אורח או עסקי מנוי
                if (userProfile?.userType == UserType.guest || 
                    userProfile?.userType == UserType.business) ...[
                  Builder(
                    builder: (context) {
                      // בדיקה אם יש מיקום קבוע ורדיוס חשיפה
                      final bool hasFixedLocation = userProfile?.latitude != null && userProfile?.longitude != null;
                      final bool canUseFixedLocation = hasFixedLocation;
                      
                      final l10nCheckbox = AppLocalizations.of(context);
                      return CheckboxListTile(
                        title: Text(
                          l10nCheckbox.filterByFixedLocation,
                          style: TextStyle(
                            fontSize: 14,
                            color: canUseFixedLocation 
                                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
                                : Colors.grey,
                          ),
                        ),
                        subtitle: !canUseFixedLocation 
                            ? Text(
                                l10nCheckbox.mustDefineFixedLocation,
                                style: const TextStyle(fontSize: 12, color: Colors.orange),
                              )
                            : null,
                        value: _useFixedLocationAndRadius,
                        onChanged: canUseFixedLocation ? (value) {
                          setDialogState(() {
                            _useFixedLocationAndRadius = value ?? false;
                            if (_useFixedLocationAndRadius) {
                              // אם המשתמש מסמן - איפוס הטווח שהוגדר ידנית
                              _maxDistance = null;
                              _userLatitude = null;
                              _userLongitude = null;
                            }
                            final atLeastOne = _useFixedLocationAndRadius || _useMobileLocationAndRadius;
                            if (atLeastOne) {
                              _receiveNewRequests ??= true;
                            } else {
                              _receiveNewRequests = false;
                            }
                          });
                        } : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // צ'קבוקס מיקום נייד + סליידר טווח
                Builder(
                  builder: (context) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          title: Text(
                            AppLocalizations.of(context).filterByMobileLocation,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: _useMobileLocationAndRadius,
                          onChanged: (value) async {
                            if (!isDialogOpen) return;
                            
                            // ✅ אם המשתמש מסמן את הצ'קבוקס, בדוק אם שירות המיקום פעיל
                            if (value == true) {
                              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                              if (!serviceEnabled) {
                                // שירות המיקום לא פעיל - הצג דיאלוג
                                if (!context.mounted) return;
                                final shouldEnable = await LocationService.showEnableLocationServiceDialog(context);
                                if (!shouldEnable) {
                                  // המשתמש ביטל - לא נסמן את הצ'קבוקס
                                  return;
                                }
                                // המשתמש לחץ על "הפעל שירותי מיקום" - נפתחו הגדרות
                                // נחכה שהמשתמש יחזור ונבדוק שוב
                                return;
                              }
                            }
                            
                            setDialogState(() {
                              _useMobileLocationAndRadius = value ?? false;
                              final atLeastOne = _useFixedLocationAndRadius || _useMobileLocationAndRadius;
                              if (atLeastOne) {
                                _receiveNewRequests ??= true;
                              } else {
                                _receiveNewRequests = false;
                              }
                            });
                            if (_useMobileLocationAndRadius) {
                              try {
                                final position = await Geolocator.getCurrentPosition();
                                if (!isDialogOpen) return;
                                setDialogState(() {
                                  _userLatitude = position.latitude;
                                  _userLongitude = position.longitude;
                                  // אם לא נבחר טווח קודם, אתחל ל-0.5 ק"מ
                                  _maxDistance = _maxDistance ?? 0.5;
                                });
                                // הפעלה מחודשת של טיימר עדכון כל 30 שניות
                                _mobileLocationTimer?.cancel();
                                _mobileLocationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
                                  try {
                                    final pos = await Geolocator.getCurrentPosition();
                                    if (isDialogOpen && mounted) {
                                      // שימוש ב-setDialogState ישירות מהפונקציה
                                      setDialogState(() {
                                        _userLatitude = pos.latitude;
                                        _userLongitude = pos.longitude;
                                      });
                                    } else {
                                      // אם הדיאלוג נסגר - ביטול הטיימר
                                      _mobileLocationTimer?.cancel();
                                      _mobileLocationTimer = null;
                                    }
                                  } catch (e) {
                                    debugPrint('⚠️ Periodic mobile location update failed: $e');
                                  }
                                });
                              } catch (e) {
                                debugPrint('⚠️ Failed to get mobile location: $e');
                              }
                            } else {
                              // ביטול טיימר אם לא מסומן
                              _mobileLocationTimer?.cancel();
                              _mobileLocationTimer = null;
                            }
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_useMobileLocationAndRadius) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final l10nSlider = AppLocalizations.of(context);
                              return Row(
                                children: [
                                  const Icon(Icons.screenshot_monitor, size: 18),
                                  const SizedBox(width: 8),
                                  Text('${l10nSlider.selectRange}: ${(_maxDistance ?? 0.5).toStringAsFixed(1)} ${l10nSlider.km}'),
                                ],
                              );
                            },
                          ),
                          Slider(
                            min: 0.1,
                            max: _currentMaxRadius ?? _maxSearchRadius,
                            divisions: 49,
                            value: (_maxDistance ?? 0.5).clamp(0.1, _currentMaxRadius ?? _maxSearchRadius),
                            label: (_maxDistance ?? 0.5).toStringAsFixed(1),
                            onChanged: (val) {
                              if (!isDialogOpen) return;
                              setDialogState(() {
                                _maxDistance = double.parse(val.toStringAsFixed(1));
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),

                // ✅ צ'יקבוקס למיקום נוסף - מוצג תמיד, אבל פעיל רק אם המיקום הנוסף נבחר
                CheckboxListTile(
                  title: Text(
                    'סנן בקשות על פי המיקום הנוסף',
                    style: TextStyle(
                      fontSize: 14,
                      color: (_additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null)
                          ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
                          : Colors.grey,
                    ),
                  ),
                  subtitle: (_additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null)
                      ? Text('מיקום נבחר: ${_additionalLocationLatitude!.toStringAsFixed(4)}, ${_additionalLocationLongitude!.toStringAsFixed(4)} | טווח: ${_additionalLocationRadius!.toStringAsFixed(1)} ק"מ')
                      : Row(
                          children: [
                            Expanded(
                              child: const Text('לחץ לבחירת מיקום וטווח חשיפה נוספים'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showDistancePickerDialog(setDialogState),
                              icon: const Icon(Icons.location_searching, size: 18),
                              label: const Text('בחר מיקום'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                  value: _useAdditionalLocation,
                  onChanged: (_additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null)
                      ? (value) {
                          setDialogState(() {
                            _useAdditionalLocation = value ?? false;
                            final atLeastOne = _useFixedLocationAndRadius || _useMobileLocationAndRadius || _useAdditionalLocation;
                            if (atLeastOne) {
                              _receiveNewRequests ??= true;
                            } else {
                              _receiveNewRequests = false;
                            }
                          });
                        }
                      : null, // ✅ הצ'יקבוקס לא פעיל אם המיקום הנוסף לא נבחר
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                
                // בחירת טווח בקשות - כפתור נוסף (אופציונלי)
                if (_additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.map),
                      title: const Text('ערוך מיקום נוסף'),
                      subtitle: Text('${_additionalLocationLatitude!.toStringAsFixed(4)}, ${_additionalLocationLongitude!.toStringAsFixed(4)} | ${_additionalLocationRadius!.toStringAsFixed(1)} ק"מ'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showDistancePickerDialog(setDialogState),
                      enabled: true,
                    ),
                  ),
                ],
                      const SizedBox(height: 12),

                      // קבל התראות על בקשות חדשות
                      Builder(
                        builder: (context) {
                          // ✅ ברירת מחדל: הצ'יקבוקס מסומן (true) אם לא הוגדר אחרת
                          // רק אם המשתמש ביטל את הסימון במפורש, אז _receiveNewRequests יהיה false
                          bool enableNewReqNotifs = _receiveNewRequests ?? true;

                          final l10nNotifications = AppLocalizations.of(context);
                          return CheckboxListTile(
                            title: Text(l10nNotifications.receiveNotificationsForNewRequests),
                            value: enableNewReqNotifs,
                            onChanged: (v) {
                              setDialogState(() {
                                enableNewReqNotifs = v ?? true;
                                _receiveNewRequests = enableNewReqNotifs;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                ),
                const SizedBox(height: 24),
                // כפתורי שמירה וביטול בסוף הגלילה
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context).cancel),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                      // ✅ אם יש מקור מיקום מסומן וההתראות כבויות – שאל אישור
                      // (ברירת מחדל: הצ'יקבוקס מסומן, אז זה יקרה רק אם המשתמש ביטל את הסימון במפורש)
                      final bool atLeastOneLocation = (_useFixedLocationAndRadius || _useMobileLocationAndRadius || (_useAdditionalLocation && _additionalLocationLatitude != null && _additionalLocationLongitude != null && _additionalLocationRadius != null));
                      final bool wantsNotifications = _receiveNewRequests ?? true; // ✅ ברירת מחדל: true
                      if (atLeastOneLocation && !wantsNotifications) {
                        final proceed = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) {
                            final l10nConfirm = AppLocalizations.of(ctx);
                            return AlertDialog(
                              title: Text(l10nConfirm.actionConfirmation),
                              content: Text(l10nConfirm.noNotificationsSelected),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(l10nConfirm.no),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: Text(l10nConfirm.yes),
                    ),
                              ],
                  );
                          },
                        );
                        if (proceed != true) {
                          // חזרה לסינון בקשות ללא שמירה
                  return;
                }
                      }
                      
                      // ✅ בדיקה אם הצ'קבוקס "קבל התראות" מסומן - בדוק הרשאות התראות
                      if (wantsNotifications) {
                        final hasPermission = await PermissionService.checkNotificationPermission();
                        if (!hasPermission) {
                          // אין הרשאות התראות - הצג דיאלוג
                          final shouldRequest = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) {
                              final l10n = AppLocalizations.of(ctx);
                              return AlertDialog(
                                title: Text(l10n.actionConfirmation),
                                content: Text(
                                  l10n.notificationPermissionRequiredForFilter,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: Text(l10n.cancel),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: Text('אשר'),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (shouldRequest == true) {
                            // המשתמש רוצה לאשר - בקש הרשאות
                            final granted = await PermissionService.requestNotificationPermission(context);
                            if (!granted) {
                              // המשתמש לא נתן הרשאות - עדכן את הצ'קבוקס לכבוי
                              setDialogState(() {
                                _receiveNewRequests = false;
                              });
                              // הצג הודעה שההתראות לא יופעלו
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('התראות לא הופעלו - נדרשות הרשאות התראות'),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                              return; // לא לשמור את הסינון עם התראות
                            }
                          } else {
                            // המשתמש לא רוצה לאשר - עדכן את הצ'קבוקס לכבוי
                            setDialogState(() {
                              _receiveNewRequests = false;
                            });
                            return; // לא לשמור את הסינון עם התראות
                          }
                        }
                      }
                      // שמירת הסינון + עדכון העדפות התראות לבקשות חדשות
                      if (mounted) {
                  setState(() {
                        // ✅ שמור את הבחירה של צ'קבוקס ההתראות לפני השמירה
                        // ברירת מחדל: true (אם לא הוגדר אחרת)
                        _receiveNewRequests = _receiveNewRequests ?? true;
                        // ✅ ביטול בחירה מהעיגולים כאשר שומרים סינון
                        _selectedMainCategoryFromCircles = null;
                      });
                      }
                      await _saveFilters();

                      // ✅ שמירת סינון ב-Firestore אם יש סינון פעיל והצ'יקבוקס "קבל התראות" מסומן
                      final hasActiveFilter = _hasActiveFilters();
                      final wantsFilterNotifications = _receiveNewRequests ?? true;
                      if (hasActiveFilter && wantsFilterNotifications) {
                        await _setupFilterNotifications();
                        // ✅ טעינה מחדש של FilterPreferences מ-Firestore לאחר שמירה
                        await _loadFilterPreferencesFromFirestore();
                      }

                      try {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          // ✅ החלטת העדפות לפי הצ'קבוקס והשילוב של מקורות המיקום
                          // ברירת מחדל: true (אם לא הוגדר אחרת)
                          final enable = (_receiveNewRequests ?? true) && atLeastOneLocation;

                          if (!enable) {
                            await NotificationPreferencesService.updateNotificationPreference(
                              userId: uid,
                              preferenceKey: 'newRequestsUseFixedLocation',
                              value: false,
                            );
                            await NotificationPreferencesService.updateNotificationPreference(
                              userId: uid,
                              preferenceKey: 'newRequestsUseMobileLocation',
                              value: false,
                            );
                            await NotificationPreferencesService.updateNotificationPreference(
                              userId: uid,
                              preferenceKey: 'newRequestsUseBothLocations',
                              value: false,
                            );
                            
                            // ✅ שמירת העדפות ב-SharedPreferences גם כאשר enable = false
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('user_use_mobile_location', false);
                            await prefs.setBool('user_use_both_locations', false);
                            debugPrint('✅ Saved mobile location preferences to SharedPreferences (disabled): useMobile=false, useBoth=false');
                          } else {
                            final useFixed = _useFixedLocationAndRadius;
                            final useMobile = _useMobileLocationAndRadius;
                            final useBoth = useFixed && useMobile;
                            await NotificationPreferencesService.updateNotificationPreference(
                              userId: uid,
                              preferenceKey: 'newRequestsUseFixedLocation',
                              value: useBoth ? false : useFixed,
                            );
                            await NotificationPreferencesService.updateNotificationPreference(
                              userId: uid,
                              preferenceKey: 'newRequestsUseMobileLocation',
                              value: useBoth ? false : useMobile,
                            );
                            await NotificationPreferencesService.updateNotificationPreference(
                              userId: uid,
                              preferenceKey: 'newRequestsUseBothLocations',
                              value: useBoth,
                            );
                            
                            // ✅ שמירת העדפות ב-SharedPreferences כדי שנוכל לבדוק אותן ב-WorkManager/BroadcastReceiver
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('user_use_mobile_location', useBoth ? false : useMobile);
                            await prefs.setBool('user_use_both_locations', useBoth);
                            debugPrint('✅ Saved mobile location preferences to SharedPreferences: useMobile=$useMobile, useBoth=$useBoth');
                          }
                        }
                      } catch (e) {
                        debugPrint('❌ Failed updating new-requests notification prefs: $e');
                      }

                      // Guard context usage after async gap - check context.mounted for builder context
                      if (!context.mounted) return;
                Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.filterSaved),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      },
                      child: Text(l10n.saveFilter),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
          ),
        );
          },
        );
      },
    ).then((_) {
      // כשהדיאלוג נסגר - ביטול הטיימר
      isDialogOpen = false;
      _mobileLocationTimer?.cancel();
      _mobileLocationTimer = null;
    });
  }

  // פונקציה לבניית סינון סוג בקשה
  Widget _buildRequestTypeFilter(UserProfile? userProfile, StateSetter setDialogState, AppLocalizations l10n) {
    // בדיקה אם המשתמש לא נותן שירותים בתשלום
    bool noPaidServices = userProfile?.noPaidServices ?? false;
    
    // כל משתמש מסוג "פרטי" (פרטי חינם או פרטי מנוי) יראה רק "חינמי"
    bool isPersonalUser = userProfile?.userType == UserType.personal;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RequestType?>(
          initialValue: (noPaidServices || isPersonalUser) ? RequestType.free : _selectedRequestType,
          decoration: InputDecoration(
            labelText: l10n.requestType,
            border: const OutlineInputBorder(),
          ),
          items: (noPaidServices || isPersonalUser) ? [
            // משתמש שלא נותן שירותים בתשלום או משתמש פרטי - רק בקשות חינמיות
            DropdownMenuItem<RequestType?>(
              value: RequestType.free,
              child: Text(l10n.freeType),
            ),
          ] : [
            // "כל הסוגים" זמין לכל סוגי המשתמשים
            DropdownMenuItem<RequestType?>(
              value: null,
              child: Text(l10n.allTypes),
            ),
            ...RequestType.values.map((type) => DropdownMenuItem(
              value: type,
              child: Text(type.typeDisplayName(l10n)),
            )),
          ],
          onChanged: (noPaidServices || isPersonalUser) ? null : (value) {
            setDialogState(() {
              _selectedRequestType = value;
              // איפוס הקטגוריות כאשר משנים את סוג הבקשה
              _selectedMainCategories.clear();
              _selectedSubCategories.clear();
            });
          },
        ),
        if (noPaidServices || isPersonalUser) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.noPaidServicesMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // פונקציה לבדיקה אם קטגוריה שייכת לתחום ראשי
  bool _isCategoryInMainCategory(RequestCategory category, String mainCategory) {
    // מציאת התחום הראשי של הקטגוריה
    MainCategory categoryMainCategory = category.mainCategory;
    
    // השוואה עם השם המוצג של התחום הראשי
    return categoryMainCategory.displayName == mainCategory;
  }

  // פונקציה לבדיקה אם תאריך היעד של בקשה פג תוקף
  bool _isRequestDeadlineExpired(Request request) {
    if (request.deadline == null) return false;
    return DateTime.now().isAfter(request.deadline!);
  }

  // פונקציה לבניית סינון קטגוריות - בחירה מרובה
  Widget _buildCategoryFilter(UserProfile? userProfile, StateSetter setDialogState, AppLocalizations l10n) {
    // לוגיקה פשוטה - כל המשתמשים יכולים לראות את כל הקטגוריות
    List<String> availableMainCategories = [];
      for (MainCategory mainCategory in MainCategory.values) {
        availableMainCategories.add(mainCategory.displayName);
      }
      
      // הגדרת קטגוריות לפי התחומים הראשיים
    Map<String, List<RequestCategory>> subCategories = {};
      for (MainCategory mainCategory in MainCategory.values) {
        List<RequestCategory> categories = [];
      for (RequestCategory category in RequestCategory.values) {
          if (category.mainCategory == mainCategory) {
            categories.add(category);
          }
        }
        subCategories[mainCategory.displayName] = categories;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // כותרת עם כפתור ניקוי
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.mainCategory,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            if (_selectedMainCategories.isNotEmpty || _selectedSubCategories.isNotEmpty)
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _selectedMainCategories.clear();
                    _selectedSubCategories.clear();
                  });
                },
                child: Text(
                  'נקה בחירה',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // רשימת תחומים ראשיים עם תת-תחומים מתחתיהם
        // ללא Container עם SingleChildScrollView פנימי - הגלילה תהיה חלק מהגלילה הראשית
        Column(
          children: availableMainCategories.map((mainCategory) {
                final isMainSelected = _selectedMainCategories.contains(mainCategory);
                final mainCategorySubCategories = subCategories[mainCategory] ?? [];
                // מצא את ה-MainCategory enum המתאים
                final mainCategoryEnum = MainCategory.values.firstWhere(
                  (cat) => cat.displayName == mainCategory,
                  orElse: () => MainCategory.values.first,
                );
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // תחום ראשי
                    CheckboxListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              mainCategory,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          // אייקון הקטגוריה מצד ימין
                          Text(
                            mainCategoryEnum.icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                      value: isMainSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            _selectedMainCategories.add(mainCategory);
                          } else {
                            _selectedMainCategories.remove(mainCategory);
                            // אם מסירים תחום ראשי, מסירים גם את כל התת-תחומים שלו
                            _selectedSubCategories.removeWhere((cat) => 
                              mainCategorySubCategories.contains(cat));
                          }
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    // תת-תחומים מתחת לתחום הראשי (מוצגים רק אם התחום הראשי נבחר)
                    if (isMainSelected && mainCategorySubCategories.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 40, left: 16),
                        child: Column(
                          children: mainCategorySubCategories.map((category) {
                            final isSubSelected = _selectedSubCategories.contains(category);
                            return CheckboxListTile(
                              title: Text(
                                category.categoryDisplayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                              value: isSubSelected,
                              onChanged: (bool? value) {
                                setDialogState(() {
                                  if (value == true) {
                                    _selectedSubCategories.add(category);
                                  } else {
                                    _selectedSubCategories.remove(category);
                                  }
                                });
                              },
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              }).toList(),
        ),
      ],
    );
  }

  // פונקציות להצגת סטטוס הבקשה - כמו במסך "בקשות שלי"
  // בניית שורת עיגולי קטגוריות
  // פונקציה לבניית שורת עיגולי קטגוריות לנותני שירות
  Widget _buildCategoryCirclesRowForProviders() {
    final allCategories = MainCategory.values;
    
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = _selectedMainCategoryFromCirclesForProviders == category;
          
          return GestureDetector(
            onTap: () async {
              await playButtonSound();
              final newSelectedCategory = _selectedMainCategoryFromCirclesForProviders == category 
                  ? null 
                  : category;
              
              debugPrint('🔵 [PROVIDERS CIRCLES] Category selected: ${newSelectedCategory?.name ?? "none"}');
              
              setState(() {
                _selectedMainCategoryFromCirclesForProviders = newSelectedCategory;
              });
            },
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.white,
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCirclesRow() {
    final allCategories = MainCategory.values;
    
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allCategories.length,
        itemBuilder: (context, index) {
          final category = allCategories[index];
          final isSelected = _selectedMainCategoryFromCircles == category;
          
          return GestureDetector(
            onTap: () async {
              await playButtonSound();
              final newSelectedCategory = _selectedMainCategoryFromCircles == category 
                  ? null 
                  : category;
              
              debugPrint('🔵 [CIRCLES] Category selected: ${newSelectedCategory?.name ?? "none"}');
              
              setState(() {
                // שמור את הקטגוריה החדשה
                _selectedMainCategoryFromCircles = newSelectedCategory;
                debugPrint('🔵 [CIRCLES] _selectedMainCategoryFromCircles set to: ${_selectedMainCategoryFromCircles?.name ?? "null"}');
                
                // נקה את שאר הסינונים (אבל לא את הקטגוריה מהעיגולים)
                _selectedMainCategories.clear();
                _selectedSubCategories.clear();
                _selectedRequestType = null;
                _selectedUrgency = null;
                _maxDistance = null;
                _additionalLocationLatitude = null;
                _additionalLocationLongitude = null;
                _additionalLocationRadius = null;
                _useAdditionalLocation = false;
                _useFixedLocationAndRadius = false;
                _useMobileLocationAndRadius = false;
                
                // נקה את המטמון והטען מחדש את הבקשות
                _allRequests.clear();
                _requestCache.clear();
                _lastDocumentSnapshot = null;
                _isLoadingInitial = false;
                _isLoadingMore = false;
                _hasMoreRequests = true;
                
                debugPrint('🔵 [CIRCLES] Cleared cache, loading requests with filter: ${newSelectedCategory?.name ?? "none"}');
                
                // טען מחדש את הבקשות
                _loadInitialRequests();
              });
              
              // ✅ הצגת הודעת מערכת אם נבחרה קטגוריה
              if (newSelectedCategory != null && mounted) {
                final l10n = AppLocalizations.of(context);
                final categoryName = newSelectedCategory.displayName;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.allRequestsFromCategory(categoryName)),
                    duration: const Duration(seconds: 3),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.white,
                border: Border.all(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          );
        },
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

  String _getStatusText(RequestStatus status, AppLocalizations l10n) {
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

  // כרטיס skeleton לטעינת נותן שירות
  // טעינת שירותים עסקיים עבור משתמש מסוים
  Future<List<Map<String, dynamic>>> _loadBusinessServicesForProvider(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return [];
      
      final userData = userDoc.data()!;
      final services = userData['businessServices'] as List<dynamic>?;
      
      if (services == null) return [];
      
      return services.map((s) => s as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error loading business services for provider $userId: $e');
      return [];
    }
  }

  // טעינת שדות משלוח ותור עבור משתמש מסוים
  Future<Map<String, bool>> _loadProviderServiceSettings(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        return {'requiresAppointment': false, 'requiresDelivery': false};
      }
      
      final userData = userDoc.data()!;
      return {
        'requiresAppointment': userData['requiresAppointment'] as bool? ?? false,
        'requiresDelivery': userData['requiresDelivery'] as bool? ?? false,
      };
    } catch (e) {
      debugPrint('Error loading provider service settings for $userId: $e');
      return {'requiresAppointment': false, 'requiresDelivery': false};
    }
  }

  // טעינת הגדרות תורים עבור משתמש מסוים
  Future<AppointmentSettings?> _loadAppointmentSettings(String userId) async {
    try {
      final appointmentsDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(userId)
          .get();
      
      if (!appointmentsDoc.exists) {
        return null;
      }
      
      return AppointmentSettings.fromFirestore(appointmentsDoc);
    } catch (e) {
      debugPrint('Error loading appointment settings for $userId: $e');
      return null;
    }
  }

  Widget _buildServiceProviderSkeletonCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 14,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 12,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 12,
              color: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  // המרת DateTime.weekday ל-DayOfWeek enum index
  // DateTime.weekday: 1=שני, 2=שלישי, ..., 7=ראשון
  // DayOfWeek index: 0=ראשון, 1=שני, ..., 6=שבת
  int _convertWeekdayToDayOfWeekIndex(int weekday) {
    // אם זה ראשון (7), מחזיר 0
    // אחרת מחזיר weekday כמו שהוא (1=שני->1, 2=שלישי->2, וכו')
    return weekday == 7 ? 0 : weekday;
  }

  // בדיקה אם העסק פתוח כרגע
  Future<bool> _isProviderOpenNow(String userId) async {
    try {
      final now = DateTime.now();
      final currentDayOfWeek = _convertWeekdayToDayOfWeekIndex(now.weekday); // 0 = ראשון, 1 = שני, ..., 6 = שבת
      final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // טעינת נתוני המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      
      // בדיקה אם זמין כל השבוע
      final availableAllWeek = userData['availableAllWeek'] as bool? ?? false;
      if (availableAllWeek) {
        return true;
      }
      
      // בדיקה אם משתמש בתורים או זמינות
      final appointmentsDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(userId)
          .get();
      
      final useAppointments = appointmentsDoc.exists 
          ? (appointmentsDoc.data()?['useAppointments'] as bool? ?? false)
          : false;
      
      if (useAppointments) {
        // בדיקה לפי תורים
        final slots = (appointmentsDoc.data()?['slots'] as List<dynamic>?)
            ?.map((e) => AppointmentSlot.fromMap(e as Map<String, dynamic>))
            .toList() ?? [];
        
        final todaySlot = slots.firstWhere(
          (slot) => slot.dayOfWeek == currentDayOfWeek,
          orElse: () => AppointmentSlot(
            dayOfWeek: currentDayOfWeek,
            startTime: '00:00',
            endTime: '00:00',
            durationMinutes: 30,
          ),
        );
        
        // בדיקה אם השעה הנוכחית בתוך שעות העבודה
        if (!_isTimeInRange(currentTimeStr, todaySlot.startTime, todaySlot.endTime)) {
          return false;
        }
        
        // בדיקה אם השעה הנוכחית בתוך הפסקה
        for (final breakTime in todaySlot.breaks) {
          if (_isTimeInRange(currentTimeStr, breakTime.startTime, breakTime.endTime)) {
            return false; // בתוך הפסקה = סגור
          }
        }
        
        return true;
      } else {
        // בדיקה לפי זמינות
        final weekAvailabilityData = userData['weekAvailability'] as List<dynamic>?;
        if (weekAvailabilityData == null || weekAvailabilityData.isEmpty) {
          return false;
        }
        
        final weekAvailability = WeekAvailability.fromFirestore(weekAvailabilityData);
        final todayAvailability = weekAvailability.days.firstWhere(
          (day) => day.day.index == currentDayOfWeek,
          orElse: () => DayAvailability(day: DayOfWeek.values[currentDayOfWeek], isAvailable: false),
        );
        
        if (!todayAvailability.isAvailable) {
          return false;
        }
        
        // בדיקה אם השעה הנוכחית בתוך שעות העבודה
        if (todayAvailability.startTime != null && todayAvailability.endTime != null) {
          return _isTimeInRange(
            currentTimeStr,
            todayAvailability.startTime!,
            todayAvailability.endTime!,
          );
        }
        
        return todayAvailability.isAvailable;
      }
    } catch (e) {
      debugPrint('Error checking if provider is open: $e');
      return false;
    }
  }

  // בדיקה אם שעה נמצאת בטווח זמן
  bool _isTimeInRange(String timeStr, String startTime, String endTime) {
    try {
      final time = _parseTimeString(timeStr);
      final start = _parseTimeString(startTime);
      final end = _parseTimeString(endTime);
      
      // אם שעת הסיום קטנה משעת ההתחלה, זה אומר שהטווח עובר את חצות הלילה
      if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
        return time.isAfter(start) || time.isBefore(end) || time.isAtSameMomentAs(start) || time.isAtSameMomentAs(end);
      }
      
      return (time.isAfter(start) || time.isAtSameMomentAs(start)) &&
             (time.isBefore(end) || time.isAtSameMomentAs(end));
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return false;
    }
  }

  // המרת מחרוזת זמן ל-DateTime (עם תאריך בסיס)
  DateTime _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  // כרטיס להצגת נותן שירות
  Widget _buildServiceProviderCard(UserProfile provider, AppLocalizations l10n) {
    final region = getGeographicRegion(provider.latitude ?? provider.mobileLatitude);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Stack(
        children: [
          // תצוגת פתוח/סגור בפינה השמאלית העליונה
          Positioned(
            top: 8,
            left: 8,
            child: FutureBuilder<bool>(
              future: _isProviderOpenNow(provider.userId),
              builder: (context, snapshot) {
                final isOpen = snapshot.data ?? false;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpen ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? 'פתוח' : 'סגור',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // שם העסק
                Row(
                  children: [
                // תמונת פרופיל או אייקון
                CircleAvatar(
                  radius: 30,
                  backgroundImage: provider.profileImageUrl != null 
                      ? NetworkImage(provider.profileImageUrl!) 
                      : null,
                  child: provider.profileImageUrl == null 
                      ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // מספר טלפון מתחת לשם העסק
                      if (provider.phoneNumber != null && provider.allowPhoneDisplay == true) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _makePhoneCall(provider.phoneNumber!),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.blue[600]),
                              const SizedBox(width: 4),
                              Text(
                                provider.phoneNumber!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // מיקום אחרי מספר הטלפון
                      if (provider.village != null || (provider.latitude != null && provider.longitude != null)) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            if (provider.latitude != null && provider.longitude != null) {
                              _showProviderLocationDialog(context, provider);
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on, 
                                size: 14, 
                                color: provider.latitude != null && provider.longitude != null
                                    ? Colors.green[600]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  provider.village ?? 
                                  (provider.latitude != null && provider.longitude != null
                                      ? '${provider.latitude!.toStringAsFixed(4)}, ${provider.longitude!.toStringAsFixed(4)}'
                                      : ''),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: provider.latitude != null && provider.longitude != null
                                        ? Colors.green[700]
                                        : Colors.grey[600],
                                    decoration: provider.latitude != null && provider.longitude != null
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // איזור מתחת למיקום
                      if (provider.village != null || (provider.latitude != null && provider.longitude != null)) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              region.getDisplayNameHebrew(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // תחומי עיסוק
            if (provider.businessCategories != null && provider.businessCategories!.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.businessCategories!.map((category) {
                  return Chip(
                    label: Text(category.categoryDisplayName),
                    backgroundColor: Colors.blue[50],
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            
            // שירותים עסקיים (רק אם זה לא שליח)
            // שליחים לא צריכים שירותים - הם מוגדרים לפי תחומי העיסוק בלבד
            if (provider.userType == UserType.business && provider.isSubscriptionActive) ...[
              Builder(
                builder: (context) {
                  // בדיקה אם המשתמש הוא שליח (יש לו קטגוריות של שליחויות)
                  final courierCategories = [
                    RequestCategory.foodDelivery,
                    RequestCategory.groceryDelivery,
                    RequestCategory.smallMoving,
                    RequestCategory.largeMoving,
                  ];
                  
                  final isCourier = provider.businessCategories?.any((cat) =>
                      courierCategories.any((c) => c.name == cat.name)) ?? false;
                  
                  // אם זה שליח, לא להציג שירותים
                  if (isCourier) {
                    return const SizedBox.shrink();
                  }
                  
                  // אם זה לא שליח, להציג שירותים כרגיל
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadBusinessServicesForProvider(provider.userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      
                      final allServices = snapshot.data ?? [];
                      // סינון רק שירותים זמינים
                      final services = allServices.where((service) {
                        return service['isAvailable'] as bool? ?? true; // ברירת מחדל זמין
                      }).toList();
                      
                      if (services.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.business_center, size: 16, color: Colors.green[600]),
                              const SizedBox(width: 8),
                              Text(
                                'שירותים:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: services.take(5).map((service) {
                              final name = service['name'] as String? ?? '';
                              final price = service['price'] as double?;
                              final isCustomPrice = service['isCustomPrice'] as bool? ?? false;
                              final priceText = isCustomPrice 
                                  ? 'בהתאמה אישית'
                                  : price != null 
                                      ? '₪${price.toStringAsFixed(0)}'
                                      : '';
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (priceText.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        priceText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          if (services.length > 5) ...[
                            const SizedBox(height: 4),
                            Text(
                              '+${services.length - 5} שירותים נוספים',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ],
            
            // הצגת משלוחים/תור (לכל המשתמשים העסקיים, כולל שליחים)
            if (provider.userType == UserType.business && provider.isSubscriptionActive) ...[
              FutureBuilder<Map<String, bool>>(
                future: _loadProviderServiceSettings(provider.userId),
                builder: (context, settingsSnapshot) {
                  if (settingsSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  
                  final requiresDelivery = settingsSnapshot.data?['requiresDelivery'] ?? false;
                  final requiresAppointment = settingsSnapshot.data?['requiresAppointment'] ?? false;
                  
                  if (!requiresDelivery && !requiresAppointment) {
                    return const SizedBox.shrink();
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (requiresDelivery) ...[
                        Row(
                          children: [
                            Icon(Icons.local_shipping, size: 16, color: Colors.blue[600]),
                            const SizedBox(width: 8),
                            Text(
                              'זמין במשלוחים',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (requiresAppointment) ...[
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.orange[600]),
                            const SizedBox(width: 8),
                            Text(
                              'יש לקבוע תור',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            
            const SizedBox(height: 12),
            
            // לחצן "הזמן עכשיו" - מוצג רק אם יש שירותים עסקיים
            if (provider.userType == UserType.business && provider.isSubscriptionActive) ...[
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _loadBusinessServicesForProvider(provider.userId),
                builder: (context, servicesSnapshot) {
                  final hasServices = servicesSnapshot.data?.isNotEmpty ?? false;
                  if (!hasServices) {
                    return const SizedBox.shrink();
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showOrderDialog(context, provider),
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text('הזמן עכשיו'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            
            // זמינות / תורים
            FutureBuilder<AppointmentSettings?>(
              future: _loadAppointmentSettings(provider.userId),
              builder: (context, appointmentsSnapshot) {
                final appointmentSettings = appointmentsSnapshot.data;
                final useAppointments = appointmentSettings?.useAppointments ?? false;
                
                // אם משתמש בתורים - הצג תורים
                if (useAppointments && appointmentSettings != null && appointmentSettings.slots.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Text(
                            'תורים:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...appointmentSettings.slots.map((slot) {
                        const days = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];
                        final dayName = days[slot.dayOfWeek];
                        final timeText = '${slot.startTime} - ${slot.endTime}';
                        final breaksText = slot.breaks.isNotEmpty
                            ? ' (הפסקות: ${slot.breaks.map((b) => '${b.startTime}-${b.endTime}').join(', ')})'
                            : '';
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 24),
                              Expanded(
                                child: Text(
                                  '$dayName: $timeText$breaksText',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                
                // אחרת - הצג זמינות רגילה
                if (provider.availableAllWeek == true) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.green[600]),
                          const SizedBox(width: 8),
                          Text(
                            'זמין כל השבוע',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                } else if (provider.weekAvailability != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'זמינות:',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...provider.weekAvailability!.days
                          .where((day) => day.isAvailable)
                          .map((day) {
                        final timeText = day.startTime != null && day.endTime != null
                            ? '${day.startTime} - ${day.endTime}'
                            : day.startTime != null
                                ? 'מ-${day.startTime}'
                                : day.endTime != null
                                    ? 'עד ${day.endTime}'
                                    : 'כל היום';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 24),
                              Text(
                                '${day.day.displayName}: $timeText',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
            
            // דירוגים
            if (provider.averageRating != null || provider.reliability != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              if (provider.averageRating != null) ...[
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'דירוג ממוצע: ${provider.averageRating!.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (provider.reliability != null) ...[
                Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'אמינות: ${provider.reliability!.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (provider.availability != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'זמינות: ${provider.availability!.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (provider.attitude != null) ...[
                Row(
                  children: [
                    Icon(Icons.sentiment_satisfied, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'יחס: ${provider.attitude!.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (provider.fairPrice != null) ...[
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'מחיר הוגן: ${provider.fairPrice!.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
            
            // תאריך הצטרפות
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'תאריך הצטרפות: ${_formatDate(provider.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // דיאלוג הזמנה
  Future<void> _showOrderDialog(BuildContext context, UserProfile provider) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // טעינת פרטי המשתמש הנוכחי
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists) return;
    
    final userData = userDoc.data()!;
    final userName = userData['displayName'] ?? userData['name'] ?? currentUser.email ?? 'משתמש';
    final userPhone = userData['phoneNumber'] as String? ?? '';

    // טעינת שירותים של נותן השירות - רק זמינים
    final allServices = await _loadBusinessServicesForProvider(provider.userId);
    final services = allServices.where((service) {
      return service['isAvailable'] as bool? ?? true; // ברירת מחדל זמין
    }).toList();
    
    if (services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא נמצאו שירותים זמינים')),
      );
      return;
    }

    // טעינת הגדרות שירות (משלוח)
    final serviceSettings = await _loadProviderServiceSettings(provider.userId);
    final requiresDelivery = serviceSettings['requiresDelivery'] ?? false;

    // משתנים לדיאלוג - שינוי לוגיקה: שירות -> כמות -> מרכיבים
    // List<Map> - כל הזמנה היא ייחודית, גם אם זה אותו שירות
    final List<Map<String, dynamic>> selectedServices = [];
    final List<int> nextServiceId = [0]; // מונה ייחודי לכל הזמנה - List כדי שיהיה mutable
    String? deliveryType; // 'pickup' או 'delivery'
    String? selectedDeliveryCategory; // קטגוריית משלוח (foodDelivery, groceryDelivery, smallMoving, largeMoving)
    Map<String, dynamic>? selectedLocation; // {latitude, longitude, address}
    String? paymentType; // 'cash', 'bit', 'credit'

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // חישוב מחיר לפי המבנה החדש
          double recalculatedTotalPrice = 0.0;
          bool hasSelectedItems = selectedServices.isNotEmpty;
          
          for (final serviceData in selectedServices) {
            final serviceName = serviceData['serviceName'] as String? ?? '';
            final quantity = serviceData['quantity'] as int? ?? 0;
            final service = services.firstWhere((s) => s['name'] == serviceName, orElse: () => {});
            
            if (quantity > 0 && service.isNotEmpty) {
              final isCustomPrice = service['isCustomPrice'] as bool? ?? false;
              if (!isCustomPrice) {
                final price = (service['price'] as num?)?.toDouble() ?? 0.0;
                recalculatedTotalPrice += price * quantity;
                
                // הוספת מחיר מרכיבים
                final selectedIngredients = serviceData['ingredients'] as List<String>? ?? [];
                final ingredients = service['ingredients'] as List<dynamic>? ?? [];
                for (final ingredientName in selectedIngredients) {
                  final ingredient = ingredients.firstWhere(
                    (ing) => (ing['name'] as String?) == ingredientName,
                    orElse: () => {},
                  );
                  if (ingredient.isNotEmpty) {
                    final ingredientCost = (ingredient['cost'] as num?)?.toDouble() ?? 0.0;
                    recalculatedTotalPrice += ingredientCost * quantity;
                  }
                }
              }
            }
          }

          return AlertDialog(
            title: const Text('הזמנה'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // שם העסק
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // שם המשתמש
                  TextField(
                    enabled: false,
                    controller: TextEditingController(text: userName),
                    decoration: const InputDecoration(
                      labelText: 'שם',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // מספר טלפון
                  TextField(
                    enabled: false,
                    controller: TextEditingController(text: userPhone),
                    decoration: const InputDecoration(
                      labelText: 'מספר טלפון',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // בחירת שירותים
                  const Text(
                    'שירותים:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // רשימת שירותים שנבחרו
                  ...selectedServices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final serviceData = entry.value;
                    final serviceName = serviceData['serviceName'] as String? ?? '';
                    final quantity = serviceData['quantity'] as int? ?? 0;
                    final selectedIngredients = serviceData['ingredients'] as List<String>? ?? [];
                    final service = services.firstWhere((s) => s['name'] == serviceName, orElse: () => {});
                    final price = (service['price'] as num?)?.toDouble();
                    final isCustomPrice = service['isCustomPrice'] as bool? ?? false;
                    final ingredients = service['ingredients'] as List<dynamic>? ?? [];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    serviceName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (price != null && !isCustomPrice)
                                  Text('₪${price.toStringAsFixed(0)}'),
                                if (isCustomPrice)
                                  const Text('בהתאמה אישית', style: TextStyle(fontSize: 12)),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedServices.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setDialogState(() {
                                      if (quantity > 1) {
                                        serviceData['quantity'] = quantity - 1;
                                      } else {
                                        selectedServices.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Text('${quantity}'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setDialogState(() {
                                      serviceData['quantity'] = (quantity + 1);
                                    });
                                  },
                                ),
                              ],
                            ),
                            // בחירת מרכיבים
                            if (ingredients.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'בחר מרכיבים:',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: ingredients.map((ingredient) {
                                  final ingredientName = ingredient['name'] as String? ?? '';
                                  final ingredientCost = (ingredient['cost'] as num?)?.toDouble() ?? 0.0;
                                  final isSelected = selectedIngredients.contains(ingredientName);
                                  
                                  return FilterChip(
                                    label: Text('$ingredientName${ingredientCost > 0 ? ' (+₪${ingredientCost.toStringAsFixed(0)})' : ''}'),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          if (!selectedIngredients.contains(ingredientName)) {
                                            selectedIngredients.add(ingredientName);
                                          }
                                        } else {
                                          selectedIngredients.remove(ingredientName);
                                        }
                                        serviceData['ingredients'] = selectedIngredients;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  
                  // כפתור להוספת שירות חדש
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'הוסף שירות',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add),
                    ),
                    items: services.map((service) {
                      final serviceName = service['name'] as String;
                      final price = (service['price'] as num?)?.toDouble();
                      final isCustomPrice = service['isCustomPrice'] as bool? ?? false;
                      final displayText = isCustomPrice 
                          ? '$serviceName (בהתאמה אישית)'
                          : price != null
                              ? '$serviceName - ₪${price.toStringAsFixed(0)}'
                              : serviceName;
                      
                      return DropdownMenuItem(
                        value: serviceName,
                        child: Text(displayText),
                      );
                    }).toList(),
                    onChanged: (selectedServiceName) {
                      if (selectedServiceName != null) {
                        setDialogState(() {
                          // תמיד מוסיף הזמנה חדשה, גם אם השירות כבר קיים
                          // כך אפשר להזמין אותו שירות עם מרכיבים שונים
                          selectedServices.add({
                            'id': nextServiceId[0]++,
                            'serviceName': selectedServiceName,
                            'quantity': 1,
                            'ingredients': <String>[],
                          });
                        });
                      }
                    },
                  ),
                  
                  // סך הכל מחיר
                  if (recalculatedTotalPrice > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'סך הכל:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₪${recalculatedTotalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // בחירת משלוח/איסוף (אם יש שירות עם משלוח)
                  if (hasSelectedItems && requiresDelivery) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'סוג שירות:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text('איסוף עצמי'),
                      value: 'pickup',
                      groupValue: deliveryType,
                      onChanged: (value) {
                        setDialogState(() {
                          deliveryType = value;
                          selectedLocation = null; // איפוס מיקום אם בוחרים איסוף עצמי
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('משלוח באמצעות שליח'),
                      value: 'delivery',
                      groupValue: deliveryType,
                      onChanged: (value) {
                        setDialogState(() {
                          deliveryType = value;
                          selectedDeliveryCategory = null; // איפוס בחירת תחום
                        });
                      },
                    ),
                    
                    // בחירת תחום משלוח (אם בחר משלוח)
                    if (deliveryType == 'delivery') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'בחר תחום משלוח:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        title: const Text('משלוחי אוכל'),
                        value: 'foodDelivery',
                        groupValue: selectedDeliveryCategory,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDeliveryCategory = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('משלוחי קניות מהסופר'),
                        value: 'groceryDelivery',
                        groupValue: selectedDeliveryCategory,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDeliveryCategory = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('הובלות קטנות'),
                        value: 'smallMoving',
                        groupValue: selectedDeliveryCategory,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDeliveryCategory = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('הובלות גדולות'),
                        value: 'largeMoving',
                        groupValue: selectedDeliveryCategory,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDeliveryCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LocationPickerScreen(),
                            ),
                          );
                          
                          if (result != null) {
                            setDialogState(() {
                              selectedLocation = {
                                'latitude': result['latitude'],
                                'longitude': result['longitude'],
                                'address': result['address'],
                              };
                            });
                          }
                        },
                        icon: const Icon(Icons.location_on),
                        label: Text(selectedLocation != null 
                            ? selectedLocation!['address'] 
                            : 'בחר מיקום'),
                      ),
                    ],
                  ],
                  
                  // בחירת סוג תשלום
                  const SizedBox(height: 16),
                  const Text(
                    'סוג תשלום:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('מזומן'),
                    value: 'cash',
                    groupValue: paymentType,
                    onChanged: (value) {
                      setDialogState(() {
                        paymentType = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('BIT'),
                    value: 'bit',
                    groupValue: paymentType,
                    onChanged: (value) {
                      setDialogState(() {
                        paymentType = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('כרטיס אשראי'),
                    value: 'credit',
                    groupValue: paymentType,
                    onChanged: (value) {
                      setDialogState(() {
                        paymentType = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ביטול'),
              ),
              // לחצן "צור הזמנה" או "שלם"
              // בדיקת תקינות: שירותים נבחרו, תשלום נבחר, ואם נדרש משלוח - סוג שירות נבחר
              Builder(
                builder: (context) {
                  final isValidOrder = hasSelectedItems && 
                      paymentType != null &&
                      (!requiresDelivery || deliveryType != null) &&
                      (!requiresDelivery || deliveryType != 'delivery' || (selectedLocation != null && selectedDeliveryCategory != null));
                  
                  if (isValidOrder) {
                    if (paymentType == 'cash') {
                      return ElevatedButton(
                        onPressed: () async {
                          // סגירת דיאלוג ההזמנה
                          Navigator.pop(context);
                          // הצגת דיאלוג אישור
                          await _showOrderConfirmationDialog(
                            context,
                            provider,
                            selectedServices,
                            recalculatedTotalPrice,
                            deliveryType,
                            selectedLocation,
                            selectedDeliveryCategory,
                            paymentType!, // כבר נבדק שהוא לא null
                            userName,
                            userPhone,
                            services,
                          );
                        },
                        child: const Text('צור הזמנה'),
                      );
                    } else {
                      return ElevatedButton(
                        onPressed: () {
                          // TODO: לוגיקה לתשלום (BIT או כרטיס אשראי)
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('מעבר לתשלום...')),
                          );
                        },
                        child: const Text('שלם'),
                      );
                    }
                  } else if (hasSelectedItems && paymentType != null && requiresDelivery && deliveryType == null) {
                    // הודעת שגיאה אם חסר סוג שירות
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'אנא בחר סוג שירות (איסוף עצמי או משלוח)',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // דיאלוג אישור הזמנה
  Future<void> _showOrderConfirmationDialog(
    BuildContext context,
    UserProfile provider,
    List<Map<String, dynamic>> selectedServices,
    double totalPrice,
    String? deliveryType,
    Map<String, dynamic>? selectedLocation,
    String? selectedDeliveryCategory,
    String paymentType,
    String customerName,
    String customerPhone,
    List<Map<String, dynamic>> allServices,
  ) async {
    // בניית רשימת OrderItems
    final orderItems = <order_model.OrderItem>[];
    for (final serviceData in selectedServices) {
      final serviceName = serviceData['serviceName'] as String? ?? '';
      final quantity = serviceData['quantity'] as int? ?? 0;
      final selectedIngredients = serviceData['ingredients'] as List<String>? ?? [];
      final service = allServices.firstWhere((s) => s['name'] == serviceName, orElse: () => {});
      
      if (service.isNotEmpty && quantity > 0) {
        final servicePrice = (service['price'] as num?)?.toDouble();
        final isCustomPrice = service['isCustomPrice'] as bool? ?? false;
        final ingredients = service['ingredients'] as List<dynamic>? ?? [];
        
        // חישוב מחיר כולל מרכיבים
        double itemTotalPrice = 0.0;
        if (!isCustomPrice && servicePrice != null) {
          itemTotalPrice = servicePrice * quantity;
          
          // הוספת מחיר מרכיבים
          for (final ingredientName in selectedIngredients) {
            final ingredient = ingredients.firstWhere(
              (ing) => (ing['name'] as String?) == ingredientName,
              orElse: () => {},
            );
            if (ingredient.isNotEmpty) {
              final ingredientCost = (ingredient['cost'] as num?)?.toDouble() ?? 0.0;
              itemTotalPrice += ingredientCost * quantity;
            }
          }
        }
        
        orderItems.add(order_model.OrderItem(
          serviceName: serviceName,
          quantity: quantity,
          selectedIngredients: selectedIngredients,
          servicePrice: servicePrice,
          isCustomPrice: isCustomPrice,
          totalItemPrice: itemTotalPrice > 0 ? itemTotalPrice : null,
        ));
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('אישור הזמנה'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // שם העסק
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // פרטי הלקוח
              const Text(
                'פרטי הלקוח:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('שם: $customerName'),
              Text('טלפון: $customerPhone'),
              const SizedBox(height: 16),
              
              // פירוט השירותים
              const Text(
                'פירוט השירותים:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...orderItems.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.serviceName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text('כמות: ${item.quantity}'),
                          ],
                        ),
                        if (item.selectedIngredients.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'מרכיבים: ${item.selectedIngredients.join(', ')}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                        if (item.totalItemPrice != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'מחיר: ₪${item.totalItemPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ] else if (item.isCustomPrice) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'מחיר: בהתאמה אישית',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              
              // סוג שירות
              if (deliveryType != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'סוג שירות:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(deliveryType == 'pickup' ? 'איסוף עצמי' : 'משלוח באמצעות שליח'),
                if (deliveryType == 'delivery' && selectedLocation != null) ...[
                  const SizedBox(height: 4),
                  Text('מיקום: ${selectedLocation['address']}'),
                ],
              ],
              
              // סוג תשלום
              const SizedBox(height: 16),
              const Text(
                'סוג תשלום:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                paymentType == 'cash' 
                    ? 'מזומן'
                    : paymentType == 'bit'
                        ? 'BIT'
                        : 'כרטיס אשראי',
              ),
              
              // סך הכל
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'סך הכל:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₪${totalPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('אשר הזמנה'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _createOrder(
        provider: provider,
        orderItems: orderItems,
        totalPrice: totalPrice,
        deliveryType: deliveryType,
        deliveryLocation: selectedLocation,
        deliveryCategory: selectedDeliveryCategory,
        paymentType: paymentType,
        customerName: customerName,
        customerPhone: customerPhone,
      );
    }
  }

  // קבלת מספר הזמנה הבא עבור עסק מסוים
  Future<int> _getNextOrderNumber(String providerId) async {
    try {
      final counterRef = FirebaseFirestore.instance
          .collection('order_counters')
          .doc(providerId);
      
      // קריאה אטומית - הגדלת המספר ב-1
      await counterRef.set({
        'lastOrderNumber': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // קבלת המספר החדש
      final counterDoc = await counterRef.get();
      final counterData = counterDoc.data();
      int lastNumber = (counterData?['lastOrderNumber'] as num?)?.toInt() ?? 99; // אם זה הראשון, נתחיל מ-100
      
      // אם המספר קטן מ-100, נגדיר אותו ל-100
      if (lastNumber < 100) {
        await counterRef.set({
          'lastOrderNumber': 100,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return 100;
      }
      
      return lastNumber;
    } catch (e) {
      debugPrint('Error getting next order number: $e');
      // במקרה של שגיאה, נחזיר 100
      return 100;
    }
  }

  // יצירת הזמנה ב-Firestore
  Future<void> _createOrder({
    required UserProfile provider,
    required List<order_model.OrderItem> orderItems,
    required double totalPrice,
    String? deliveryType,
    Map<String, dynamic>? deliveryLocation,
    String? deliveryCategory,
    required String paymentType,
    required String customerName,
    required String customerPhone,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // קבלת מספר הזמנה הבא עבור העסק
      final orderNumber = await _getNextOrderNumber(provider.userId);

      final order = order_model.Order(
        orderId: '', // יוגדר ב-Firestore
        customerId: currentUser.uid,
        customerName: customerName,
        customerPhone: customerPhone,
        providerId: provider.userId,
        providerName: provider.displayName,
        items: orderItems,
        totalPrice: totalPrice,
        deliveryType: deliveryType,
        deliveryLocation: deliveryLocation,
        deliveryCategory: deliveryCategory,
        paymentType: paymentType,
        status: 'pending',
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
      );

      final orderDocRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(order.toFirestore());
      
      final orderId = orderDocRef.id;

      // אם ההזמנה היא עם משלוח, שלח התראות לשליחים
      if (deliveryType == 'delivery' && deliveryLocation != null && deliveryCategory != null) {
        await _notifyCouriersForOrder(
          orderId: orderId,
          provider: provider,
          deliveryLocation: deliveryLocation,
          deliveryCategory: deliveryCategory,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ההזמנה נוצרה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת ההזמנה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // פונקציה לשליחת התראות לשליחים על הזמנה חדשה
  Future<void> _notifyCouriersForOrder({
    required String orderId,
    required UserProfile provider,
    required Map<String, dynamic> deliveryLocation,
    required String deliveryCategory,
  }) async {
    try {
      final deliveryLat = (deliveryLocation['latitude'] as num?)?.toDouble();
      final deliveryLng = (deliveryLocation['longitude'] as num?)?.toDouble();
      
      if (deliveryLat == null || deliveryLng == null) {
        debugPrint('❌ Invalid delivery location coordinates');
        return;
      }

      // המרת שם הקטגוריה הנבחרת ל-RequestCategory
      RequestCategory? selectedCategory;
      try {
        selectedCategory = RequestCategory.values.firstWhere(
          (cat) => cat.name == deliveryCategory,
        );
      } catch (e) {
        debugPrint('❌ Invalid delivery category: $deliveryCategory');
        return;
      }

      debugPrint('🔍 Looking for couriers with category: ${selectedCategory.name}');
      debugPrint('📍 Delivery location: lat=$deliveryLat, lng=$deliveryLng');

      // מציאת כל המשתמשים העסקיים עם קטגוריות של שליחים
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .get();

      debugPrint('👥 Found ${usersSnapshot.docs.length} business users with active subscription');

      final eligibleCouriers = <String, UserProfile>{};

      for (var userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final businessCategories = userData['businessCategories'] as List<dynamic>?;
          
          if (businessCategories == null || businessCategories.isEmpty) {
            debugPrint('⏭️ Skipping user ${userDoc.id} - no business categories');
            continue;
          }

          debugPrint('🔍 Checking user ${userDoc.id} (${userData['displayName'] ?? 'no name'})');
          debugPrint('   Categories: $businessCategories');

          // בדיקה אם המשתמש הוא שליח עם התחום הנבחר
          bool hasMatchingCategory = false;
          final selectedCategoryName = selectedCategory.name; // שם באנגלית
          final selectedCategoryDisplayName = selectedCategory.categoryDisplayName; // שם בעברית
          
          for (var category in businessCategories) {
            String categoryName;
            // טיפול בכמה פורמטים אפשריים
            if (category is String) {
              categoryName = category;
            } else {
              // אם זה לא string, נסה לחלץ את השם
              final categoryStr = category.toString();
              if (categoryStr.startsWith('RequestCategory.')) {
                categoryName = categoryStr.replaceFirst('RequestCategory.', '');
              } else {
                categoryName = categoryStr;
              }
            }
            
            debugPrint('   Checking category: "$categoryName" vs "$selectedCategoryName" (EN) or "$selectedCategoryDisplayName" (HE)');
            
            // בדיקה אם הקטגוריה תואמת לתחום הנבחר
            // נבדוק גם לפי שם באנגלית וגם לפי שם בעברית
            bool matches = false;
            
            // בדיקה לפי שם באנגלית (case-insensitive)
            if (categoryName.toLowerCase() == selectedCategoryName.toLowerCase()) {
              matches = true;
            }
            
            // בדיקה לפי שם בעברית
            if (!matches && categoryName == selectedCategoryDisplayName) {
              matches = true;
            }
            
            // אם הקטגוריה היא string, נסה למצוא את ה-RequestCategory המתאים ולבדוק
            if (!matches && category is String) {
              try {
                // נסה למצוא את הקטגוריה לפי שם בעברית
                final matchingCategory = RequestCategory.values.firstWhere(
                  (cat) => cat.categoryDisplayName == categoryName,
                  orElse: () => RequestCategory.plumbing,
                );
                if (matchingCategory == selectedCategory) {
                  matches = true;
                }
              } catch (e) {
                // אם לא מצאנו, נמשיך
              }
            }
            
            if (matches) {
              hasMatchingCategory = true;
              debugPrint('   ✅ Category matches!');
              break;
            }
          }

          if (!hasMatchingCategory) {
            debugPrint('   ❌ No matching category');
            continue;
          }

          // בדיקת מיקום קבוע וטווח חשיפה
          final userLat = (userData['latitude'] as num?)?.toDouble();
          final userLng = (userData['longitude'] as num?)?.toDouble();
          final maxRadius = (userData['maxRadius'] as num?)?.toDouble();

          debugPrint('   Location: lat=$userLat, lng=$userLng, maxRadius=$maxRadius');

          // חייב להיות מיקום קבוע וטווח חשיפה
          if (userLat == null || userLng == null || maxRadius == null) {
            debugPrint('   ❌ Missing location or radius');
            continue;
          }

          // בדיקת מיקום בטווח
          final distance = LocationService.calculateDistance(
            userLat,
            userLng,
            deliveryLat,
            deliveryLng,
          );

          debugPrint('   📏 Distance: ${distance.toStringAsFixed(2)} km (max: $maxRadius km)');

          if (distance <= maxRadius) {
            final userProfile = UserProfile.fromFirestore(userDoc);
            eligibleCouriers[userDoc.id] = userProfile;
            debugPrint('   ✅ Courier eligible!');
          } else {
            debugPrint('   ❌ Out of range');
          }
        } catch (e) {
          debugPrint('❌ Error processing courier ${userDoc.id}: $e');
          continue;
        }
      }

      debugPrint('📦 Found ${eligibleCouriers.length} eligible couriers for order $orderId');

      // שליחת התראות לכל השליחים המתאימים
      for (var entry in eligibleCouriers.entries) {
        final courierId = entry.key;
        final courierProfile = entry.value;

        // קבלת שם התצוגה של הקטגוריה
        final categoryDisplayName = selectedCategory.categoryDisplayName;

        await NotificationService.sendNotification(
          toUserId: courierId,
          title: 'הזמנה חדשה למשלוח',
          message: 'התקבלה הזמנה חדשה מ-${provider.displayName} בתחום $categoryDisplayName בטווח שלך',
          type: 'order_delivery',
          data: {
            'orderId': orderId,
            'providerId': provider.userId,
            'providerName': provider.displayName,
            'deliveryCategory': deliveryCategory,
            'deliveryLat': deliveryLat.toString(),
            'deliveryLng': deliveryLng.toString(),
            'address': deliveryLocation['address']?.toString() ?? '',
          },
        );

        debugPrint('✅ Notification sent to courier: ${courierProfile.displayName}');
      }
    } catch (e) {
      debugPrint('❌ Error notifying couriers: $e');
    }
  }

  // פונקציה לעיצוב תאריך
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // דיאלוג סינון נותני שירות
  void _showServiceProvidersFilterDialog(UserProfile? userProfile) {
    bool isDialogOpen = true;
    
    // ביטול בחירה מהעיגולים כאשר פותחים את דיאלוג הסינון
    if (_selectedMainCategoryFromCirclesForProviders != null) {
      setState(() {
        _selectedMainCategoryFromCirclesForProviders = null;
      });
    }
    
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Material(
              child: AlertDialog(
                title: const Text('סינון נותני שירות'),
                content: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        
                        // קטגוריה - מבנה של תחום ראשי ותת-תחומים
                        _buildProviderCategoryFilter(userProfile, setDialogState, l10n),
                        const SizedBox(height: 16),
                        
                        // סינון לפי איזור
                        DropdownButtonFormField<GeographicRegion?>(
                          value: _selectedProviderRegion,
                          decoration: const InputDecoration(
                            labelText: 'איזור',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<GeographicRegion?>(
                              value: null,
                              child: Text('כל האיזורים'),
                            ),
                            const DropdownMenuItem<GeographicRegion?>(
                              value: GeographicRegion.north,
                              child: Text('צפון'),
                            ),
                            const DropdownMenuItem<GeographicRegion?>(
                              value: GeographicRegion.center,
                              child: Text('מרכז'),
                            ),
                            const DropdownMenuItem<GeographicRegion?>(
                              value: GeographicRegion.south,
                              child: Text('דרום'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedProviderRegion = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // צ'קבוקס "סנן נותני שירות בטווח 5 ק"מ רדיוס סביב המיקום שלי"
                        CheckboxListTile(
                          title: const Text(
                            'סנן נותני שירות בטווח 5 ק"מ רדיוס סביב המיקום שלי',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: _filterProvidersByMyLocation,
                          onChanged: (value) async {
                            if (value == true) {
                              // בדיקה אם שירות המיקום פעיל
                              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                              if (!serviceEnabled) {
                                if (!context.mounted) return;
                                final shouldEnable = await LocationService.showEnableLocationServiceDialog(context);
                                if (!shouldEnable) {
                                  return;
                                }
                              }
                              
                              // עדכון המיקום הנוכחי של המשתמש
                              try {
                                final position = await Geolocator.getCurrentPosition();
                                if (!isDialogOpen || !context.mounted) return;
                                // המיקום יישמר ב-_userProfile דרך עדכון Firestore או SharedPreferences
                                // כרגע נשתמש במיקום הנוכחי מהמשתמש - position כבר נטען
                                debugPrint('📍 Current location: ${position.latitude}, ${position.longitude}');
                              } catch (e) {
                                debugPrint('⚠️ Failed to get current location: $e');
                              }
                            }
                            
                            setDialogState(() {
                              _filterProvidersByMyLocation = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        
                        const SizedBox(height: 24),
                        // כפתורי שמירה וביטול
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(l10n.cancel),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (mounted) {
                                  setState(() {
                                    // ביטול בחירה מהעיגולים כאשר שומרים סינון
                                    _selectedMainCategoryFromCirclesForProviders = null;
                                    
                                    // הסינון משתמש ב-_userProfile ישירות, אין צורך בשמירת ערכים נוספים
                                  });
                                }
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.providerFilterSaved),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text('שמור סינון'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // פונקציה לבניית סינון קטגוריות לנותני שירות
  Widget _buildProviderCategoryFilter(UserProfile? userProfile, StateSetter setDialogState, AppLocalizations l10n) {
    List<String> availableMainCategories = [];
    for (MainCategory mainCategory in MainCategory.values) {
      availableMainCategories.add(mainCategory.displayName);
    }
    
    Map<String, List<RequestCategory>> subCategories = {};
    for (MainCategory mainCategory in MainCategory.values) {
      List<RequestCategory> categories = [];
      for (RequestCategory category in RequestCategory.values) {
        if (category.mainCategory == mainCategory) {
          categories.add(category);
        }
      }
      subCategories[mainCategory.displayName] = categories;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.mainCategory,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            if (_selectedProviderMainCategories.isNotEmpty || _selectedProviderSubCategories.isNotEmpty)
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _selectedProviderMainCategories.clear();
                    _selectedProviderSubCategories.clear();
                  });
                },
                child: Text(
                  'נקה בחירה',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: availableMainCategories.map((mainCategory) {
            final isMainSelected = _selectedProviderMainCategories.contains(mainCategory);
            final mainCategorySubCategories = subCategories[mainCategory] ?? [];
            final mainCategoryEnum = MainCategory.values.firstWhere(
              (cat) => cat.displayName == mainCategory,
              orElse: () => MainCategory.values.first,
            );
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          mainCategory,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      Text(
                        mainCategoryEnum.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                  value: isMainSelected,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        _selectedProviderMainCategories.add(mainCategory);
                      } else {
                        _selectedProviderMainCategories.remove(mainCategory);
                        _selectedProviderSubCategories.removeWhere((cat) => 
                          mainCategorySubCategories.contains(cat));
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (isMainSelected && mainCategorySubCategories.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Column(
                      children: mainCategorySubCategories.map((subCategory) {
                        final isSubSelected = _selectedProviderSubCategories.contains(subCategory);
                        return CheckboxListTile(
                          title: Text(subCategory.categoryDisplayName),
                          value: isSubSelected,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                _selectedProviderSubCategories.add(subCategory);
                              } else {
                                _selectedProviderSubCategories.remove(subCategory);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // שיתוף האפליקציה לנותני שירות
  Future<void> _shareAppToProviders() async {
    if (!mounted) return;
    await AppSharingService.shareApp(context);
  }
}
