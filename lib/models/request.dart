import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// איזורים גאוגרפיים בישראל
enum GeographicRegion {
  north,    // צפון: latitude ≥ 32.4
  center,   // מרכז: 31.75 < latitude < 32.4
  south,    // דרום: latitude ≤ 31.75
}

extension GeographicRegionExtension on GeographicRegion {
  String getDisplayName(AppLocalizations l10n) {
    switch (this) {
      case GeographicRegion.north:
        return l10n.northRegion;
      case GeographicRegion.center:
        return l10n.centerRegion;
      case GeographicRegion.south:
        return l10n.southRegion;
    }
  }
  
  String getDisplayNameHebrew() {
    switch (this) {
      case GeographicRegion.north:
        return 'צפון';
      case GeographicRegion.center:
        return 'מרכז';
      case GeographicRegion.south:
        return 'דרום';
    }
  }
}

/// פונקציה לזיהוי איזור גאוגרפי לפי קו רוחב
GeographicRegion getGeographicRegion(double? latitude) {
  if (latitude == null) {
    return GeographicRegion.center; // ברירת מחדל
  }
  
  if (latitude >= 32.4) {
    return GeographicRegion.north;
  } else if (latitude > 31.75) {
    return GeographicRegion.center;
  } else {
    return GeographicRegion.south;
  }
}

// תחומים ראשיים
enum MainCategory {
  constructionAndMaintenance,      // 🏠 בנייה, תיקונים ותחזוקה
  deliveriesAndMoving,             // 🚚 שליחויות, הובלות ושירותים מהירים
  beautyAndCosmetics,              // 🧖‍♀️ יופי, טיפוח וקוסמטיקה
  marketingAndSales,               // 🛒 שיווק ומכירות
  technologyAndComputers,          // 🛠️ טכנולוגיה, מחשבים ואפליקציות
  vehicles,                        // 🚗 כלי תחבורה
  gardeningAndCleaning,            // 🌱 גינון, ניקיון וסביבה
  educationAndTraining,            // 🎓 חינוך, לימודים והדרכה
  professionalConsulting,          // 🧭 ייעוץ והכוונה מקצועית
  artsAndMedia,                    // 🎨 יצירה, אומנות ומדיה
  specialServices,                 // 💡 שירותים מיוחדים ופתוחים
}

// תחומי משנה
enum RequestCategory {
  // 🏠 בנייה, תיקונים ותחזוקה
  plumbing,                    // אינסטלציה
  electrical,                  // חשמל
  renovations,                 // שיפוצים
  airConditioning,             // מזגנים
  carpentry,                   // נגרות
  drywall,                     // גבס
  painting,                    // צבע
  flooring,                    // ריצוף
  frames,                      // מסגרות
  waterproofing,               // איטום
  doorsAndWindows,             // דלתות וחלונות
  
  // 🚚 שליחויות, הובלות ושירותים מהירים
  foodDelivery,                // משלוחי אוכל
  groceryDelivery,             // משלוחי קניות מהסופר
  smallMoving,                 // הובלות קטנות
  largeMoving,                 // הובלות גדולות
  
  // 🧖‍♀️ יופי, טיפוח וקוסמטיקה
  manicurePedicure,            // מניקור/פדיקור
  nailExtension,              // בניית ציפורניים
  hairstyling,                // תסרוקות
  makeup,                      // איפור
  eyebrowDesign,               // עיצוב גבות
  facialTreatments,            // טיפולי פנים
  massages,                    // עיסויים
  hairRemoval,                 // הסרת שיער
  beautyTreatments,            // טיפולים
  
  // 🛒 שיווק ומכירות
  // אוכל מהיר
  shawarma,                    // שווארמה
  falafel,                     // פלאפל
  hamburger,                   // המבורגר
  pizza,                       // פיצה
  toast,                       // טוסט
  sandwiches,                  // סנדוויץ'
  // אוכל ביתי
  homeFood,                    // אוכל ביתי
  // מאפים וקינוחים
  pastriesAndDesserts,         // מאפים וקינוחים
  // אלקטרוניקה
  electronicsSales,            // אלקטרוניקה
  // כלי תחבורה (מכירה)
  vehiclesSales,               // כלי תחבורה
  // ריהוט
  furniture,                   // ריהוט
  // אופנה
  fashion,                     // אופנה
  // גיימינג
  gaming,                      // גיימינג
  // ילדים ותינוקות
  kidsAndBabies,               // ילדים ותינוקות
  // ציוד לבית ולגן
  homeAndGardenEquipment,      // ציוד לבית ולגן
  // חיות מחמד (מכירה)
  petsSales,                   // חיות מחמד
  // מוצרים מיוחדים
  specialProducts,             // מוצרים מיוחדים
  
  // 🛠️ טכנולוגיה, מחשבים ואפליקציות
  computerPhoneRepair,         // תיקוני מחשבים וטלפונים
  networksAndInternet,         // רשתות ואינטרנט
  smartHomeInstallation,       // התקנות בית חכם
  camerasAndAlarms,            // מצלמות ואזעקות
  webAppDevelopment,           // פיתוח אתרים ואפליקציות
  
  // 🚗 כלי תחבורה
  carMechanic,                 // מכונאי רכב
  carElectrician,              // חשמלאי רכב
  motorcycles,                 // אופנועים
  bicycles,                    // אופניים
  scooters,                    // קורקינטים
  towingServices,              // שירותי גרירה
  
  // 🌱 גינון, ניקיון וסביבה
  homeGardening,               // גינון ביתי
  yardCleaning,                // ניקוי חצרות
  postRenovationCleaning,      // ניקוי בתים אחרי שיפוץ
  plantsAndPets,               // טיפול בצמחים ובעלי חיים
  
  // 🎓 חינוך, לימודים והדרכה
  privateTutoring,             // שיעורים פרטיים
  coursesAndAssignments,       // קורסים ועבודות
  translation,                 // תרגום
  languageLearning,            // לימודי שפות
  
  // 🧭 ייעוץ והכוונה מקצועית
  nutritionConsulting,         // יועץ תזונה
  careerConsulting,            // יועץ קריירה
  travelConsulting,            // יועץ טיולים
  financialConsulting,        // יועץ פיננסי
  educationConsulting,         // יועץ לימודים
  personalTrainer,             // מאמן אישי
  familyCoupleCounseling,      // ייעוץ זוגי או משפחתי
  
  // 🎨 יצירה, אומנות ומדיה
  eventPhotography,            // צילום אירועים
  graphics,                    // גרפיקה
  video,                       // וידאו
  logoDesign,                  // עיצוב לוגו
  smallEventProduction,        // הפקת אירועים קטנים
  
  // 💡 שירותים מיוחדים ופתוחים
  elderlyAssistance,           // עזרה לקשישים
  youthMentoring,              // חונכות לנוער
  formFillingHelp,             // עזרה במילוי טפסים
  donations,                   // תרומות
  volunteering,                // התנדבות
  petsCare,                    // בעלי חיים
}
enum RequestLocation { custom }
enum RequestStatus { open, inProgress, completed, cancelled }
enum RequestType { free, paid }
enum TargetAudience { all, distance, village, category }

