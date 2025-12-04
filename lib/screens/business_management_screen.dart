import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/request.dart';
import '../models/ad.dart';
import '../l10n/app_localizations.dart';
import 'location_picker_screen.dart';
import '../widgets/phone_input_widget.dart';
import '../widgets/two_level_category_selector.dart';
import '../widgets/network_aware_widget.dart';
import '../utils/phone_validation.dart';
import '../services/payme_payment_service.dart';
import '../services/manual_payment_service.dart';
import '../models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_screen.dart';

class BusinessManagementScreen extends StatefulWidget {
  const BusinessManagementScreen({super.key});

  @override
  State<BusinessManagementScreen> createState() => _BusinessManagementScreenState();
}

// מודל מרכיב
class _Ingredient {
  final TextEditingController nameController;
  final TextEditingController costController;

  _Ingredient({
    required this.nameController,
    required this.costController,
  });

  void dispose() {
    nameController.dispose();
    costController.dispose();
  }
}

// מודל שירות
class _Service {
  final TextEditingController nameController;
  final TextEditingController priceController;
  File? imageFile;
  bool isCustomPrice;
  final List<_Ingredient> ingredients;

  _Service({
    required this.nameController,
    required this.priceController,
  }) : imageFile = null,
       isCustomPrice = false,
       ingredients = [];

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    for (final ingredient in ingredients) {
      ingredient.dispose();
    }
  }
}

class _BusinessManagementScreenState extends State<BusinessManagementScreen> with NetworkAwareMixin {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // משתנים חדשים לטלפון
  String _selectedPhonePrefix = '';
  String _selectedPhoneNumber = '';
  
  final List<RequestCategory> _selectedCategories = [];
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = false;
  
  // רשימת שירותים
  final List<_Service> _services = [];
  
  // תמונת עסק
  File? _businessImageFile;
  String? _businessImageUrl;
  bool _isUploadingBusinessImage = false;
  
