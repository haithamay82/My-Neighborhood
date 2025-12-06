import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/request.dart';

class CategoriesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static List<Map<String, dynamic>>? _cachedMainCategories;
  static List<Map<String, dynamic>>? _cachedSubCategories;
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Load main categories from Firestore, fallback to enum if not available
  static Future<List<Map<String, dynamic>>> getMainCategories() async {
    // Check cache first
    if (_cachedMainCategories != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
      return _cachedMainCategories!;
    }

    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('type', isEqualTo: 'main')
          .orderBy('order', descending: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _cachedMainCategories = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'nameHebrew': data['nameHebrew'] ?? '',
            'nameArabic': data['nameArabic'] ?? '',
            'nameEnglish': data['nameEnglish'] ?? '',
            'icon': data['icon'] ?? '',
            'order': data['order'] ?? 0,
          };
        }).toList();
        _lastCacheTime = DateTime.now();
        debugPrint('✅ [CategoriesService] Loaded ${_cachedMainCategories!.length} main categories from Firestore');
        debugPrint('📋 [CategoriesService] Main categories: ${_cachedMainCategories!.map((c) => '${c['nameHebrew']} (${c['id']})').toList()}');
        return _cachedMainCategories!;
      }
    } catch (e) {
      debugPrint('❌ [CategoriesService] Error loading main categories from Firestore: $e');
    }

    // Fallback to enum
    return _getMainCategoriesFromEnum();
  }

  /// Load sub categories from Firestore, fallback to enum if not available
  static Future<List<Map<String, dynamic>>> getSubCategories({String? mainCategoryId}) async {
    // Check cache first
    if (_cachedSubCategories != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
      if (mainCategoryId == null) {
        return _cachedSubCategories!;
      }
      return _cachedSubCategories!
          .where((cat) => cat['mainCategoryId'] == mainCategoryId)
          .toList();
    }

    try {
      Query query = _firestore
          .collection('categories')
          .where('type', isEqualTo: 'sub');

      if (mainCategoryId != null) {
        query = query.where('mainCategoryId', isEqualTo: mainCategoryId);
        debugPrint('🔍 [CategoriesService] Loading sub categories for mainCategoryId: $mainCategoryId');
      } else {
        debugPrint('🔍 [CategoriesService] Loading all sub categories');
      }

      final snapshot = await query.orderBy('order', descending: false).get();
      debugPrint('📥 [CategoriesService] Firestore returned ${snapshot.docs.length} sub category documents');

      if (snapshot.docs.isNotEmpty) {
        _cachedSubCategories = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'nameHebrew': data['nameHebrew'] ?? '',
            'nameArabic': data['nameArabic'] ?? '',
            'nameEnglish': data['nameEnglish'] ?? '',
            'mainCategoryId': data['mainCategoryId'] ?? '',
            'order': data['order'] ?? 0,
          };
        }).toList();
        _lastCacheTime = DateTime.now();
        debugPrint('✅ [CategoriesService] Loaded ${_cachedSubCategories!.length} sub categories from Firestore');
        debugPrint('📋 [CategoriesService] Sub categories: ${_cachedSubCategories!.map((c) => '${c['name']} (${c['nameHebrew']}) -> ${c['mainCategoryId']}').toList()}');
        
        final cached = _cachedSubCategories!;
        if (mainCategoryId == null) {
          return cached;
        }
        return cached
            .where((cat) => cat['mainCategoryId'] == mainCategoryId)
            .toList();
      }
    } catch (e) {
      debugPrint('❌ [CategoriesService] Error loading sub categories from Firestore: $e');
    }

    // Fallback to enum
    return _getSubCategoriesFromEnum(mainCategoryId: mainCategoryId);
  }

  /// Get sub categories for a specific main category
  static Future<List<Map<String, dynamic>>> getSubCategoriesForMainCategory(
    String mainCategoryId,
  ) async {
    return getSubCategories(mainCategoryId: mainCategoryId);
  }

  /// Clear cache to force reload
  static void clearCache() {
    _cachedMainCategories = null;
    _cachedSubCategories = null;
    _lastCacheTime = null;
  }

  /// Get main categories from enum (fallback)
  static List<Map<String, dynamic>> _getMainCategoriesFromEnum() {
    final mainCategoryMap = {
      MainCategory.constructionAndMaintenance: {
        'id': 'constructionAndMaintenance',
        'name': 'constructionAndMaintenance',
        'nameHebrew': 'בנייה, תיקונים ותחזוקה',
        'nameArabic': 'البناء والإصلاحات والصيانة',
        'nameEnglish': 'Construction, Repairs and Maintenance',
        'icon': '🏠',
        'order': 1,
      },
      MainCategory.deliveriesAndMoving: {
        'id': 'deliveriesAndMoving',
        'name': 'deliveriesAndMoving',
        'nameHebrew': 'שליחויות, הובלות ושירותים מהירים',
        'nameArabic': 'التوصيل والنقل والخدمات السريعة',
        'nameEnglish': 'Deliveries, Moving and Fast Services',
        'icon': '🚚',
        'order': 2,
      },
      MainCategory.beautyAndCosmetics: {
        'id': 'beautyAndCosmetics',
        'name': 'beautyAndCosmetics',
        'nameHebrew': 'יופי, טיפוח וקוסמטיקה',
        'nameArabic': 'الجمال والعناية ومستحضرات التجميل',
        'nameEnglish': 'Beauty, Grooming and Cosmetics',
        'icon': '🧖‍♀️',
        'order': 3,
      },
      MainCategory.marketingAndSales: {
        'id': 'marketingAndSales',
        'name': 'marketingAndSales',
        'nameHebrew': 'שיווק ומכירות',
        'nameArabic': 'التسويق والمبيعات',
        'nameEnglish': 'Marketing and Sales',
        'icon': '🛒',
        'order': 4,
      },
      MainCategory.technologyAndComputers: {
        'id': 'technologyAndComputers',
        'name': 'technologyAndComputers',
        'nameHebrew': 'טכנולוגיה, מחשבים ואפליקציות',
        'nameArabic': 'التكنولوجيا وأجهزة الكمبيوتر والتطبيقات',
        'nameEnglish': 'Technology, Computers and Applications',
        'icon': '🛠️',
        'order': 5,
      },
      MainCategory.vehicles: {
        'id': 'vehicles',
        'name': 'vehicles',
        'nameHebrew': 'כלי תחבורה',
        'nameArabic': 'وسائل النقل',
        'nameEnglish': 'Vehicles',
        'icon': '🚗',
        'order': 6,
      },
      MainCategory.gardeningAndCleaning: {
        'id': 'gardeningAndCleaning',
        'name': 'gardeningAndCleaning',
        'nameHebrew': 'גינון, ניקיון וסביבה',
        'nameArabic': 'البستنة والتنظيف والبيئة',
        'nameEnglish': 'Gardening, Cleaning and Environment',
        'icon': '🌱',
        'order': 7,
      },
      MainCategory.educationAndTraining: {
        'id': 'educationAndTraining',
        'name': 'educationAndTraining',
        'nameHebrew': 'חינוך, לימודים והדרכה',
        'nameArabic': 'التعليم والتدريب',
        'nameEnglish': 'Education and Training',
        'icon': '🎓',
        'order': 8,
      },
      MainCategory.professionalConsulting: {
        'id': 'professionalConsulting',
        'name': 'professionalConsulting',
        'nameHebrew': 'ייעוץ והכוונה מקצועית',
        'nameArabic': 'الاستشارة والتوجيه المهني',
        'nameEnglish': 'Professional Consulting and Guidance',
        'icon': '🧭',
        'order': 9,
      },
      MainCategory.artsAndMedia: {
        'id': 'artsAndMedia',
        'name': 'artsAndMedia',
        'nameHebrew': 'יצירה, אומנות ומדיה',
        'nameArabic': 'الإبداع والفن والإعلام',
        'nameEnglish': 'Creativity, Art and Media',
        'icon': '🎨',
        'order': 10,
      },
      MainCategory.specialServices: {
        'id': 'specialServices',
        'name': 'specialServices',
        'nameHebrew': 'שירותים מיוחדים ופתוחים',
        'nameArabic': 'خدمات خاصة ومفتوحة',
        'nameEnglish': 'Special and Open Services',
        'icon': '💡',
        'order': 11,
      },
    };

    return mainCategoryMap.values.toList();
  }

  /// Get sub categories from enum (fallback)
  static List<Map<String, dynamic>> _getSubCategoriesFromEnum({String? mainCategoryId}) {
    final allSubCategories = RequestCategory.values.map((category) {
      final mainCategory = category.mainCategory;
      return {
        'id': category.name,
        'name': category.name,
        'nameHebrew': category.categoryDisplayName,
        'nameArabic': category.categoryDisplayName, // TODO: Add Arabic translations
        'nameEnglish': category.name, // TODO: Add English translations
        'mainCategoryId': mainCategory.name,
        'order': RequestCategory.values.indexOf(category),
      };
    }).toList();

    if (mainCategoryId != null) {
      // Find the main category name from the id
      final mainCategoryName = MainCategory.values.firstWhere(
        (mc) => mc.name == mainCategoryId,
        orElse: () => MainCategory.constructionAndMaintenance,
      ).name;

      return allSubCategories
          .where((cat) => cat['mainCategoryId'] == mainCategoryName)
          .toList();
    }

    return allSubCategories;
  }

  /// Get category display name by name/id
  static Future<String> getCategoryDisplayName(String categoryName, {String? language}) async {
    try {
      final subCategories = await getSubCategories();
      final category = subCategories.firstWhere(
        (cat) => cat['name'] == categoryName || cat['id'] == categoryName,
        orElse: () => {},
      );

      if (category.isNotEmpty) {
        switch (language) {
          case 'ar':
            return category['nameArabic'] ?? category['nameHebrew'] ?? categoryName;
          case 'en':
            return category['nameEnglish'] ?? category['nameHebrew'] ?? categoryName;
          default:
            return category['nameHebrew'] ?? categoryName;
        }
      }
    } catch (e) {
      debugPrint('Error getting category display name: $e');
    }

    // Fallback to enum
    try {
      final category = RequestCategory.values.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => RequestCategory.plumbing,
      );
      return category.categoryDisplayName;
    } catch (e) {
      return categoryName;
    }
  }

  /// Convert RequestCategory enum to Firestore category name
  static String categoryEnumToName(RequestCategory category) {
    return category.name;
  }

  /// Convert Firestore category name to RequestCategory enum
  static RequestCategory? categoryNameToEnum(String categoryName) {
    try {
      return RequestCategory.values.firstWhere(
        (c) => c.name == categoryName,
      );
    } catch (e) {
      return null;
    }
  }
}