// רמות דחיפות חדשות
enum UrgencyLevel {
  normal,      // 🕓 רגיל
  urgent24h,   // ⏰ תוך 24 שעות  
  emergency,   // 🚨 דחוף
}

// תגיות דחיפות לפי קטגוריות
enum RequestTag {
  // בנייה ותיקונים
  suddenLeak,           // נזילה פתאומית
  powerOutage,          // הפסקת חשמל
  lockedOut,            // תקוע מחוץ לבית
  urgentBeforeShabbat,  // תיקון דחוף לפני שבת
  
  // רכב ותחבורה
  carStuck,             // רכב נתקע בדרך
  jumpStart,            // התנעה / כבלים
  quickParkingRepair,   // תיקון מהיר בחניה
  movingToday,          // עזרה במעבר דירה היום
  
  // משפחה וילדים
  urgentBabysitter,     // בייביסיטר דחוף
  examTomorrow,         // שיעור לפני מבחן מחר
  sickChild,            // עזרה עם ילד חולה
  zoomLessonNow,        // שיעור בזום עכשיו
  
  // עסקים ושירותים
  urgentDocument,       // מסמך דחוף
  meetingToday,         // פגישה היום
  presentationTomorrow, // מצגת מחר
  urgentTranslation,    // תרגום דחוף
  
  // אומנות ומלאכה
  weddingToday,         // חתונה היום
  urgentGift,           // מתנה דחופה
  eventTomorrow,        // אירוע מחר
  urgentCraftRepair,    // תיקון מלאכה דחוף
  
  // בריאות ורווחה
  urgentAppointment,    // תור דחוף
  emergencyCare,        // טיפול חירום
  urgentTherapy,        // טיפול דחוף
  healthEmergency,      // חירום בריאותי
  
  // שירותים טכניים
  urgentITSupport,      // תמיכה טכנית דחופה
  systemDown,           // מערכת לא עובדת
  urgentTechRepair,     // תיקון טכני דחוף
  dataRecovery,         // שחזור נתונים
  
  // חינוך והכשרה
  urgentTutoring,       // שיעור דחוף
  examPreparation,      // הכנה למבחן
  urgentCourse,         // קורס דחוף
  certificationUrgent,  // הסמכה דחופה
  
  // אירועים ובידור
  partyToday,           // מסיבה היום
  urgentEntertainment,  // בידור דחוף
  eventSetup,           // הכנת אירוע
  urgentPhotography,    // צילום דחוף
  
  // גינון וסביבה
  urgentGardenCare,     // טיפול בגן דחוף
  treeEmergency,        // חירום עץ
  urgentCleaning,       // ניקיון דחוף
  pestControl,          // הדברת מזיקים
  
  // אוכל ובישול
  urgentCatering,       // קייטרינג דחוף
  partyFood,            // אוכל למסיבה
  urgentDelivery,       // משלוח דחוף
  specialDiet,          // דיאטה מיוחדת
  
  // ספורט וכושר
  urgentTraining,       // אימון דחוף
  competitionPrep,      // הכנה לתחרות
  injuryRecovery,       // החלמה מפציעה
  urgentCoaching,       // אימון דחוף
  
  // יופי, טיפוח וקוסמטיקה (תגיות נוספות)
  eventToday,           // אירוע היום
  urgentBeforeEvent,    // דחוף לפני אירוע
  urgentBeautyFix,      // תיקון יופי דחוף
  
  // שיווק ומכירות
  urgentPurchase,       // קנייה דחופה
  urgentSale,           // מכירה דחופה
  eventShopping,        // קניות לאירוע היום
  urgentProduct,        // מוצר דחוף
  
  // שליחויות, הובלות ושירותים מהירים (תגיות נוספות)
  urgentDeliveryToday,  // משלוח דחוף היום
  urgentMoving,         // הובלה דחופה
  
  // כלי תחבורה (תגיות נוספות)
  urgentRoadRepair,     // תיקון דחוף בדרך
  urgentTowing,         // גרירה דחופה
  
  // גינון, ניקיון וסביבה (תגיות נוספות)
  urgentPostRenovation, // ניקיון דחוף אחרי שיפוץ
  
  // ייעוץ והכוונה מקצועית (תגיות נוספות)
  urgentConsultation,   // ייעוץ דחוף
  urgentMeeting,        // פגישה דחופה
  
  // שירותים מיוחדים ופתוחים (תגיות נוספות)
  urgentElderlyHelp,    // עזרה דחופה לקשיש
  urgentVolunteering,   // התנדבות דחופה
  urgentPetCare,        // טיפול דחוף בבעלי חיים
}

class Request {
  final String requestId;
  final String title;
  final String description;
  final RequestCategory category;
  final RequestLocation? location;
  final bool isUrgent;
  final List<String> images;
  final DateTime createdAt;
  final String createdBy;
  final RequestStatus status;
  final List<String> helpers;
  final String? phoneNumber;
  final RequestType type;
  final DateTime? deadline;
  final TargetAudience targetAudience;
  final double? maxDistance; // קילומטרים
  final String? targetVillage;
  final List<RequestCategory>? targetCategories;
  final double? minRating; // דירוג מינימלי (לשמירת תאימות)
  final double? minReliability; // דירוג מינימלי אמינות
  final double? minAvailability; // דירוג מינימלי זמינות
  final double? minAttitude; // דירוג מינימלי יחס
  final double? minFairPrice; // דירוג מינימלי מחיר הוגן
  
  // שדות דחיפות חדשים
  final UrgencyLevel urgencyLevel; // רמת דחיפות
  final List<RequestTag> tags; // תגיות דחיפות
  final String? customTag; // תגית מותאמת אישית
  
  // Location coordinates
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? exposureRadius; // רדיוס חשיפה בקילומטרים
  
  // מחיר (אופציונאלי) - רק לבקשות בתשלום
  final double? price; // המחיר שהמשתמש חושב שישלם עבור השירות
  
  // האם להציג בקשה לנותני שירות שלא בטווח שהגדרת
  final bool? showToProvidersOutsideRange; // null = לא נבחר, true = כן, false = לא
  final bool? showToAllUsers; // null = לא נבחר, true = לכל המשתמשים, false = רק לנותני שירות מתחום X

  Request({
    required this.requestId,
    required this.title,
    required this.description,
    required this.category,
    this.location,
    required this.isUrgent,
    required this.images,
    required this.createdAt,
    required this.createdBy,
    required this.status,
    required this.helpers,
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
    this.price,
    this.showToProvidersOutsideRange,
    this.showToAllUsers,
  });

