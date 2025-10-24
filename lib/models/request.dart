import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// תחומים ראשיים
enum MainCategory {
  constructionAndRepairs,
  transportation,
  familyAndChildren,
  businessAndServices,
  artsAndCrafts,
  healthAndWellness,
  technicalServices,
  educationAndTraining,
  eventsAndEntertainment,
  gardeningAndEnvironment,
  foodAndCooking,
  sportsAndFitness,
}

// תחומי משנה
enum RequestCategory {
  // בנייה ותיקונים
  flooringAndCeramics,
  paintingAndPlaster,
  plumbing,
  electrical,
  carpentry,
  roofsAndWalls,
  elevatorsAndStairs,
  
  // רכב ותחבורה
  carRepair,
  carServices,
  movingAndTransport,
  ridesAndShuttles,
  bicyclesAndScooters,
  heavyVehicles,
  
  // משפחה וילדים
  babysitting,
  privateLessons,
  childrenActivities,
  childrenHealth,
  birthAndParenting,
  specialEducation,
  
  // עסקים ושירותים
  officeServices,
  marketingAndAdvertising,
  consulting,
  businessEvents,
  cleaningServices,
  security,
  
  // יצירה ואומנות
  paintingAndSculpture,
  handicrafts,
  music,
  photography,
  design,
  performingArts,
  
  // בריאות ורווחה
  physiotherapy,
  yogaAndPilates,
  nutrition,
  mentalHealth,
  alternativeMedicine,
  beautyAndCosmetics,
  
  // מקצועות טכניים
  computersAndTechnology,
  electricalAndElectronics,
  internetAndCommunication,
  appsAndDevelopment,
  smartSystems,
  medicalEquipment,
  
  // חינוך והכשרה
  privateLessonsEducation,
  languages,
  professionalTraining,
  lifeSkills,
  higherEducation,
  vocationalTraining,
  
  // אירועים ובידור
  events,
  entertainment,
  sports,
  tourism,
  partiesAndEvents,
  photographyAndVideo,
  
  // גינון וסביבה
  gardening,
  environmentalCleaning,
  cleaningServicesEnv,
  environmentalQuality,
  pets,
  maintenance,
  
  // מזון ובישול
  cooking,
  healthyFood,
  foodEvents,
  fastFood,
  restaurants,
  baking,
  nutritionalConsulting,
  
  // ספורט וכושר
  personalTraining,
  teamSports,
  martialArts,
  dance,
  extremeSports,
  sportsRehabilitation,
}
enum RequestLocation { custom }
enum RequestStatus { open, inProgress, completed, cancelled }
enum RequestType { free, paid }
enum TargetAudience { all, distance, village, category }

