import 'package:cloud_firestore/cloud_firestore.dart';
import 'request.dart';

/// מודל למודעה (Ad) - דומה ל-Request עם שדות נוספים
class Ad {
  final String adId;
  final String title;
  final String description;
  final RequestCategory category;
  final RequestLocation? location;
  final bool isUrgent;
  final List<String> images;
  final DateTime createdAt;
  final String createdBy;
  final List<String> interestedUsers; // משתמשים שהביעו עניין במודעה
  final String? phoneNumber;
  final RequestType type;
  final DateTime? deadline;
  final TargetAudience targetAudience;
  final double? maxDistance;
  final String? targetVillage;
  final List<RequestCategory>? targetCategories;
  final double? minRating;
  final double? minReliability;
  final double? minAvailability;
  final double? minAttitude;
  final double? minFairPrice;
  final UrgencyLevel urgencyLevel;
  final List<RequestTag> tags;
  final String? customTag;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? exposureRadius;
  final bool? showToProvidersOutsideRange;
  final bool? showToAllUsers;
  
  // שדות חדשים למודעה
  final double? price; // מחיר השירות (אופציונלי)
  final bool requiresAppointment; // האם השירות דורש תור
  final bool requiresDelivery; // האם השירות דורש משלוח
  final String? deliveryLocation; // כתובת משלוח (אם דורש משלוח)
  final double? deliveryLatitude; // קואורדינטות משלוח
  final double? deliveryLongitude;
  final double? deliveryRadius; // טווח משלוח בקילומטרים

  Ad({
    required this.adId,
    required this.title,
    required this.description,
    required this.category,
    this.location,
    required this.isUrgent,
    required this.images,
    required this.createdAt,
    required this.createdBy,
    required this.interestedUsers,
    this.phoneNumber,
    required this.type,
    this.deadline,
    required this.targetAudience,
    this.maxDistance,
    this.targetVillage,
    this.targetCategories,
    this.minRating,
    this.minReliability,
    this.minAvailability,
    this.minAttitude,
    this.minFairPrice,
    required this.urgencyLevel,
    required this.tags,
    this.customTag,
    this.latitude,
    this.longitude,
    this.address,
    this.exposureRadius,
    this.showToProvidersOutsideRange,
    this.showToAllUsers,
    this.price,
    required this.requiresAppointment,
    required this.requiresDelivery,
    this.deliveryLocation,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryRadius,
  });

  // Factory method from Firestore
  factory Ad.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final images = List<String>.from(data['images'] ?? []);
    final interestedUsers = List<String>.from(data['interestedUsers'] ?? []);
    final tags = (data['tags'] as List<dynamic>?)
        ?.map((e) => RequestTag.values.firstWhere(
              (tag) => tag.name == e,
              orElse: () => RequestTag.carStuck,
            ))
        .toList() ?? [];

    return Ad(
      adId: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: RequestCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => RequestCategory.plumbing,
      ),
      location: data['location'] != null
          ? RequestLocation.values.firstWhere(
              (e) => e.name == data['location'],
              orElse: () => RequestLocation.custom,
            )
          : null,
      isUrgent: data['isUrgent'] ?? false,
      images: images,
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      interestedUsers: interestedUsers,
      phoneNumber: data['phoneNumber'],
      type: RequestType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => RequestType.free,
      ),
      deadline: data['deadline'] != null && data['deadline'] is Timestamp
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      targetAudience: TargetAudience.values.firstWhere(
        (e) => e.name == data['targetAudience'],
        orElse: () => TargetAudience.all,
      ),
      maxDistance: data['maxDistance']?.toDouble(),
      targetVillage: data['targetVillage'],
      targetCategories: data['targetCategories'] != null
          ? (data['targetCategories'] as List<dynamic>)
              .map((e) => RequestCategory.values.firstWhere(
                    (cat) => cat.name == e,
                    orElse: () => RequestCategory.plumbing,
                  ))
              .toList()
          : null,
      minRating: data['minRating']?.toDouble(),
      minReliability: data['minReliability']?.toDouble(),
      minAvailability: data['minAvailability']?.toDouble(),
      minAttitude: data['minAttitude']?.toDouble(),
      minFairPrice: data['minFairPrice']?.toDouble(),
      urgencyLevel: UrgencyLevel.values.firstWhere(
        (e) => e.name == data['urgencyLevel'],
        orElse: () => UrgencyLevel.normal,
      ),
      tags: tags,
      customTag: data['customTag'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      address: data['address'],
      exposureRadius: data['exposureRadius']?.toDouble(),
      showToProvidersOutsideRange: data['showToProvidersOutsideRange'],
      showToAllUsers: data['showToAllUsers'],
      price: data['price']?.toDouble(),
      requiresAppointment: data['requiresAppointment'] ?? false,
      requiresDelivery: data['requiresDelivery'] ?? false,
      deliveryLocation: data['deliveryLocation'],
      deliveryLatitude: data['deliveryLatitude']?.toDouble(),
      deliveryLongitude: data['deliveryLongitude']?.toDouble(),
      deliveryRadius: data['deliveryRadius']?.toDouble(),
    );
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category.name,
      'location': location?.name,
      'isUrgent': isUrgent,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'interestedUsers': interestedUsers,
      'phoneNumber': phoneNumber,
      'type': type.name,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'targetAudience': targetAudience.name,
      'maxDistance': maxDistance,
      'targetVillage': targetVillage,
      'targetCategories': targetCategories?.map((e) => e.name).toList(),
      'minRating': minRating,
      'minReliability': minReliability,
      'minAvailability': minAvailability,
      'minAttitude': minAttitude,
      'minFairPrice': minFairPrice,
      'urgencyLevel': urgencyLevel.name,
      'tags': tags.map((e) => e.name).toList(),
      'customTag': customTag,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'exposureRadius': exposureRadius,
      'showToProvidersOutsideRange': showToProvidersOutsideRange,
      'showToAllUsers': showToAllUsers,
      'price': price,
      'requiresAppointment': requiresAppointment,
      'requiresDelivery': requiresDelivery,
      'deliveryLocation': deliveryLocation,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'deliveryRadius': deliveryRadius,
    };
  }
}