  // ⬇️ Lightweight factory - only loads essential fields for initial list view
  factory Request.fromFirestoreLightweight(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final images = List<String>.from(data['images'] ?? []);
    
    return Request(
      requestId: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '', // Keep description for card preview
      category: RequestCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => RequestCategory.plumbing,
      ),
      location: null, // Skip location parsing for lightweight
      isUrgent: data['isUrgent'] ?? false,
      images: images,
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      status: RequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RequestStatus.open,
      ),
      helpers: List<String>.from(data['helpers'] ?? []),
      phoneNumber: data['phoneNumber'] as String?, // Load phoneNumber for display
      type: RequestType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => RequestType.free,
      ),
      deadline: data['deadline'] != null && data['deadline'] is Timestamp ? (data['deadline'] as Timestamp).toDate() : null,
      targetAudience: TargetAudience.all, // Default for lightweight
      maxDistance: null, // Skip for lightweight
      targetVillage: null, // Skip for lightweight
      targetCategories: null, // Skip for lightweight
      minRating: null, // Skip for lightweight
      minReliability: null, // Skip for lightweight
      minAvailability: null, // Skip for lightweight
      minAttitude: null, // Skip for lightweight
      minFairPrice: null, // Skip for lightweight
      urgencyLevel: UrgencyLevel.values.firstWhere(
        (e) => e.name == data['urgencyLevel'],
        orElse: () => UrgencyLevel.normal,
      ),
      tags: data['tags'] != null 
          ? (data['tags'] as List).map((e) => RequestTag.values.firstWhere(
              (tag) => tag.name == e,
              orElse: () => RequestTag.carStuck,
            )).toList()
          : [],
      customTag: data['customTag'],
      latitude: data['latitude']?.toDouble(), // Keep for distance calculation
      longitude: data['longitude']?.toDouble(), // Keep for distance calculation
      address: data['address'], // Keep address for display
      exposureRadius: data['exposureRadius']?.toDouble(),
      price: data['price']?.toDouble(), // Keep price for display // Keep for filtering
      showToProvidersOutsideRange: data['showToProvidersOutsideRange'] as bool?,
      showToAllUsers: data['showToAllUsers'] as bool?,
    );
  }

  factory Request.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Request(
      requestId: doc.id,
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
      images: List<String>.from(data['images'] ?? []),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      status: RequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RequestStatus.open,
      ),
      helpers: List<String>.from(data['helpers'] ?? []),
      phoneNumber: data['phoneNumber'],
      type: RequestType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => RequestType.free,
      ),
      deadline: data['deadline'] != null && data['deadline'] is Timestamp ? (data['deadline'] as Timestamp).toDate() : null,
      targetAudience: TargetAudience.values.firstWhere(
        (e) => e.name == data['targetAudience'],
        orElse: () => TargetAudience.all,
      ),
      maxDistance: data['maxDistance']?.toDouble(),
      targetVillage: data['targetVillage'],
      targetCategories: data['targetCategories'] != null 
          ? (data['targetCategories'] as List).map((e) => RequestCategory.values.firstWhere(
              (cat) => cat.name == e,
              orElse: () => RequestCategory.plumbing,
            )).toList()
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
      tags: data['tags'] != null 
          ? (data['tags'] as List).map((e) => RequestTag.values.firstWhere(
              (tag) => tag.name == e,
              orElse: () => RequestTag.carStuck, // default fallback
            )).toList()
          : [],
      customTag: data['customTag'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      address: data['address'],
      exposureRadius: data['exposureRadius']?.toDouble(),
      price: data['price']?.toDouble(),
      showToProvidersOutsideRange: data['showToProvidersOutsideRange'] as bool?,
      showToAllUsers: data['showToAllUsers'] as bool?,
    );
  }

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
      'status': status.name,
      'helpers': helpers,
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
      'price': price,
      'showToProvidersOutsideRange': showToProvidersOutsideRange,
      'showToAllUsers': showToAllUsers,
    };
  }

  String get categoryDisplayName {
    switch (category) {
      // 🏠 בנייה, תיקונים ותחזוקה
      case RequestCategory.plumbing:
        return 'אינסטלציה';
      case RequestCategory.electrical:
        return 'חשמל';
      case RequestCategory.renovations:
        return 'שיפוצים';
      case RequestCategory.airConditioning:
        return 'מזגנים';
      case RequestCategory.carpentry:
        return 'נגרות';
      case RequestCategory.drywall:
        return 'גבס';
      case RequestCategory.painting:
        return 'צבע';
      case RequestCategory.flooring:
        return 'ריצוף';
      case RequestCategory.frames:
        return 'מסגרות';
      case RequestCategory.waterproofing:
        return 'איטום';
      case RequestCategory.doorsAndWindows:
        return 'דלתות וחלונות';
      
      // 🚚 שליחויות, הובלות ושירותים מהירים
      case RequestCategory.foodDelivery:
        return 'משלוחי אוכל';
      case RequestCategory.groceryDelivery:
        return 'משלוחי קניות מהסופר';
      case RequestCategory.smallMoving:
        return 'הובלות קטנות';
      case RequestCategory.largeMoving:
        return 'הובלות גדולות';
      
      // 🧖‍♀️ יופי, טיפוח וקוסמטיקה
      case RequestCategory.manicurePedicure:
        return 'מניקור/פדיקור';
      case RequestCategory.nailExtension:
        return 'בניית ציפורניים';
      case RequestCategory.hairstyling:
        return 'תסרוקות';
      case RequestCategory.makeup:
        return 'איפור';
      case RequestCategory.eyebrowDesign:
        return 'עיצוב גבות';
      case RequestCategory.facialTreatments:
        return 'טיפולי פנים';
      case RequestCategory.massages:
        return 'עיסויים';
      case RequestCategory.hairRemoval:
        return 'הסרת שיער';
      case RequestCategory.beautyTreatments:
        return 'טיפולים';
      
      // 🛒 שיווק ומכירות
      // אוכל מהיר
      case RequestCategory.shawarma:
        return 'שווארמה';
      case RequestCategory.falafel:
        return 'פלאפל';
      case RequestCategory.hamburger:
        return 'המבורגר';
      case RequestCategory.pizza:
        return 'פיצה';
      case RequestCategory.toast:
        return 'טוסט';
      case RequestCategory.sandwiches:
        return 'סנדוויץ\'';
      // אוכל ביתי
      case RequestCategory.homeFood:
        return 'אוכל ביתי';
      // מאפים וקינוחים
      case RequestCategory.pastriesAndDesserts:
        return 'מאפים וקינוחים';
      // אלקטרוניקה
      case RequestCategory.electronicsSales:
        return 'אלקטרוניקה';
      // כלי תחבורה (מכירה)
      case RequestCategory.vehiclesSales:
        return 'כלי תחבורה';
      // ריהוט
      case RequestCategory.furniture:
        return 'ריהוט';
      // אופנה
      case RequestCategory.fashion:
        return 'אופנה';
      // גיימינג
      case RequestCategory.gaming:
        return 'גיימינג';
      // ילדים ותינוקות
      case RequestCategory.kidsAndBabies:
        return 'ילדים ותינוקות';
      // ציוד לבית ולגן
      case RequestCategory.homeAndGardenEquipment:
        return 'ציוד לבית ולגן';
      // חיות מחמד (מכירה)
      case RequestCategory.petsSales:
        return 'חיות מחמד';
      // מוצרים מיוחדים
      case RequestCategory.specialProducts:
        return 'מוצרים מיוחדים';
      
      // 🛠️ טכנולוגיה, מחשבים ואפליקציות
      case RequestCategory.computerPhoneRepair:
        return 'תיקוני מחשבים וטלפונים';
      case RequestCategory.networksAndInternet:
        return 'רשתות ואינטרנט';
      case RequestCategory.smartHomeInstallation:
        return 'התקנות בית חכם';
      case RequestCategory.camerasAndAlarms:
        return 'מצלמות ואזעקות';
      case RequestCategory.webAppDevelopment:
        return 'פיתוח אתרים ואפליקציות';
      
      // 🚗 כלי תחבורה
      case RequestCategory.carMechanic:
        return 'מכונאי רכב';
      case RequestCategory.carElectrician:
        return 'חשמלאי רכב';
      case RequestCategory.motorcycles:
        return 'אופנועים';
      case RequestCategory.bicycles:
        return 'אופניים';
      case RequestCategory.scooters:
        return 'קורקינטים';
      case RequestCategory.towingServices:
        return 'שירותי גרירה';
      
      // 🌱 גינון, ניקיון וסביבה
      case RequestCategory.homeGardening:
        return 'גינון ביתי';
      case RequestCategory.yardCleaning:
        return 'ניקוי חצרות';
      case RequestCategory.postRenovationCleaning:
        return 'ניקוי בתים אחרי שיפוץ';
      case RequestCategory.plantsAndPets:
        return 'טיפול בצמחים ובעלי חיים';
      
      // 🎓 חינוך, לימודים והדרכה
      case RequestCategory.privateTutoring:
        return 'שיעורים פרטיים';
      case RequestCategory.coursesAndAssignments:
        return 'קורסים ועבודות';
      case RequestCategory.translation:
        return 'תרגום';
      case RequestCategory.languageLearning:
        return 'לימודי שפות';
      
      // 🧭 ייעוץ והכוונה מקצועית
      case RequestCategory.nutritionConsulting:
        return 'יועץ תזונה';
      case RequestCategory.careerConsulting:
        return 'יועץ קריירה';
      case RequestCategory.travelConsulting:
        return 'יועץ טיולים';
      case RequestCategory.financialConsulting:
        return 'יועץ פיננסי';
      case RequestCategory.educationConsulting:
        return 'יועץ לימודים';
      case RequestCategory.personalTrainer:
        return 'מאמן אישי';
      case RequestCategory.familyCoupleCounseling:
        return 'ייעוץ זוגי או משפחתי';
      
      // 🎨 יצירה, אומנות ומדיה
      case RequestCategory.eventPhotography:
        return 'צילום אירועים';
      case RequestCategory.graphics:
        return 'גרפיקה';
      case RequestCategory.video:
        return 'וידאו';
      case RequestCategory.logoDesign:
        return 'עיצוב לוגו';
      case RequestCategory.smallEventProduction:
        return 'הפקת אירועים קטנים';
      
      // 💡 שירותים מיוחדים ופתוחים
      case RequestCategory.elderlyAssistance:
        return 'עזרה לקשישים';
      case RequestCategory.youthMentoring:
        return 'חונכות לנוער';
      case RequestCategory.formFillingHelp:
        return 'עזרה במילוי טפסים';
      case RequestCategory.donations:
        return 'תרומות';
      case RequestCategory.volunteering:
        return 'התנדבות';
      case RequestCategory.petsCare:
        return 'בעלי חיים';
    }
  }

  String get locationDisplayName {
    if (location == RequestLocation.custom) {
      return address ?? 'מיקום מותאם אישית';
    }
    return 'ללא מיקום';
  }
}

