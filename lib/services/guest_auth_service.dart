import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../models/request.dart';
import 'notification_service.dart';

class GuestAuthService {
  static const int GUEST_TRIAL_DAYS = 30;
  static const int GUEST_MAX_REQUESTS = 10; // כמו עסקי מנוי
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
    final trialEndDate = now.add(Duration(days: GUEST_TRIAL_DAYS));
    
    // קבלת device ID למניעת ניצול
    final deviceId = await _getDeviceId();
    
    final guestProfile = UserProfile(
      userId: user.uid,
      displayName: displayName,
      email: email,
      userType: UserType.guest,
      createdAt: now,
      isSubscriptionActive: true, // אורח נחשב פעיל
      subscriptionStatus: 'guest_trial',
      businessCategories: selectedCategories,
      guestTrialStartDate: now,
      guestTrialEndDate: trialEndDate,
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

    // הוספת device ID למניעת ניצול
    await FirebaseFirestore.instance
        .collection('guest_devices')
        .doc(deviceId)
        .set({
      'userId': user.uid,
      'createdAt': Timestamp.fromDate(now),
      'trialEndDate': Timestamp.fromDate(trialEndDate),
    });

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

  /// בדיקה אם תקופת האורח הסתיימה
  static Future<bool> isGuestTrialExpired(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    if (data['userType'] != 'guest') return false;
    
    final trialEndDate = (data['guestTrialEndDate'] as Timestamp).toDate();
    return DateTime.now().isAfter(trialEndDate);
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
      title: 'עברת למנוי פרטי חינם',
      message: 'המידע שלך נשמר! תוכל לשדרג בכל עת לקבלת תנאים משופרים',
    );
  }

  /// בדיקה אם device כבר השתמש בתקופת אורח
  static Future<bool> hasDeviceUsedGuestTrial() async {
    final deviceId = await _getDeviceId();
    
    final doc = await FirebaseFirestore.instance
        .collection('guest_devices')
        .doc(deviceId)
        .get();
    
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    final trialEndDate = (data['trialEndDate'] as Timestamp).toDate();
    
    // אם התקופה הסתיימה, אפשר להשתמש שוב
    return DateTime.now().isBefore(trialEndDate);
  }

  /// קבלת device ID
  static Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown';
    } else {
      return 'web_${DateTime.now().millisecondsSinceEpoch}';
    }
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
          message: '${guestProfile.displayName} התחיל תקופת אורח של 30 ימים',
        );
      }
    } catch (e) {
      print('Error notifying admin about new guest: $e');
    }
  }

  /// בדיקה יומית של אורחים שצריכים לעבור לפרטי
  static Future<void> checkAndTransitionExpiredGuests() async {
    final now = DateTime.now();
    
    // מציאת אורחים שהתקופה שלהם הסתיימה
    final expiredGuestsQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('userType', isEqualTo: 'guest')
        .where('guestTrialEndDate', isLessThan: Timestamp.fromDate(now))
        .get();

    for (final guestDoc in expiredGuestsQuery.docs) {
      await transitionGuestToPersonal(guestDoc.id);
    }
  }

  /// שליחת תזכורת 7 ימים לפני סיום תקופת אורח
  static Future<void> sendTrialReminderNotifications() async {
    final sevenDaysFromNow = DateTime.now().add(Duration(days: 7));
    
    // מציאת אורחים שנותרו להם 7 ימים או פחות
    final guestsQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('userType', isEqualTo: 'guest')
        .where('guestTrialEndDate', isLessThanOrEqualTo: Timestamp.fromDate(sevenDaysFromNow))
        .get();

    for (final guestDoc in guestsQuery.docs) {
      final data = guestDoc.data();
      final trialEndDate = (data['guestTrialEndDate'] as Timestamp).toDate();
      final daysLeft = trialEndDate.difference(DateTime.now()).inDays;
      
      if (daysLeft > 0) {
        await NotificationService.sendNotification(
          toUserId: guestDoc.id,
          title: 'תקופת האורח שלך מסתיימת בקרוב',
          message: 'נותרו לך $daysLeft ימים. שדרג עכשיו כדי לשמור על הגישה המלאה!',
        );
      }
    }
  }

  /// קבלת מידע על תקופת האורח
  static Future<Map<String, dynamic>?> getGuestTrialInfo(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    if (data['userType'] != 'guest') return null;
    
    final trialStartDate = (data['guestTrialStartDate'] as Timestamp).toDate();
    final trialEndDate = (data['guestTrialEndDate'] as Timestamp).toDate();
    final now = DateTime.now();
    
    return {
      'startDate': trialStartDate,
      'endDate': trialEndDate,
      'daysLeft': trialEndDate.difference(now).inDays,
      'isExpired': now.isAfter(trialEndDate),
      'progress': (now.difference(trialStartDate).inDays / GUEST_TRIAL_DAYS * 100).clamp(0, 100),
    };
  }
}
