import 'package:cloud_firestore/cloud_firestore.dart';

/// מודל להעדפות התראות של המשתמש
class NotificationPreferences {
  final String userId;
  
  // העדפות על בקשות חדשות
  final bool newRequestsUseFixedLocation; // רק מיקום קבוע
  final bool newRequestsUseMobileLocation; // רק מיקום נייד
  final bool newRequestsUseBothLocations; // גם וגם
  
  // העדפות על מנויים (תמיד פעיל, לא ניתן לכבות)
  final bool subscriptionExpiry; // סוף תקופה
  final bool subscriptionReminder; // תזכורת לפני סוף
  final bool subscriptionExtension; // הארכת אורח
  final bool subscriptionUpgrade; // שדרוג
  
  // העדפות על סטטוס בקשות (תמיד פעיל, לא ניתן לכבות)
  final bool requestInterest; // התעניינות
  final bool chatMessages; // הודעות בצ'אט
  final bool requestCompletion; // סיום ודירוג
  final bool radiusExpansion; // הגדלת טווח
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotificationPreferences({
    required this.userId,
    this.newRequestsUseFixedLocation = true,
    this.newRequestsUseMobileLocation = false,
    this.newRequestsUseBothLocations = false,
    this.subscriptionExpiry = true,
    this.subscriptionReminder = true,
    this.subscriptionExtension = true,
    this.subscriptionUpgrade = true,
    this.requestInterest = true,
    this.chatMessages = true,
    this.requestCompletion = true,
    this.radiusExpansion = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'newRequestsUseFixedLocation': newRequestsUseFixedLocation,
      'newRequestsUseMobileLocation': newRequestsUseMobileLocation,
      'newRequestsUseBothLocations': newRequestsUseBothLocations,
      'subscriptionExpiry': subscriptionExpiry,
      'subscriptionReminder': subscriptionReminder,
      'subscriptionExtension': subscriptionExtension,
      'subscriptionUpgrade': subscriptionUpgrade,
      'requestInterest': requestInterest,
      'chatMessages': chatMessages,
      'requestCompletion': requestCompletion,
      'radiusExpansion': radiusExpansion,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      userId: map['userId'] ?? '',
      newRequestsUseFixedLocation: map['newRequestsUseFixedLocation'] ?? true,
      newRequestsUseMobileLocation: map['newRequestsUseMobileLocation'] ?? false,
      newRequestsUseBothLocations: map['newRequestsUseBothLocations'] ?? false,
      subscriptionExpiry: map['subscriptionExpiry'] ?? true,
      subscriptionReminder: map['subscriptionReminder'] ?? true,
      subscriptionExtension: map['subscriptionExtension'] ?? true,
      subscriptionUpgrade: map['subscriptionUpgrade'] ?? true,
      requestInterest: map['requestInterest'] ?? true,
      chatMessages: map['chatMessages'] ?? true,
      requestCompletion: map['requestCompletion'] ?? true,
      radiusExpansion: map['radiusExpansion'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  NotificationPreferences copyWith({
    String? userId,
    bool? newRequestsUseFixedLocation,
    bool? newRequestsUseMobileLocation,
    bool? newRequestsUseBothLocations,
    bool? subscriptionExpiry,
    bool? subscriptionReminder,
    bool? subscriptionExtension,
    bool? subscriptionUpgrade,
    bool? requestInterest,
    bool? chatMessages,
    bool? requestCompletion,
    bool? radiusExpansion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      newRequestsUseFixedLocation: newRequestsUseFixedLocation ?? this.newRequestsUseFixedLocation,
      newRequestsUseMobileLocation: newRequestsUseMobileLocation ?? this.newRequestsUseMobileLocation,
      newRequestsUseBothLocations: newRequestsUseBothLocations ?? this.newRequestsUseBothLocations,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      subscriptionReminder: subscriptionReminder ?? this.subscriptionReminder,
      subscriptionExtension: subscriptionExtension ?? this.subscriptionExtension,
      subscriptionUpgrade: subscriptionUpgrade ?? this.subscriptionUpgrade,
      requestInterest: requestInterest ?? this.requestInterest,
      chatMessages: chatMessages ?? this.chatMessages,
      requestCompletion: requestCompletion ?? this.requestCompletion,
      radiusExpansion: radiusExpansion ?? this.radiusExpansion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt,
    );
  }
}