extension RequestCategoryExtension on RequestCategory {
  String get categoryDisplayName {
    switch (this) {
      // 🏠 בנייה, תיקונים ותחזוקה
      case RequestCategory.plumbing:
        return 'אינסטלציה';
      case RequestCategory.electrical:
        return 'חשמל';
      case RequestCategory.renovations:
        return 'שיפוצים';
      case RequestCategory.airConditioning:
        return 'מזגנים';
      case RequestCategory.carpentry:
        return 'נגרות';
      case RequestCategory.drywall:
        return 'גבס';
      case RequestCategory.painting:
        return 'צבע';
      case RequestCategory.flooring:
        return 'ריצוף';
      case RequestCategory.frames:
        return 'מסגרות';
      case RequestCategory.waterproofing:
        return 'איטום';
      case RequestCategory.doorsAndWindows:
        return 'דלתות וחלונות';
      
      // 🚚 שליחויות, הובלות ושירותים מהירים
      case RequestCategory.foodDelivery:
        return 'משלוחי אוכל';
      case RequestCategory.groceryDelivery:
        return 'משלוחי קניות מהסופר';
      case RequestCategory.smallMoving:
        return 'הובלות קטנות';
      case RequestCategory.largeMoving:
        return 'הובלות גדולות';
      
      // 🧖‍♀️ יופי, טיפוח וקוסמטיקה
      case RequestCategory.manicurePedicure:
        return 'מניקור/פדיקור';
      case RequestCategory.nailExtension:
        return 'בניית ציפורניים';
      case RequestCategory.hairstyling:
        return 'תסרוקות';
      case RequestCategory.makeup:
        return 'איפור';
      case RequestCategory.eyebrowDesign:
        return 'עיצוב גבות';
      case RequestCategory.facialTreatments:
        return 'טיפולי פנים';
      case RequestCategory.massages:
        return 'עיסויים';
      case RequestCategory.hairRemoval:
        return 'הסרת שיער';
      case RequestCategory.beautyTreatments:
        return 'טיפולים';
      
      // 🛒 שיווק ומכירות
      // אוכל מהיר
      case RequestCategory.shawarma:
        return 'שווארמה';
      case RequestCategory.falafel:
        return 'פלאפל';
      case RequestCategory.hamburger:
        return 'המבורגר';
      case RequestCategory.pizza:
        return 'פיצה';
      case RequestCategory.toast:
        return 'טוסט';
      case RequestCategory.sandwiches:
        return 'סנדוויץ\'';
      // אוכל ביתי
      case RequestCategory.homeFood:
        return 'אוכל ביתי';
      // מאפים וקינוחים
      case RequestCategory.pastriesAndDesserts:
        return 'מאפים וקינוחים';
      // אלקטרוניקה
      case RequestCategory.electronicsSales:
        return 'אלקטרוניקה';
      // כלי תחבורה (מכירה)
      case RequestCategory.vehiclesSales:
        return 'כלי תחבורה';
      // ריהוט
      case RequestCategory.furniture:
        return 'ריהוט';
      // אופנה
      case RequestCategory.fashion:
        return 'אופנה';
      // גיימינג
      case RequestCategory.gaming:
        return 'גיימינג';
      // ילדים ותינוקות
      case RequestCategory.kidsAndBabies:
        return 'ילדים ותינוקות';
      // ציוד לבית ולגן
      case RequestCategory.homeAndGardenEquipment:
        return 'ציוד לבית ולגן';
      // חיות מחמד (מכירה)
      case RequestCategory.petsSales:
        return 'חיות מחמד';
      // מוצרים מיוחדים
      case RequestCategory.specialProducts:
        return 'מוצרים מיוחדים';
      
      // 🛠️ טכנולוגיה, מחשבים ואפליקציות
      case RequestCategory.computerPhoneRepair:
        return 'תיקוני מחשבים וטלפונים';
      case RequestCategory.networksAndInternet:
        return 'רשתות ואינטרנט';
      case RequestCategory.smartHomeInstallation:
        return 'התקנות בית חכם';
      case RequestCategory.camerasAndAlarms:
        return 'מצלמות ואזעקות';
      case RequestCategory.webAppDevelopment:
        return 'פיתוח אתרים ואפליקציות';
      
      // 🚗 כלי תחבורה
      case RequestCategory.carMechanic:
        return 'מכונאי רכב';
      case RequestCategory.carElectrician:
        return 'חשמלאי רכב';
      case RequestCategory.motorcycles:
        return 'אופנועים';
      case RequestCategory.bicycles:
        return 'אופניים';
      case RequestCategory.scooters:
        return 'קורקינטים';
      case RequestCategory.towingServices:
        return 'שירותי גרירה';
      
      // 🌱 גינון, ניקיון וסביבה
      case RequestCategory.homeGardening:
        return 'גינון ביתי';
      case RequestCategory.yardCleaning:
        return 'ניקוי חצרות';
      case RequestCategory.postRenovationCleaning:
        return 'ניקוי בתים אחרי שיפוץ';
      case RequestCategory.plantsAndPets:
        return 'טיפול בצמחים ובעלי חיים';
      
      // 🎓 חינוך, לימודים והדרכה
      case RequestCategory.privateTutoring:
        return 'שיעורים פרטיים';
      case RequestCategory.coursesAndAssignments:
        return 'קורסים ועבודות';
      case RequestCategory.translation:
        return 'תרגום';
      case RequestCategory.languageLearning:
        return 'לימודי שפות';
      
      // 🧭 ייעוץ והכוונה מקצועית
      case RequestCategory.nutritionConsulting:
        return 'יועץ תזונה';
      case RequestCategory.careerConsulting:
        return 'יועץ קריירה';
      case RequestCategory.travelConsulting:
        return 'יועץ טיולים';
      case RequestCategory.financialConsulting:
        return 'יועץ פיננסי';
      case RequestCategory.educationConsulting:
        return 'יועץ לימודים';
      case RequestCategory.personalTrainer:
        return 'מאמן אישי';
      case RequestCategory.familyCoupleCounseling:
        return 'ייעוץ זוגי או משפחתי';
      
      // 🎨 יצירה, אומנות ומדיה
      case RequestCategory.eventPhotography:
        return 'צילום אירועים';
      case RequestCategory.graphics:
        return 'גרפיקה';
      case RequestCategory.video:
        return 'וידאו';
      case RequestCategory.logoDesign:
        return 'עיצוב לוגו';
      case RequestCategory.smallEventProduction:
        return 'הפקת אירועים קטנים';
      
      // 💡 שירותים מיוחדים ופתוחים
      case RequestCategory.elderlyAssistance:
        return 'עזרה לקשישים';
      case RequestCategory.youthMentoring:
        return 'חונכות לנוער';
      case RequestCategory.formFillingHelp:
        return 'עזרה במילוי טפסים';
      case RequestCategory.donations:
        return 'תרומות';
      case RequestCategory.volunteering:
        return 'התנדבות';
      case RequestCategory.petsCare:
        return 'בעלי חיים';
    }
  }

