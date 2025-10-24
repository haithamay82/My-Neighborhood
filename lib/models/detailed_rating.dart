import 'package:cloud_firestore/cloud_firestore.dart';

/// מודל דירוג מפורט עם 4 קטגוריות
class DetailedRating {
  final String ratingId;
  final String requestId;
  final String ratedUserId; // המשתמש שדורג
  final String raterUserId; // המשתמש שדירג
  final String category; // קטגוריית השירות
  final String comment; // הערה
  final DateTime createdAt;
  final String helperDisplayName;
  final String requestTitle;
  
  // 4 קטגוריות דירוג
  final int reliability; // אמינות (1-5)
  final int availability; // זמינות (1-5)
  final int attitude; // יחס (1-5)
  final int fairPrice; // מחיר הוגן (1-5)
  
  // דירוג כולל (ממוצע של 4 הקטגוריות)
  double get overallRating => (reliability + availability + attitude + fairPrice) / 4.0;

  DetailedRating({
    required this.ratingId,
    required this.requestId,
    required this.ratedUserId,
    required this.raterUserId,
    required this.category,
    required this.comment,
    required this.createdAt,
    required this.helperDisplayName,
    required this.requestTitle,
    required this.reliability,
    required this.availability,
    required this.attitude,
    required this.fairPrice,
  });

  factory DetailedRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DetailedRating(
      ratingId: doc.id,
      requestId: data['requestId'],
      ratedUserId: data['ratedUserId'],
      raterUserId: data['raterUserId'],
      category: data['category'],
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      helperDisplayName: data['helperDisplayName'],
      requestTitle: data['requestTitle'],
      reliability: data['reliability'],
      availability: data['availability'],
      attitude: data['attitude'],
      fairPrice: data['fairPrice'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'ratedUserId': ratedUserId,
      'raterUserId': raterUserId,
      'category': category,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'helperDisplayName': helperDisplayName,
      'requestTitle': requestTitle,
      'reliability': reliability,
      'availability': availability,
      'attitude': attitude,
      'fairPrice': fairPrice,
    };
  }
}

/// מודל סטטיסטיקות דירוג מפורטות
class DetailedRatingStats {
  final String userId;
  final String category;
  final double averageReliability;
  final double averageAvailability;
  final double averageAttitude;
  final double averageFairPrice;
  final double overallAverage;
  final int totalRatings;
  final DateTime lastUpdated;

  DetailedRatingStats({
    required this.userId,
    required this.category,
    required this.averageReliability,
    required this.averageAvailability,
    required this.averageAttitude,
    required this.averageFairPrice,
    required this.overallAverage,
    required this.totalRatings,
    required this.lastUpdated,
  });

  factory DetailedRatingStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DetailedRatingStats(
      userId: data['userId'],
      category: data['category'],
      averageReliability: (data['averageReliability'] as num).toDouble(),
      averageAvailability: (data['averageAvailability'] as num).toDouble(),
      averageAttitude: (data['averageAttitude'] as num).toDouble(),
      averageFairPrice: (data['averageFairPrice'] as num).toDouble(),
      overallAverage: (data['overallAverage'] as num).toDouble(),
      totalRatings: data['totalRatings'],
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'category': category,
      'averageReliability': averageReliability,
      'averageAvailability': averageAvailability,
      'averageAttitude': averageAttitude,
      'averageFairPrice': averageFairPrice,
      'overallAverage': overallAverage,
      'totalRatings': totalRatings,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