// רמות דחיפות חדשות
enum UrgencyLevel {
  normal,      // 🕓 רגיל
  urgent24h,   // ⏰ תוך 24 שעות  
  emergency,   // 🚨 עכשיו
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
  });

  factory Request.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Request(
      requestId: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: RequestCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => RequestCategory.maintenance,
      ),
      location: data['location'] != null 
          ? RequestLocation.values.firstWhere(
              (e) => e.name == data['location'],
              orElse: () => RequestLocation.custom,
            )
          : null,
      isUrgent: data['isUrgent'] ?? false,
      images: List<String>.from(data['images'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
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
      deadline: data['deadline'] != null ? (data['deadline'] as Timestamp).toDate() : null,
      targetAudience: TargetAudience.values.firstWhere(
        (e) => e.name == data['targetAudience'],
        orElse: () => TargetAudience.all,
      ),
      maxDistance: data['maxDistance']?.toDouble(),
      targetVillage: data['targetVillage'],
      targetCategories: data['targetCategories'] != null 
          ? (data['targetCategories'] as List).map((e) => RequestCategory.values.firstWhere(
              (cat) => cat.name == e,
              orElse: () => RequestCategory.maintenance,
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
    };
  }

  String get categoryDisplayName {
    switch (category) {
      // בנייה ותיקונים
      case RequestCategory.flooringAndCeramics:
        return 'ריצוף וקרמיקה';
      case RequestCategory.paintingAndPlaster:
        return 'צבע וטיח';
      case RequestCategory.plumbing:
        return 'אינסטלציה';
      case RequestCategory.electrical:
        return 'חשמל';
      case RequestCategory.carpentry:
        return 'נגרות';
      case RequestCategory.roofsAndWalls:
        return 'גגות וקירות';
      case RequestCategory.elevatorsAndStairs:
        return 'מעליות ומדרגות';
      
      // רכב ותחבורה
      case RequestCategory.carRepair:
        return 'תיקון רכב';
      case RequestCategory.carServices:
        return 'שירותי רכב';
      case RequestCategory.movingAndTransport:
        return 'הובלה ומעבר';
      case RequestCategory.ridesAndShuttles:
        return 'הסעות';
      case RequestCategory.bicyclesAndScooters:
        return 'אופניים וקורקינטים';
      case RequestCategory.heavyVehicles:
        return 'כלי רכב כבדים';
      
      // משפחה וילדים
      case RequestCategory.babysitting:
        return 'שמרטפות';
      case RequestCategory.privateLessons:
        return 'שיעורים פרטיים';
      case RequestCategory.childrenActivities:
        return 'פעילויות ילדים';
      case RequestCategory.childrenHealth:
        return 'בריאות ילדים';
      case RequestCategory.birthAndParenting:
        return 'לידה והורות';
      case RequestCategory.specialEducation:
        return 'חינוך מיוחד';
      
      // עסקים ושירותים
      case RequestCategory.officeServices:
        return 'שירותי משרד';
      case RequestCategory.marketingAndAdvertising:
        return 'שיווק ופרסום';
      case RequestCategory.consulting:
        return 'ייעוץ';
      case RequestCategory.businessEvents:
        return 'אירועים עסקיים';
      case RequestCategory.cleaningServices:
        return 'שירותי ניקיון';
      case RequestCategory.security:
        return 'אבטחה';
      
      // יצירה ואומנות
      case RequestCategory.paintingAndSculpture:
        return 'ציור ופיסול';
      case RequestCategory.handicrafts:
        return 'מלאכת יד';
      case RequestCategory.music:
        return 'מוזיקה';
      case RequestCategory.photography:
        return 'צילום';
      case RequestCategory.design:
        return 'עיצוב';
      case RequestCategory.performingArts:
        return 'אומנויות הבמה';
      
      // בריאות ורווחה
      case RequestCategory.physiotherapy:
        return 'פיזיותרפיה';
      case RequestCategory.yogaAndPilates:
        return 'יוגה ופילאטיס';
      case RequestCategory.nutrition:
        return 'תזונה';
      case RequestCategory.mentalHealth:
        return 'בריאות הנפש';
      case RequestCategory.alternativeMedicine:
        return 'רפואה משלימה';
      case RequestCategory.beautyAndCosmetics:
        return 'קוסמטיקה ויופי';
      
      // מקצועות טכניים
      case RequestCategory.computersAndTechnology:
        return 'מחשבים וטכנולוגיה';
      case RequestCategory.electricalAndElectronics:
        return 'חשמל ואלקטרוניקה';
      case RequestCategory.internetAndCommunication:
        return 'אינטרנט ותקשורת';
      case RequestCategory.appsAndDevelopment:
        return 'אפליקציות ופיתוח';
      case RequestCategory.smartSystems:
        return 'מערכות חכמות';
      case RequestCategory.medicalEquipment:
        return 'מכשור רפואי';
      
      // חינוך והכשרה
      case RequestCategory.privateLessonsEducation:
        return 'שיעורים פרטיים';
      case RequestCategory.languages:
        return 'שפות';
      case RequestCategory.professionalTraining:
        return 'מקצועות';
      case RequestCategory.lifeSkills:
        return 'כישורי חיים';
      case RequestCategory.higherEducation:
        return 'לימודים גבוהים';
      case RequestCategory.vocationalTraining:
        return 'הכשרה מקצועית';
      
      // אירועים ובידור
      case RequestCategory.events:
        return 'אירועים';
      case RequestCategory.entertainment:
        return 'בידור';
      case RequestCategory.sports:
        return 'ספורט';
      case RequestCategory.tourism:
        return 'תיירות';
      case RequestCategory.partiesAndEvents:
        return 'מסיבות ואירועים';
      case RequestCategory.photographyAndVideo:
        return 'צילום ווידאו';
      
      // גינון וסביבה
      case RequestCategory.gardening:
        return 'גינון';
      case RequestCategory.environmentalCleaning:
        return 'ניקיון סביבתי';
      case RequestCategory.cleaningServicesEnv:
        return 'שירותי ניקיון';
      case RequestCategory.environmentalQuality:
        return 'איכות הסביבה';
      case RequestCategory.pets:
        return 'בעלי חיים';
      case RequestCategory.maintenance:
        return 'תחזוקה';
      
      // מזון ובישול
      case RequestCategory.cooking:
        return 'בישול';
      case RequestCategory.healthyFood:
        return 'מזון בריא';
      case RequestCategory.foodEvents:
        return 'אירועי מזון';
      case RequestCategory.fastFood:
        return 'אוכל מהיר';
      case RequestCategory.restaurants:
        return 'מסעדות';
      case RequestCategory.baking:
        return 'מאפים';
      case RequestCategory.nutritionalConsulting:
        return 'ייעוץ תזונתי';
      
      // ספורט וכושר
      case RequestCategory.personalTraining:
        return 'אימונים אישיים';
      case RequestCategory.teamSports:
        return 'ספורט קבוצתי';
      case RequestCategory.martialArts:
        return 'אומנויות לחימה';
      case RequestCategory.dance:
        return 'ריקוד';
      case RequestCategory.extremeSports:
        return 'ספורט אתגרי';
      case RequestCategory.sportsRehabilitation:
        return 'שיקום ספורט';
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
      // בנייה ותיקונים
      case RequestCategory.flooringAndCeramics:
        return 'ריצוף וקרמיקה';
      case RequestCategory.paintingAndPlaster:
        return 'צבע וטיח';
      case RequestCategory.plumbing:
        return 'אינסטלציה';
      case RequestCategory.electrical:
        return 'חשמל';
      case RequestCategory.carpentry:
        return 'נגרות';
      case RequestCategory.roofsAndWalls:
        return 'גגות וקירות';
      case RequestCategory.elevatorsAndStairs:
        return 'מעליות ומדרגות';
      
      // רכב ותחבורה
      case RequestCategory.carRepair:
        return 'תיקון רכב';
      case RequestCategory.carServices:
        return 'שירותי רכב';
      case RequestCategory.movingAndTransport:
        return 'הובלה ומעבר';
      case RequestCategory.ridesAndShuttles:
        return 'הסעות';
      case RequestCategory.bicyclesAndScooters:
        return 'אופניים וקורקינטים';
      case RequestCategory.heavyVehicles:
        return 'כלי רכב כבדים';
      
      // משפחה וילדים
      case RequestCategory.babysitting:
        return 'שמרטפות';
      case RequestCategory.privateLessons:
        return 'שיעורים פרטיים';
      case RequestCategory.childrenActivities:
        return 'פעילויות ילדים';
      case RequestCategory.childrenHealth:
        return 'בריאות ילדים';
      case RequestCategory.birthAndParenting:
        return 'לידה והורות';
      case RequestCategory.specialEducation:
        return 'חינוך מיוחד';
      
      // עסקים ושירותים
      case RequestCategory.officeServices:
        return 'שירותי משרד';
      case RequestCategory.marketingAndAdvertising:
        return 'שיווק ופרסום';
      case RequestCategory.consulting:
        return 'ייעוץ';
      case RequestCategory.businessEvents:
        return 'אירועים עסקיים';
      case RequestCategory.cleaningServices:
        return 'שירותי ניקיון';
      case RequestCategory.security:
        return 'אבטחה';
      
      // יצירה ואומנות
      case RequestCategory.paintingAndSculpture:
        return 'ציור ופיסול';
      case RequestCategory.handicrafts:
        return 'מלאכת יד';
      case RequestCategory.music:
        return 'מוזיקה';
      case RequestCategory.photography:
        return 'צילום';
      case RequestCategory.design:
        return 'עיצוב';
      case RequestCategory.performingArts:
        return 'אומנויות הבמה';
      
      // בריאות ורווחה
      case RequestCategory.physiotherapy:
        return 'פיזיותרפיה';
      case RequestCategory.yogaAndPilates:
        return 'יוגה ופילאטיס';
      case RequestCategory.nutrition:
        return 'תזונה';
      case RequestCategory.mentalHealth:
        return 'בריאות הנפש';
      case RequestCategory.alternativeMedicine:
        return 'רפואה משלימה';
      case RequestCategory.beautyAndCosmetics:
        return 'קוסמטיקה ויופי';
      
      // מקצועות טכניים
      case RequestCategory.computersAndTechnology:
        return 'מחשבים וטכנולוגיה';
      case RequestCategory.electricalAndElectronics:
        return 'חשמל ואלקטרוניקה';
      case RequestCategory.internetAndCommunication:
        return 'אינטרנט ותקשורת';
      case RequestCategory.appsAndDevelopment:
        return 'אפליקציות ופיתוח';
      case RequestCategory.smartSystems:
        return 'מערכות חכמות';
      case RequestCategory.medicalEquipment:
        return 'מכשור רפואי';
      
      // חינוך והכשרה
      case RequestCategory.privateLessonsEducation:
        return 'שיעורים פרטיים';
      case RequestCategory.languages:
        return 'שפות';
      case RequestCategory.professionalTraining:
        return 'מקצועות';
      case RequestCategory.lifeSkills:
        return 'כישורי חיים';
      case RequestCategory.higherEducation:
        return 'לימודים גבוהים';
      case RequestCategory.vocationalTraining:
        return 'הכשרה מקצועית';
      
      // אירועים ובידור
      case RequestCategory.events:
        return 'אירועים';
      case RequestCategory.entertainment:
        return 'בידור';
      case RequestCategory.sports:
        return 'ספורט';
      case RequestCategory.tourism:
        return 'תיירות';
      case RequestCategory.partiesAndEvents:
        return 'מסיבות ואירועים';
      case RequestCategory.photographyAndVideo:
        return 'צילום ווידאו';
      
      // גינון וסביבה
      case RequestCategory.gardening:
        return 'גינון';
      case RequestCategory.environmentalCleaning:
        return 'ניקיון סביבתי';
      case RequestCategory.cleaningServicesEnv:
        return 'שירותי ניקיון';
      case RequestCategory.environmentalQuality:
        return 'איכות הסביבה';
      case RequestCategory.pets:
        return 'בעלי חיים';
      case RequestCategory.maintenance:
        return 'תחזוקה';
      
      // מזון ובישול
      case RequestCategory.cooking:
        return 'בישול';
      case RequestCategory.healthyFood:
        return 'מזון בריא';
      case RequestCategory.foodEvents:
        return 'אירועי מזון';
      case RequestCategory.fastFood:
        return 'אוכל מהיר';
      case RequestCategory.restaurants:
        return 'מסעדות';
      case RequestCategory.baking:
        return 'מאפים';
      case RequestCategory.nutritionalConsulting:
        return 'ייעוץ תזונתי';
      
      // ספורט וכושר
      case RequestCategory.personalTraining:
        return 'אימונים אישיים';
      case RequestCategory.teamSports:
        return 'ספורט קבוצתי';
      case RequestCategory.martialArts:
        return 'אומנויות לחימה';
      case RequestCategory.dance:
        return 'ריקוד';
      case RequestCategory.extremeSports:
        return 'ספורט אתגרי';
      case RequestCategory.sportsRehabilitation:
        return 'שיקום ספורט';
    }
  }

  // פונקציה לקבלת התחום הראשי
  MainCategory get mainCategory {
    switch (this) {
      // בנייה ותיקונים
      case RequestCategory.flooringAndCeramics:
      case RequestCategory.paintingAndPlaster:
      case RequestCategory.plumbing:
      case RequestCategory.electrical:
      case RequestCategory.carpentry:
      case RequestCategory.roofsAndWalls:
      case RequestCategory.elevatorsAndStairs:
        return MainCategory.constructionAndRepairs;
      
      // רכב ותחבורה
      case RequestCategory.carRepair:
      case RequestCategory.carServices:
      case RequestCategory.movingAndTransport:
      case RequestCategory.ridesAndShuttles:
      case RequestCategory.bicyclesAndScooters:
      case RequestCategory.heavyVehicles:
        return MainCategory.transportation;
      
      // משפחה וילדים
      case RequestCategory.babysitting:
      case RequestCategory.privateLessons:
      case RequestCategory.childrenActivities:
      case RequestCategory.childrenHealth:
      case RequestCategory.birthAndParenting:
      case RequestCategory.specialEducation:
        return MainCategory.familyAndChildren;
      
      // עסקים ושירותים
      case RequestCategory.officeServices:
      case RequestCategory.marketingAndAdvertising:
      case RequestCategory.consulting:
      case RequestCategory.businessEvents:
      case RequestCategory.cleaningServices:
      case RequestCategory.security:
        return MainCategory.businessAndServices;
      
      // יצירה ואומנות
      case RequestCategory.paintingAndSculpture:
      case RequestCategory.handicrafts:
      case RequestCategory.music:
      case RequestCategory.photography:
      case RequestCategory.design:
      case RequestCategory.performingArts:
        return MainCategory.artsAndCrafts;
      
      // בריאות ורווחה
      case RequestCategory.physiotherapy:
      case RequestCategory.yogaAndPilates:
      case RequestCategory.nutrition:
      case RequestCategory.mentalHealth:
      case RequestCategory.alternativeMedicine:
      case RequestCategory.beautyAndCosmetics:
        return MainCategory.healthAndWellness;
      
      // מקצועות טכניים
      case RequestCategory.computersAndTechnology:
      case RequestCategory.electricalAndElectronics:
      case RequestCategory.internetAndCommunication:
      case RequestCategory.appsAndDevelopment:
      case RequestCategory.smartSystems:
      case RequestCategory.medicalEquipment:
        return MainCategory.technicalServices;
      
      // חינוך והכשרה
      case RequestCategory.privateLessonsEducation:
      case RequestCategory.languages:
      case RequestCategory.professionalTraining:
      case RequestCategory.lifeSkills:
      case RequestCategory.higherEducation:
      case RequestCategory.vocationalTraining:
        return MainCategory.educationAndTraining;
      
      // אירועים ובידור
      case RequestCategory.events:
      case RequestCategory.entertainment:
      case RequestCategory.sports:
      case RequestCategory.tourism:
      case RequestCategory.partiesAndEvents:
      case RequestCategory.photographyAndVideo:
        return MainCategory.eventsAndEntertainment;
      
      // גינון וסביבה
      case RequestCategory.gardening:
      case RequestCategory.environmentalCleaning:
      case RequestCategory.cleaningServicesEnv:
      case RequestCategory.environmentalQuality:
      case RequestCategory.pets:
      case RequestCategory.maintenance:
        return MainCategory.gardeningAndEnvironment;
      
      // מזון ובישול
      case RequestCategory.cooking:
      case RequestCategory.healthyFood:
      case RequestCategory.foodEvents:
      case RequestCategory.fastFood:
      case RequestCategory.restaurants:
      case RequestCategory.baking:
      case RequestCategory.nutritionalConsulting:
        return MainCategory.foodAndCooking;
      
      // ספורט וכושר
      case RequestCategory.personalTraining:
      case RequestCategory.teamSports:
      case RequestCategory.martialArts:
      case RequestCategory.dance:
      case RequestCategory.extremeSports:
      case RequestCategory.sportsRehabilitation:
        return MainCategory.sportsAndFitness;
    }
  }
}

extension MainCategoryExtension on MainCategory {
  String get displayName {
    switch (this) {
      case MainCategory.constructionAndRepairs:
        return 'בנייה ותיקונים';
      case MainCategory.transportation:
        return 'רכב ותחבורה';
      case MainCategory.familyAndChildren:
        return 'משפחה וילדים';
      case MainCategory.businessAndServices:
        return 'עסקים ושירותים';
      case MainCategory.artsAndCrafts:
        return 'יצירה ואומנות';
      case MainCategory.healthAndWellness:
        return 'בריאות ורווחה';
      case MainCategory.technicalServices:
        return 'מקצועות טכניים';
      case MainCategory.educationAndTraining:
        return 'חינוך והכשרה';
      case MainCategory.eventsAndEntertainment:
        return 'אירועים ובידור';
      case MainCategory.gardeningAndEnvironment:
        return 'גינון וסביבה';
      case MainCategory.foodAndCooking:
        return 'מזון ובישול';
      case MainCategory.sportsAndFitness:
        return 'ספורט וכושר';
    }
  }

  String get icon {
    switch (this) {
      case MainCategory.constructionAndRepairs:
        return '🏠';
      case MainCategory.transportation:
        return '🚗';
      case MainCategory.familyAndChildren:
        return '👶';
      case MainCategory.businessAndServices:
        return '💼';
      case MainCategory.artsAndCrafts:
        return '🎨';
      case MainCategory.healthAndWellness:
        return '🏥';
      case MainCategory.technicalServices:
        return '🛠️';
      case MainCategory.educationAndTraining:
        return '🎓';
      case MainCategory.eventsAndEntertainment:
        return '🎉';
      case MainCategory.gardeningAndEnvironment:
        return '🌱';
      case MainCategory.foodAndCooking:
        return '🍽️';
      case MainCategory.sportsAndFitness:
        return '🏃‍♂️';
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
    if (phoneNumber == null || phoneNumber!.isEmpty) return null;
    
    final phone = phoneNumber!;
    
    // פורמט למספרי סלולר (05X-XXX-XXXX)
    if (phone.length == 10 && phone.startsWith('05')) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
    }
    
    // פורמט למספרי קווי (0XX-XXX-XXXX או 0XXX-XXX-XXX)
    if (phone.length == 9) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
    } else if (phone.length == 10) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 6)}-${phone.substring(6)}';
    }
    
    // אם לא מתאים לאף פורמט, החזר כפי שהוא
    return phone;
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
        return '🚨 עכשיו';
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
  String get displayName {
    switch (this) {
      // בנייה ותיקונים
      case RequestTag.suddenLeak:
        return '❗ נזילה פתאומית';
      case RequestTag.powerOutage:
        return '⚡ הפסקת חשמל';
      case RequestTag.lockedOut:
        return '🔒 תקוע מחוץ לבית';
      case RequestTag.urgentBeforeShabbat:
        return '🔧 תיקון דחוף לפני שבת';
      
      // רכב ותחבורה
      case RequestTag.carStuck:
        return '🚨 רכב נתקע בדרך';
      case RequestTag.jumpStart:
        return '🔋 התנעה / כבלים';
      case RequestTag.quickParkingRepair:
        return '🧰 תיקון מהיר בחניה';
      case RequestTag.movingToday:
        return '🧳 עזרה במעבר דירה היום';
      
      // משפחה וילדים
      case RequestTag.urgentBabysitter:
        return '🍼 בייביסיטר דחוף';
      case RequestTag.examTomorrow:
        return '📚 שיעור לפני מבחן מחר';
      case RequestTag.sickChild:
        return '🧸 עזרה עם ילד חולה';
      case RequestTag.zoomLessonNow:
        return '👩‍🏫 שיעור בזום עכשיו';
      
      // עסקים ושירותים
      case RequestTag.urgentDocument:
        return '📄 מסמך דחוף';
      case RequestTag.meetingToday:
        return '🤝 פגישה היום';
      case RequestTag.presentationTomorrow:
        return '📊 מצגת מחר';
      case RequestTag.urgentTranslation:
        return '🌐 תרגום דחוף';
      
      // אומנות ומלאכה
      case RequestTag.weddingToday:
        return '💒 חתונה היום';
      case RequestTag.urgentGift:
        return '🎁 מתנה דחופה';
      case RequestTag.eventTomorrow:
        return '🎉 אירוע מחר';
      case RequestTag.urgentCraftRepair:
        return '🔧 תיקון מלאכה דחוף';
      
      // בריאות ורווחה
      case RequestTag.urgentAppointment:
        return '🏥 תור דחוף';
      case RequestTag.emergencyCare:
        return '🚑 טיפול חירום';
      case RequestTag.urgentTherapy:
        return '💆 טיפול דחוף';
      case RequestTag.healthEmergency:
        return '⚕️ חירום בריאותי';
      
      // שירותים טכניים
      case RequestTag.urgentITSupport:
        return '💻 תמיכה טכנית דחופה';
      case RequestTag.systemDown:
        return '🖥️ מערכת לא עובדת';
      case RequestTag.urgentTechRepair:
        return '🔧 תיקון טכני דחוף';
      case RequestTag.dataRecovery:
        return '💾 שחזור נתונים';
      
      // חינוך והכשרה
      case RequestTag.urgentTutoring:
        return '📖 שיעור דחוף';
      case RequestTag.examPreparation:
        return '📝 הכנה למבחן';
      case RequestTag.urgentCourse:
        return '🎓 קורס דחוף';
      case RequestTag.certificationUrgent:
        return '🏆 הסמכה דחופה';
      
      // אירועים ובידור
      case RequestTag.partyToday:
        return '🎊 מסיבה היום';
      case RequestTag.urgentEntertainment:
        return '🎭 בידור דחוף';
      case RequestTag.eventSetup:
        return '🎪 הכנת אירוע';
      case RequestTag.urgentPhotography:
        return '📸 צילום דחוף';
      
      // גינון וסביבה
      case RequestTag.urgentGardenCare:
        return '🌱 טיפול בגן דחוף';
      case RequestTag.treeEmergency:
        return '🌳 חירום עץ';
      case RequestTag.urgentCleaning:
        return '🧹 ניקיון דחוף';
      case RequestTag.pestControl:
        return '🐛 הדברת מזיקים';
      
      // אוכל ובישול
      case RequestTag.urgentCatering:
        return '🍽️ קייטרינג דחוף';
      case RequestTag.partyFood:
        return '🍕 אוכל למסיבה';
      case RequestTag.urgentDelivery:
        return '🚚 משלוח דחוף';
      case RequestTag.specialDiet:
        return '🥗 דיאטה מיוחדת';
      
      // ספורט וכושר
      case RequestTag.urgentTraining:
        return '💪 אימון דחוף';
      case RequestTag.competitionPrep:
        return '🏆 הכנה לתחרות';
      case RequestTag.injuryRecovery:
        return '🩹 החלמה מפציעה';
      case RequestTag.urgentCoaching:
        return '🏃 אימון דחוף';
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
    }
  }
  
  // פונקציה לקבלת תגיות לפי קטגוריה
  static List<RequestTag> getTagsForCategory(RequestCategory category) {
    switch (category.mainCategory) {
      case MainCategory.constructionAndRepairs:
        return [
          RequestTag.suddenLeak,
          RequestTag.powerOutage,
          RequestTag.lockedOut,
          RequestTag.urgentBeforeShabbat,
        ];
      case MainCategory.transportation:
        return [
          RequestTag.carStuck,
          RequestTag.jumpStart,
          RequestTag.quickParkingRepair,
          RequestTag.movingToday,
        ];
      case MainCategory.familyAndChildren:
        return [
          RequestTag.urgentBabysitter,
          RequestTag.examTomorrow,
          RequestTag.sickChild,
          RequestTag.zoomLessonNow,
        ];
      case MainCategory.businessAndServices:
        return [
          RequestTag.urgentDocument,
          RequestTag.meetingToday,
          RequestTag.presentationTomorrow,
          RequestTag.urgentTranslation,
        ];
      case MainCategory.artsAndCrafts:
        return [
          RequestTag.weddingToday,
          RequestTag.urgentGift,
          RequestTag.eventTomorrow,
          RequestTag.urgentCraftRepair,
        ];
      case MainCategory.healthAndWellness:
        return [
          RequestTag.urgentAppointment,
          RequestTag.emergencyCare,
          RequestTag.urgentTherapy,
          RequestTag.healthEmergency,
        ];
      case MainCategory.technicalServices:
        return [
          RequestTag.urgentITSupport,
          RequestTag.systemDown,
          RequestTag.urgentTechRepair,
          RequestTag.dataRecovery,
        ];
      case MainCategory.educationAndTraining:
        return [
          RequestTag.urgentTutoring,
          RequestTag.examPreparation,
          RequestTag.urgentCourse,
          RequestTag.certificationUrgent,
        ];
      case MainCategory.eventsAndEntertainment:
        return [
          RequestTag.partyToday,
          RequestTag.urgentEntertainment,
          RequestTag.eventSetup,
          RequestTag.urgentPhotography,
        ];
      case MainCategory.gardeningAndEnvironment:
        return [
          RequestTag.urgentGardenCare,
          RequestTag.treeEmergency,
          RequestTag.urgentCleaning,
          RequestTag.pestControl,
        ];
      case MainCategory.foodAndCooking:
        return [
          RequestTag.urgentCatering,
          RequestTag.partyFood,
          RequestTag.urgentDelivery,
          RequestTag.specialDiet,
        ];
      case MainCategory.sportsAndFitness:
        return [
          RequestTag.urgentTraining,
          RequestTag.competitionPrep,
          RequestTag.injuryRecovery,
          RequestTag.urgentCoaching,
        ];
      default:
        return [];
    }
  }
}
