import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'request.dart';

enum UserType { guest, personal, business, admin }

class UserProfile {
  final String userId;
  final String displayName;
  final String email;
  final UserType userType;
  final DateTime createdAt;
  final DateTime? subscriptionExpiry; // תאריך פג תוקף המנוי
  final bool isSubscriptionActive;
  final String? subscriptionStatus; // סטטוס המנוי: private_free, pending_approval, active, rejected
  final String? requestedSubscriptionType; // סוג המנוי המבוקש: personal, business
  final String? phoneNumber;
  final bool? allowPhoneDisplay; // האם המשתמש מסכים להציג את הטלפון שלו במפה
  final String? village;
  final double? latitude;
  final double? longitude;
  final List<RequestCategory>? businessCategories; // תחומי עיסוק למשתמש עסקי
  final String? profileImageUrl; // תמונת פרופיל
  final int? recommendationsCount; // מספר המלצות של המשתמש
  final double? averageRating; // דירוג ממוצע של המשתמש
  final double? reliability; // דירוג אמינות
  final double? availability; // דירוג זמינות
  final double? attitude; // דירוג יחס
  final double? fairPrice; // דירוג מחיר הוגן
  final bool? isAdmin; // האם המשתמש הוא מנהל
  final bool? hasAcceptedTerms; // האם המשתמש אישר את תנאי השימוש ומדיניות הפרטיות
  
  // שדות עבור מערכת אורחים
  final DateTime? guestTrialStartDate; // תאריך התחלת תקופת אורח
  final DateTime? guestTrialEndDate; // תאריך סיום תקופת אורח
  final int maxRequestsPerMonth; // מספר בקשות מקסימלי לחודש
  final double maxRadius; // טווח מקסימלי בק"מ
  final bool canCreatePaidRequests; // האם יכול ליצור בקשות בתשלום
  final UserType? previousUserType; // סוג המשתמש הקודם
  final DateTime? transitionDate; // תאריך המעבר האחרון
  final bool? guestTrialExtensionReceived; // האם המשתמש כבר קיבל הארכת תקופת ניסיון
  final bool? noPaidServices; // האם המשתמש לא נותן שירותים בתשלום

