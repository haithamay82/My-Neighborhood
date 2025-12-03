import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  subscriptionApproved,    // אישור מנוי
  subscriptionRejected,    // דחיית מנוי
  chatMessage,            // הודעה בצ'אט
  newRequest,             // בקשה חדשה בתחום
}

class AppNotification {
  final String notificationId;
  final String toUserId;
  final String title;
  final String message;
  final NotificationType type;
  final String? originalType; // שמירת ה-type המקורי מ-Firestore (למשל 'order_new', 'order_delivery')
  final Map<String, dynamic>? data; // נתונים נוספים (chatId, requestId, וכו')
  final DateTime createdAt;
  final bool read;
  final String? imageUrl;

  AppNotification({
    required this.notificationId,
    required this.toUserId,
    required this.title,
    required this.message,
    required this.type,
    this.originalType,
    this.data,
    required this.createdAt,
    this.read = false,
    this.imageUrl,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final originalType = data['type'] as String?;
    return AppNotification(
      notificationId: doc.id,
      toUserId: data['toUserId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == originalType,
        orElse: () => NotificationType.newRequest,
      ),
      originalType: originalType,
      data: data['data'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      read: data['read'] ?? false,
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'toUserId': toUserId,
      'title': title,
      'message': message,
      'type': type.name,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
      'imageUrl': imageUrl,
    };
  }

  AppNotification copyWith({
    String? notificationId,
    String? toUserId,
    String? title,
    String? message,
    NotificationType? type,
    String? originalType,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? read,
    String? imageUrl,
  }) {
    return AppNotification(
      notificationId: notificationId ?? this.notificationId,
      toUserId: toUserId ?? this.toUserId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      originalType: originalType ?? this.originalType,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}