  // פונקציה לקבלת התחום הראשי
  MainCategory get mainCategory {
    switch (this) {
      // 🏠 בנייה, תיקונים ותחזוקה
      case RequestCategory.plumbing:
      case RequestCategory.electrical:
      case RequestCategory.renovations:
      case RequestCategory.airConditioning:
      case RequestCategory.carpentry:
      case RequestCategory.drywall:
      case RequestCategory.painting:
      case RequestCategory.flooring:
      case RequestCategory.frames:
      case RequestCategory.waterproofing:
      case RequestCategory.doorsAndWindows:
        return MainCategory.constructionAndMaintenance;
      
      // 🚚 שליחויות, הובלות ושירותים מהירים
      case RequestCategory.foodDelivery:
      case RequestCategory.groceryDelivery:
      case RequestCategory.smallMoving:
      case RequestCategory.largeMoving:
        return MainCategory.deliveriesAndMoving;
      
      // 🧖‍♀️ יופי, טיפוח וקוסמטיקה
      case RequestCategory.manicurePedicure:
      case RequestCategory.nailExtension:
      case RequestCategory.hairstyling:
      case RequestCategory.makeup:
      case RequestCategory.eyebrowDesign:
      case RequestCategory.facialTreatments:
      case RequestCategory.massages:
      case RequestCategory.hairRemoval:
      case RequestCategory.beautyTreatments:
        return MainCategory.beautyAndCosmetics;
      
      // 🛒 שיווק ומכירות
      case RequestCategory.shawarma:
      case RequestCategory.falafel:
      case RequestCategory.hamburger:
      case RequestCategory.pizza:
      case RequestCategory.toast:
      case RequestCategory.sandwiches:
      case RequestCategory.homeFood:
      case RequestCategory.pastriesAndDesserts:
      case RequestCategory.electronicsSales:
      case RequestCategory.vehiclesSales:
      case RequestCategory.furniture:
      case RequestCategory.fashion:
      case RequestCategory.gaming:
      case RequestCategory.kidsAndBabies:
      case RequestCategory.homeAndGardenEquipment:
      case RequestCategory.petsSales:
      case RequestCategory.specialProducts:
        return MainCategory.marketingAndSales;
      
      // 🛠️ טכנולוגיה, מחשבים ואפליקציות
      case RequestCategory.computerPhoneRepair:
      case RequestCategory.networksAndInternet:
      case RequestCategory.smartHomeInstallation:
      case RequestCategory.camerasAndAlarms:
      case RequestCategory.webAppDevelopment:
        return MainCategory.technologyAndComputers;
      
      // 🚗 כלי תחבורה
      case RequestCategory.carMechanic:
      case RequestCategory.carElectrician:
      case RequestCategory.motorcycles:
      case RequestCategory.bicycles:
      case RequestCategory.scooters:
      case RequestCategory.towingServices:
        return MainCategory.vehicles;
      
      // 🌱 גינון, ניקיון וסביבה
      case RequestCategory.homeGardening:
      case RequestCategory.yardCleaning:
      case RequestCategory.postRenovationCleaning:
      case RequestCategory.plantsAndPets:
        return MainCategory.gardeningAndCleaning;
      
      // 🎓 חינוך, לימודים והדרכה
      case RequestCategory.privateTutoring:
      case RequestCategory.coursesAndAssignments:
      case RequestCategory.translation:
      case RequestCategory.languageLearning:
        return MainCategory.educationAndTraining;
      
      // 🧭 ייעוץ והכוונה מקצועית
      case RequestCategory.nutritionConsulting:
      case RequestCategory.careerConsulting:
      case RequestCategory.travelConsulting:
      case RequestCategory.financialConsulting:
      case RequestCategory.educationConsulting:
      case RequestCategory.personalTrainer:
      case RequestCategory.familyCoupleCounseling:
        return MainCategory.professionalConsulting;
      
      // 🎨 יצירה, אומנות ומדיה
      case RequestCategory.eventPhotography:
      case RequestCategory.graphics:
      case RequestCategory.video:
      case RequestCategory.logoDesign:
      case RequestCategory.smallEventProduction:
        return MainCategory.artsAndMedia;
      
      // 💡 שירותים מיוחדים ופתוחים
      case RequestCategory.elderlyAssistance:
      case RequestCategory.youthMentoring:
      case RequestCategory.formFillingHelp:
      case RequestCategory.donations:
      case RequestCategory.volunteering:
      case RequestCategory.petsCare:
        return MainCategory.specialServices;
    }
  }
}

