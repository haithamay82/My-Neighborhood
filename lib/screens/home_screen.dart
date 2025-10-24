import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/request.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/notification_service_local.dart';
import '../services/cloud_function_service.dart';
import '../services/app_state_service.dart';
import '../services/location_service.dart';
import '../services/admin_auth_service.dart';
import '../services/network_service.dart';
import 'profile_screen.dart';
import '../services/tutorial_service.dart';
import '../services/like_service.dart';
import '../services/share_service.dart';
import '../services/audio_service.dart';
import '../services/notification_tracking_service.dart';
import 'chat_screen.dart';
import 'image_gallery_screen.dart';
import 'profile_screen.dart';
import 'location_picker_screen.dart';
import 'tutorial_center_screen.dart';

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
  late AnimationController _blinkingController;
  // הסרת סינון מיקום - לא רלוונטי יותר
  RequestCategory? _selectedCategory;
  UserProfile? _userProfile;
  
  // סינון מתקדם
  RequestType? _selectedRequestType;
  UrgencyFilter? _selectedUrgency;
  double? _maxDistance;
  
  // קטגוריות לסינון
  String? _selectedMainCategory;
  RequestCategory? _selectedSubCategory;
  
  
  // מיקום המשתמש
  double? _userLatitude;
  double? _userLongitude;
  
  // בקשות שהמשתמש לחץ "אני מעוניין"
  Set<String> _interestedRequests = {};
  
  // מעקב אחר מצב ההרחבה של כל בקשה
  Set<String> _expandedRequests = {};
  
  // משתנים לניהול Pagination
  int _requestsPerPage = 5;
  bool _isLoadingMore = false;
  bool _hasMoreRequests = true; // האם יש עוד בקשות לטעינה
  
  
  // דירוגים של המשתמש לפי קטגוריה
  final Map<String, double> _userRatingsByCategory = {};
  
  
  
  // בקר גלילה לרשימת הבקשות
  final ScrollController _scrollController = ScrollController();
  
  // מצב סינון הבקשות
  bool _showMyRequests = false; // true = בקשות שפניתי אליהם, false = כל הבקשות
  
  // מערכת בונוסים לטווח בקשות
  int _maxRequestsPerMonth = 1; // מקסימום בקשות בחודש
  double _maxSearchRadius = 10.0; // מקסימום רדיוס חיפוש בק"מ
  
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
    
    // חישוב הטווח הבסיסי לפי סוג המנוי
    double baseRadius = 1.0; // ברירת מחדל - פרטי חינם
    String userTypeText = 'פרטי חינם';
    
    if (userProfile.userType == UserType.personal) {
      if (userProfile.isSubscriptionActive) {
        baseRadius = 2.0; // פרטי מנוי
        userTypeText = 'פרטי מנוי';
      } else {
        baseRadius = 1.0; // פרטי חינם
        userTypeText = 'פרטי חינם';
      }
    } else if (userProfile.userType == UserType.business) {
      if (userProfile.isSubscriptionActive) {
        baseRadius = 3.0; // עסקי מנוי
        userTypeText = 'עסקי מנוי';
      } else {
        baseRadius = 1.0; // עסקי ללא מנוי (לא אמור לקרות)
        userTypeText = 'עסקי ללא מנוי';
      }
    } else if (AdminAuthService.isCurrentUserAdmin()) {
      baseRadius = 50.0; // מנהל
      userTypeText = 'מנהל';
    }
    
    final bonusRadius = currentRadius - baseRadius;
    
    final recommendationsCount = userProfile.recommendationsCount ?? 0;
    final averageRating = userProfile.averageRating ?? 0.0;
    
    String bonusDetails = '';
    if (recommendationsCount > 0) {
      bonusDetails += '• המלצות: +${(recommendationsCount * 0.2).toStringAsFixed(1)} ק"מ\n';
    }
    if (averageRating >= 3.5) {
      double ratingBonus = 0.0;
      if (averageRating >= 4.5) {
        ratingBonus = 1.5;
      } else if (averageRating >= 4.0) {
        ratingBonus = 1.0;
      } else if (averageRating >= 3.5) {
        ratingBonus = 0.5;
      }
      bonusDetails += '• דירוג גבוה: +${ratingBonus.toStringAsFixed(1)} ק"מ\n';
    }

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
              color: Colors.blue[600],
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'הטווח הנוכחי שלך: ${currentRadius.toStringAsFixed(1)} ק"מ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'סוג מנוי: $userTypeText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (bonusRadius > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'טווח בסיסי: ${baseRadius.toStringAsFixed(1)} ק"מ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'בונוסים: +${bonusRadius.toStringAsFixed(1)} ק"מ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[600],
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
                          color: Colors.blue[700],
                        ),
                      ),
                      Text(
                        bonusDetails.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
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
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'איך לשפר את הטווח:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🎉 המלץ על האפליקציה לחברים (+0.2 ק"מ לכל המלצה)\n'
                    '⭐ קבל דירוגים גבוהים (+0.5-1.5 ק"מ)\n'
                    '💎 שדרג למנוי (טווח בסיסי גדול יותר)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
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
            child: const Text('הבנתי'),
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
        return (data['interestedAt'] as Timestamp).toDate();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last interest time: $e');
      return null;
    }
  }

  /// סידור בקשות לפי זמן ההתעניינות האחרונה
  Future<List<Request>> _sortRequestsByInterestTime(List<Request> requests) async {
    final List<MapEntry<Request, DateTime>> requestTimes = [];

    for (final request in requests) {
      final interestTime = await _getLastInterestTime(request.requestId);
      final timeToUse = interestTime ?? request.createdAt;
      requestTimes.add(MapEntry(request, timeToUse));
    }

    // סידור לפי זמן (החדש ביותר ראשון)
    requestTimes.sort((a, b) => b.value.compareTo(a.value));

    return requestTimes.map((entry) => entry.key).toList();
  }

  /// בניית רשימת הבקשות
  Widget _buildRequestsList(List<Request> requests, AppLocalizations l10n) {
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

    // הודעה מיוחדת למצב "פניות שלי" כשאין פניות
    if (_showMyRequests && requests.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.pink[300],
              ),
              const SizedBox(height: 24),
              Text(
                'אין לך פניות',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'לחץ "אני מעוניין" על בקשות שמעניינות אותך ב"כל הבקשות"',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.pink[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.pink[600],
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'איך זה עובד?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. עבור ל"כל הבקשות"\n2. לחץ "אני מעוניין" על בקשות שמעניינות אותך\n3. הבקשות יופיעו כאן ב"פניות שלי"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.pink[600],
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
                label: const Text('עבור לכל הבקשות'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[600],
                  foregroundColor: Colors.white,
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

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // הודעה למשתמשים עסקיים שאין להם מנוי פעיל
          if (index == 0 && isBusinessUserWithoutSubscription) {
            return Card(
              margin: const EdgeInsets.all(8),
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'מנוי נדרש',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'כדי לראות בקשות בתשלום, אנא הפעל את המנוי שלך',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[600],
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
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
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
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'תחומי עיסוק נדרשים',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'כדי לראות בקשות בתשלום, אנא בחר תחומי עיסוק בפרופיל',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[600],
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
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
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
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.amber[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'הגבלת קטגוריה',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'תחום העיסוק "${_selectedCategory!.categoryDisplayName}" שבחרת אינו אחד מתחומי העיסוק שלך. במידה ותרצה לראות בקשות בתשלום בקטגוריה זו, עדכן את תחומי העיסוק שלך בפרופיל.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[600],
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
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('עדכן פרופיל'),
                    ),
                  ],
                ),
              ),
            );
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
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('requestId', isEqualTo: request.requestId)
                  .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.hasError) {
                  return _buildRequestCard(request, l10n);
                }
                
                if (chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty) {
                  final chatData = chatSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  
                  if (deletedBy.contains(currentUserId)) {
                    return const SizedBox.shrink();
                  }
                }
                
                return _buildRequestCard(request, l10n);
              },
            );
          }
          
          // אינדיקטור טעינה בתחתית הרשימה (רק אם יש עוד בקשות)
          if (index == requests.length + 
              (isBusinessUserWithoutSubscription ? 1 : 0) +
              (isBusinessUserWithSubscriptionButNoCategories ? 1 : 0) +
              (hasRestrictedCategoryMessage ? 1 : 0) &&
              _hasMoreRequests) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'טוען עוד בקשות...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // הודעה שאין עוד בקשות
          if (index == requests.length + 
              (isBusinessUserWithoutSubscription ? 1 : 0) +
              (isBusinessUserWithSubscriptionButNoCategories ? 1 : 0) +
              (hasRestrictedCategoryMessage ? 1 : 0) &&
              !_hasMoreRequests && requests.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 32,
                      color: Colors.green[400],
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
          
          return _buildRequestCard(request, l10n);
        },
        childCount: requests.length + 
            (isBusinessUserWithoutSubscription ? 1 : 0) +
            (isBusinessUserWithSubscriptionButNoCategories ? 1 : 0) +
            (hasRestrictedCategoryMessage ? 1 : 0) +
            (_isLoadingMore && _hasMoreRequests ? 1 : 0) + // אינדיקטור טעינה רק אם יש עוד בקשות
            (!_hasMoreRequests && requests.isNotEmpty ? 1 : 0), // הודעה שאין עוד בקשות
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
      label: Text(isInterested ? 'אני לא מעוניין' : 'אני מעוניין'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isInterested ? Colors.red : const Color(0xFF03A9F4), // כחול יפה מהלוגו
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  // פונקציה לניהול גלילה לטעינת עוד בקשות
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // אם הגענו ל-200 פיקסלים מהתחתית ויש עוד בקשות, טען עוד
      if (_hasMoreRequests && !_isLoadingMore) {
        _loadMoreRequests();
      }
    }
  }

  // פונקציה לטעינת עוד בקשות
  Future<void> _loadMoreRequests() async {
    if (_isLoadingMore || !_hasMoreRequests) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      // בדיקה אם יש עוד בקשות בטווח הנוכחי
      final currentRequests = await FirebaseFirestore.instance
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .limit(_requestsPerPage + 5)
          .get();
      
      // אם מספר הבקשות שנטענו קטן מהמספר שביקשנו, אין עוד בקשות
      if (currentRequests.docs.length < _requestsPerPage + 5) {
        setState(() {
          _hasMoreRequests = false;
        });
        debugPrint('📄 No more requests available. Total loaded: ${currentRequests.docs.length}');
      } else {
        // עדכון מספר הבקשות לטעינה
        setState(() {
          _requestsPerPage += 5;
        });
        debugPrint('✅ Loaded more requests. Total per page: $_requestsPerPage');
      }
    } catch (e) {
      debugPrint('❌ Error loading more requests: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _helpWithRequest(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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
      
      // בדיקה אם המשתמש הוא אורח ובקשה בתשלום
      if (requestType == 'paid') {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final userType = userData['userType'] as String?;
          final businessCategories = userData['businessCategories'] as List<dynamic>? ?? [];
          
          // אם המשתמש הוא אורח
          if (userType == 'guest') {
            // אם אין תחומי עיסוק כלל
            if (businessCategories.isEmpty) {
              await _showGuestCategoryDialog(category ?? 'לא ידוע');
              return;
            }
            
            // אם יש תחומי עיסוק אבל לא מתאימים לקטגוריית הבקשה
            final requestCategory = category;
            final hasMatchingCategory = businessCategories.any((cat) => cat == requestCategory);
            
            if (!hasMatchingCategory) {
              await _showCategoryMismatchDialog(category ?? 'לא ידוע');
              return;
            }
          }
        }
      }

      // הוספת המשתמש לרשימת העוזרים
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update({
        'helpers': FieldValue.arrayUnion([user.uid]),
      });

      // הוספת הבקשה לרשימת הבקשות שהמשתמש מעוניין בהן
      setState(() {
        _interestedRequests.add(requestId);
        _showMyRequests = true; // מעבר אוטומטי למצב "בקשות שפניתי אליהם"
      });
      
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
        await _sendAutoMessageWithRating(chatId, user.uid, requestData['category'] ?? 'other');
        
        // יצירת התראה למבקש
        await NotificationService.notifyHelpOffered(
          requestCreatorId: creatorId,
          helperName: user.displayName ?? 'משתמש',
          requestTitle: requestData['title'] ?? 'בקשה',
        );
        
        // שליחת push notification למבקש הבקשה
        await CloudFunctionService.sendHelpOfferNotification(
          requestCreatorId: creatorId,
          helperName: user.displayName ?? 'משתמש',
          requestTitle: requestData['title'] ?? 'בקשה',
        );
        
        debugPrint('Help notification sent to creator: $creatorId');
      }

      // שליחת התראה מקומית למשתמש הנוכחי (אישור שההצעת עזרה נשלחה)
      await NotificationServiceLocal.showNotification(
        id: 100,
        title: 'הצעת עזרה נשלחה!',
        body: 'הצעת העזרה שלך נשלחה בהצלחה',
        payload: 'help_sent',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הצעת עזרה נשלחה!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה: $e'),
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
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('אישור ביטול עניין'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'האם אתה בטוח שאתה רוצה לבטל את העניין שלך בבקשה?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey[800] 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[600]! 
                          : Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'בקשה: ${request.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'תחום: ${request.category.categoryDisplayName}',
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
                        'סוג: בתשלום',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'לאחר הביטול, לא תוכל לראות את הצ\'אט עם יוצר הבקשה.',
                style: TextStyle(
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
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'ביטול',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await playButtonSound();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('כן, בטל עניין'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _unhelpWithRequest(request.requestId);
    }
  }

  Future<void> _unhelpWithRequest(String requestId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('🔍 User unhelping with request: $requestId');
      debugPrint('🔍 User UID: ${user.uid}');

      // הסרת המשתמש מרשימת העוזרים
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update({
        'helpers': FieldValue.arrayRemove([user.uid]),
      });

      debugPrint('✅ User removed from helpers list');

      // הסרת הבקשה מרשימת הבקשות שהמשתמש מעוניין בהן
      setState(() {
        _interestedRequests.remove(requestId);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה: $e'),
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

  Future<void> _sendAutoMessageWithRating(String chatId, String helperId, String category) async {
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
      String message = 'שלום! אני $displayName$expertBadge';
      
      if (ratingCount > 0) {
        message += ' (${averageRating.toStringAsFixed(1)}⭐ ב${_getCategoryDisplayName(category)})';
      } else {
        message += ' (חדש בתחום ${_getCategoryDisplayName(category)})';
      }
      
      message += ' מעוניין לעזור לך עם הבקשה שלך. איך אוכל לעזור?';
      
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
        orElse: () => RequestCategory.maintenance,
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
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: correctChatId!,
                requestTitle: 'בקשה', // TODO: קבלת כותרת הבקשה
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
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                requestTitle: 'בקשה', // TODO: קבלת כותרת הבקשה
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
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                requestTitle: 'בקשה', // TODO: Get request title
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
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() => setState(() {}));
    
    // אתחול אנימציית ההבהוב
    _blinkingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    
    // הוספת Listener לגלילה לטעינת עוד בקשות
    _scrollController.addListener(_onScroll);
    
    _loadUserProfile();
    _loadSavedFilters(); // טעינת סינון שמור
    _loadInterestedRequests(); // טעינת בקשות שהמשתמש מעוניין בהן
    _loadUserRatings(); // טעינת דירוגים של המשתמש
    _checkForNewNotifications();
    _startLocationTracking(); // התחלת מעקב מיקום
    
    // בדיקת הגדלת טווח
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationService.checkAndShowRadiusIncreaseNotification(context);
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

  // הצגת הודעת הדרכה למשתמשים חדשים - רק למסך הבית
  Future<void> _showTutorialIfNeeded() async {
    debugPrint('🏠 HOME SCREEN - _showTutorialIfNeeded called');
    
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
  }
  
  // הודעת הדרכה מינימלית
  void _showMinimalTutorial() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.waving_hand, color: Colors.orange[600]),
            const SizedBox(width: 8),
            Text(
              'ברוכים הבאים!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ברוכים הבאים לאפליקציית "שכונתי"!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'כדי ללמוד איך להשתמש באפליקציה, לחץ על אייקון המדריך (📚) בתפריט העליון.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'המדריך מכיל הדרכות מפורטות לכל הפונקציות!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
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
              'הבנתי',
              style: TextStyle(
                color: Colors.grey[800],
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
            child: const Text('פתח מדריך'),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [
            BoxShadow(
              color: activeColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey('$icon-$isActive'),
                size: 20,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.white : Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// בניית כפתור פעולה מודרני
  Widget _buildModernActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          vertical: isSmall ? 8 : 12,
          horizontal: isSmall ? 12 : 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: isSmall ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isSmall ? 18 : 20,
              color: Colors.white,
            ),
            if (!isSmall) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
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

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Listen to real-time profile changes
      _profileSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _userProfile = UserProfile.fromFirestore(snapshot);
            debugPrint('🔄 Real-time profile update - business categories: ${_userProfile?.businessCategories?.map((c) => c.name).toList()}');
          });
          // חישוב הטווח העדכני
          _calculateCurrentMaxRadius();
          // הצגת הודעה למשתמש אורח
          _showGuestStatusMessage(_userProfile);
          // הצגת הודעה על מיקום קבוע
          _showLocationReminderMessage(_userProfile);
        }
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  // שמירת סינון נוכחי
  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterData = {
        'selectedCategory': _selectedCategory?.name,
        'selectedRequestType': _selectedRequestType?.name,
        'selectedUrgency': _selectedUrgency?.name,
        'maxDistance': _maxDistance,
        'userLatitude': _userLatitude,
        'userLongitude': _userLongitude,
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
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('סינון שמור'),
          content: const Text('נמצא סינון שמור מהפעם הקודמת. האם ברצונך לשחזר אותו?'),
          actions: <Widget>[
            TextButton(
              child: const Text('לא'),
              onPressed: () {
                Navigator.of(context).pop();
                _clearSavedFilters();
              },
            ),
            TextButton(
              child: const Text('כן'),
              onPressed: () {
                Navigator.of(context).pop();
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
            // שחזור קטגוריה
            if (filterData['selectedCategory'] != null) {
              _selectedCategory = RequestCategory.values.firstWhere(
                (cat) => cat.name == filterData['selectedCategory'],
                orElse: () => RequestCategory.values.first,
              );
            }
            
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
            
            
            // שחזור מרחק מקסימלי
            if (filterData['maxDistance'] != null) {
              _maxDistance = filterData['maxDistance'] as double;
            }
            
            // שחזור מיקום משתמש
            if (filterData['userLatitude'] != null) {
              _userLatitude = filterData['userLatitude'] as double;
            }
            if (filterData['userLongitude'] != null) {
              _userLongitude = filterData['userLongitude'] as double;
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
      // בדיקה אם יש הרשאות מיקום
      bool hasPermission = await LocationService.checkLocationPermission();
      if (!hasPermission) return;

      // קבלת מיקום נוכחי
      Position? position = await LocationService.getCurrentPosition();
      if (position == null) return;

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
        
        // רענון התוצאות אם יש סינון לפי מרחק
        if (_maxDistance != null) {
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
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[700], size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'הטווח המקסימלי שלך: ${(_currentMaxRadius ?? _maxSearchRadius).toStringAsFixed(1)} ק"מ\n'
                          'בקשות בחודש: ${_maxRequestsPerMonth} בקשות',
                          style: TextStyle(
                            color: Colors.orange[700],
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
                    // פתיחת מסך בחירת מיקום
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          initialLatitude: _userLatitude,
                          initialLongitude: _userLongitude,
                          initialAddress: 'מיקום נוכחי',
                          initialExposureRadius: _maxDistance,
                          maxExposureRadius: _currentMaxRadius ?? _maxSearchRadius,
                          showExposureCircle: true,
                        ),
                      ),
                    );
                    
                    if (result != null) {
                      setState(() {
                        _userLatitude = result['latitude'];
                        _userLongitude = result['longitude'];
                        _maxDistance = result['exposureRadius'] ?? 10.0;
                      });
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('בחר מיקום וטווח במפה'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // הצגת מיקום נבחר
                if (_userLatitude != null && _userLongitude != null && _maxDistance != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                                'מיקום נבחר: ${_userLatitude?.toStringAsFixed(4) ?? 'N/A'}, ${_userLongitude?.toStringAsFixed(4) ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.green[700],
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
                            Icon(Icons.radio_button_checked, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                        Text(
                              'טווח: ${_maxDistance!.toStringAsFixed(1)} ק"מ',
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
                      color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey[800] 
                      : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[600]! 
                          : Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 24),
                        const SizedBox(width: 8),
                            Expanded(
                          child: Text(
                            'לחץ על "בחר מיקום וטווח במפה" כדי לבחור מיקום וטווח',
                          style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Colors.grey[600],
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
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: _maxDistance != null && _userLatitude != null && _userLongitude != null
                  ? () {
                      setDialogState(() {}); // עדכון הדיאלוג הראשי
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('אישור'),
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
        final notificationId = notificationsQuery.docs.first.id;
        
        if (message != null && message.isNotEmpty && createdAt != null) {
          // בדיקה שההתראה חדשה (פחות מ-60 שניות)
          final now = DateTime.now();
          final notificationTime = createdAt.toDate();
          final timeDiff = now.difference(notificationTime).inSeconds;
          
          debugPrint('Notification time diff: $timeDiff seconds');
          
          if (timeDiff <= 60) { // התראה חדשה
            // בדיקה אם כבר נשלחה התראה מקומית עבור התראה זו
            final hasBeenShown = await NotificationTrackingService.hasNotificationWithParamsBeenSent(
              userId: user.uid,
              notificationType: 'local_notification',
              params: {'notificationId': notificationId},
            );
            
            if (!hasBeenShown) {
              final title = notification['title'] as String? ?? 'התראה חדשה!';
              await NotificationServiceLocal.showNotification(
                id: 200,
                title: title,
                body: message,
                payload: 'new_notification',
              );
              
              // סימון שההתראה המקומית נשלחה
              await NotificationTrackingService.markNotificationWithParamsAsSent(
                userId: user.uid,
                notificationType: 'local_notification',
                params: {'notificationId': notificationId},
              );
              
              debugPrint('Initial notification check - shown: $title - $message');
            } else {
              debugPrint('Local notification already shown for notification: $notificationId');
            }
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
        final notificationId = notificationsQuery.docs.first.id;
        
        if (message != null && message.isNotEmpty && createdAt != null) {
          // בדיקה שההתראה חדשה (פחות מ-120 שניות)
          final now = DateTime.now();
          final notificationTime = createdAt.toDate();
          final timeDiff = now.difference(notificationTime).inSeconds;
          
          debugPrint('Delayed notification time diff: $timeDiff seconds');
          
          if (timeDiff <= 120) { // התראה חדשה
            // בדיקה אם כבר נשלחה התראה מקומית עבור התראה זו
            final hasBeenShown = await NotificationTrackingService.hasNotificationWithParamsBeenSent(
              userId: currentUser.uid,
              notificationType: 'local_notification_delayed',
              params: {'notificationId': notificationId},
            );
            
            if (!hasBeenShown) {
              final title = notification['title'] as String? ?? 'התראה חדשה!';
              await NotificationServiceLocal.showNotification(
                id: 201,
                title: title,
                body: message,
                payload: 'new_notification_delayed',
              );
              
              // סימון שההתראה המקומית נשלחה
              await NotificationTrackingService.markNotificationWithParamsAsSent(
                userId: currentUser.uid,
                notificationType: 'local_notification_delayed',
                params: {'notificationId': notificationId},
              );
              
              debugPrint('Delayed notification check - shown: $title - $message');
            } else {
              debugPrint('Delayed local notification already shown for notification: $notificationId');
            }
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Profile is now loaded via real-time StreamBuilder
      debugPrint('🔄 didChangeAppLifecycleState - app resumed, profile loaded via StreamBuilder');
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

  // בדיקה אם משתמש אורח נמצא בשבוע הראשון
  bool _isGuestInFirstWeek(UserProfile? userProfile) {
    debugPrint('🔍 _isGuestInFirstWeek called');
    debugPrint('🔍 User type: ${userProfile?.userType}');
    debugPrint('🔍 Guest trial start date: ${userProfile?.guestTrialStartDate}');
    
    if (userProfile?.userType != UserType.guest) {
      debugPrint('❌ Not a guest user');
      return false;
    }
    if (userProfile?.guestTrialStartDate == null) {
      debugPrint('❌ No guest trial start date');
      return false;
    }
    
    final now = DateTime.now();
    final trialStart = userProfile!.guestTrialStartDate!;
    final daysSinceStart = now.difference(trialStart).inDays;
    
    debugPrint('🕐 Guest trial check: $daysSinceStart days since start');
    debugPrint('🕐 Trial start: $trialStart');
    debugPrint('🕐 Now: $now');
    debugPrint('🕐 Is first week: ${daysSinceStart < 7}');
    
    return daysSinceStart < 7; // שבוע = 7 ימים
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
    
    final isFirstWeek = _isGuestInFirstWeek(userProfile);
    final hasCategories = _hasGuestSelectedCategories(userProfile);
    
    // קביעת סוג ההתראה על בסיס המצב
    String notificationType;
    if (isFirstWeek) {
      notificationType = 'guest_welcome_first_week';
    } else if (hasCategories) {
      notificationType = 'guest_with_categories';
    } else {
      notificationType = 'guest_trial_ended';
    }
    
    // בדיקה אם כבר נשלחה התראה מסוג זה למשתמש הזה
    final hasBeenSent = await NotificationTrackingService.hasNotificationBeenSent(
      userId: userProfile!.userId,
      notificationType: notificationType,
    );
    
    if (hasBeenSent) {
      debugPrint('Guest status notification already sent: $notificationType for user: ${userProfile.userId}');
      return; // כבר נשלחה התראה מסוג זה
    }
    
    String title;
    String message;
    if (isFirstWeek) {
      title = 'ברוכים הבאים! תקופת אורח החלה';
      message = 'אתה נמצא בשבוע הראשון שלך - תוכל לראות כל הבקשות (חינם ובתשלום) מכל הקטגוריות!';
    } else if (hasCategories) {
      title = 'מצב אורח - תחומי עיסוק מוגדרים';
      message = 'אתה רואה בקשות בתשלום רק מתחומי העיסוק שבחרת. כדי לראות יותר בקשות, בחר תחומי עיסוק נוספים בפרופיל.';
    } else {
      title = 'שבוע הניסיון הסתיים';
      message = 'כדי לראות בקשות בתשלום, בחר תחומי עיסוק בפרופיל שלך.';
    }
    
    // שליחת התראה למסך התראות
    await NotificationService.sendNotification(
      toUserId: userProfile.userId,
      title: title,
      message: message,
    );
    
    // סימון שההתראה נשלחה
    await NotificationTrackingService.markNotificationAsSent(
      userId: userProfile.userId,
      notificationType: notificationType,
    );
    
    debugPrint('✅ Guest status notification sent: $notificationType for user: ${userProfile.userId}');
  }

  // הצגת הודעה למשתמשים שלא הגדירו מיקום קבוע (כהתראה חד-פעמית)
  void _showLocationReminderMessage(UserProfile? userProfile) async {
    if (userProfile?.latitude != null && userProfile?.longitude != null) return;
    
    // בדיקה אם כבר נשלחה התראה למשתמש הזה
    final hasBeenSent = await NotificationTrackingService.hasNotificationBeenSent(
      userId: userProfile!.userId,
      notificationType: 'location_reminder',
    );
    
    if (hasBeenSent) {
      debugPrint('Location reminder notification already sent for user: ${userProfile.userId}');
      return; // כבר נשלחה התראה מסוג זה
    }
    
    // שליחת התראה למסך התראות
    await NotificationService.sendNotification(
      toUserId: userProfile.userId,
      title: 'הגדר מיקום קבוע בפרופיל',
      message: 'כנותן שירות, הגדרת מיקום קבוע חיונית כדי להופיע במפות של בקשות גם כששירות המיקום כובה בטלפון',
    );
    
    // סימון שההתראה נשלחה
    await NotificationTrackingService.markNotificationAsSent(
      userId: userProfile.userId,
      notificationType: 'location_reminder',
    );
    
    debugPrint('✅ Location reminder notification sent for user: ${userProfile.userId}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    _blinkingController.dispose();
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    print('🏠 HOME SCREEN - build() called');
    debugPrint('🏠 HOME SCREEN - build() called');
    final l10n = AppLocalizations.of(context);
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך הבית
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTutorialIfNeeded();
    });

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: CustomScrollView(
          controller: _scrollController,
          key: const PageStorageKey('home_screen_list'),
        slivers: [
          SliverAppBar(
            expandedHeight: 60,
            toolbarHeight: 60,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFFFF9800) // כתום ענתיק
                : Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
                title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'בקשות של מפרסמים',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                                    if (displayName != null && displayName.isNotEmpty) {
                                      return Text(
                                        'שלום, $displayName',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                        // אינדיקטור חיבור לאינטרנט
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isConnected ? Icons.wifi : Icons.wifi_off,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                    Text(
                                isConnected ? 'מחובר' : 'אין חיבור',
                      style: const TextStyle(
                        color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Notifications are now handled in initState() and background
                  // שדה חיפוש
                  TextField(
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
                      fillColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      // הפעלת החיפוש בזמן אמת
                      _performSearch();
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // כפתורי סינון מודרניים
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                    children: [
                      // כפתור פניות שלי
                      Expanded(
                          child: _buildModernFilterButton(
                            icon: Icons.favorite,
                            label: 'פניות שלי',
                            isActive: _showMyRequests,
                            activeColor: Colors.pink,
                            onTap: () {
                            setState(() {
                              _showMyRequests = true;
                            });
                          },
                          ),
                        ),
                        const SizedBox(width: 4),
                      // כפתור כל הבקשות
                      Expanded(
                          child: _buildModernFilterButton(
                            icon: Icons.grid_view,
                            label: 'כל הבקשות',
                            isActive: !_showMyRequests,
                            activeColor: Colors.blue,
                            onTap: () {
                            setState(() {
                              _showMyRequests = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(height: 12),
                  
                  // כפתור סינון מתקדם מודרני
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showAdvancedFilterDialog(_userProfile),
                          child: Image.asset(
                            'assets/images/filter.png',
                            width: 32,
                            height: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_hasActiveFilters())
                        _buildModernActionButton(
                          icon: Icons.clear_all,
                          label: 'נקה',
                          color: Colors.red,
                          onTap: _clearFilters,
                          isSmall: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .orderBy('createdAt', descending: true)
                .limit(_requestsPerPage)
                .snapshots(),
            builder: (context, snapshot) {
              print('🏠 HOME SCREEN - StreamBuilder called');
              debugPrint('🏠 HOME SCREEN - StreamBuilder called');
              final currentUser = FirebaseAuth.instance.currentUser;
              debugPrint('Current user: ${currentUser?.uid}');
              debugPrint('User email: ${currentUser?.email}');
              debugPrint('StreamBuilder state: ${snapshot.connectionState}');
              debugPrint('Snapshot has error: ${snapshot.hasError}');
              debugPrint('Snapshot has data: ${snapshot.hasData}');
              debugPrint('Snapshot docs count: ${snapshot.data?.docs.length ?? 0}');
              if (snapshot.hasError) {
                debugPrint('Snapshot error: ${snapshot.error}');
                debugPrint('Error details: ${snapshot.error.toString()}');
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
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'שגיאה בטעינת הנתונים',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {});
                            },
                            child: const Text('נסה שוב'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                debugPrint('⏳ HOME SCREEN - Waiting for data...');
                return SliverToBoxAdapter(
                  child: Center(
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
                  ),
                );
              }

              // בדיקה אם המשתמש מחובר
              if (currentUser == null) {
                debugPrint('❌ HOME SCREEN - No user logged in');
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.orange[300]),
                            const SizedBox(height: 16),
                            Text(
                              'לא מחובר',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[700]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'אנא התחבר כדי לראות בקשות',
                              style: TextStyle(fontSize: 14, color: Colors.orange[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }


              if (snapshot.hasError) {
                // הצגת הודעת שגיאת רשת אם אין חיבור
                if (!isConnected) {
                  showNetworkMessage(context);
                } else {
                  showNetworkError(context, customMessage: 'שגיאה בטעינת הבקשות');
                }
                
                return SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isConnected ? Icons.error : Icons.wifi_off, 
                          size: 64, 
                          color: isConnected ? Colors.red[300] : Colors.orange[300]
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isConnected ? 'שגיאה בטעינת הבקשות' : 'אין חיבור לאינטרנט',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: isConnected ? Colors.red[700] : Colors.orange[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isConnected 
                            ? 'שגיאה טכנית - נסה שוב מאוחר יותר'
                            : 'בדוק את החיבור שלך לאינטרנט',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14, 
                            color: isConnected ? Colors.red[600] : Colors.orange[600],
                        ),
                        ),
                        if (isConnected) ...[
                        const SizedBox(height: 8),
                        Text(
                            '${snapshot.error}',
                          textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await playButtonSound();
                            if (mounted) {
                              // בדיקת חיבור לפני רענון
                              final connected = await NetworkService.checkConnection();
                              if (connected) {
                              setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('מרענן...'),
                                    backgroundColor: Colors.blue,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              } else {
                                showNetworkMessage(context);
                              }
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('נסה שוב'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnected ? Colors.blue : Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
                debugPrint('No data or empty docs. Docs count: ${snapshot.data?.docs.length ?? 0}');
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.green[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'השתמש בכפתור "בקשה חדשה" למטה כדי ליצור בקשה ראשונה',
                              style: TextStyle(
                                color: Colors.green[700],
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

              if (snapshot.data == null) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            await playButtonSound();
                            Navigator.pushNamed(context, '/new_request');
                          },
                          child: const Text('צור בקשה חדשה'),
                    ),
                  ],
                ),
              ),
                );
              }

              final allRequests = snapshot.data!.docs
                  .map((doc) => Request.fromFirestore(doc))
                  .where((request) => request.status == RequestStatus.open || request.status == RequestStatus.completed)
                  .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // מיון לפי תאריך - החדשות ביותר בראש
              
              debugPrint('Total requests loaded: ${allRequests.length}');
              debugPrint('User profile loaded: ${_userProfile != null}');
              if (_userProfile != null) {
                debugPrint('User type: ${_userProfile!.userType.name}');
                debugPrint('Is subscription active: ${_userProfile!.isSubscriptionActive}');
                debugPrint('Business categories: ${_userProfile!.businessCategories?.map((c) => c.name).toList()}');
              }
              debugPrint('Is admin: ${AdminAuthService.isCurrentUserAdmin()}');
              for (var request in allRequests) {
                debugPrint('Request: ${request.title}, createdBy: ${request.createdBy}, type: ${request.type.name}, status: ${request.status.name}, minRating: ${request.minRating}');
              }
              
              // סינון הבקשות - לוגיקה פשוטה וברורה
              debugPrint('🔍 Starting request filtering for ${allRequests.length} requests');
              debugPrint('🔍 User profile: ${_userProfile != null}');
              if (_userProfile != null) {
                debugPrint('🔍 User type: ${_userProfile!.userType.name}');
                debugPrint('🔍 Is subscription active: ${_userProfile!.isSubscriptionActive}');
              } else {
                debugPrint('🔍 User profile not loaded yet, using default filtering');
                // אם הפרופיל לא נטען, נשתמש בסינון בסיסי
              }
              
              // בדיקת מנהל - מנהל רואה הכל חוץ מהבקשות שלו
              final isAdmin = AdminAuthService.isCurrentUserAdmin();
              debugPrint('🔍 Admin check result: $isAdmin');
              
              final requests = allRequests.where((request) {
                debugPrint('🔍 Filtering request: ${request.title}, type: ${request.type.name}');
                
                // סינון לפי מצב "בקשות שפניתי אליהם" או "כל הבקשות"
                if (_showMyRequests) {
                  // מצב "בקשות שפניתי אליהם" - הצג רק בקשות שהמשתמש לחץ "אני מעוניין"
                  final isInterested = _interestedRequests.contains(request.requestId);
                  if (!isInterested) {
                    debugPrint('❌ Request ${request.title} not in interested requests - hiding');
                    return false;
                  }
                  debugPrint('✅ Request ${request.title} is in interested requests - showing');
                } else {
                  // מצב "כל הבקשות" - הצג רק בקשות שהמשתמש לא לחץ "אני מעוניין"
                  final isInterested = _interestedRequests.contains(request.requestId);
                  if (isInterested) {
                    debugPrint('❌ Request ${request.title} is in interested requests - hiding from all requests');
                    return false;
                  }
                  debugPrint('✅ Request ${request.title} not in interested requests - showing in all requests');
                }
                
                if (isAdmin) {
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  final isMyRequest = request.createdBy == currentUserId;
                  
                  if (isMyRequest) {
                    debugPrint('❌ Request ${request.requestId} is admin\'s own request - hiding from home screen');
                    return false;
                  }
                  
                  // מנהל רואה את כל הבקשות אבל עדיין צריך לעבור סינון מתקדם
                  debugPrint('✅ Admin user - request passed admin check: ${request.title}');
                  // לא מחזירים true כאן - ממשיכים לסינון המתקדם
                }
                
                // 1. סינון לפי דירוג מינימלי (רק למשתמשים רגילים)
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                
                // בקשות שלי לא יוצגו במסך הבית (רק למשתמשים רגילים, לא למנהל)
                if (!isAdmin) {
                  final isMyRequest = request.createdBy == currentUserId;
                if (isMyRequest) {
                  debugPrint('❌ Request ${request.requestId} is my request - hiding from home screen');
                  return false;
                  }
                }
                
                // בדיקה אם המשתמש הנוכחי מחק צ'אט סגור עבור בקשה זו
                // אם כן, נסתיר את הבקשה ממסך הבית שלו
                if (request.helpers.contains(currentUserId)) {
                  // נבדוק אם יש צ'אט שנמחק על ידי המשתמש הנוכחי
                  // זה יבוצע בצורה אסינכרונית, אז נחזיר true כרגע ונבדוק אחר כך
                  // TODO: Add async check for deleted chats
                }
                
                // בדיקת סוג הבקשה
                
                // 1. סינון מתקדם (חיפוש, סוג בקשה, קטגוריה, דחיפות, כפר, מרחק)
                
                // סינון בקשות שפג תוקף - בקשות שפג תוקף לא יוצגו במסך "כל הבקשות" אבל יוצגו ב"בקשות שלי"
                if (!_showMyRequests && _isRequestDeadlineExpired(request)) {
                  debugPrint('❌ Request deadline expired - hiding from all requests: ${request.title}, deadline: ${request.deadline}');
                  return false;
                }
                
                if (_selectedRequestType != null && request.type != _selectedRequestType!) {
                  debugPrint('❌ Request type filter - hiding request: ${request.title}, type: ${request.type.name}, selected: ${_selectedRequestType!.name}');
                  return false;
                }
                
                // סינון לפי קטגוריה (תחום ראשי ותת-תחום)
                if (_selectedMainCategory != null || _selectedSubCategory != null) {
                  bool categoryMatches = false;
                  
                  if (_selectedSubCategory != null) {
                    // אם נבחר תת-תחום ספציפי
                    categoryMatches = request.category == _selectedSubCategory!;
                  } else if (_selectedMainCategory != null) {
                    // אם נבחר רק תחום ראשי - בדוק אם הקטגוריה שייכת לתחום הזה
                    // כאן נצטרך להוסיף לוגיקה שמתאימה בין תחום ראשי לקטגוריות
                    categoryMatches = _isCategoryInMainCategory(request.category, _selectedMainCategory!);
                  }
                  
                  if (!categoryMatches) {
                    debugPrint('❌ Category filter - hiding request: ${request.title}, category: ${request.category.name}');
                    return false;
                  }
                }
                
                // סינון לפי רמת דחיפות (אם נבחר)
                if (_selectedUrgency != null) {
                  debugPrint('🔍 Urgency filter - checking request: ${request.title}, urgencyLevel: ${request.urgencyLevel.name}, selected: ${_selectedUrgency!.name}');
                  
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
                  
                  if (!shouldShow) {
                    debugPrint('❌ Urgency filter - hiding request: ${request.title}, urgencyLevel: ${request.urgencyLevel.name}, selected: ${_selectedUrgency!.name}');
                    return false;
                  } else {
                    debugPrint('✅ Urgency filter - showing request: ${request.title}, urgencyLevel: ${request.urgencyLevel.name}, selected: ${_selectedUrgency!.name}');
                  }
                }
                
                
                if (_maxDistance != null && _userLatitude != null && _userLongitude != null) {
                  if (request.latitude != null && request.longitude != null) {
                    // בדיקה 1: מיקום הסינון של המשתמש בתוך ישראל
                    if (_userLatitude != null && _userLongitude != null && !LocationService.isLocationInIsrael(_userLatitude!, _userLongitude!)) {
                      debugPrint('❌ User filter location outside Israel: $_userLatitude, $_userLongitude');
                      return false;
                    }
                    
                    // בדיקה 2: מיקום הבקשה בתוך ישראל
                    if (!LocationService.isLocationInIsrael(request.latitude!, request.longitude!)) {
                      debugPrint('❌ Request location outside Israel: ${request.latitude}, ${request.longitude}');
                      return false;
                    }
                    
                    // בדיקה 3: מיקום הבקשה בטווח של המשתמש
                    if (_userLatitude != null && _userLongitude != null && request.latitude != null && request.longitude != null && _maxDistance != null && !LocationService.isLocationInRange(_userLatitude!, _userLongitude!, request.latitude!, request.longitude!, _maxDistance!)) {
                      debugPrint('❌ Request outside user range: ${request.latitude}, ${request.longitude}');
                      return false;
                    }
                  }
                }
                
                final searchQuery = _searchController.text.trim();
                if (searchQuery.isNotEmpty) {
                  if (!request.title.toLowerCase().contains(searchQuery.toLowerCase()) &&
                      !request.description.toLowerCase().contains(searchQuery.toLowerCase())) {
                    debugPrint('❌ Search filter - hiding request: ${request.title}, search: $searchQuery');
                    return false;
                  }
                }
                
                // 2. בדיקת סוג הבקשה לפי סוג המשתמש
                // בקשות חינמיות - כל המשתמשים רואים אותן
                if (request.type == RequestType.free) {
                  debugPrint('✅ Free request - showing to all users: ${request.title}');
                  return true;
                }
                
                // בקשות בתשלום - בדיקה לפי סוג המשתמש
                if (request.type == RequestType.paid) {
                  debugPrint('🔍 Processing paid request: ${request.title}');
                  debugPrint('🔍 User type: ${_userProfile?.userType}');
                  debugPrint('🔍 Is admin: ${AdminAuthService.isCurrentUserAdmin()}');
                  
                  // בדיקה אם המשתמש הגדיר שלא הוא נותן שירותים בתשלום
                  if (_userProfile?.noPaidServices == true) {
                    debugPrint('❌ Paid request - hiding from user who doesn\'t provide paid services: ${request.title}');
                    return false;
                  }
                  
                  // בדיקה אם המשתמש הוא מנהל
                  if (AdminAuthService.isCurrentUserAdmin()) {
                    debugPrint('✅ Paid request - showing to admin: ${request.title}');
                    return true;
                  }
                  
                  // בדיקה אם המשתמש הוא עסקי מנוי
                  if (_userProfile?.userType == UserType.business && _userProfile?.isSubscriptionActive == true) {
                    // בדיקה אם הקטגוריה של הבקשה היא אחת מתחומי העיסוק של המשתמש
                    if (_userProfile?.businessCategories != null && 
                        _userProfile!.businessCategories!.any((category) => category == request.category)) {
                      debugPrint('✅ Paid request - showing to business user (matching category): ${request.title}');
                      return true;
                    } else {
                      debugPrint('❌ Paid request - hiding from business user (no matching category): ${request.title}');
                      return false;
                    }
                  }
                  
                  // בדיקה אם המשתמש הוא אורח
                  if (_userProfile?.userType == UserType.guest) {
                    debugPrint('🔍 User is guest - checking guest logic');
                    debugPrint('🔍 Guest trial start date: ${_userProfile?.guestTrialStartDate}');
                    debugPrint('🔍 Guest categories: ${_userProfile?.businessCategories?.map((c) => c.name).toList()}');
                    
                    // שבוע ראשון - רואה כל הבקשות בתשלום
                    if (_isGuestInFirstWeek(_userProfile)) {
                      debugPrint('✅ Paid request - showing to guest (first week): ${request.title}');
                      return true;
                    }
                    
                    // אחרי שבוע - רק אם בחר תחומי עיסוק והבקשה מתאימה
                    if (_hasGuestSelectedCategories(_userProfile)) {
                      debugPrint('🔍 Guest has selected categories - checking if request matches');
                      if (_userProfile?.businessCategories != null && 
                          _userProfile!.businessCategories!.any((category) => category == request.category)) {
                        debugPrint('✅ Paid request - showing to guest (matching category): ${request.title}');
                        return true;
                      } else {
                        debugPrint('❌ Paid request - hiding from guest (no matching category): ${request.title}');
                        return false;
                      }
                    } else {
                      debugPrint('❌ Paid request - hiding from guest (no categories selected): ${request.title}');
                      return false;
                    }
                  }
                  
                  // משתמשים פרטיים (חינם או מנוי) לא רואים בקשות בתשלום
                  debugPrint('❌ Paid request - hiding from personal user: ${request.title}');
                  return false;
                }
                
                // בדיקת דירוגים מותאמים אישית
                if (request.minReliability != null || request.minAvailability != null || 
                    request.minAttitude != null || request.minFairPrice != null) {
                  debugPrint('🔍 Request ${request.requestId} has custom rating requirements');
                  
                  // רשימת דרישות דירוג שנבחרו
                  List<String> selectedRequirements = [];
                  List<String> failedRequirements = [];
                  
                  // בדיקת דירוג אמינות
                  if (request.minReliability != null) {
                    selectedRequirements.add('אמינות: ${request.minReliability!.toStringAsFixed(1)}');
                    final userReliability = _userProfile?.reliability ?? 0.0;
                    if (userReliability < request.minReliability!) {
                      failedRequirements.add('אמינות: $userReliability < ${request.minReliability!.toStringAsFixed(1)}');
                      debugPrint('❌ User reliability $userReliability < required ${request.minReliability}');
                    } else {
                      debugPrint('✅ User reliability $userReliability >= required ${request.minReliability}');
                    }
                  }
                  
                  // בדיקת דירוג זמינות
                  if (request.minAvailability != null) {
                    selectedRequirements.add('זמינות: ${request.minAvailability!.toStringAsFixed(1)}');
                    final userAvailability = _userProfile?.availability ?? 0.0;
                    if (userAvailability < request.minAvailability!) {
                      failedRequirements.add('זמינות: $userAvailability < ${request.minAvailability!.toStringAsFixed(1)}');
                      debugPrint('❌ User availability $userAvailability < required ${request.minAvailability}');
                } else {
                      debugPrint('✅ User availability $userAvailability >= required ${request.minAvailability}');
                    }
                  }
                  
                  // בדיקת דירוג יחס
                  if (request.minAttitude != null) {
                    selectedRequirements.add('יחס: ${request.minAttitude!.toStringAsFixed(1)}');
                    final userAttitude = _userProfile?.attitude ?? 0.0;
                    if (userAttitude < request.minAttitude!) {
                      failedRequirements.add('יחס: $userAttitude < ${request.minAttitude!.toStringAsFixed(1)}');
                      debugPrint('❌ User attitude $userAttitude < required ${request.minAttitude}');
                    } else {
                      debugPrint('✅ User attitude $userAttitude >= required ${request.minAttitude}');
                    }
                  }
                  
                  // בדיקת דירוג מחיר הוגן
                  if (request.minFairPrice != null) {
                    selectedRequirements.add('מחיר הוגן: ${request.minFairPrice!.toStringAsFixed(1)}');
                    final userFairPrice = _userProfile?.fairPrice ?? 0.0;
                    if (userFairPrice < request.minFairPrice!) {
                      failedRequirements.add('מחיר הוגן: $userFairPrice < ${request.minFairPrice!.toStringAsFixed(1)}');
                      debugPrint('❌ User fair price $userFairPrice < required ${request.minFairPrice}');
                    } else {
                      debugPrint('✅ User fair price $userFairPrice >= required ${request.minFairPrice}');
                    }
                  }
                  
                  // אם יש דרישות שנכשלו - הסתר את הבקשה
                  if (failedRequirements.isNotEmpty) {
                    debugPrint('❌ Request ${request.requestId}: user failed requirements: ${failedRequirements.join(', ')} - hiding');
                  return false;
                }
                
                  // אם אין דרישות שנכשלו - הצג את הבקשה
                  debugPrint('✅ Request ${request.requestId}: user meets all selected requirements: ${selectedRequirements.join(', ')} - showing');
                  return true;
                }
                
                // בקשות עם דירוג מינימלי פשוט (לשמירת תאימות)
                if (request.minRating != null) {
                  debugPrint('🔍 Request ${request.requestId} has simple min rating: ${request.minRating}');
                  final userRating = _userProfile?.averageRating ?? 0.0;
                  if (userRating < request.minRating!) {
                    debugPrint('❌ User rating $userRating < required ${request.minRating} - hiding');
                    return false;
                  }
                  debugPrint('✅ Request ${request.requestId}: user rating $userRating >= min rating ${request.minRating} - showing');
                } else {
                  debugPrint('✅ Request ${request.requestId} has no rating requirements - showing to all users');
                }
                
                
                
                // אם הגענו לכאן - לא אמור לקרות
                debugPrint('⚠️ Unexpected case - showing request: ${request.title}');
                return true;
              }).toList();

              // מיון הבקשות
              // בדיקה אם יש סינון פעיל ואין תוצאות
              if (requests.isEmpty && _hasActiveFilters()) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 80,
                          color: Colors.orange[300],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'אין בקשות מתאימות לסינון הנבחר',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'נסה לשנות את הסינון או לנקות אותו כדי לראות יותר בקשות',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
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
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
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
                                foregroundColor: Colors.blue[600],
                                side: BorderSide(color: Colors.blue[600]!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_showMyRequests) {
                // במצב "בקשות שפניתי אליהם" - נשתמש ב-FutureBuilder לסידור לפי זמן ההתעניינות
                return FutureBuilder<List<Request>>(
                  future: _sortRequestsByInterestTime(requests),
                  builder: (context, sortSnapshot) {
                    if (sortSnapshot.connectionState == ConnectionState.waiting) {
                      return SliverToBoxAdapter(
                        child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }
                    
                    final sortedRequests = sortSnapshot.data ?? requests;
                    return _buildRequestsList(sortedRequests, l10n);
                  },
                );
              } else {
                // במצב "כל הבקשות" - סידור לפי תאריך יצירה (החדשות ביותר בראש)
                requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return _buildRequestsList(requests, l10n);
              }
              
              // עדכון הבקשות הנוכחיות לגלילה (לפני הפילטרים)

              // הודעה למשתמשים עסקיים שאין להם מנוי פעיל
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Request request, AppLocalizations l10n) {
    final isOwnRequest = request.createdBy == FirebaseAuth.instance.currentUser?.uid;
    final isUrgent = request.urgencyLevel == UrgencyLevel.emergency;
    
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
            color: urgencyLevel.color.withOpacity(0.3 + (value * 0.7)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: urgencyLevel.color.withOpacity(value * 0.8),
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
                  color: Colors.black.withOpacity(0.3),
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
    final l10n = AppLocalizations.of(context)!;
    return StatefulBuilder(
      builder: (context, setCardState) {
        final isExpanded = _expandedRequests.contains(request.requestId);
        
        return GestureDetector(
          onTap: () {
            // עדכון רק של הכרטיס הספציפי
            if (isExpanded) {
              _expandedRequests.remove(request.requestId);
            } else {
              _expandedRequests.add(request.requestId);
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
                    if (request.status == RequestStatus.completed) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'טופל',
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
                            ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    )),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // תיאור
                Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: request.urgencyLevel == UrgencyLevel.emergency 
                        ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
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
                            ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                            : Theme.of(context).textTheme.bodySmall?.color, 
                        fontSize: 12
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.payment, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      request.type.typeDisplayName(l10n),
                      style: TextStyle(
                        color: request.urgencyLevel == UrgencyLevel.emergency 
                            ? (request.type == RequestType.paid ? Colors.green[800] : Colors.black87)  // טקסט כהה יותר לבקשות דחופות
                            : (request.type == RequestType.paid ? Colors.green[600] : Theme.of(context).textTheme.bodySmall?.color),
                        fontSize: 12,
                        fontWeight: request.type == RequestType.paid ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    if (request.address != null && request.address!.isNotEmpty) ...[
                      Icon(Icons.location_on, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          request.address!,
                          style: TextStyle(
                            color: request.urgencyLevel == UrgencyLevel.emergency 
                                ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                                : Theme.of(context).textTheme.bodySmall?.color, 
                            fontSize: 12
                          ),
                        ),
                      ),
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
                                  color: tag.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: tag.color,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  tag.displayName,
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
                              color: Colors.purple.withOpacity(0.2),
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
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(result ? 'הוספת לייק! ❤️' : 'הסרת לייק'),
                                          duration: const Duration(seconds: 2),
                                          backgroundColor: result ? Colors.pink : Colors.grey,
                                        ),
                                      );
                                    }
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
                                        ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
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
                
                // מידע מורחב (רק אם הבקשה מורחבת)
                if (isExpanded) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // מספר טלפון
                  if (request.createdBy != FirebaseAuth.instance.currentUser?.uid) ...[
                    if (request.formattedPhoneNumber != null && request.formattedPhoneNumber!.isNotEmpty) ...[
                      if (_interestedRequests.contains(request.requestId)) ...[
                        // המשתמש לחץ "אני מעוניין" - הצג את מספר הטלפון
                        GestureDetector(
                          onTap: () {
                            debugPrint('=== PHONE NUMBER TAPPED ===');
                            debugPrint('Phone number: ${request.formattedPhoneNumber}');
                            _makePhoneCall(request.formattedPhoneNumber!);
                          },
                          child: Row(
                            children: [
                              Icon(Icons.phone, size: 20, color: Colors.blue[600]),
                              const SizedBox(width: 4),
                              Text(
                                request.formattedPhoneNumber!,
                                style: TextStyle(
                                  color: Colors.blue[600], 
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // המשתמש לא לחץ "אני מעוניין" - הצג הודעה
                        Row(
                          children: [
                            Icon(Icons.phone_locked, size: 20, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              'לחץ "אני מעוניין" כדי להציג מספר טלפון',
                              style: TextStyle(
                                color: request.urgencyLevel == UrgencyLevel.emergency 
                                    ? Colors.black87  // טקסט כהה יותר לבקשות דחופות
                                    : Theme.of(context).textTheme.bodySmall?.color, 
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      // אין מספר טלפון - הצג הודעה
                      Row(
                        children: [
                          Icon(Icons.phone_disabled, size: 20, color: Colors.orange[600]),
                          const SizedBox(width: 4),
                          Text(
                            'בקשה ללא מספר טלפון',
                            style: TextStyle(
                              color: Colors.orange[600], 
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  
                  // תאריך יעד
                  if (request.deadline != null) ...[
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'תאריך יעד: ${request.deadline!.day}/${request.deadline!.month}/${request.deadline!.year}',
                          style: TextStyle(
                            color: request.urgencyLevel == UrgencyLevel.emergency 
                                ? (request.deadline!.isBefore(DateTime.now()) 
                                    ? Colors.red[800]  // כהה יותר לבקשות דחופות
                                    : Colors.black87)  // טקסט כהה יותר לבקשות דחופות
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
                          '${request.helpers.length} פונים מעוניינים',
                          style: TextStyle(
                            color: request.urgencyLevel == UrgencyLevel.emergency 
                                ? (request.helpers.isNotEmpty ? Colors.blue[800] : Colors.black87)  // טקסט כהה יותר לבקשות דחופות
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
                                        child: Image.network(
                                          imageSnapshot.data!,
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(Icons.person, size: 16, color: Colors.grey[600]);
                                          },
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
                                            child: Image.network(
                                              imageSnapshot.data!,
                                              width: 24,
                                              height: 24,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(Icons.person, size: 16, color: Colors.grey[600]);
                                              },
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
                                  'פורסם על ידי: משתמש',
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
                  
                  // כפתור "אני מעוניין"
                  if (request.createdBy != FirebaseAuth.instance.currentUser?.uid && request.status == RequestStatus.open) ...[
                    _buildInterestButton(request, l10n),
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
                        if (chatSnapshot.hasData && chatSnapshot.data!.docs.isNotEmpty) {
                          final chatData = chatSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                          final isClosed = chatData['isClosed'] as bool? ?? false;
                          final deletedBy = List<String>.from(chatData['deletedBy'] ?? []);
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                          
                          final isRequestCreator = request.createdBy == currentUserId;
                          if (!isRequestCreator && deletedBy.contains(currentUserId)) {
                            return const SizedBox.shrink();
                          }
                          
                          return Stack(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await playButtonSound();
                                  _openChat(request.requestId);
                                },
                                icon: Icon(isClosed ? Icons.lock : Icons.chat, size: 20),
                                label: Text(isClosed ? 'צ\'אט סגור' : 'צ\'אט'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isClosed ? Colors.grey : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              ),
                              // ספירת הודעות חדשות
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(chatSnapshot.data!.docs.first.id)
                                    .collection('messages')
                                    .snapshots(),
                                builder: (context, messageSnapshot) {
                                  if (messageSnapshot.hasData) {
                                    int unreadCount = 0;
                                    final chatId = chatSnapshot.data!.docs.first.id;
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
        ));
      },
    );
  }

  /// הצגת דיאלוג למשתמש אורח שלא עדכן תחומי עיסוק
  // דיאלוג למקרה של אי התאמה בין תחומי העיסוק לקטגוריית הבקשה
  Future<void> _showCategoryMismatchDialog(String category) async {
    // המרת שם הקטגוריה לעברית
    final hebrewCategory = _getCategoryDisplayName(category);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('תחומי עיסוק לא מתאימים'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'הבקשה הזו היא מתחום "$hebrewCategory" ולא מתאימה לתחומי העיסוק שלך.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'במידה ותרצה לפנות ליוצר הבקשה, עליך לעדכן את תחומי העיסוק שלך בפרופיל כך שיתאימו לקטגוריה של הבקשה.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ביטול'),
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
            child: const Text('ערוך תחומי עיסוק'),
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
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info, color: Colors.blue[700], size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'עדכן תחומי עיסוק',
                  style: TextStyle(fontSize: 16),
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
                  'הבקשה הזאת היא בתחום "$hebrewCategory".',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Text(
                  'אם אתה נותן שירות בתחום זה, עליך קודם לעדכן תחומי עיסוק בפרופיל ולאחר מכן תוכל לפנות ליוצר הבקשה.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'לאחר עדכון תחומי העיסוק, תוכל לפנות למפרסם הבקשה בתחום זה.',
                          style: TextStyle(fontSize: 12),
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
                Navigator.of(context).pop();
              },
              child: const Text('הבנתי'),
            ),
            ElevatedButton(
              onPressed: () async {
                await AudioService().playSound(AudioEvent.buttonClick);
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
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
    return _selectedMainCategory != null ||
           _selectedSubCategory != null ||
           _selectedRequestType != null ||
           _selectedUrgency != null ||
           _maxDistance != null;
  }

  void _clearFilters() {
    // ניקוי מיידי של הסינון ללא דיאלוג שמירה
      _performClearFilters();
  }

  // ביצוע ניקוי הסינון
  void _performClearFilters() {
    if (mounted) {
      setState(() {
        _selectedMainCategory = null;
        _selectedSubCategory = null;
        _selectedRequestType = null;
        _selectedUrgency = null;
        _maxDistance = null;
      });
    }
  }


  // דיאלוג שמירת סינון אחרי הפעלה
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
                  child: const Text('ביטול'),
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

  // הגדרת התראות לסינון
  Future<void> _setupFilterNotifications() async {
    try {
      // שמירת הגדרות התראות ב-SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      // יצירת מפתח ייחודי לסינון הנוכחי
      final filterKey = 'filter_notifications_${DateTime.now().millisecondsSinceEpoch}';
      
      // שמירת פרטי הסינון
      final filterData = {
        'requestType': _selectedRequestType?.toString(),
        'mainCategory': _selectedMainCategory?.toString(),
        'subCategory': _selectedSubCategory?.toString(),
        'urgency': _selectedUrgency?.toString(),
        'maxDistance': _maxDistance,
        'userLatitude': _userLatitude,
        'userLongitude': _userLongitude,
        'createdAt': DateTime.now().toIso8601String(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'isActive': true,
      };
      
      await prefs.setString(filterKey, filterData.toString());
      
      // שמירת רשימת מפתחות התראות
      List<String> notificationKeys = prefs.getStringList('filter_notification_keys') ?? [];
      notificationKeys.add(filterKey);
      await prefs.setStringList('filter_notification_keys', notificationKeys);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 התראות הוגדרו בהצלחה! תקבל התראות לבקשות חדשות המתאימות לסינון'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      debugPrint('🔔 Filter notifications setup completed for key: $filterKey');
      debugPrint('🔔 Filter data: $filterData');
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

  void _showAdvancedFilterDialog(UserProfile? userProfile) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('סינון מתקדם'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // סוג בקשה - לפי סוג המשתמש
                _buildRequestTypeFilter(userProfile, setDialogState, l10n),

        // קטגוריה - מבנה של תחום ראשי ותת-תחומים
        _buildCategoryFilter(userProfile, setDialogState),
                const SizedBox(height: 16),

                // דחיפות
                DropdownButtonFormField<UrgencyFilter?>(
                  initialValue: _selectedUrgency,
                  decoration: const InputDecoration(
                    labelText: 'דחיפות',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<UrgencyFilter?>(
                      value: null,
                      child: Text('כל הבקשות'),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.normal,
                      child: Text('🕓 רגיל'),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.urgent24h,
                      child: Text('⏰ תוך 24 שעות'),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.emergency,
                      child: Text('🚨 עכשיו'),
                    ),
                    DropdownMenuItem<UrgencyFilter?>(
                      value: UrgencyFilter.urgentAndEmergency,
                      child: Text('⏰🚨 תוך 24 שעות וגם עכשיו'),
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
                    color: Colors.blue[50],
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
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'טווח הבקשות שלך: 0.1-${(_currentMaxRadius ?? _maxSearchRadius).toStringAsFixed(1)} ק"מ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
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

                // בחירת טווח בקשות
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_searching),
                    title: const Text('טווח בקשות'),
                    subtitle: _maxDistance != null && _userLatitude != null && _userLongitude != null
                        ? Text('${_maxDistance!.toStringAsFixed(1)} ק״מ ממיקום נוכחי')
                        : const Text('לחץ לבחירת מיקום ורדיוס להגדרת טווח בקשות'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showDistancePickerDialog(setDialogState),
                  ),
                ),
              ],
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () {
                // בדיקה אם נדרש מיקום לסינון
                if (_maxDistance != null && _maxDistance! > 0 && 
                    (_userLatitude == null || _userLongitude == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('נדרש מיקום נוכחי לסינון לפי מרחק'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                if (mounted) {
                  setState(() {
                    // עדכון המשתנים כדי שהסינון יעבוד
                    debugPrint('🔍 Applying filters:');
                    debugPrint('  - Request type: $_selectedRequestType');
                    debugPrint('  - Category: $_selectedCategory');
                    debugPrint('  - Urgency: $_selectedUrgency');
                    debugPrint('  - Max distance: $_maxDistance');
                    debugPrint('  - User location: $_userLatitude, $_userLongitude');
                  });
                }
                Navigator.pop(context);
                // שאלת המשתמש אם לשמור את הסינון
                  _showSaveFilterAfterApplyDialog();
              },
              child: const Text('החל'),
            ),
          ],
        ),
      ),
    );
  }

  // פונקציה לבניית סינון סוג בקשה
  Widget _buildRequestTypeFilter(UserProfile? userProfile, StateSetter setDialogState, AppLocalizations l10n) {
    // בדיקה אם המשתמש לא נותן שירותים בתשלום
    bool noPaidServices = userProfile?.noPaidServices ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RequestType?>(
          value: noPaidServices ? RequestType.free : _selectedRequestType,
          decoration: const InputDecoration(
            labelText: 'סוג בקשה',
            border: OutlineInputBorder(),
          ),
          items: noPaidServices ? [
            // משתמש שלא נותן שירותים בתשלום - רק בקשות חינמיות
            const DropdownMenuItem<RequestType?>(
              value: RequestType.free,
              child: Text('חינמי בלבד'),
            ),
          ] : [
            // "כל הסוגים" זמין לכל סוגי המשתמשים
            const DropdownMenuItem<RequestType?>(
              value: null,
              child: Text('כל הסוגים'),
            ),
            ...RequestType.values.map((type) => DropdownMenuItem(
              value: type,
              child: Text(type.typeDisplayName(l10n)),
            )),
          ],
          onChanged: noPaidServices ? null : (value) {
            setDialogState(() {
              _selectedRequestType = value;
              // איפוס הקטגוריות כאשר משנים את סוג הבקשה
              _selectedMainCategory = null;
              _selectedSubCategory = null;
            });
          },
        ),
        if (noPaidServices) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[600], size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'הגדרת שלא אתה נותן שירותים בתשלום - תוכל לראות רק בקשות חינמיות',
                    style: TextStyle(fontSize: 12),
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

  // פונקציה לבניית סינון קטגוריות
  Widget _buildCategoryFilter(UserProfile? userProfile, StateSetter setDialogState) {
    // לוגיקה פשוטה - כל המשתמשים יכולים לראות את כל הקטגוריות
    List<String> availableMainCategories = ['כל הקטגוריות'];
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
        // בחירת תחום ראשי
        DropdownButtonFormField<String?>(
          value: _selectedMainCategory,
          decoration: const InputDecoration(
            labelText: 'תחום ראשי',
            border: OutlineInputBorder(),
          ),
          items: availableMainCategories.map((category) => DropdownMenuItem(
            value: category == 'כל הקטגוריות' ? null : category,
            child: Text(category),
          )).toList(),
          onChanged: (value) {
            setDialogState(() {
              _selectedMainCategory = value;
              _selectedSubCategory = null; // איפוס תת-קטגוריה
            });
          },
        ),
        
        // בחירת תת-קטגוריה (רק אם נבחר תחום ראשי)
        if (_selectedMainCategory != null && subCategories.containsKey(_selectedMainCategory)) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<RequestCategory?>(
            value: _selectedSubCategory,
            decoration: const InputDecoration(
              labelText: 'תת-תחום',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<RequestCategory?>(
                value: null,
                child: Text('כל התת-תחומים'),
              ),
              ...subCategories[_selectedMainCategory]!.map((category) => DropdownMenuItem(
                value: category,
                child: Text(category.categoryDisplayName),
              )),
            ],
            onChanged: (value) {
              setDialogState(() {
                _selectedSubCategory = value;
              });
            },
          ),
        ],
      ],
    );
  }
}
