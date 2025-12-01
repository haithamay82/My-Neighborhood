import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/request.dart';
import 'notification_service.dart';

class GuestAuthService {
  // ignore: constant_identifier_names
  static const int GUEST_MAX_REQUESTS = 10; // כמו עסקי מנוי
  // ignore: constant_identifier_names
  static const double GUEST_MAX_RADIUS = 3.0; // כמו עסקי מנוי
  
  /// יצירת משתמש אורח חדש
  static Future<UserProfile> createGuestUser({
    required String displayName,
    required String email,
    required List<RequestCategory> selectedCategories,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('משתמש לא מחובר');
    }

    final now = DateTime.now();
    
    debugPrint('🔍 Creating guest user:');
    debugPrint('   - Now: $now');
    debugPrint('   - Guest user (no time limit)');
    
    final guestProfile = UserProfile(
      userId: user.uid,
      displayName: displayName,
      email: email,
      userType: UserType.guest,
      createdAt: now,
      isSubscriptionActive: true, // אורח נחשב פעיל
      subscriptionStatus: 'guest_active',
      businessCategories: selectedCategories,
      maxRequestsPerMonth: GUEST_MAX_REQUESTS,
      maxRadius: GUEST_MAX_RADIUS,
      canCreatePaidRequests: true, // אורח יכול ליצור בקשות בתשלום
      hasAcceptedTerms: true,
    );

    // שמירה ב-Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(guestProfile.toFirestore());

    // שליחת התראה למנהל
    await _notifyAdminAboutNewGuest(guestProfile);

    return guestProfile;
  }

  /// בדיקה אם משתמש הוא אורח
  static Future<bool> isGuestUser(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    return data['userType'] == 'guest';
  }

  /// בדיקה אם תקופת האורח הסתיימה - תמיד מחזיר false (אין הגבלת זמן)
  static Future<bool> isGuestTrialExpired(String userId) async {
    return false; // אורחים ללא הגבלת זמן
  }

  /// בדיקה מהירה - האם תקופת האורח הסתיימה (לבדיקות) - תמיד מחזיר false
  static Future<bool> isGuestTrialExpiredForTesting(String userId, {DateTime? testDate}) async {
    return false; // אורחים ללא הגבלת זמן
  }

  /// מעבר אוטומטי מאורח לפרטי חינם
  static Future<void> transitionGuestToPersonal(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!userDoc.exists) return;
    
    final userData = userDoc.data()!;
    
    // שמירת המידע הקיים
    final preservedData = {
      'createdRequests': userData['createdRequests'] ?? [],
      'interestedRequests': userData['interestedRequests'] ?? [],
      'chatHistory': userData['chatHistory'] ?? [],
      'ratings': userData['ratings'] ?? {},
      'requestCounts': userData['requestCounts'] ?? {},
      'guestTrialHistory': {
        'startDate': userData['guestTrialStartDate'],
        'endDate': userData['guestTrialEndDate'],
        'categoriesUsed': userData['businessCategories'] ?? [],
        'requestsCreated': userData['createdRequests']?.length ?? 0,
      }
    };
    
    // עדכון למנוי פרטי חינם
    await userDoc.reference.update({
      'userType': UserType.personal.name,
      'isSubscriptionActive': false,
      'subscriptionStatus': 'private_free',
      'maxRequestsPerMonth': 3,        // פרטי חינם
      'maxRadius': 1.0,                // פרטי חינם
      'businessCategories': [],        // לא רלוונטי לפרטי
      'previousUserType': UserType.guest.name,
      'transitionDate': FieldValue.serverTimestamp(),
      ...preservedData,                // שמירת המידע
    });

    // שליחת התראה למשתמש
    await NotificationService.sendNotification(
      toUserId: userId,
      title: 'המנוי שלך עבר לסוג "פרטי חינם"',
      message: 'שדרג עכשיו למנוי "פרטי מנוי" או "עסקי"',
    );
  }

  /// בדיקה אם device כבר השתמש בתקופת אורח - תמיד מחזיר false (אין הגבלה)
  static Future<bool> hasDeviceUsedGuestTrial() async {
    return false; // אין הגבלה על device
  }

  /// שליחת התראה למנהל על אורח חדש
  static Future<void> _notifyAdminAboutNewGuest(UserProfile guestProfile) async {
    try {
      // מציאת כל המנהלים
      final adminsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();

      for (final adminDoc in adminsQuery.docs) {
        await NotificationService.sendNotification(
          toUserId: adminDoc.id,
          title: 'אורח חדש הצטרף',
          message: '${guestProfile.displayName} הצטרף כאורח',
        );
      }
    } catch (e) {
      debugPrint('Error notifying admin about new guest: $e');
    }
  }

  /// בדיקה יומית של אורחים שצריכים לעבור לפרטי - לא בשימוש (אין הגבלת זמן)
  static Future<void> checkAndTransitionExpiredGuests() async {
    // לא נדרש - אורחים ללא הגבלת זמן
    debugPrint('🔍 Guest trial expiry check skipped - no time limit for guests');
  }

  /// שליחת תזכורת 7 ימים לפני סיום תקופת אורח - לא נדרש (אין הגבלת זמן)
  static Future<void> sendTrialReminderNotifications() async {
    // לא נדרש - אורחים ללא הגבלת זמן
    debugPrint('🔍 Trial reminder notifications skipped - no time limit for guests');
  }

  /// קבלת מידע על תקופת האורח - מחזיר null (אין הגבלת זמן)
  static Future<Map<String, dynamic>?> getGuestTrialInfo(String userId) async {
    // לא נדרש - אורחים ללא הגבלת זמן
    return null;
  }
}