extension MainCategoryExtension on MainCategory {
  String get displayName {
    switch (this) {
      case MainCategory.constructionAndMaintenance:
        return 'בנייה, תיקונים ותחזוקה';
      case MainCategory.deliveriesAndMoving:
        return 'שליחויות, הובלות ושירותים מהירים';
      case MainCategory.beautyAndCosmetics:
        return 'יופי, טיפוח וקוסמטיקה';
      case MainCategory.marketingAndSales:
        return 'שיווק ומכירות';
      case MainCategory.technologyAndComputers:
        return 'טכנולוגיה, מחשבים ואפליקציות';
      case MainCategory.vehicles:
        return 'כלי תחבורה';
      case MainCategory.gardeningAndCleaning:
        return 'גינון, ניקיון וסביבה';
      case MainCategory.educationAndTraining:
        return 'חינוך, לימודים והדרכה';
      case MainCategory.professionalConsulting:
        return 'ייעוץ והכוונה מקצועית';
      case MainCategory.artsAndMedia:
        return 'יצירה, אומנות ומדיה';
      case MainCategory.specialServices:
        return 'שירותים מיוחדים ופתוחים';
    }
  }

  String get icon {
    switch (this) {
      case MainCategory.constructionAndMaintenance:
        return '🏠';
      case MainCategory.deliveriesAndMoving:
        return '🚚';
      case MainCategory.beautyAndCosmetics:
        return '🧖‍♀️';
      case MainCategory.marketingAndSales:
        return '🛒';
      case MainCategory.technologyAndComputers:
        return '🛠️';
      case MainCategory.vehicles:
        return '🚗';
      case MainCategory.gardeningAndCleaning:
        return '🌱';
      case MainCategory.educationAndTraining:
        return '🎓';
      case MainCategory.professionalConsulting:
        return '🧭';
      case MainCategory.artsAndMedia:
        return '🎨';
      case MainCategory.specialServices:
        return '💡';
    }
  }
}

extension RequestLocationExtension on RequestLocation {
  String get locationDisplayName {
    switch (this) {
      case RequestLocation.custom:
        return 'מיקום מותאם אישית';
    }
  }
}

extension RequestStatusExtension on RequestStatus {
  String statusDisplayName(AppLocalizations l10n) {
    // ✅ Safe: All status getters now use _safeGet with fallbacks
    switch (this) {
      case RequestStatus.open:
        return l10n.open;
      case RequestStatus.inProgress:
        return l10n.inProgress;
      case RequestStatus.completed:
        return l10n.completed;
      case RequestStatus.cancelled:
        return l10n.cancelled;
    }
  }
}

extension RequestPhoneExtension on Request {
  String? get formattedPhoneNumber {
    if (phoneNumber == null || phoneNumber!.isEmpty) {
      debugPrint('📞 formattedPhoneNumber: phoneNumber is null or empty');
      return null;
    }
    
    final phone = phoneNumber!.trim();
    if (phone.isEmpty) {
      debugPrint('📞 formattedPhoneNumber: phone is empty after trim');
      return null;
    }
    
    debugPrint('📞 formattedPhoneNumber: Processing phone: $phone');
    
    // אם המספר כבר בפורמט prefix-number (למשל 050-1234567), נהפוך אותו לפורמט 050-123-4567
    if (phone.contains('-')) {
      final parts = phone.split('-');
      
      // אם המספר כבר בפורמט הנכון (למשל 050-123-4567), נחזיר אותו כפי שהוא
      if (parts.length == 3) {
        return phone;
      }
      
      if (parts.length == 2) {
        final prefix = parts[0].trim();
        final number = parts[1].trim();
        
        // אם הקידומת היא 3 ספרות והמספר הוא 7 ספרות (למשל 050-1234567), נהפוך אותו לפורמט 050-123-4567
        if (prefix.length == 3 && number.length == 7) {
          return '$prefix-${number.substring(0, 3)}-${number.substring(3)}';
        }
        
        // אם הקידומת היא 2 ספרות והמספר הוא 6 ספרות (למשל 02-123456), נהפוך אותו לפורמט 02-123-456
        if (prefix.length == 2 && number.length == 6) {
          return '$prefix-${number.substring(0, 3)}-${number.substring(3)}';
        }
        
        // אם הקידומת היא 2 ספרות והמספר הוא 7 ספרות (למשל 04-1234567), נהפוך אותו לפורמט 04-123-4567
        if (prefix.length == 2 && number.length == 7) {
          return '$prefix-${number.substring(0, 3)}-${number.substring(3)}';
        }
        
        // אם הקידומת היא 3 ספרות והמספר הוא 6 ספרות (למשל 050-123456), נהפוך אותו לפורמט 050-123-456
        if (prefix.length == 3 && number.length == 6) {
          return '$prefix-${number.substring(0, 3)}-${number.substring(3)}';
        }
        
        // אם הקידומת והמספר לא ריקים, נחזיר אותם בפורמט prefix-number (לפחות יש מספר)
        if (prefix.isNotEmpty && number.isNotEmpty) {
          debugPrint('📞 formattedPhoneNumber: Returning phone as-is: $phone');
          return phone; // נחזיר את המספר כפי שהוא (לפחות יש מספר)
        }
      }
    }
    
    // הסרת מקפים קיימים לטיפול
    final cleanPhone = phone.replaceAll('-', '').replaceAll(' ', '');
    
    // פורמט למספרי סלולר (05X-XXX-XXXX)
    if (cleanPhone.length == 10 && cleanPhone.startsWith('05')) {
      return '${cleanPhone.substring(0, 3)}-${cleanPhone.substring(3, 6)}-${cleanPhone.substring(6)}';
    }
    
    // פורמט למספרי קווי (0XX-XXX-XXXX או 0XXX-XXX-XXX)
    if (cleanPhone.length == 9) {
      return '${cleanPhone.substring(0, 3)}-${cleanPhone.substring(3, 6)}-${cleanPhone.substring(6)}';
    } else if (cleanPhone.length == 10) {
      return '${cleanPhone.substring(0, 3)}-${cleanPhone.substring(3, 6)}-${cleanPhone.substring(6)}';
    }
    
    // אם לא מתאים לאף פורמט, אבל יש תוכן, נחזיר אותו (לפחות יש מספר)
    if (phone.isNotEmpty) {
      debugPrint('📞 formattedPhoneNumber: Returning phone as fallback: $phone');
      return phone;
    }
    
    debugPrint('📞 formattedPhoneNumber: Returning null');
    return null;
  }
}

extension RequestTypeExtension on RequestType {
  String typeDisplayName(AppLocalizations l10n) {
    switch (this) {
      case RequestType.free:
        return l10n.free;
      case RequestType.paid:
        return l10n.paid;
    }
  }
}

extension TargetAudienceExtension on TargetAudience {
  String audienceDisplayName(AppLocalizations l10n) {
    switch (this) {
      case TargetAudience.all:
        return l10n.all;
      case TargetAudience.distance:
        return l10n.distance;
      case TargetAudience.village:
        return l10n.selectVillage;
      case TargetAudience.category:
        return l10n.category;
    }
  }
}

