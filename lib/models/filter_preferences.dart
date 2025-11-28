import 'package:cloud_firestore/cloud_firestore.dart';

class FilterPreferences {
  final String userId;
  final bool isEnabled; // האם ההתראות מופעלות
  final List<String> categories; // קטגוריות
  final double? maxRadius; // רדיוס מקסימלי
  final String? urgency; // דחיפות
  final String? requestType; // סוג בקשה (paid/free)
  final double? minRating; // דירוג מינימלי
  // מיקום נוסף (נבחר במפה)
  final double? additionalLocationLatitude;
  final double? additionalLocationLongitude;
  final double? additionalLocationRadius;
  final bool useAdditionalLocation; // האם להשתמש במיקום נוסף
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FilterPreferences({
    required this.userId,
    required this.isEnabled,
    this.categories = const [],
    this.maxRadius,
    this.urgency,
    this.requestType,
    this.minRating,
    this.additionalLocationLatitude,
    this.additionalLocationLongitude,
    this.additionalLocationRadius,
    this.useAdditionalLocation = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isEnabled': isEnabled,
      'categories': categories,
      'maxRadius': maxRadius,
      'urgency': urgency,
      'requestType': requestType,
      'minRating': minRating,
      'additionalLocationLatitude': additionalLocationLatitude,
      'additionalLocationLongitude': additionalLocationLongitude,
      'additionalLocationRadius': additionalLocationRadius,
      'useAdditionalLocation': useAdditionalLocation,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory FilterPreferences.fromMap(Map<String, dynamic> map) {
    return FilterPreferences(
      userId: map['userId'] ?? '',
      isEnabled: map['isEnabled'] ?? false,
      categories: List<String>.from(map['categories'] ?? []),
      maxRadius: map['maxRadius']?.toDouble(),
      urgency: map['urgency'],
      requestType: map['requestType'],
      minRating: map['minRating']?.toDouble(),
      additionalLocationLatitude: map['additionalLocationLatitude']?.toDouble(),
      additionalLocationLongitude: map['additionalLocationLongitude']?.toDouble(),
      additionalLocationRadius: map['additionalLocationRadius']?.toDouble(),
      useAdditionalLocation: map['useAdditionalLocation'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  FilterPreferences copyWith({
    String? userId,
    bool? isEnabled,
    List<String>? categories,
    double? maxRadius,
    String? urgency,
    String? requestType,
    double? minRating,
    double? additionalLocationLatitude,
    double? additionalLocationLongitude,
    double? additionalLocationRadius,
    bool? useAdditionalLocation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FilterPreferences(
      userId: userId ?? this.userId,
      isEnabled: isEnabled ?? this.isEnabled,
      categories: categories ?? this.categories,
      maxRadius: maxRadius ?? this.maxRadius,
      urgency: urgency ?? this.urgency,
      requestType: requestType ?? this.requestType,
      minRating: minRating ?? this.minRating,
      additionalLocationLatitude: additionalLocationLatitude ?? this.additionalLocationLatitude,
      additionalLocationLongitude: additionalLocationLongitude ?? this.additionalLocationLongitude,
      additionalLocationRadius: additionalLocationRadius ?? this.additionalLocationRadius,
      useAdditionalLocation: useAdditionalLocation ?? this.useAdditionalLocation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