  UserProfile({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.userType,
    required this.createdAt,
    this.subscriptionExpiry,
    this.isSubscriptionActive = false,
    this.subscriptionStatus = 'private_free',
    this.requestedSubscriptionType,
    this.phoneNumber,
    this.allowPhoneDisplay,
    this.village,
    this.latitude,
    this.longitude,
    this.businessCategories,
    this.profileImageUrl,
    this.recommendationsCount,
    this.averageRating,
    this.reliability,
    this.availability,
    this.attitude,
    this.fairPrice,
    this.isAdmin,
    this.hasAcceptedTerms,
    this.guestTrialStartDate,
    this.guestTrialEndDate,
    this.maxRequestsPerMonth = 3, // ברירת מחדל לפרטי חינם
    this.maxRadius = 1.0, // ברירת מחדל לפרטי חינם
    this.canCreatePaidRequests = false, // ברירת מחדל
    this.previousUserType,
    this.transitionDate,
    this.guestTrialExtensionReceived = false,
    this.noPaidServices = false,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      userId: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      userType: UserType.values.firstWhere(
        (e) => e.name == data['userType'],
        orElse: () => UserType.personal,
      ),
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      subscriptionExpiry: data['subscriptionExpiry'] != null 
          ? (data['subscriptionExpiry'] as Timestamp).toDate() 
          : null,
      isSubscriptionActive: data['isSubscriptionActive'] ?? false,
      subscriptionStatus: data['subscriptionStatus'] ?? 'private_free',
      requestedSubscriptionType: data['requestedSubscriptionType'],
      phoneNumber: data['phoneNumber'],
      allowPhoneDisplay: data['allowPhoneDisplay'] ?? false,
      village: data['village'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      businessCategories: data['businessCategories'] != null
          ? (data['businessCategories'] as List).map((e) {
              debugPrint('🔄 Converting category: $e (type: ${e.runtimeType})');
              // בדיקה אם זה נתונים עם "RequestCategory." - חילוץ השם
              if (e.toString().startsWith('RequestCategory.')) {
                final categoryName = e.toString().replaceFirst('RequestCategory.', '');
                final result = RequestCategory.values.firstWhere(
                  (cat) => cat.name == categoryName,
                  orElse: () => RequestCategory.officeServices,
                );
                debugPrint('✅ Converted RequestCategory: $categoryName -> $result');
                return result;
              } else {
                // נתונים באנגלית - המרה מ-String ל-RequestCategory
                final result = RequestCategory.values.firstWhere(
                  (cat) => cat.name == e,
                  orElse: () => RequestCategory.officeServices,
                );
                debugPrint('✅ Converted String: $e -> $result');
                return result;
              }
            }).toSet().toList() // הסרת כפילויות
          : null,
      profileImageUrl: data['profileImageUrl'],
      recommendationsCount: data['recommendationsCount'] ?? 0,
      averageRating: data['averageRating']?.toDouble() ?? 0.0,
      reliability: data['reliability']?.toDouble(),
      availability: data['availability']?.toDouble(),
      attitude: data['attitude']?.toDouble(),
      fairPrice: data['fairPrice']?.toDouble(),
      isAdmin: data['isAdmin'] ?? false,
      hasAcceptedTerms: data['hasAcceptedTerms'] ?? false,
      guestTrialStartDate: data['guestTrialStartDate'] != null 
          ? (data['guestTrialStartDate'] as Timestamp).toDate() 
          : null,
      guestTrialEndDate: data['guestTrialEndDate'] != null 
          ? (data['guestTrialEndDate'] as Timestamp).toDate() 
          : null,
      maxRequestsPerMonth: data['maxRequestsPerMonth'] ?? 3,
      maxRadius: data['maxRadius']?.toDouble() ?? 1.0,
      canCreatePaidRequests: data['canCreatePaidRequests'] ?? false,
      previousUserType: data['previousUserType'] != null 
          ? UserType.values.firstWhere(
              (e) => e.name == data['previousUserType'],
              orElse: () => UserType.personal,
            )
          : null,
      transitionDate: data['transitionDate'] != null 
          ? (data['transitionDate'] as Timestamp).toDate() 
          : null,
      guestTrialExtensionReceived: data['guestTrialExtensionReceived'] ?? false,
      noPaidServices: data['noPaidServices'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'userType': userType.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'subscriptionExpiry': subscriptionExpiry != null 
          ? Timestamp.fromDate(subscriptionExpiry!) 
          : null,
      'isSubscriptionActive': isSubscriptionActive,
      'subscriptionStatus': subscriptionStatus,
      'requestedSubscriptionType': requestedSubscriptionType,
      'phoneNumber': phoneNumber,
      'allowPhoneDisplay': allowPhoneDisplay,
      'village': village,
      'latitude': latitude,
      'longitude': longitude,
      'businessCategories': businessCategories?.map((e) => e.name).toList(),
      'profileImageUrl': profileImageUrl,
      'recommendationsCount': recommendationsCount,
      'averageRating': averageRating,
      'reliability': reliability,
      'availability': availability,
      'attitude': attitude,
      'fairPrice': fairPrice,
      'isAdmin': isAdmin,
      'hasAcceptedTerms': hasAcceptedTerms,
      'guestTrialStartDate': guestTrialStartDate != null 
          ? Timestamp.fromDate(guestTrialStartDate!) 
          : null,
      'guestTrialEndDate': guestTrialEndDate != null 
          ? Timestamp.fromDate(guestTrialEndDate!) 
          : null,
      'maxRequestsPerMonth': maxRequestsPerMonth,
      'maxRadius': maxRadius,
      'canCreatePaidRequests': canCreatePaidRequests,
      'previousUserType': previousUserType?.name,
      'transitionDate': transitionDate != null 
          ? Timestamp.fromDate(transitionDate!) 
          : null,
      'guestTrialExtensionReceived': guestTrialExtensionReceived,
      'noPaidServices': noPaidServices,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    UserType? userType,
    DateTime? subscriptionExpiry,
    bool? isSubscriptionActive,
    String? subscriptionStatus,
    String? phoneNumber,
    bool? allowPhoneDisplay,
    String? village,
    double? latitude,
    double? longitude,
    List<RequestCategory>? businessCategories,
    String? profileImageUrl,
    int? recommendationsCount,
    double? averageRating,
    double? reliability,
    double? availability,
    double? attitude,
    double? fairPrice,
    bool? isAdmin,
    bool? hasAcceptedTerms,
    DateTime? guestTrialStartDate,
    DateTime? guestTrialEndDate,
    int? maxRequestsPerMonth,
    double? maxRadius,
    bool? canCreatePaidRequests,
    UserType? previousUserType,
    DateTime? transitionDate,
    bool? guestTrialExtensionReceived,
    bool? noPaidServices,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      createdAt: createdAt,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      isSubscriptionActive: isSubscriptionActive ?? this.isSubscriptionActive,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      allowPhoneDisplay: allowPhoneDisplay ?? this.allowPhoneDisplay,
      village: village ?? this.village,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      businessCategories: businessCategories ?? this.businessCategories,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      recommendationsCount: recommendationsCount ?? this.recommendationsCount,
      averageRating: averageRating ?? this.averageRating,
      reliability: reliability ?? this.reliability,
      availability: availability ?? this.availability,
      attitude: attitude ?? this.attitude,
      fairPrice: fairPrice ?? this.fairPrice,
      isAdmin: isAdmin ?? this.isAdmin,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
      guestTrialStartDate: guestTrialStartDate ?? this.guestTrialStartDate,
      guestTrialEndDate: guestTrialEndDate ?? this.guestTrialEndDate,
      maxRequestsPerMonth: maxRequestsPerMonth ?? this.maxRequestsPerMonth,
      maxRadius: maxRadius ?? this.maxRadius,
      canCreatePaidRequests: canCreatePaidRequests ?? this.canCreatePaidRequests,
      previousUserType: previousUserType ?? this.previousUserType,
      transitionDate: transitionDate ?? this.transitionDate,
      guestTrialExtensionReceived: guestTrialExtensionReceived ?? this.guestTrialExtensionReceived,
      noPaidServices: noPaidServices ?? this.noPaidServices,
    );
  }
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.guest:
        return 'אורח';
      case UserType.personal:
        return 'פרטי';
      case UserType.business:
        return 'עסקי';
      case UserType.admin:
        return 'מנהל';
    }
  }
}