// Extensions חדשים לדחיפות
extension UrgencyLevelExtension on UrgencyLevel {
  String get displayName {
    switch (this) {
      case UrgencyLevel.normal:
        return '🕓 רגיל';
      case UrgencyLevel.urgent24h:
        return '⏰ תוך 24 שעות';
      case UrgencyLevel.emergency:
        return '🚨 דחוף';
    }
  }
  
  Color get color {
    switch (this) {
      case UrgencyLevel.normal:
        return Colors.blue;
      case UrgencyLevel.urgent24h:
        return Colors.orange;
      case UrgencyLevel.emergency:
        return Colors.red;
    }
  }
}

extension RequestTagExtension on RequestTag {
  String displayName(AppLocalizations l10n) {
    switch (this) {
      // בנייה ותיקונים
      case RequestTag.suddenLeak:
        return l10n.tagSuddenLeak;
      case RequestTag.powerOutage:
        return l10n.tagPowerOutage;
      case RequestTag.lockedOut:
        return l10n.tagLockedOut;
      case RequestTag.urgentBeforeShabbat:
        return l10n.tagUrgentBeforeShabbat;
      
      // רכב ותחבורה
      case RequestTag.carStuck:
        return l10n.tagCarStuck;
      case RequestTag.jumpStart:
        return l10n.tagJumpStart;
      case RequestTag.quickParkingRepair:
        return l10n.tagQuickParkingRepair;
      case RequestTag.movingToday:
        return l10n.tagMovingToday;
      
      // משפחה וילדים
      case RequestTag.urgentBabysitter:
        return l10n.tagUrgentBabysitter;
      case RequestTag.examTomorrow:
        return l10n.tagExamTomorrow;
      case RequestTag.sickChild:
        return l10n.tagSickChild;
      case RequestTag.zoomLessonNow:
        return l10n.tagZoomLessonNow;
      
      // עסקים ושירותים
      case RequestTag.urgentDocument:
        return l10n.tagUrgentDocument;
      case RequestTag.meetingToday:
        return l10n.tagMeetingToday;
      case RequestTag.presentationTomorrow:
        return l10n.tagPresentationTomorrow;
      case RequestTag.urgentTranslation:
        return l10n.tagUrgentTranslation;
      
      // אומנות ומלאכה
      case RequestTag.weddingToday:
        return l10n.tagWeddingToday;
      case RequestTag.urgentGift:
        return l10n.tagUrgentGift;
      case RequestTag.eventTomorrow:
        return l10n.tagEventTomorrow;
      case RequestTag.urgentCraftRepair:
        return l10n.tagUrgentCraftRepair;
      
      // בריאות ורווחה
      case RequestTag.urgentAppointment:
        return l10n.tagUrgentAppointment;
      case RequestTag.emergencyCare:
        return l10n.tagEmergencyCare;
      case RequestTag.urgentTherapy:
        return l10n.tagUrgentTherapy;
      case RequestTag.healthEmergency:
        return l10n.tagHealthEmergency;
      
      // שירותים טכניים
      case RequestTag.urgentITSupport:
        return l10n.tagUrgentITSupport;
      case RequestTag.systemDown:
        return l10n.tagSystemDown;
      case RequestTag.urgentTechRepair:
        return l10n.tagUrgentTechRepair;
      case RequestTag.dataRecovery:
        return l10n.tagDataRecovery;
      
      // חינוך והכשרה
      case RequestTag.urgentTutoring:
        return l10n.tagUrgentTutoring;
      case RequestTag.examPreparation:
        return l10n.tagExamPreparation;
      case RequestTag.urgentCourse:
        return l10n.tagUrgentCourse;
      case RequestTag.certificationUrgent:
        return l10n.tagCertificationUrgent;
      
      // אירועים ובידור
      case RequestTag.partyToday:
        return l10n.tagPartyToday;
      case RequestTag.urgentEntertainment:
        return l10n.tagUrgentEntertainment;
      case RequestTag.eventSetup:
        return l10n.tagEventSetup;
      case RequestTag.urgentPhotography:
        return l10n.tagUrgentPhotography;
      
      // גינון וסביבה
      case RequestTag.urgentGardenCare:
        return l10n.tagUrgentGardenCare;
      case RequestTag.treeEmergency:
        return l10n.tagTreeEmergency;
      case RequestTag.urgentCleaning:
        return l10n.tagUrgentCleaning;
      case RequestTag.pestControl:
        return l10n.tagPestControl;
      
      // אוכל ובישול
      case RequestTag.urgentCatering:
        return l10n.tagUrgentCatering;
      case RequestTag.partyFood:
        return l10n.tagPartyFood;
      case RequestTag.urgentDelivery:
        return l10n.tagUrgentDelivery;
      case RequestTag.specialDiet:
        return l10n.tagSpecialDiet;
      
      // ספורט וכושר
      case RequestTag.urgentTraining:
        return l10n.tagUrgentTraining;
      case RequestTag.competitionPrep:
        return l10n.tagCompetitionPrep;
      case RequestTag.injuryRecovery:
        return l10n.tagInjuryRecovery;
      case RequestTag.urgentCoaching:
        return l10n.tagUrgentCoaching;
      
      // יופי, טיפוח וקוסמטיקה (תגיות נוספות)
      case RequestTag.eventToday:
        return l10n.tagEventToday;
      case RequestTag.urgentBeforeEvent:
        return l10n.tagUrgentBeforeEvent;
      case RequestTag.urgentBeautyFix:
        return l10n.tagUrgentBeautyFix;
      
      // שיווק ומכירות
      case RequestTag.urgentPurchase:
        return l10n.tagUrgentPurchase;
      case RequestTag.urgentSale:
        return l10n.tagUrgentSale;
      case RequestTag.eventShopping:
        return l10n.tagEventShopping;
      case RequestTag.urgentProduct:
        return l10n.tagUrgentProduct;
      
      // שליחויות, הובלות ושירותים מהירים (תגיות נוספות)
      case RequestTag.urgentDeliveryToday:
        return l10n.tagUrgentDeliveryToday;
      case RequestTag.urgentMoving:
        return l10n.tagUrgentMoving;
      
      // כלי תחבורה (תגיות נוספות)
      case RequestTag.urgentRoadRepair:
        return l10n.tagUrgentRoadRepair;
      case RequestTag.urgentTowing:
        return l10n.tagUrgentTowing;
      
      // גינון, ניקיון וסביבה (תגיות נוספות)
      case RequestTag.urgentPostRenovation:
        return l10n.tagUrgentPostRenovation;
      
      // ייעוץ והכוונה מקצועית (תגיות נוספות)
      case RequestTag.urgentConsultation:
        return l10n.tagUrgentConsultation;
      case RequestTag.urgentMeeting:
        return l10n.tagUrgentMeeting;
      
      // שירותים מיוחדים ופתוחים (תגיות נוספות)
      case RequestTag.urgentElderlyHelp:
        return l10n.tagUrgentElderlyHelp;
      case RequestTag.urgentVolunteering:
        return l10n.tagUrgentVolunteering;
      case RequestTag.urgentPetCare:
        return l10n.tagUrgentPetCare;
    }
  }
  