  // קישורים חברתיים
  final Map<String, TextEditingController> _socialLinksControllers = {
    'instagram': TextEditingController(),
    'facebook': TextEditingController(),
    'tiktok': TextEditingController(),
    'website': TextEditingController(),
  };
  
  
  @override
  void initState() {
    super.initState();
    debugPrint('🔍 BusinessManagementScreen initState called');
    // טעינת מספר הטלפון אחרי שה-widget נבנה
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      _loadUserPhoneNumber();
      }
    });
  }
  
  // טעינת מספר הטלפון מהפרופיל
  Future<void> _loadUserPhoneNumber() async {
    try {
      debugPrint('🔍 _loadUserPhoneNumber: Starting to load user phone number');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('🔍 _loadUserPhoneNumber: No user found');
        return;
      }
      
      debugPrint('🔍 _loadUserPhoneNumber: User ID: ${user.uid}');
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final phoneNumber = userData['phoneNumber'] as String?;
        
        debugPrint('🔍 _loadUserPhoneNumber: Phone number from profile: $phoneNumber');
        
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          // חלוקת המספר לקידומת ומספר
          final phoneParts = _parsePhoneNumber(phoneNumber);
          debugPrint('🔍 _loadUserPhoneNumber: Parsed phone parts: $phoneParts');
          
          if (phoneParts != null) {
            if (mounted) {
              setState(() {
                _selectedPhonePrefix = phoneParts['prefix']!;
                _selectedPhoneNumber = phoneParts['number']!;
              });
              debugPrint('🔍 _loadUserPhoneNumber: Set prefix: "$_selectedPhonePrefix", number: "$_selectedPhoneNumber"');
              debugPrint('🔍 _loadUserPhoneNumber: _selectedPhonePrefix.isNotEmpty: ${_selectedPhonePrefix.isNotEmpty}');
              debugPrint('🔍 _loadUserPhoneNumber: _selectedPhoneNumber.isNotEmpty: ${_selectedPhoneNumber.isNotEmpty}');
            }
          } else {
            debugPrint('🔍 _loadUserPhoneNumber: Failed to parse phone number: $phoneNumber');
          }
        } else {
          debugPrint('🔍 _loadUserPhoneNumber: No phone number in profile');
        }
      } else {
        debugPrint('🔍 _loadUserPhoneNumber: User document does not exist');
      }
    } catch (e) {
      debugPrint('🔍 _loadUserPhoneNumber: Error loading user phone number: $e');
    }
  }
  
  // פונקציה לחלוקת מספר טלפון לקידומת ומספר
  Map<String, String>? _parsePhoneNumber(String phoneNumber) {
    // ניקוי המספר מתווים לא רלוונטיים
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    debugPrint('🔍 _parsePhoneNumber: Clean number: $cleanNumber');
    
    // בדיקה אם המספר מתחיל ב-+972
    if (cleanNumber.startsWith('+972')) {
      final number = cleanNumber.substring(4); // הסרת +972
      debugPrint('🔍 _parsePhoneNumber: After removing +972: $number');
      if (number.length >= 7) { // שינוי מ-9 ל-7
        // חילוץ הקידומת הישראלית
        final israeliPrefix = _extractIsraeliPrefix(number);
        if (israeliPrefix != null) {
          debugPrint('🔍 _parsePhoneNumber: Found prefix: $israeliPrefix');
          final extractedNumber = number.substring(israeliPrefix.length);
          debugPrint('🔍 _parsePhoneNumber: Extracted number: $extractedNumber');
          debugPrint('🔍 _parsePhoneNumber: Final format should be: $israeliPrefix-$extractedNumber');
          return {
            'prefix': israeliPrefix,
            'number': extractedNumber,
          };
        }
      }
    }
    
    // בדיקה אם המספר מתחיל ב-972
    if (cleanNumber.startsWith('972')) {
      final number = cleanNumber.substring(3); // הסרת 972
      debugPrint('🔍 _parsePhoneNumber: After removing 972: $number');
      if (number.length >= 7) { // שינוי מ-9 ל-7
        // חילוץ הקידומת הישראלית
        final israeliPrefix = _extractIsraeliPrefix(number);
        if (israeliPrefix != null) {
          debugPrint('🔍 _parsePhoneNumber: Found prefix: $israeliPrefix');
          return {
            'prefix': israeliPrefix,
            'number': number.substring(israeliPrefix.length),
          };
        }
      }
    }
    
    // בדיקה אם המספר מתחיל ב-0
    if (cleanNumber.startsWith('0')) {
      debugPrint('🔍 _parsePhoneNumber: Number starts with 0: $cleanNumber');
      // חילוץ הקידומת הישראלית ישירות מהמספר המלא
      final israeliPrefix = _extractIsraeliPrefix(cleanNumber);
      if (israeliPrefix != null) {
        debugPrint('🔍 _parsePhoneNumber: Found prefix: $israeliPrefix');
        return {
          'prefix': israeliPrefix,
          'number': cleanNumber.substring(israeliPrefix.length),
        };
      }
    }
    
    debugPrint('🔍 _parsePhoneNumber: Failed to parse phone number');
    return null;
  }
  
  // פונקציה לחילוץ קידומת ישראלית
  String? _extractIsraeliPrefix(String number) {
    const israeliPrefixes = [
      '050', '051', '052', '053', '054', '055', '056', '057', '058', '059', // סלולרי
      '02', '03', '04', '08', '09', // קווי
    ];
    
    for (String prefix in israeliPrefixes) {
      if (number.startsWith(prefix)) {
        return prefix;
      }
    }
    
    return null;
  }
  
  // הפונקציה הוסרה - לא נדרש יותר
  // ignore: unused_element
  Widget _buildDetailedRatingField(
    String title,
    String description,
    double? currentValue,
    Function(double?) onChanged,
    IconData icon,
    Color color,
  ) {
    // אם אין ערך, נגדיר 0.0
    final ratingValue = currentValue ?? 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${ratingValue.toStringAsFixed(1)}+',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // סליידר תמיד מוצג
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  ratingValue.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '5',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: ratingValue,
                min: 0.0,
                max: 5.0,
                divisions: 50, // 0.1 increments
                onChanged: (value) => onChanged(value),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // שדות מיקום
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;
  double? _exposureRadius; // רדיוס חשיפה בקילומטרים

  // שדות חדשים למודעה
  bool _requiresAppointment = false; // האם השירות דורש תור
  bool _requiresDelivery = false; // האם השירות דורש משלוח
  // שדות מיקום משלוח - לא נדרש יותר, משתמשים במיקום הראשי

  // בדיקת התראות סינון (לא נדרש למודעות כרגע)
  // TODO: להוסיף התראות למודעות אם נדרש
  // ignore: unused_element
  Future<void> _checkFilterNotifications(Ad ad) async {
    try {
      debugPrint('🔔 ===== START _checkFilterNotifications =====');
      debugPrint('🔔 Ad: ${ad.title} (ID: ${ad.adId}), Category: ${ad.category.categoryDisplayName}');
      
      final prefs = await SharedPreferences.getInstance();
      final notificationKeys = prefs.getStringList('filter_notification_keys') ?? [];
      
      // רשימת משתמשים שקיבלו התראה מותאמת אישית
      // Set<String> usersWithCustomNotifications = {}; // לא בשימוש כרגע
      
      if (notificationKeys.isEmpty) {
        debugPrint('🔔 No custom filter notifications found - will send default notifications to all matching users');
      } else {
        debugPrint('🔔 Checking ${notificationKeys.length} custom filter notifications');
      
      for (String key in notificationKeys) {
        try {
          final filterDataString = prefs.getString(key);
          if (filterDataString == null) continue;
          
          // פענוח נתוני הסינון (זה דוגמה פשוטה - בפועל צריך JSON)
            debugPrint('🔔 Checking filter: $key');
          
          // בדיקה אם המודעה מתאימה לסינון (לא נדרש למודעות כרגע)
          // bool matchesFilter = await _doesRequestMatchFilter(ad, filterDataString);
          
          // if (matchesFilter) {
          //     debugPrint('✅ Ad matches filter: $key');
          //   // כאן אפשר לשלוח התראה למשתמש
          //   // await _sendFilterNotification(ad, key);
          //   // usersWithCustomNotifications.add(userId);
          // }
        } catch (e) {
            debugPrint('❌ Error checking filter $key: $e');
          }
        }
      }
      
      // אם יש משתמשים עם סינון מותאם אישית, נשלח להם התראות מותאמות
      // ואחר כך נשלח התראות רגילות לשאר המשתמשים
      // TODO: להוסיף התראות למודעות אם נדרש
      // if (usersWithCustomNotifications.isNotEmpty) {
      //   debugPrint('🔔 Sending custom notifications to ${usersWithCustomNotifications.length} users');
      //   await _sendCustomFilterNotifications(ad, usersWithCustomNotifications);
      // }
      
      // נשלח התראות רגילות לשאר המשתמשים (תמיד נקרא, גם אם אין custom filters)
      // TODO: להוסיף התראות למודעות אם נדרש
      // debugPrint('🔔 Sending default notifications to all matching users');
      // await _sendDefaultNotifications(ad, usersWithCustomNotifications);
      
      debugPrint('✅ ===== END _checkFilterNotifications =====');
      
    } catch (e) {
      debugPrint('❌ ===== ERROR in _checkFilterNotifications =====');
      debugPrint('Error: $e');
      // במקרה של שגיאה, נשלח התראות רגילות
      // TODO: להוסיף התראות למודעות אם נדרש
      // await _sendDefaultNotifications(ad, {});
    }
  }

  // בדיקה אם מודעה מתאימה לסינון (לא נדרש למודעות כרגע)
  // ignore: unused_element
  Future<bool> _doesRequestMatchFilter(Ad ad, String filterDataString) async {
    try {
      // פענוח נתוני הסינון
      final filterData = _parseFilterData(filterDataString);
      if (filterData == null) return false;
      
      // TODO: להוסיף לוגיקה לבדיקת מודעות אם נדרש
      debugPrint('Checking if ad matches filter: ${ad.title}');
      debugPrint('Filter data: $filterDataString');
      
      // לא נדרש למודעות כרגע - נחזיר true
      return true;
    } catch (e) {
      debugPrint('Error in _doesRequestMatchFilter: $e');
      return false;
    }
  }

  // בדיקה אם קטגוריה שייכת לתחום ראשי
  // ignore: unused_element
  bool _isCategoryInMainCategory(RequestCategory category, String mainCategory) {
    // כאן צריך להוסיף לוגיקה שמתאימה בין קטגוריות לתחומים ראשיים
    // כרגע נחזיר true לכל הקטגוריות (לצורך הדגמה)
    debugPrint('Checking if ${category.name} belongs to main category: $mainCategory');
    return true; // דוגמה - תמיד נחזיר true
  }

  // שליחת התראות מותאמות אישית
  // לא נדרש למודעות כרגע
  // ignore: unused_element
  Future<void> _sendCustomFilterNotifications(Ad ad, Set<String> userIds) async {
    try {
      // TODO: להוסיף התראות למודעות אם נדרש
      debugPrint('Sending custom filter notifications for ad: ${ad.title}');
      return; // לא נדרש למודעות כרגע
      
      // for (String userId in userIds) {
      //   try {
      //     // לא לשלוח התראה ליוצר המודעה עצמו
      //     if (userId == ad.createdBy) {
      //       debugPrint('⏭️ Skipping creator $userId for custom filter notification');
      //       continue;
      //     }
      //     // קבלת פרטי המשתמש
      //     final userDoc = await FirebaseFirestore.instance
      //         .collection('users')
      //         .doc(userId)
      //         .get();
      //     
      //     if (!userDoc.exists) continue;
      //     
      //     final userData = userDoc.data()!;
      //     final userName = userData['displayName'] as String? ?? 'משתמש';
      //     
      //     // שליחת התראה מותאמת אישית
      //     // TODO: להוסיף פונקציה לשליחת התראות למודעות
      //     // await NotificationService.sendNewAdNotification(
      //     //   toUserId: userId,
      //     //   adTitle: ad.title,
      //     //   adCategory: ad.category.categoryDisplayName,
      //     //   adId: ad.adId,
      //     //   creatorName: userName,
      //     // );
      //     
      //     debugPrint('Custom filter notification sent to user: $userId');
      //   } catch (e) {
      //     debugPrint('Error sending custom notification to user $userId: $e');
      //   }
      // }
      // 
      // debugPrint('Custom filter notifications sent successfully');
    } catch (e) {
      debugPrint('Error sending custom filter notifications: $e');
    }
  }

  // פענוח נתוני הסינון
  Map<String, dynamic>? _parseFilterData(String filterDataString) {
    try {
      // הסרת סוגריים ותווים מיותרים
      String cleanData = filterDataString
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll(' ', '');
      
      Map<String, dynamic> result = {};
      
      // פיצול לפי פסיקים
      List<String> pairs = cleanData.split(',');
      
      for (String pair in pairs) {
        List<String> keyValue = pair.split(':');
        if (keyValue.length == 2) {
          String key = keyValue[0].trim();
          String value = keyValue[1].trim();
          
          // המרת ערכים
          if (value == 'null') {
            result[key] = null;
          } else if (value == 'true') {
            result[key] = true;
          } else if (value == 'false') {
            result[key] = false;
          } else if (value.contains('.')) {
            result[key] = double.tryParse(value);
          } else {
            result[key] = value;
          }
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('Error parsing filter data: $e');
      return null;
    }
  }

  // שליחת התראות רגילות למשתמשים שלא קיבלו התראות מותאמות אישית (לא נדרש למודעות כרגע)
  // ignore: unused_element
  Future<void> _sendDefaultNotifications(Ad ad, Set<String> usersWithCustomNotifications) async {
    // TODO: להוסיף התראות למודעות אם נדרש
      debugPrint('🚀 ===== START _sendDefaultNotifications =====');
    debugPrint('📝 Ad: ${ad.title} (ID: ${ad.adId})');
    debugPrint('📝 Category: ${ad.category.categoryDisplayName} (${ad.category.name})');
    debugPrint('📝 Location: ${ad.latitude}, ${ad.longitude}');
    debugPrint('📝 Exposure Radius: ${ad.exposureRadius} km');
      debugPrint('📝 Users with custom notifications: ${usersWithCustomNotifications.length}');
    return; // לא נדרש למודעות כרגע
    /*
    try {
      
      // קבלת כל המשתמשים שיש להם את הקטגוריה הזו בתחומי העיסוק שלהם
      // תמיכה גם בערכים ישנים שנשמרו בשם הפנימי של ה-enum וגם בתצוגה בעברית
      final displayName = request.category.categoryDisplayName;
      final internalName = request.category.name;

      debugPrint('🔍 Searching users with category: "$displayName" or "$internalName"');
      
      final queryByDisplayName = await FirebaseFirestore.instance
          .collection('users')
          .where('businessCategories', arrayContains: displayName)
          .get();

      final queryByInternalName = await FirebaseFirestore.instance
          .collection('users')
          .where('businessCategories', arrayContains: internalName)
          .get();

      debugPrint('🔍 Query by displayName ("$displayName") found: ${queryByDisplayName.docs.length} users');
      debugPrint('🔍 Query by internalName ("$internalName") found: ${queryByInternalName.docs.length} users');

      // מיזוג התוצאות ללא כפילויות
      final Map<String, DocumentSnapshot<Map<String, dynamic>>> userDocs = {};
      for (final doc in queryByDisplayName.docs) {
        userDocs[doc.id] = doc;
      }
      for (final doc in queryByInternalName.docs) {
        userDocs[doc.id] = doc;
      }

      debugPrint('📣 Candidate users for notification (unique): ${userDocs.length}');
      debugPrint('📣 Request details: ID=${request.requestId}, Category=${request.category.categoryDisplayName}, Location=${request.latitude},${request.longitude}, ExposureRadius=${request.exposureRadius} km');

      // קבלת שם מציג של יוצר הבקשה
      String creatorDisplayName = 'משתמש';
      try {
        final creatorDoc = await FirebaseFirestore.instance.collection('users').doc(request.createdBy).get();
        if (creatorDoc.exists) {
          final cd = creatorDoc.data();
          if (cd != null) {
            final displayName = (cd['displayName'] as String?)?.trim();
            final email = (cd['email'] as String?)?.trim();
            final bool looksLikeUid = displayName != null && RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(displayName) && !displayName.contains(' ');
            if (displayName != null && displayName.isNotEmpty && !looksLikeUid) {
              creatorDisplayName = displayName;
            } else if (email != null && email.contains('@')) {
              creatorDisplayName = email.split('@').first;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to fetch creator display name, using fallback: $e');
      }

      for (final userDoc in userDocs.values) {
        final userData = userDoc.data();
        if (userData == null) {
          continue;
        }
        final userId = userDoc.id;
        final userType = userData['userType'] as String? ?? 'personal';
        debugPrint('👤 Considering user $userId (type: $userType) for request ${request.requestId}');
        debugPrint('   User mobile location: ${userData['mobileLatitude']}, ${userData['mobileLongitude']}');
        debugPrint('   User fixed location: ${userData['latitude']}, ${userData['longitude']}');
        
        // דילוג על משתמשים שכבר קיבלו התראה מותאמת אישית
        if (usersWithCustomNotifications.contains(userId)) {
          debugPrint('Skipping user $userId - already received custom notification');
          continue;
        }
        
        // לא לשלוח התראה למשתמש שיצר את הבקשה
        if (userId == FirebaseAuth.instance.currentUser?.uid) {
          debugPrint('Skipping user $userId - is the creator of the request');
          continue;
        }
        
        // בדיקה למשתמשים עסקיים - רק עם מנוי פעיל
        if (userType == 'business') {
          final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
          if (!isSubscriptionActive) {
            debugPrint('Skipping user $userId - business user without active subscription');
            continue;
          }
        }
        
        // בדיקה למשתמשי אורח - רק אם יש להם תחומי עיסוק
        if (userType == 'guest') {
          final businessCategories = userData['businessCategories'] as List?;
          if (businessCategories == null || businessCategories.isEmpty) {
            debugPrint('Skipping user $userId - guest user without business categories');
            continue;
          }
        }
        
        // בדיקת העדפות התראות
        final notificationPrefs = await NotificationPreferencesService
            .getNotificationPreferencesWithDefaults(userId);
        
        // בדיקה אם יש FilterPreferences עם התראות מופעלות
        FilterPreferences? filterPrefs;
        try {
          filterPrefs = await FilterPreferencesService.getFilterPreferences(userId);
        } catch (e) {
          debugPrint('❌ Error loading filter preferences for user $userId: $e');
        }
        
        // בדיקה אם המשתמש רוצה התראות על בקשות חדשות
        // ✅ בדיקה ראשונה: העדפות מיקום רגילות (קבוע/נייד)
        final wantsRegularNotifications = notificationPrefs.newRequestsUseFixedLocation ||
            notificationPrefs.newRequestsUseMobileLocation ||
            notificationPrefs.newRequestsUseBothLocations;
        
        // ✅ בדיקה שנייה: FilterPreferences עם התראות מופעלות (כולל מיקום נוסף)
        final wantsFilterNotifications = filterPrefs != null && 
            filterPrefs.isEnabled &&
            (filterPrefs.categories.isNotEmpty ||
             filterPrefs.maxRadius != null ||
             filterPrefs.urgency != null ||
             filterPrefs.requestType != null ||
             (filterPrefs.useAdditionalLocation && 
              filterPrefs.additionalLocationLatitude != null &&
              filterPrefs.additionalLocationLongitude != null &&
              filterPrefs.additionalLocationRadius != null));
        
        final wantsNotifications = wantsRegularNotifications || wantsFilterNotifications;
        
        if (!wantsNotifications) {
          debugPrint('Skipping user $userId - notification preferences disabled');
          continue;
        }
        
        // בדיקת מיקום וטווח לפי ההעדפות
        debugPrint('🔍 Checking notification eligibility for user $userId:');
        debugPrint('   Notification prefs - UseFixedLocation: ${notificationPrefs.newRequestsUseFixedLocation}');
        debugPrint('   Notification prefs - UseMobileLocation: ${notificationPrefs.newRequestsUseMobileLocation}');
        debugPrint('   Notification prefs - UseBothLocations: ${notificationPrefs.newRequestsUseBothLocations}');
        final shouldNotify = await _shouldNotifyUser(
          userId: userId,
          userData: userData,
          request: request,
          notificationPrefs: notificationPrefs,
          filterPrefs: filterPrefs, // ✅ העברת FilterPreferences לפונקציה
        );
        
        if (!shouldNotify) {
          debugPrint('❌ Skipping user $userId - location/distance check failed');
          continue;
        } else {
          debugPrint('✅ User $userId passed location/distance check - sending notification');
        }
        
        try {
          // חישוב מרחק מהמיקום של המשתמש לשילוב בהודעה
          double? distanceKm;
          String? distanceSourceHeb;
          if (request.latitude != null && request.longitude != null) {
            final double rLat = request.latitude!;
            final double rLng = request.longitude!;

            final double? mobileLat = (userData['mobileLatitude'] as num?)?.toDouble();
            final double? mobileLng = (userData['mobileLongitude'] as num?)?.toDouble();
            final double? fixedLat = (userData['latitude'] as num?)?.toDouble();
            final double? fixedLng = (userData['longitude'] as num?)?.toDouble();

            double? mobileDist;
            double? fixedDist;
            if (mobileLat != null && mobileLng != null) {
              mobileDist = Geolocator.distanceBetween(mobileLat, mobileLng, rLat, rLng) / 1000.0;
            }
            if (fixedLat != null && fixedLng != null) {
              fixedDist = Geolocator.distanceBetween(fixedLat, fixedLng, rLat, rLng) / 1000.0;
            }

            if (notificationPrefs.newRequestsUseBothLocations) {
              // בחר את הקטן מבין הזמינים
              if (mobileDist != null && fixedDist != null) {
                if (mobileDist <= fixedDist) {
                  distanceKm = mobileDist;
                  distanceSourceHeb = 'מהמיקום הנייד';
                } else {
                  distanceKm = fixedDist;
                  distanceSourceHeb = 'מהמיקום הקבוע';
                }
              } else if (mobileDist != null) {
                distanceKm = mobileDist;
                distanceSourceHeb = 'מהמיקום הנייד';
              } else if (fixedDist != null) {
                distanceKm = fixedDist;
                distanceSourceHeb = 'מהמיקום הקבוע';
              }
            } else if (notificationPrefs.newRequestsUseMobileLocation && mobileDist != null) {
              distanceKm = mobileDist;
              distanceSourceHeb = 'מהמיקום הנייד';
            } else if (notificationPrefs.newRequestsUseFixedLocation && fixedDist != null) {
              distanceKm = fixedDist;
              distanceSourceHeb = 'מהמיקום הקבוע';
            }
          }
        
        await NotificationService.sendNewRequestNotification(
          toUserId: userId,
          requestTitle: request.title,
          requestCategory: request.category.categoryDisplayName,
          requestId: request.requestId,
            creatorName: creatorDisplayName,
            distanceKm: distanceKm,
            distanceSourceHeb: distanceSourceHeb,
          );
          debugPrint('✅ Default notification sent to user: $userId');
        } catch (e) {
          debugPrint('❌ Failed sending notification to $userId: $e');
        }
      }
      
      debugPrint('✅ ===== END _sendDefaultNotifications - Success =====');
    } catch (e, stackTrace) {
      debugPrint('❌ ===== ERROR in _sendDefaultNotifications =====');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    */
  }

  /// בדיקה אם צריך לשלוח התראה למשתמש לפי מיקום וטווח
  // לא נדרש למודעות כרגע
  /*
  Future<bool> _shouldNotifyUser({
    required String userId,
    required Map<String, dynamic> userData,
    required Request request,
    required NotificationPreferences notificationPrefs,
    FilterPreferences? filterPrefs, // ✅ פרמטר נוסף ל-FilterPreferences
  }) async {
    try {
      // אם אין מיקום לבקשה, תמיד לשלוח (אם לא בוטל ב-prefs)
      if (request.latitude == null || request.longitude == null) {
        return true;
      }
      
      final requestLat = request.latitude!;
      final requestLng = request.longitude!;
      final exposureRadius = request.exposureRadius ?? 0.0; // קילומטרים

      // טווח סינון של המשתמש (אם הגדר בהתראות/סינון בקשות)
      double? userFilterRadiusKm;
      List<String> userFilterCategories = const [];
      String? userFilterRequestType; // 'paid' | 'free'
      bool filterIsEnabled = false;
      
      // ✅ אם FilterPreferences לא הועבר, נטען אותו
      FilterPreferences? finalFilterPrefs = filterPrefs;
      if (finalFilterPrefs == null) {
        try {
          finalFilterPrefs = await FilterPreferencesService.getFilterPreferences(userId);
        } catch (e) {
          debugPrint('❌ Error loading filter preferences: $e');
        }
      }
      
      if (finalFilterPrefs != null) {
        filterIsEnabled = finalFilterPrefs.isEnabled;
        userFilterRadiusKm = finalFilterPrefs.maxRadius;
        userFilterCategories = finalFilterPrefs.categories;
        userFilterRequestType = finalFilterPrefs.requestType;
        }

      // אם המשתמש לא הפעיל התראות מסוננות – עדיין נמשיך לפי העדפות ההתראה (notificationPrefs),
      // אך אם הוא הפעיל סינון – נדרוש התאמה גם לפילטרים שבחר.
      
      // בדיקת מיקום קבוע
      bool fixedLocationMatch = false;
      if (notificationPrefs.newRequestsUseFixedLocation || notificationPrefs.newRequestsUseBothLocations) {
        final userFixedLat = userData['latitude']?.toDouble();
        final userFixedLng = userData['longitude']?.toDouble();
        
        if (userFixedLat != null && userFixedLng != null) {
          // בדיקה אם הבקשה נמצאת בטווח החשיפה מהמיקום הקבוע של המשתמש
          final distanceFromFixed = Geolocator.distanceBetween(
            userFixedLat,
            userFixedLng,
            requestLat,
            requestLng,
          ) / 1000; // המרה למטרים לקילומטרים
          
          // בדיקה אם הבקשה נמצאת בטווח החשיפה מהמיקום הקבוע של המשתמש
          if (distanceFromFixed <= exposureRadius) {
            fixedLocationMatch = true;
            debugPrint('✅ Fixed location match for user $userId: distance = ${distanceFromFixed.toStringAsFixed(2)} km, exposure radius = ${exposureRadius.toStringAsFixed(2)} km');
          }
          
          // בדיקה גם בכיוון השני - אם המיקום הקבוע של המשתמש נמצא בטווח החשיפה של הבקשה
          // (זה לא צריך להיות כפול, אבל בואו נשמור את זה לכל מקרה)
          // כבר בדקנו למעלה
        }
      }
      
      // בדיקת מיקום נייד - נבדוק אם נשמר ב-Firestore
      bool mobileLocationMatch = false;
      if (notificationPrefs.newRequestsUseMobileLocation || notificationPrefs.newRequestsUseBothLocations) {
        double? userMobileLat = userData['mobileLatitude']?.toDouble();
        double? userMobileLng = userData['mobileLongitude']?.toDouble();

        // אם אין מיקום נייד שמור, ננסה למשוך אותו מהשרת מספר פעמים (כל 30 שנ')
        int retries = 3; // נבדוק למשך דקה וחצי סה"כ
        while ((userMobileLat == null || userMobileLng == null) && retries > 0) {
          await Future.delayed(const Duration(seconds: 30));
          try {
            final refreshedUserDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            final refreshed = refreshedUserDoc.data();
            userMobileLat = refreshed?['mobileLatitude']?.toDouble();
            userMobileLng = refreshed?['mobileLongitude']?.toDouble();
            if (userMobileLat != null && userMobileLng != null) {
              debugPrint('📍 Pulled fresh mobile location for user $userId');
              break;
            }
          } catch (_) {}
          retries--;
        }

        if (userMobileLat != null && userMobileLng != null) {
          // בדיקה אם הבקשה נמצאת בטווח החשיפה מהמיקום הנייד של המשתמש
          final distanceFromMobile = Geolocator.distanceBetween(
            userMobileLat,
            userMobileLng,
            requestLat,
            requestLng,
          ) / 1000; // המרה למטרים לקילומטרים
          
          debugPrint('📍 Checking mobile location for user $userId:');
          debugPrint('   Mobile location: $userMobileLat, $userMobileLng');
          debugPrint('   Request location: $requestLat, $requestLng');
          debugPrint('   Distance: ${distanceFromMobile.toStringAsFixed(2)} km');
          debugPrint('   Request exposure radius: ${exposureRadius.toStringAsFixed(2)} km');
          
          if (distanceFromMobile <= exposureRadius) {
            mobileLocationMatch = true;
            debugPrint('✅ Mobile location match for user $userId: distance = ${distanceFromMobile.toStringAsFixed(2)} km <= exposure radius = ${exposureRadius.toStringAsFixed(2)} km');
          } else {
            debugPrint('❌ Mobile location NOT in range for user $userId: distance = ${distanceFromMobile.toStringAsFixed(2)} km > exposure radius = ${exposureRadius.toStringAsFixed(2)} km');
          }
          
        } else {
          debugPrint('⚠️ No mobile location stored for user $userId (mobileLat: $userMobileLat, mobileLng: $userMobileLng) - will use fixed location if available');
          // אם אין מיקום נייד אך יש העדפה "מיקום נייד בלבד" - ניפול חזרה למיקום קבוע כדי לא לפספס
          // זאת בהתאם לדרישה לבדוק גם מיקום קבוע
          if (notificationPrefs.newRequestsUseMobileLocation && !notificationPrefs.newRequestsUseBothLocations && !fixedLocationMatch) {
            debugPrint('⚠️ User $userId prefers mobile location only, but no mobile location available and fixed location does not match');
            return false;
          }
        }
      }
      
      // בדיקה לפי טווח הסינון של המשתמש (אם הוגדר) מול המיקום הטוב ביותר הזמין
      bool userFilterRadiusMatch = false;
      if (userFilterRadiusKm != null && userFilterRadiusKm > 0) {
        debugPrint('🔍 Checking user filter radius for user $userId: filterMaxRadius = $userFilterRadiusKm km');
        // בחר מיקום משתמש מועדף לפי ההעדפות: נייד -> קבוע
        double? bestLat;
        double? bestLng;
        String bestLocationSource = 'none';
        if (notificationPrefs.newRequestsUseMobileLocation || notificationPrefs.newRequestsUseBothLocations) {
          bestLat = userData['mobileLatitude']?.toDouble();
          bestLng = userData['mobileLongitude']?.toDouble();
          if (bestLat != null && bestLng != null) {
            bestLocationSource = 'mobile';
          }
        }
        if ((bestLat == null || bestLng == null) && (notificationPrefs.newRequestsUseFixedLocation || notificationPrefs.newRequestsUseBothLocations)) {
          bestLat = userData['latitude']?.toDouble();
          bestLng = userData['longitude']?.toDouble();
          if (bestLat != null && bestLng != null) {
            bestLocationSource = 'fixed';
          }
        }
        if (bestLat != null && bestLng != null) {
          debugPrint('   Best location source: $bestLocationSource ($bestLat, $bestLng)');
          final distFromBest = Geolocator.distanceBetween(bestLat, bestLng, requestLat, requestLng) / 1000;
          debugPrint('   Distance from best location: ${distFromBest.toStringAsFixed(2)} km');
          debugPrint('   User filter max radius: $userFilterRadiusKm km');
          if (distFromBest <= userFilterRadiusKm) {
            userFilterRadiusMatch = true;
            debugPrint('✅ User filter radius match: distance = ${distFromBest.toStringAsFixed(2)} km (<= $userFilterRadiusKm km)');
          } else {
            debugPrint('❌ User filter radius NOT in range: distance = ${distFromBest.toStringAsFixed(2)} km (> $userFilterRadiusKm km)');
          }
        } else {
          debugPrint('⚠️ No location available for user filter radius check');
        }
      } else {
        debugPrint('🔍 No user filter radius defined (userFilterRadiusKm: $userFilterRadiusKm)');
      }
      
      // בדיקת מיקום נוסף (אם הוגדר בסינון)
      bool additionalLocationMatch = false;
      if (finalFilterPrefs != null &&
          finalFilterPrefs.useAdditionalLocation == true && 
          finalFilterPrefs.additionalLocationLatitude != null && 
          finalFilterPrefs.additionalLocationLongitude != null && 
          finalFilterPrefs.additionalLocationRadius != null) {
        final additionalLat = finalFilterPrefs.additionalLocationLatitude!;
        final additionalLng = finalFilterPrefs.additionalLocationLongitude!;
        final additionalRadius = finalFilterPrefs.additionalLocationRadius!;
        
        debugPrint('🔍 Checking additional location for user $userId:');
        debugPrint('   Additional location: $additionalLat, $additionalLng');
        debugPrint('   Additional location radius: $additionalRadius km');
        debugPrint('   Request location: $requestLat, $requestLng');
        
        final distFromAdditional = Geolocator.distanceBetween(
          additionalLat,
          additionalLng,
          requestLat,
          requestLng,
        ) / 1000;
        
        debugPrint('   Distance from additional location: ${distFromAdditional.toStringAsFixed(2)} km');
        debugPrint('   Additional location radius: $additionalRadius km');
        
        if (distFromAdditional <= additionalRadius) {
          additionalLocationMatch = true;
          debugPrint('✅ Additional location match: distance = ${distFromAdditional.toStringAsFixed(2)} km (<= $additionalRadius km)');
        } else {
          debugPrint('❌ Additional location NOT in range: distance = ${distFromAdditional.toStringAsFixed(2)} km (> $additionalRadius km)');
        }
      }

      // בדיקת קטגוריה מול סינון (אם המשתמש הגדיר קטגוריות בסינון)
      bool categoryFilterMatch = true; // ברירת מחדל – אם לא הגדיר קטגוריות
      if (filterIsEnabled && userFilterCategories.isNotEmpty) {
        final displayName = request.category.categoryDisplayName;
        final internalName = request.category.name;
        final bool filterCategoriesMatch = userFilterCategories.contains(displayName) || userFilterCategories.contains(internalName);

        // התאמה מול תחומי העיסוק של המשתמש (כגיבוי אם הפילטרים מצמצמים מדי)
        final List<dynamic> userBusinessCatsRaw = (userData['businessCategories'] as List?) ?? const [];
        final Set<String> userBusinessCats = userBusinessCatsRaw.map((e) => e.toString()).toSet();
        final bool businessCategoriesMatch = userBusinessCats.contains(displayName) || userBusinessCats.contains(internalName);

        categoryFilterMatch = filterCategoriesMatch || businessCategoriesMatch;
        debugPrint('   Category filter decision: filterMatch=$filterCategoriesMatch, businessMatch=$businessCategoriesMatch => final=$categoryFilterMatch');
      }

      // בדיקת סוג בקשה מול סינון (אם הוגדר)
      bool requestTypeFilterMatch = true;
      if (filterIsEnabled && userFilterRequestType != null) {
        if (userFilterRequestType == 'paid') {
          requestTypeFilterMatch = request.type == RequestType.paid;
        } else if (userFilterRequestType == 'free') {
          requestTypeFilterMatch = request.type == RequestType.free;
        }
      }

      // החזרת תוצאה: התאמת מיקום לפי ההעדפות OR התאמה לטווח הסינון שהמשתמש הגדיר OR מיקום נוסף
      debugPrint('📊 Final location check results for user $userId:');
      debugPrint('   Fixed location match: $fixedLocationMatch');
      debugPrint('   Mobile location match: $mobileLocationMatch');
      debugPrint('   User filter radius match: $userFilterRadiusMatch');
      debugPrint('   Additional location match: $additionalLocationMatch');
      debugPrint('   Category filter match: $categoryFilterMatch');
      debugPrint('   Request type filter match: $requestTypeFilterMatch');
      
      bool finalResult = false;
      if (notificationPrefs.newRequestsUseBothLocations) {
        finalResult = ((fixedLocationMatch || mobileLocationMatch) || userFilterRadiusMatch || additionalLocationMatch) && categoryFilterMatch && requestTypeFilterMatch;
        debugPrint('   Using "both locations" logic: (($fixedLocationMatch || $mobileLocationMatch) || $userFilterRadiusMatch || $additionalLocationMatch) && $categoryFilterMatch && $requestTypeFilterMatch = $finalResult');
      } else if (notificationPrefs.newRequestsUseFixedLocation) {
        finalResult = (fixedLocationMatch || userFilterRadiusMatch || additionalLocationMatch) && categoryFilterMatch && requestTypeFilterMatch;
        debugPrint('   Using "fixed location" logic: ($fixedLocationMatch || $userFilterRadiusMatch || $additionalLocationMatch) && $categoryFilterMatch && $requestTypeFilterMatch = $finalResult');
      } else if (notificationPrefs.newRequestsUseMobileLocation) {
        finalResult = (mobileLocationMatch || userFilterRadiusMatch || additionalLocationMatch) && categoryFilterMatch && requestTypeFilterMatch;
        debugPrint('   Using "mobile location" logic: ($mobileLocationMatch || $userFilterRadiusMatch || $additionalLocationMatch) && $categoryFilterMatch && $requestTypeFilterMatch = $finalResult');
      } else {
        // גם אם אין העדפות מיקום, נבדוק מיקום נוסף
        finalResult = additionalLocationMatch && categoryFilterMatch && requestTypeFilterMatch;
        debugPrint('   Using "additional location only" logic: $additionalLocationMatch && $categoryFilterMatch && $requestTypeFilterMatch = $finalResult');
        if (!additionalLocationMatch) {
          debugPrint('   ⚠️ No location preference enabled and no additional location match - returning false');
        return false;
        }
      }
      
      debugPrint('🎯 Final notification decision for user $userId: $finalResult');
      return finalResult;
    } catch (e) {
      debugPrint('❌ Error checking notification location for user $userId: $e');
      // במקרה של שגיאה, לא נשלוח התראה (זהירות)
      return false;
    }
  }
  */

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    // ניקוי כל השירותים
    for (var service in _services) {
      service.dispose();
    }
    // dispose של controllers לקישורים חברתיים
    for (var controller in _socialLinksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  // הוספת שירות חדש
  void _addService() {
    setState(() {
      _services.add(_Service(
        nameController: TextEditingController(),
        priceController: TextEditingController(),
      ));
    });
  }
  
  // הסרת שירות
  void _removeService(int index) {
    setState(() {
      _services[index].dispose();
      _services.removeAt(index);
    });
  }
  
  // בחירת תמונה לשירות
  Future<void> _pickServiceImage(int index) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _services[index].imageFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }
  
  // צילום תמונה לשירות
  Future<void> _takeServicePhoto(int index) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _services[index].imageFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  // העלאת תמונת שירות ל-Firebase Storage
  Future<String?> _uploadServiceImage(File imageFile, String userId, int serviceIndex) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('business_services')
          .child(userId)
          .child('service_$serviceIndex.jpg');
      
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading service image: $e');
      return null;
    }
  }

  // בניית כרטיס שירות
  Widget _buildServiceCard(int index, _Service service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כותרת עם כפתור מחיקה
            Row(
              children: [
                Expanded(
                  child: Text(
                    'שירות ${index + 1}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeService(index),
                  tooltip: 'מחק שירות',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // שדה שם השירות
            TextFormField(
              controller: service.nameController,
              decoration: const InputDecoration(
                labelText: 'שם השירות',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'אנא הזן שם שירות';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // תמונה
            Row(
              children: [
                // תצוגת תמונה או כפתור בחירה
                GestureDetector(
                  onTap: () => _showImagePickerDialog(index),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: service.imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              service.imageFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, color: Colors.grey[600]),
                              const SizedBox(height: 4),
                              Text(
                                'הוסף תמונה',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'תמונה',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickServiceImage(index),
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('גלריה'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _takeServicePhoto(index),
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('צלם'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // מרכיבים
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'מרכיבים',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          service.ingredients.add(_Ingredient(
                            nameController: TextEditingController(),
                            costController: TextEditingController(text: '0'),
                          ));
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('הוסף מרכיב'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...service.ingredients.asMap().entries.map((entry) {
                  final ingredientIndex = entry.key;
                  final ingredient = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: ingredient.nameController,
                              decoration: const InputDecoration(
                                labelText: 'שם מרכיב',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: ingredient.costController,
                              decoration: const InputDecoration(
                                labelText: 'עלות',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money, size: 18),
                                suffixText: '₪',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                ingredient.dispose();
                                service.ingredients.removeAt(ingredientIndex);
                              });
                            },
                            tooltip: 'מחק מרכיב',
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            
            // מחיר וצ'קבוקס בהתאמה אישית
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: service.priceController,
                    enabled: !service.isCustomPrice,
                    decoration: const InputDecoration(
                      labelText: 'מחיר',
                      hintText: 'לדוגמה: 100',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: '₪',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (!service.isCustomPrice && (value == null || value.isEmpty)) {
                        return 'אנא הזן מחיר';
                      }
                      if (!service.isCustomPrice && value != null && value.isNotEmpty) {
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'אנא הזן מחיר תקין';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Checkbox(
                      value: service.isCustomPrice,
                      onChanged: (value) {
                        setState(() {
                          service.isCustomPrice = value ?? false;
                          if (service.isCustomPrice) {
                            service.priceController.clear();
                          }
                        });
                      },
                    ),
                    const Text('בהתאמה אישית'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // הצגת דיאלוג בחירת תמונה
  void _showImagePickerDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('בחר תמונה'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('בחר מגלריה'),
              onTap: () {
                Navigator.pop(context);
                _pickServiceImage(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('צלם תמונה'),
              onTap: () {
                Navigator.pop(context);
                _takeServicePhoto(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return NetworkAwareWidget(
      child: Directionality(
        textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'צור את העסק שלך',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'יוצר מודעה...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // הודעה על הגבלת בקשות
                      FutureBuilder<DocumentSnapshot?>(
                        future: () async {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) return null;
                          return FirebaseFirestore.instance
                            .collection('user_profiles')
                              .doc(currentUser.uid)
                              .get();
                        }(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data = snapshot.data!.data() as Map<String, dynamic>;
                            final userType = data['userType'] as String? ?? 'personal';
                            final isSubscriptionActive = data['isSubscriptionActive'] as bool? ?? false;
                            
                            // חישוב הגבלות
                            int maxRequests = 1;
                            double maxRadius = 3.0; // ברירת מחדל לפרטי חינם
                            
                            if (userType == 'business' && isSubscriptionActive) {
                              maxRequests = 10;
                              maxRadius = 8.0;
                            } else if (userType == 'personal' && isSubscriptionActive) {
                              maxRequests = 5;
                              maxRadius = 5.0;
                            } else if (userType == 'guest') {
                              maxRadius = 5.0;
                            }
                            
                            // הגבלת תצוגה לתוך תחום הגיוני
                            maxRadius = maxRadius.clamp(0.1, 250.0);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Theme.of(context).colorScheme.primary),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info, color: Theme.of(context).colorScheme.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.requestLimits,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${l10n.maxRequestsPerMonth(maxRequests)}\n• ${l10n.maxSearchRange(maxRadius.toStringAsFixed(0))}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  if (maxRequests < 10) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '💡 איך להגדיל: המלץ על האפליקציה, שפר דירוג, או הירשם כמנוי',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.primary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      
                      // שם העסק
                      TextFormField(
                        controller: _businessNameController,
                        decoration: InputDecoration(
                          labelText: 'שם העסק',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.business),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'אנא הזן שם עסק';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // טלפון
                      PhoneInputWidget(
                        initialPrefix: _selectedPhonePrefix,
                        initialNumber: _selectedPhoneNumber,
                        onChanged: (prefix, number) {
                          setState(() {
                            _selectedPhonePrefix = prefix;
                            _selectedPhoneNumber = number;
                          });
                        },
                        validator: (value) {
                          // אימות חובה
                          if (_selectedPhonePrefix.isEmpty || _selectedPhoneNumber.isEmpty) {
                            return l10n.enterFullPrefixAndNumber;
                          }
                          String fullNumber = '$_selectedPhonePrefix$_selectedPhoneNumber';
                          if (!PhoneValidation.isValidIsraeliPhone(fullNumber)) {
                            return l10n.invalidPhoneNumber;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // העלאת תמונת עסק
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.image,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'תמונת עסק',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'תמונה עוזרת מאוד לשווק את העסק שלך. התמונה תוצג במסך פרופיל ובמסך עסקים ועצמאיים.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_businessImageFile != null || _businessImageUrl != null)
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _businessImageFile != null
                                        ? Image.file(
                                            _businessImageFile!,
                                            fit: BoxFit.cover,
                                          )
                                        : _businessImageUrl != null
                                            ? Image.network(
                                                _businessImageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Center(
                                                    child: Icon(Icons.error, color: Colors.red),
                                                  );
                                                },
                                              )
                                            : null,
                                  ),
                                ),
                              if (_businessImageFile != null || _businessImageUrl != null)
                                const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isUploadingBusinessImage ? null : _pickBusinessImage,
                                      icon: _isUploadingBusinessImage
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.add_photo_alternate),
                                      label: Text(_businessImageFile != null || _businessImageUrl != null
                                          ? 'שנה תמונה'
                                          : 'העלה תמונה'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (_businessImageFile != null || _businessImageUrl != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _businessImageFile = null;
                                          _businessImageUrl = null;
                                        });
                                      },
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'מחק תמונה',
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // בחירת קטגוריה - שני שלבים
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: TwoLevelCategorySelector(
                          selectedCategories: _selectedCategories,
                          maxSelections: 999, // ללא הגבלה מעשית - ניתן לבחור כמה תחומים שרוצים
                          title: l10n.selectCategory,
                          instruction: 'בחר את תחומי העיסוק שלך',
                          onSelectionChanged: (categories) {
                            setState(() {
                              _selectedCategories.clear();
                              _selectedCategories.addAll(categories);
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // רשימת שירותים
                      ..._services.asMap().entries.map((entry) {
                        final index = entry.key;
                        final service = entry.value;
                        return _buildServiceCard(index, service);
                      }).toList(),
                      
                      // לחצן הוסף שירות
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _selectedCategories.isEmpty ? null : _addService,
                          icon: const Icon(Icons.add),
                          label: const Text('הוסף שירות'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // שדה דורש תור
                      Card(
                        child: CheckboxListTile(
                          title: const Text('השירותים דורשים קביעת תור?'),
                          subtitle: const Text('אם השירותים דורשים קביעת תור, בחר באפשרות זו'),
                          value: _requiresAppointment,
                          onChanged: (value) {
                            setState(() {
                              _requiresAppointment = value ?? false;
                            });
                          },
                          secondary: const Icon(Icons.calendar_today),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // שדה דורש משלוח
                      Card(
                        child: CheckboxListTile(
                          title: const Text('אפשר לקבל שירות במשלוח?'),
                          subtitle: Text(l10n.canReceiveByDeliveryHint),
                          value: _requiresDelivery,
                          onChanged: (value) {
                            setState(() {
                              _requiresDelivery = value ?? false;
                            });
                          },
                          secondary: const Icon(Icons.local_shipping),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // בחירת מיקום - זמין רק אחרי בחירת קטגוריה
                      Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: _selectedCategories.isEmpty 
                                ? Colors.grey 
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedAddress ?? 'בחר מיקום העסק שלך',
                                  style: TextStyle(
                                    color: _selectedCategories.isEmpty 
                                        ? Colors.grey 
                                        : null,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showLocationInfoDialog(),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Theme.of(context).colorScheme.primary),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: _selectedCategories.isEmpty
                              ? Text(
                                  'אנא בחר תחום קודם',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.tertiary,
                                    fontSize: 12,
                                  ),
                                )
                              : (_selectedLatitude != null 
                                  ? Text('${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}${_exposureRadius != null ? ' • רדיוס: ${_exposureRadius!.toStringAsFixed(1)} ק"מ' : ''}')
                                  : const Text('')),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: _selectedCategories.isEmpty 
                                ? Colors.grey 
                                : null,
                          ),
                          enabled: _selectedCategories.isNotEmpty,
                          onTap: _selectedCategories.isEmpty 
                              ? () {
                                  // הצגת הודעה אם מנסים לבחור מיקום בלי קטגוריה
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.pleaseSelectCategoryFirst),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : _selectLocation,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // קישורים חברתיים
                      if (_selectedLatitude != null && _selectedLongitude != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.link,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'קישורים לאתר או חשבון חברתי',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'יש לך חשבון אינסטגרם/פייסבוק/טיקטוק? הקישורים יוצגו במסך פרופיל ובמסך עסקים ועצמאיים.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // אינסטגרם
                                _buildSocialLinkField(
                                  'instagram',
                                  'אינסטגרם',
                                  Icons.camera_alt,
                                  'https://instagram.com/',
                                ),
                                const SizedBox(height: 12),
                                // פייסבוק
                                _buildSocialLinkField(
                                  'facebook',
                                  'פייסבוק',
                                  Icons.facebook,
                                  'https://facebook.com/',
                                ),
                                const SizedBox(height: 12),
                                // טיקטוק
                                _buildSocialLinkField(
                                  'tiktok',
                                  'טיקטוק',
                                  Icons.music_video,
                                  'https://tiktok.com/@',
                                ),
                                const SizedBox(height: 12),
                                // אתר
                                _buildSocialLinkField(
                                  'website',
                                  'אתר',
                                  Icons.language,
                                  'https://',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      
                      
                      const SizedBox(height: 24),
                      
                      // כפתור שמירה
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveAd,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('המשך לתשלום מנוי שנתי'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    ));
  }

  /// הצגת דיאלוג מידע על בחירת מיקום
  void _showLocationInfoDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.locationInfoTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.howToSelectLocation,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectLocationInstructions,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.locationSelectionTips,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.locationSelectionTipsDetails,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.understood,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialExposureRadius: _exposureRadius,
        ),
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _selectedAddress = result['address'];
        _exposureRadius = result['exposureRadius']; // קבלת רדיוס החשיפה
      });
    }
  }

  // בחירת תמונת עסק
  Future<void> _pickBusinessImage() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('בחר מקור תמונה'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('בחר מהגלריה'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('צלם תמונה'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _businessImageFile = File(image.path);
          _businessImageUrl = null; // איפוס URL אם יש תמונה חדשה
        });
      }
    } catch (e) {
      debugPrint('Error picking business image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בבחירת תמונה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // העלאת תמונת עסק ל-Firebase Storage
  Future<String?> _uploadBusinessImage(String userId) async {
    if (_businessImageFile == null) return _businessImageUrl;

    try {
      setState(() {
        _isUploadingBusinessImage = true;
      });

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('business_images')
          .child(userId)
          .child('business_image.jpg');

      await storageRef.putFile(_businessImageFile!);
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _businessImageUrl = downloadUrl;
        _isUploadingBusinessImage = false;
      });

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading business image: $e');
      setState(() {
        _isUploadingBusinessImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהעלאת תמונה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // בניית שדה קישור חברתי
  Widget _buildSocialLinkField(String key, String label, IconData icon, String prefix) {
    final controller = _socialLinksControllers[key]!;
    return TextField(
      controller: controller,
      onChanged: (value) {
        setState(() {}); // עדכון UI כשהטקסט משתנה
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        hintText: prefix,
        border: const OutlineInputBorder(),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    controller.clear();
                  });
                },
              )
            : null,
      ),
      keyboardType: TextInputType.url,
    );
  }

  // הפונקציה הוסרה - משתמשים במיקום הראשי במקום מיקום משלוח נפרד

  /// הודעה למסך הפרופיל על יצירת בקשה
  // ignore: unused_element
  Future<void> _notifyProfileScreenOfRequestCreation() async {
    try {
      // עדכון זמן העדכון האחרון ב-SharedPreferences
      // זה יגרום למסך הפרופיל לטעון מחדש את המונה
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_request_creation', DateTime.now().toIso8601String());
      
      debugPrint('✅ Profile screen notified of request creation');
    } catch (e) {
      debugPrint('❌ Error notifying profile screen: $e');
    }
  }



  


  // הצגת דיאלוג הפעלת מנוי עסקי
  Future<void> _showPaymentDialog(UserType subscriptionType, [List<RequestCategory>? categories]) async {
    debugPrint('💰 _showPaymentDialog called with: $subscriptionType');
    
    final l10n = AppLocalizations.of(context);
    final price = subscriptionType == UserType.personal ? 30 : 90;
    final typeName = subscriptionType == UserType.personal ? l10n.privateSubscription : l10n.businessSubscription;
    
    debugPrint('💰 Opening payment dialog for $typeName subscription, price: $price');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subscriptionType == UserType.business ? 'תשלום עבור מנוי עסקי לשנה' : 'הפעלת מנוי $typeName'),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subscriptionType == UserType.business) ...[
                    // שם העסק
                    Text(
                      'שם העסק: ${_businessNameController.text.trim()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // תחומי עיסוק
                    if (categories != null && categories.isNotEmpty) ...[
                      Text(
                        'תחומי עיסוק: ${categories.map((c) => c.categoryDisplayName).join(', ')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // מחיר
                    Text(
                      '90 ₪ לשנה',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ] else ...[
                    // למנוי פרטי - הטקסט הישן
                    Text(
                      l10n.subscriptionTypeWithType(typeName),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.perYear(price),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (categories != null && categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.businessAreas(categories.map((c) => c.categoryDisplayName).join(', ')),
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline, 
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Theme.of(context).colorScheme.onTertiaryContainer
                            : Theme.of(context).colorScheme.onSurface, 
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.howToPay,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.onTertiaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.paymentInstructions(price),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onTertiaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning, 
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.onTertiaryContainer
                              : Theme.of(context).colorScheme.onSurface, 
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'BIT (PayMe): יפתח דף תשלום מאובטח של PayMe\n'
                            'כרטיס אשראי (PayMe): יפתח דף תשלום מאובטח של PayMe\n'
                            'המנוי יופעל אוטומטית לאחר התשלום',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.onTertiaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // כפתור PayMe (multi-payment - משתמש בוחר Bit או כרטיס אשראי)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  // שמירת שם העסק ומספר הטלפון ב-Firestore לפני פתיחת תשלום PayMe
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && subscriptionType == UserType.business) {
                    // קבלת השם המקורי לפני עדכון
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();
                    
                    final updateData = <String, dynamic>{
                      'updatedAt': DateTime.now(),
                    };
                    
                    // שמירת השם המקורי ב-name לפני עדכון displayName לשם העסק
                    final businessName = _businessNameController.text.trim();
                    if (userDoc.exists) {
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final currentName = userData['name'] as String?;
                      final currentDisplayName = userData['displayName'] as String?;
                      
                      // אם אין name, נשמור את השם המקורי ב-name
                      if ((currentName == null || currentName.isEmpty)) {
                        // אם displayName שונה מ-businessName, זה השם המקורי
                        if (currentDisplayName != null && 
                            currentDisplayName.isNotEmpty &&
                            currentDisplayName != businessName) {
                          // displayName הוא השם המקורי, שמור אותו ב-name
                          updateData['name'] = currentDisplayName;
                        } else {
                          // displayName כבר שונה לשם העסק או ריק, נשתמש במייל
                          final email = userData['email'] as String?;
                          if (email != null && email.isNotEmpty) {
                            updateData['name'] = email.split('@')[0];
                          } else {
                            // אם אין גם מייל, נשתמש ב-displayName הנוכחי (אפילו אם זה שם העסק)
                            // זה יקרה רק במקרים נדירים
                            if (currentDisplayName != null && currentDisplayName.isNotEmpty) {
                              updateData['name'] = currentDisplayName;
                            }
                          }
                        }
                      }
                    }
                    
                    if (businessName.isNotEmpty) {
                      updateData['displayName'] = businessName;
                    }
                    
                    // שמירת מספר הטלפון
                    if (_selectedPhonePrefix.isNotEmpty && _selectedPhoneNumber.isNotEmpty) {
                      final phoneNumber = '$_selectedPhonePrefix$_selectedPhoneNumber';
                      updateData['phoneNumber'] = phoneNumber;
                    }
                    
                    // שמירת מיקום העסק
                    if (_selectedLatitude != null && _selectedLongitude != null) {
                      updateData['latitude'] = _selectedLatitude;
                      updateData['longitude'] = _selectedLongitude;
                      if (_selectedAddress != null && _selectedAddress!.isNotEmpty) {
                        updateData['village'] = _selectedAddress;
                      }
                      if (_exposureRadius != null) {
                        updateData['exposureRadius'] = _exposureRadius;
                      }
                    }
                    
                    // שמירת השירותים
                    final List<Map<String, dynamic>> servicesData = [];
                    for (var service in _services) {
                      final serviceData = <String, dynamic>{
                        'name': service.nameController.text.trim(),
                        'isCustomPrice': service.isCustomPrice,
                        'isAvailable': true, // ברירת מחדל זמין
                      };
                      if (!service.isCustomPrice && service.priceController.text.trim().isNotEmpty) {
                        serviceData['price'] = double.tryParse(service.priceController.text.trim()) ?? 0.0;
                      }
                      // שמירת תמונה אם קיימת
                      if (service.imageFile != null) {
                        try {
                          final imageUrl = await _uploadServiceImage(service.imageFile!, user.uid, servicesData.length);
                          if (imageUrl != null) {
                            serviceData['imageUrl'] = imageUrl;
                          }
                        } catch (e) {
                          debugPrint('Error uploading service image: $e');
                        }
                      }
                      // שמירת מרכיבים
                      if (service.ingredients.isNotEmpty) {
                        serviceData['ingredients'] = service.ingredients.map((ingredient) {
                          return {
                            'name': ingredient.nameController.text.trim(),
                            'cost': double.tryParse(ingredient.costController.text.trim()) ?? 0.0,
                          };
                        }).toList();
                      }
                      servicesData.add(serviceData);
                    }
                    updateData['businessServices'] = servicesData;
                    updateData['requiresAppointment'] = _requiresAppointment;
                    updateData['requiresDelivery'] = _requiresDelivery;
                    
                    // העלאת תמונת עסק אם יש
                    if (_businessImageFile != null) {
                      final imageUrl = await _uploadBusinessImage(user.uid);
                      if (imageUrl != null) {
                        updateData['businessImageUrl'] = imageUrl;
                      }
                    } else if (_businessImageUrl != null) {
                      updateData['businessImageUrl'] = _businessImageUrl;
                    }
                    
                    // שמירת קישורים חברתיים
                    final socialLinks = <String, String>{};
                    for (var entry in _socialLinksControllers.entries) {
                      final link = entry.value.text.trim();
                      if (link.isNotEmpty) {
                        // הוספת prefix אם לא קיים
                        String fullLink = link;
                        if (entry.key == 'instagram' && !link.startsWith('http')) {
                          fullLink = 'https://instagram.com/$link';
                        } else if (entry.key == 'facebook' && !link.startsWith('http')) {
                          fullLink = 'https://facebook.com/$link';
                        } else if (entry.key == 'tiktok' && !link.startsWith('http')) {
                          fullLink = 'https://tiktok.com/@$link';
                        } else if (entry.key == 'website' && !link.startsWith('http')) {
                          fullLink = 'https://$link';
                        }
                        socialLinks[entry.key] = fullLink;
                      }
                    }
                    if (socialLinks.isNotEmpty) {
                      updateData['socialLinks'] = socialLinks;
                    }
                    
                    if (updateData.length > 1) { // יותר מ-updatedAt בלבד
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update(updateData);
                    }
                  }
                  await _openPayMePayment(subscriptionType, price, context, categories);
                },
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text('שלם דרך PayMe (Bit או כרטיס אשראי)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // כפתור תשלום במזומן
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // סגירת דיאלוג התשלום הנוכחי
                  await _showCashPaymentDialog(subscriptionType, price, categories);
                },
                icon: const Icon(Icons.money, color: Colors.white),
                label: Text(AppLocalizations.of(context).payCash),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('חזור'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }

  /// פתיחת תשלום דרך PayMe API (multi-payment - משתמש בוחר Bit או כרטיס אשראי)
  Future<void> _openPayMePayment(UserType subscriptionType, int price, [BuildContext? dialogContext, List<RequestCategory>? categories]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה: משתמש לא מחובר'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // בדיקה אם המשתמש הוא אורח זמני
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final isTemporaryGuest = userData['isTemporaryGuest'] ?? false;
          
          if (isTemporaryGuest) {
            if (mounted) {
              final l10n = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.pleaseRegisterFirst),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Error checking temporary guest status: $e');
      }

      final l10n = AppLocalizations.of(context);
      final typeName = subscriptionType == UserType.personal ? l10n.privateSubscription : l10n.businessSubscription;
      final subscriptionTypeString = subscriptionType == UserType.personal ? 'personal' : 'business';
      
      debugPrint('💳 Creating PayMe payment for $typeName subscription, price: ₪$price');
      
      // הצגת אינדיקטור טעינה
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      try {
        // יצירת תשלום דרך PayMe API (multi-payment - משתמש בוחר Bit או כרטיס אשראי)
        final result = await PayMePaymentService.createSubscriptionPayment(
          subscriptionType: subscriptionTypeString,
          businessCategories: categories != null ? categories.map((c) => c.categoryDisplayName).toList() : null,
        );

        // סגירת אינדיקטור הטעינה
        if (mounted) {
          Navigator.pop(context);
        }

        if (result.success && result.saleUrl != null) {
          debugPrint('✅ PayMe payment created successfully: ${result.transactionId}');
          
          // סגירת הדיאלוג (אם יש)
          if (dialogContext != null && mounted) {
            Navigator.pop(dialogContext);
          }
          
          // פתיחת דף התשלום (multi-payment - משתמש בוחר Bit או כרטיס אשראי)
          final opened = await PayMePaymentService.openCheckout(result.saleUrl!);
          
          if (opened && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('פתחתי את דף התשלום PayMe עבור ₪$price\nתוכל לבחור Bit או כרטיס אשראי'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('שגיאה בפתיחת דף התשלום'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          debugPrint('❌ PayMe payment creation failed: ${result.error}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('שגיאה ביצירת תשלום: ${result.error ?? "שגיאה לא ידועה"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('❌ Error in PayMe payment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בתשלום: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in PayMe payment: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בתשלום: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// דיאלוג תשלום במזומן
  Future<void> _showCashPaymentDialog(UserType subscriptionType, int price, [List<RequestCategory>? categories]) async {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // קבלת פרטי המשתמש
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) return;
    
    final userData = userDoc.data()!;
    final userName = userData['displayName'] ?? userData['name'] ?? user.email ?? 'משתמש';
    final userEmail = user.email ?? '';
    final userPhone = userData['phoneNumber'] as String? ?? '';
    
    final typeName = subscriptionType == UserType.personal ? l10n.privateSubscription : l10n.businessSubscription;
    final subscriptionTypeString = subscriptionType == UserType.personal ? 'personal' : 'business';
    
    final TextEditingController phoneController = TextEditingController();
    // שימוש במספר הטלפון מהמסך ניהול עסק אם קיים, אחרת מהפרופיל
    final String phoneFromScreen = _selectedPhonePrefix.isNotEmpty && _selectedPhoneNumber.isNotEmpty
        ? '$_selectedPhonePrefix$_selectedPhoneNumber'
        : userPhone;
    if (phoneFromScreen.isNotEmpty) {
      phoneController.text = phoneFromScreen;
    }
    String? phoneError;
    final bool hasPhone = phoneFromScreen.isNotEmpty;
    
    final navigator = Navigator.of(context);
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.isRTL ? 'תשלום מזומן' : l10n.cashPaymentTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // שם המשתמש
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: userName),
                  decoration: InputDecoration(
                    labelText: l10n.fullName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // שם העסק
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: _businessNameController.text.trim()),
                  decoration: const InputDecoration(
                    labelText: 'שם העסק',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // מייל המשתמש
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: userEmail),
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // שדה טלפון
                TextField(
                  enabled: !hasPhone,
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: '${l10n.phoneNumber}${hasPhone ? '' : ' *'}',
                    hintText: hasPhone ? '' : l10n.enterPhoneNumber,
                    border: const OutlineInputBorder(),
                    errorText: phoneError,
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (value) {
                    if (phoneError != null) {
                      setState(() {
                        phoneError = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                // פרטי המנוי
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.subscriptionDetails,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.subscriptionTypeWithType(typeName)}\n${l10n.perYear(price)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      if (categories != null && categories.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.businessAreas(categories.map((c) => c.categoryDisplayName).join(', ')),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // הוראות תשלום במזומן
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onTertiaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                      Text(
                        'איך לשלם במזומן',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onTertiaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'שלח בקשת תשלום במזומן במערכת, ניצור איתך קשר בהקדם לצורך הסדרת תשלום והפעלת העסק שלך.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onTertiaryContainer
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () async {
                // בדיקת טלפון אם לא הוזן
                if (!hasPhone && phoneController.text.trim().isEmpty) {
                  setState(() {
                    phoneError = l10n.enterPhoneNumber;
                  });
                  return;
                }

                // בדיקת תקינות טלפון
                if (!hasPhone && phoneController.text.trim().isNotEmpty) {
                  if (!PhoneValidation.isValidIsraeliPhone(phoneController.text.trim())) {
                    setState(() {
                      phoneError = l10n.invalidPhoneNumber;
                    });
                    return;
                  }
                }

                final finalPhone = hasPhone ? phoneFromScreen : phoneController.text.trim();
                
                // הצגת דיאלוג טעינה
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) => const AlertDialog(
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('שולח בקשה...'),
                      ],
                    ),
                  ),
                );
                
                // שליחת בקשה לתשלום במזומן
                try {
                  // שמירת שם העסק ומספר הטלפון ב-Firestore לפני שליחת הבקשה
                  final businessName = _businessNameController.text.trim();
                  if (subscriptionTypeString == 'business') {
                    // קבלת השם המקורי לפני עדכון
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();
                    
                    final updateData = <String, dynamic>{
                      'updatedAt': DateTime.now(),
                    };
                    
                    // שמירת השם המקורי ב-name לפני עדכון displayName לשם העסק
                    if (userDoc.exists) {
                      final userData = userDoc.data() as Map<String, dynamic>;
                      final currentName = userData['name'] as String?;
                      final currentDisplayName = userData['displayName'] as String?;
                      
                      // אם אין name, נשמור את השם המקורי ב-name
                      if ((currentName == null || currentName.isEmpty)) {
                        // אם displayName שונה מ-businessName, זה השם המקורי
                        if (currentDisplayName != null && 
                            currentDisplayName.isNotEmpty &&
                            currentDisplayName != businessName) {
                          // displayName הוא השם המקורי, שמור אותו ב-name
                          updateData['name'] = currentDisplayName;
                        } else {
                          // displayName כבר שונה לשם העסק או ריק, נשתמש במייל
                          final email = userData['email'] as String?;
                          if (email != null && email.isNotEmpty) {
                            updateData['name'] = email.split('@')[0];
                          } else {
                            // אם אין גם מייל, נשתמש ב-displayName הנוכחי (אפילו אם זה שם העסק)
                            // זה יקרה רק במקרים נדירים
                            if (currentDisplayName != null && currentDisplayName.isNotEmpty) {
                              updateData['name'] = currentDisplayName;
                            }
                          }
                        }
                      }
                    }
                    
                    if (businessName.isNotEmpty) {
                      updateData['displayName'] = businessName;
                    }
                    
                    // שמירת מספר הטלפון
                    if (finalPhone.isNotEmpty) {
                      updateData['phoneNumber'] = finalPhone;
                    }
                    
                    // שמירת מיקום העסק
                    if (_selectedLatitude != null && _selectedLongitude != null) {
                      updateData['latitude'] = _selectedLatitude;
                      updateData['longitude'] = _selectedLongitude;
                      if (_selectedAddress != null && _selectedAddress!.isNotEmpty) {
                        updateData['village'] = _selectedAddress;
                      }
                      if (_exposureRadius != null) {
                        updateData['exposureRadius'] = _exposureRadius;
                      }
                    }
                    
                    // שמירת השירותים
                    final List<Map<String, dynamic>> servicesData = [];
                    for (var service in _services) {
                      final serviceData = <String, dynamic>{
                        'name': service.nameController.text.trim(),
                        'isCustomPrice': service.isCustomPrice,
                        'isAvailable': true, // ברירת מחדל זמין
                      };
                      if (!service.isCustomPrice && service.priceController.text.trim().isNotEmpty) {
                        serviceData['price'] = double.tryParse(service.priceController.text.trim()) ?? 0.0;
                      }
                      // שמירת תמונה אם קיימת
                      if (service.imageFile != null) {
                        try {
                          final imageUrl = await _uploadServiceImage(service.imageFile!, user.uid, servicesData.length);
                          if (imageUrl != null) {
                            serviceData['imageUrl'] = imageUrl;
                          }
                        } catch (e) {
                          debugPrint('Error uploading service image: $e');
                        }
                      }
                      // שמירת מרכיבים
                      if (service.ingredients.isNotEmpty) {
                        serviceData['ingredients'] = service.ingredients.map((ingredient) {
                          return {
                            'name': ingredient.nameController.text.trim(),
                            'cost': double.tryParse(ingredient.costController.text.trim()) ?? 0.0,
                          };
                        }).toList();
                      }
                      servicesData.add(serviceData);
                    }
                    updateData['businessServices'] = servicesData;
                    updateData['requiresAppointment'] = _requiresAppointment;
                    updateData['requiresDelivery'] = _requiresDelivery;
                    
                    // העלאת תמונת עסק אם יש
                    if (_businessImageFile != null) {
                      final imageUrl = await _uploadBusinessImage(user.uid);
                      if (imageUrl != null) {
                        updateData['businessImageUrl'] = imageUrl;
                      }
                    } else if (_businessImageUrl != null) {
                      updateData['businessImageUrl'] = _businessImageUrl;
                    }
                    
                    // שמירת קישורים חברתיים
                    final socialLinks = <String, String>{};
                    for (var entry in _socialLinksControllers.entries) {
                      final link = entry.value.text.trim();
                      if (link.isNotEmpty) {
                        // הוספת prefix אם לא קיים
                        String fullLink = link;
                        if (entry.key == 'instagram' && !link.startsWith('http')) {
                          fullLink = 'https://instagram.com/$link';
                        } else if (entry.key == 'facebook' && !link.startsWith('http')) {
                          fullLink = 'https://facebook.com/$link';
                        } else if (entry.key == 'tiktok' && !link.startsWith('http')) {
                          fullLink = 'https://tiktok.com/@$link';
                        } else if (entry.key == 'website' && !link.startsWith('http')) {
                          fullLink = 'https://$link';
                        }
                        socialLinks[entry.key] = fullLink;
                      }
                    }
                    if (socialLinks.isNotEmpty) {
                      updateData['socialLinks'] = socialLinks;
                    }
                    
                    if (updateData.length > 1) { // יותר מ-updatedAt בלבד
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update(updateData);
                    }
                  }
                  
                  await ManualPaymentService.submitCashPaymentRequest(
                    userId: user.uid,
                    userName: userName,
                    userEmail: userEmail,
                    phone: finalPhone,
                    subscriptionType: subscriptionTypeString,
                    amount: price.toDouble(),
                    businessCategories: categories != null ? categories.map((c) => c.categoryDisplayName).toList() : null,
                  );
                  
                  // סגירת דיאלוג טעינה
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  
                  // סגירת כל הדיאלוגים - סגירה בטוחה
                  // סגירת דיאלוג תשלום מזומן
                  Navigator.pop(dialogContext);
                  
                  // המתנה קצרה לפני סגירת הדיאלוג הבא
                  await Future.delayed(const Duration(milliseconds: 150));
                  
                  // סגירת דיאלוג תשלום עבור מנוי עסקי לשנה (אם עדיין פתוח)
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                  
                  // המתנה קצרה לפני סגירת מסך ניהול העסק
                  await Future.delayed(const Duration(milliseconds: 150));
                  
                  // סגירת מסך ניהול העסק וניווט למסך פרופיל
                  if (mounted) {
                    Navigator.of(context).pop(); // סגירת מסך ניהול העסק
                    
                    // המתנה קצרה לפני ניווט למסך פרופיל
                    await Future.delayed(const Duration(milliseconds: 150));
                    
                    if (mounted) {
                      // ניווט למסך פרופיל
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                      
                      // הצגת הודעה במסך פרופיל
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('בקשת התשלום נשלחה בהצלחה'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('Error submitting cash payment request: $e');
                  
                  // סגירת דיאלוג טעינה אם עדיין פתוח
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  
                  // גם במקרה של שגיאה, נסגור את הדיאלוגים
                  Navigator.pop(dialogContext);
                  
                  await Future.delayed(const Duration(milliseconds: 150));
                  
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                  
                  // המתנה קצרה לפני סגירת מסך ניהול העסק
                  await Future.delayed(const Duration(milliseconds: 150));
                  
                  // סגירת מסך ניהול העסק וניווט למסך פרופיל
                  if (mounted) {
                    Navigator.of(context).pop(); // סגירת מסך ניהול העסק
                    
                    // המתנה קצרה לפני ניווט למסך פרופיל
                    await Future.delayed(const Duration(milliseconds: 150));
                    
                    if (mounted) {
                      // ניווט למסך פרופיל
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                      
                      // הצגת הודעת שגיאה במסך פרופיל
                      await Future.delayed(const Duration(milliseconds: 300));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('שגיאה בשליחת הבקשה: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                }
              },
              child: const Text('שלח בקשה'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAd() async {
    final l10n = AppLocalizations.of(context);
    
    // בדיקת תקינות הטופס
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // בדיקת שם העסק
    if (_businessNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא הזן שם עסק'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // בדיקת טלפון
    if (_selectedPhonePrefix.isEmpty || _selectedPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enterFullPrefixAndNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // בדיקת תקינות טלפון
    String fullNumber = '$_selectedPhonePrefix$_selectedPhoneNumber';
    if (!PhoneValidation.isValidIsraeliPhone(fullNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.invalidPhoneNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // בדיקת בחירת לפחות תחום אחד
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא בחר לפחות תחום אחד'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // בדיקת הוספת לפחות שירות אחד
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא הוסף לפחות שירות אחד'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // בדיקת תקינות כל השירותים
    bool hasInvalidService = false;
    for (var service in _services) {
      if (service.nameController.text.trim().isEmpty) {
        hasInvalidService = true;
        break;
      }
      if (!service.isCustomPrice && (service.priceController.text.trim().isEmpty || 
          double.tryParse(service.priceController.text.trim()) == null)) {
        hasInvalidService = true;
        break;
      }
    }
    
    if (hasInvalidService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא מלא את כל פרטי השירותים'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // בדיקת בחירת מיקום העסק
    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא בחר מיקום העסק'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // כל הבדיקות עברו - הצגת דיאלוג הפעלת מנוי עסקי
    await _showPaymentDialog(UserType.business, _selectedCategories);
  }
}