  Color get color {
    switch (this) {
      // בנייה ותיקונים - אדום
      case RequestTag.suddenLeak:
      case RequestTag.powerOutage:
      case RequestTag.lockedOut:
      case RequestTag.urgentBeforeShabbat:
        return Colors.red[300]!;
      
      // רכב ותחבורה - כתום
      case RequestTag.carStuck:
      case RequestTag.jumpStart:
      case RequestTag.quickParkingRepair:
      case RequestTag.movingToday:
        return Colors.orange[300]!;
      
      // משפחה וילדים - סגול
      case RequestTag.urgentBabysitter:
      case RequestTag.examTomorrow:
      case RequestTag.sickChild:
      case RequestTag.zoomLessonNow:
        return Colors.purple[300]!;
      
      // עסקים ושירותים - כחול
      case RequestTag.urgentDocument:
      case RequestTag.meetingToday:
      case RequestTag.presentationTomorrow:
      case RequestTag.urgentTranslation:
        return Colors.blue[300]!;
      
      // אומנות ומלאכה - ורוד
      case RequestTag.weddingToday:
      case RequestTag.urgentGift:
      case RequestTag.eventTomorrow:
      case RequestTag.urgentCraftRepair:
        return Colors.pink[300]!;
      
      // בריאות ורווחה - ירוק
      case RequestTag.urgentAppointment:
      case RequestTag.emergencyCare:
      case RequestTag.urgentTherapy:
      case RequestTag.healthEmergency:
        return Colors.green[300]!;
      
      // שירותים טכניים - טורקיז
      case RequestTag.urgentITSupport:
      case RequestTag.systemDown:
      case RequestTag.urgentTechRepair:
      case RequestTag.dataRecovery:
        return Colors.teal[300]!;
      
      // חינוך והכשרה - צהוב
      case RequestTag.urgentTutoring:
      case RequestTag.examPreparation:
      case RequestTag.urgentCourse:
      case RequestTag.certificationUrgent:
        return Colors.yellow[700]!;
      
      // אירועים ובידור - סגול בהיר
      case RequestTag.partyToday:
      case RequestTag.urgentEntertainment:
      case RequestTag.eventSetup:
      case RequestTag.urgentPhotography:
        return Colors.deepPurple[300]!;
      
      // גינון וסביבה - ירוק כהה
      case RequestTag.urgentGardenCare:
      case RequestTag.treeEmergency:
      case RequestTag.urgentCleaning:
      case RequestTag.pestControl:
        return Colors.lightGreen[600]!;
      
      // אוכל ובישול - חום
      case RequestTag.urgentCatering:
      case RequestTag.partyFood:
      case RequestTag.urgentDelivery:
      case RequestTag.specialDiet:
        return Colors.brown[300]!;
      
      // ספורט וכושר - אדום בהיר
      case RequestTag.urgentTraining:
      case RequestTag.competitionPrep:
      case RequestTag.injuryRecovery:
      case RequestTag.urgentCoaching:
        return Colors.red[400]!;
      
      // יופי, טיפוח וקוסמטיקה - ורוד בהיר
      case RequestTag.eventToday:
      case RequestTag.urgentBeforeEvent:
      case RequestTag.urgentBeautyFix:
        return Colors.pink[400]!;
      
      // שיווק ומכירות - כתום בהיר
      case RequestTag.urgentPurchase:
      case RequestTag.urgentSale:
      case RequestTag.eventShopping:
      case RequestTag.urgentProduct:
        return Colors.deepOrange[300]!;
      
      // שליחויות, הובלות ושירותים מהירים - חום
      case RequestTag.urgentDeliveryToday:
      case RequestTag.urgentMoving:
        return Colors.brown[400]!;
      
      // כלי תחבורה - כתום
      case RequestTag.urgentRoadRepair:
      case RequestTag.urgentTowing:
        return Colors.orange[400]!;
      
      // גינון, ניקיון וסביבה - ירוק כהה
      case RequestTag.urgentPostRenovation:
        return Colors.lightGreen[700]!;
      
      // ייעוץ והכוונה מקצועית - כחול
      case RequestTag.urgentConsultation:
      case RequestTag.urgentMeeting:
        return Colors.blue[400]!;
      
      // שירותים מיוחדים ופתוחים - סגול
      case RequestTag.urgentElderlyHelp:
      case RequestTag.urgentVolunteering:
      case RequestTag.urgentPetCare:
        return Colors.purple[400]!;
    }
  }
  
  // פונקציה לקבלת תגיות לפי קטגוריה
  static List<RequestTag> getTagsForCategory(RequestCategory category) {
    switch (category.mainCategory) {
      case MainCategory.constructionAndMaintenance:
        return [
          RequestTag.suddenLeak,
          RequestTag.powerOutage,
          RequestTag.lockedOut,
          RequestTag.urgentBeforeShabbat,
        ];
      case MainCategory.deliveriesAndMoving:
        return [
          RequestTag.movingToday,
          RequestTag.urgentDelivery,
          RequestTag.urgentDeliveryToday,
          RequestTag.urgentMoving,
        ];
      case MainCategory.beautyAndCosmetics:
        return [
          RequestTag.urgentAppointment,
          RequestTag.eventToday,
          RequestTag.urgentBeforeEvent,
          RequestTag.urgentBeautyFix,
        ];
      case MainCategory.marketingAndSales:
        return [
          RequestTag.urgentDelivery,
          RequestTag.urgentPurchase,
          RequestTag.urgentSale,
          RequestTag.eventShopping,
          RequestTag.urgentProduct,
        ];
      case MainCategory.technologyAndComputers:
        return [
          RequestTag.urgentITSupport,
          RequestTag.systemDown,
          RequestTag.urgentTechRepair,
          RequestTag.dataRecovery,
        ];
      case MainCategory.vehicles:
        return [
          RequestTag.carStuck,
          RequestTag.jumpStart,
          RequestTag.quickParkingRepair,
          RequestTag.urgentRoadRepair,
          RequestTag.urgentTowing,
        ];
      case MainCategory.gardeningAndCleaning:
        return [
          RequestTag.urgentGardenCare,
          RequestTag.urgentCleaning,
          RequestTag.pestControl,
          RequestTag.treeEmergency,
          RequestTag.urgentPostRenovation,
        ];
      case MainCategory.educationAndTraining:
        return [
          RequestTag.urgentTutoring,
          RequestTag.examPreparation,
          RequestTag.urgentCourse,
          RequestTag.certificationUrgent,
        ];
      case MainCategory.professionalConsulting:
        return [
          RequestTag.urgentDocument,
          RequestTag.meetingToday,
          RequestTag.presentationTomorrow,
          RequestTag.urgentConsultation,
          RequestTag.urgentMeeting,
        ];
      case MainCategory.artsAndMedia:
        return [
          RequestTag.weddingToday,
          RequestTag.urgentGift,
          RequestTag.eventTomorrow,
          RequestTag.urgentPhotography,
        ];
      case MainCategory.specialServices:
        return [
          RequestTag.urgentBabysitter,
          RequestTag.sickChild,
          RequestTag.urgentElderlyHelp,
          RequestTag.urgentVolunteering,
          RequestTag.urgentPetCare,
        ];
    }
  }
}
