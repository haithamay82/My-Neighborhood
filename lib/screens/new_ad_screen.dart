import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/request.dart';
import '../models/ad.dart';
import '../l10n/app_localizations.dart';
import 'location_picker_screen.dart';
import '../services/tutorial_service.dart';
import '../widgets/tutorial_dialog.dart';
import '../widgets/phone_input_widget.dart';
import '../widgets/two_level_category_selector.dart';
import '../widgets/network_aware_widget.dart';
import '../utils/phone_validation.dart';
import '../services/network_service.dart';
import '../services/app_sharing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewAdScreen extends StatefulWidget {
  const NewAdScreen({super.key});

  @override
  State<NewAdScreen> createState() => _NewAdScreenState();
}

class _NewAdScreenState extends State<NewAdScreen> with NetworkAwareMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // משתנים חדשים לטלפון
  String _selectedPhonePrefix = '';
  String _selectedPhoneNumber = '';
  
  RequestCategory? _selectedCategory;
  RequestLocation? _selectedLocation;
  final List<String> _selectedImages = [];
  final List<File> _selectedImageFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  
  // דירוג מינימלי
  double? _minRating;
  
  // דירוגים מינימליים מפורטים
  double? _minReliability;
  double? _minAvailability;
  double? _minAttitude;
  double? _minFairPrice;
  
  bool _isLoading = false;
  
  // שדות חדשים
  RequestType _selectedType = RequestType.free;
  final List<RequestCategory> _selectedTargetCategories = [];
  
  // מחיר (אופציונאלי) - רק לבקשות בתשלום
  final _priceController = TextEditingController();
  double? _price;
  bool _isCustomPrice = false; // מחיר בהתאמה אישית
  
  // בדיקת מספר נותני שירות
  int _availableHelpersCount = 0;
  
  @override
  void initState() {
    super.initState();
    debugPrint('🔍 NewAdScreen initState called');
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
  
  // בדיקת מספר נותני שירות זמינים
  Future<void> _checkAvailableHelpers() async {
    if (_selectedCategory == null) return;
    
    debugPrint('🔍 Checking available helpers for sub-category: ${_selectedCategory.toString()}');
    debugPrint('🔍 Looking for exact sub-category: ${_selectedCategory!.name}');
    debugPrint('🔍 Request type: ${_selectedType.toString()}');
    
    try {
      // בדיקה מקיפה - נספור כל סוגי המשתמשים שיכולים לספק שירות בתחום הרלוונטי
      // 1. משתמשים עסקיים עם מנוי פעיל
      final businessQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'business')
          .where('isSubscriptionActive', isEqualTo: true)
          .get();
      
      // 2. משתמשי אורח (עם מנוי פעיל)
      final guestQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'guest')
          .where('isSubscriptionActive', isEqualTo: true)
          .get();
      
      // 3. מנהלים
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'admin')
          .get();
      
      debugPrint('📊 Found ${businessQuery.docs.length} business users with active subscription');
      debugPrint('📊 Found ${guestQuery.docs.length} guest users with active subscription');
      debugPrint('📊 Found ${adminQuery.docs.length} admin users');
      
      // איחוד כל התוצאות
      final allUsers = [
        ...businessQuery.docs,
        ...guestQuery.docs,
        ...adminQuery.docs,
      ];
      
      debugPrint('📊 Total users found: ${allUsers.length}');
      debugPrint('🔍 Filtering users for category: ${_selectedCategory!.name} (${_selectedCategory!.categoryDisplayName})');
      debugPrint('🔍 Request type: ${_selectedType == RequestType.free ? "FREE" : "PAID"}');
      
      int count = 0;
      final selectedCategoryName = _selectedCategory!.name; // שם ה-enum המדויק (למשל "plumbing")
      
      for (var doc in allUsers) {
        final data = doc.data();
        final businessCategories = data['businessCategories'] as List<dynamic>? ?? [];
        final userType = data['userType'] as String? ?? '';
        
        debugPrint('👤 Checking user ${doc.id} ($userType) with categories: $businessCategories');
        
        // בדיקה אם המשתמש הוא משתמש אמיתי (לא משתמש בדיקה עם כל הקטגוריות)
        bool isRealUser = businessCategories.length < 20; // משתמש אמיתי לא יהיה לו 20+ קטגוריות
        
        if (!isRealUser) {
          debugPrint('🚫 Skipping test user with ${businessCategories.length} categories');
          continue;
        }
        
        bool canProvideService = false;
        
        // בדיקה: האם המשתמש יכול לספק שירות בקטגוריה הנבחרת
        // תמיד צריך לבדוק אם המשתמש יש לו את הקטגוריה הנבחרת (גם לבקשות חינם)
        if (businessCategories.isNotEmpty) {
          // קבלת שם התצוגה של הקטגוריה הנבחרת (למשל "חשמל")
          final selectedCategoryDisplayName = _selectedCategory!.categoryDisplayName;
          
          for (var category in businessCategories) {
            bool matches = false;
            
            // אם category הוא Map, נגש ל'category' או 'categoryDisplayName'
            if (category is Map) {
              final mapCategoryName = category['category']?.toString() ?? '';
              final mapCategoryDisplayName = category['categoryDisplayName']?.toString();
              
              // השוואה לפי name (למשל "electrical")
              if (mapCategoryName == selectedCategoryName) {
                matches = true;
              }
              // השוואה לפי categoryDisplayName (למשל "חשמל")
              else if (mapCategoryDisplayName != null && mapCategoryDisplayName == selectedCategoryDisplayName) {
                matches = true;
              }
            }
            // אם category הוא String, נשווה ישירות
            else if (category is String) {
              final categoryStr = category;
              
              // השוואה ישירה לפי name (למשל "electrical")
              if (categoryStr == selectedCategoryName) {
                matches = true;
              }
              // השוואה ישירה לפי categoryDisplayName (למשל "חשמל")
              else if (categoryStr == selectedCategoryDisplayName) {
                matches = true;
              }
              // נסה למצוא את הקטגוריה לפי שם או שם תצוגה ולהשוות
              else {
                try {
                  final cat = RequestCategory.values.firstWhere(
                    (c) => c.name == categoryStr || c.categoryDisplayName == categoryStr,
                    orElse: () => RequestCategory.plumbing,
                  );
                  // אם מצאנו קטגוריה, נשווה אותה לקטגוריה הנבחרת
                  if (cat == _selectedCategory) {
                    matches = true;
                  }
                } catch (e) {
                  // אם לא מצאנו, נמשיך
                }
              }
            }
            
            if (matches) {
              canProvideService = true;
              debugPrint('✅ $userType user has exact matching sub-category: "$category" matches "$selectedCategoryName" (display: "$selectedCategoryDisplayName")');
              break;
            }
          }
        }
        
        if (!canProvideService) {
          debugPrint('❌ $userType user has no matching category "$selectedCategoryName" (display: "${_selectedCategory!.categoryDisplayName}") in their business categories: $businessCategories');
        }
        
        if (canProvideService) {
          count++;
          debugPrint('✅ User ${doc.id} ($userType) CAN provide service in category $selectedCategoryName');
        } else {
          debugPrint('❌ User ${doc.id} ($userType) CANNOT provide service in category $selectedCategoryName');
        }
      }
      
      debugPrint('🎯 Total helpers found: $count');
      
      setState(() {
        _availableHelpersCount = count;
      });
      
      // ✅ הצגת דיאלוג עם מספר נותני שירות רק כשמשתמש בוחר "רק לנותני שירות מתחום X"
      // לא מציגים את הדיאלוג אם סוג הבקשה הוא "בתשלום"
      if (_selectedType != RequestType.paid) {
        debugPrint('📊 Showing dialog with helpers count: $count');
        _showHelpersCountDialog(count);
      }
    } catch (e) {
      debugPrint('Error checking available helpers: $e');
    }
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
  
  // הצגת הודעת הדרכה למסך בקשה חדשה
  // הודעת הדרכה ספציפית לבקשה חדשה - רק כשצריך
  Future<void> _showNewRequestSpecificTutorial() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    // רק אם המשתמש לא ראה את ההדרכה הזו קודם
    final hasSeenTutorial = await TutorialService.hasSeenTutorial('new_request_specific_tutorial');
    if (hasSeenTutorial) return;
    
    // רק אם המשתמש חדש (פחות מ-3 ימים)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) return;
    
    final userData = userDoc.data()!;
    final createdAt = userData['createdAt'] as Timestamp?;
    if (createdAt == null) return;
    
    final daysSinceCreation = DateTime.now().difference(createdAt.toDate()).inDays;
    if (daysSinceCreation > 3) return;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TutorialDialog(
        tutorialKey: 'new_request_specific_tutorial',
        title: l10n.newRequestTutorialTitle,
        message: l10n.newRequestTutorialMessage,
        features: [
          '📝 ${l10n.writeRequestDescription}',
          '🏷️ ${l10n.selectAppropriateCategory}',
          '📍 ${l10n.selectLocationAndExposure}',
          '💰 ${l10n.setPriceFreeOrPaid}',
          '📤 ${l10n.publishRequest}',
        ],
      ),
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
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.of(context);
    try {
      // בדיקת הרשאות
      PermissionStatus permission = PermissionStatus.denied;
      
      // ננסה קודם עם photos (Android 13+)
      try {
        permission = await Permission.photos.status;
        if (permission == PermissionStatus.denied) {
          permission = await Permission.photos.request();
        }
      } catch (e) {
        debugPrint('Photos permission not supported: $e');
      }

      // אם photos לא עובד, ננסה עם storage
      if (permission != PermissionStatus.granted) {
        try {
          permission = await Permission.storage.status;
          if (permission == PermissionStatus.denied) {
            permission = await Permission.storage.request();
          }
        } catch (e) {
          debugPrint('Storage permission not supported: $e');
        }
      }

      // אם עדיין לא עובד, ננסה עם camera
      if (permission != PermissionStatus.granted) {
        try {
          permission = await Permission.camera.status;
          if (permission == PermissionStatus.denied) {
            permission = await Permission.camera.request();
          }
        } catch (e) {
          debugPrint('Camera permission not supported: $e');
        }
      }

      if (permission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.permissionRequiredImages),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // בחירת תמונות (מוגבל ל-5)
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        // בדיקה כמה תמונות ניתן להוסיף
        final availableSlots = 5 - _selectedImageFiles.length;
        
        if (availableSlots <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.alreadyHas5Images),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        // הוספת תמונות חדשות (מוגבל למספר המקומות הפנויים)
        final imagesToAdd = images.take(availableSlots).toList();
        
        setState(() {
          for (var image in imagesToAdd) {
            _selectedImageFiles.add(File(image.path));
          }
        });
        
        // הצגת הודעה אם נבחרו יותר תמונות ממה שאפשר
        if (images.length > availableSlots) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.addedImagesCount(availableSlots)),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.addedImagesCount(imagesToAdd.length)),
                duration: const Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorSelectingImages}: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context);
    try {
      // בדיקת הרשאות מצלמה
      PermissionStatus permission = await Permission.camera.status;
      if (permission == PermissionStatus.denied) {
        permission = await Permission.camera.request();
      }

      if (permission != PermissionStatus.granted) {
        if (mounted) {
          // אם ההרשאה נדחתה לצמיתות, הצג דיאלוג עם כפתור לפתיחת הגדרות
          if (permission == PermissionStatus.permanentlyDenied) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(l10n.permissionsRequired),
                  content: Text(l10n.cameraAccessPermissionRequired),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        openAppSettings();
                      },
                      child: Text(l10n.openSettings),
                    ),
                  ],
                );
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.permissionRequiredCamera),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        return;
      }

      // צילום תמונה (מצלמה אחורית)
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front, // מצלמה קדמית (לבדיקה)
        requestFullMetadata: false,
      );

      if (image != null) {
        // בדיקה אם כבר יש 5 תמונות
        if (_selectedImageFiles.length >= 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.cannotAddMoreThan5Images),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        setState(() {
          _selectedImageFiles.add(File(image.path));
        });
        
        // הצגת הודעה על הצלחה
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.imageAddedSuccessfully),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorTakingPhoto}: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _takeMultiplePhotos() async {
    final l10n = AppLocalizations.of(context);
    try {
      // בדיקת הרשאות מצלמה
      PermissionStatus permission = await Permission.camera.status;
      if (permission == PermissionStatus.denied) {
        permission = await Permission.camera.request();
      }

      if (permission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.permissionRequiredCamera),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Guard context usage after async gap
      if (!mounted) return;

      // הצגת דיאלוג לאישור
      final bool? shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.multiplePhotoCapture),
          content: Text(l10n.clickOkToCapture),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );

      if (shouldContinue == true) {
        // צילום תמונה (מצלמה אחורית)
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.front, // מצלמה קדמית (לבדיקה)
          requestFullMetadata: false,
        );

        if (image != null) {
          // בדיקה אם כבר יש 5 תמונות
          if (_selectedImageFiles.length >= 5) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.cannotAddMoreThan5Images),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          
          setState(() {
            _selectedImageFiles.add(File(image.path));
          });
          
          // הצגת הודעה על הצלחה
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.imageAddedSuccessfully),
                duration: Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error taking multiple photos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בצילום תמונות: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _uploadImages() async {
    final l10n = AppLocalizations.of(context);
    if (_selectedImageFiles.isEmpty) {
      debugPrint('No images to upload');
      return;
    }

    debugPrint('Starting to upload ${_selectedImageFiles.length} images');

    try {
      final storage = FirebaseStorage.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('User is null, cannot upload images');
        return;
      }

      debugPrint('User ID: ${user.uid}');

      for (int i = 0; i < _selectedImageFiles.length; i++) {
        final imageFile = _selectedImageFiles[i];
        debugPrint('Uploading image ${i + 1}/${_selectedImageFiles.length}: ${imageFile.path}');
        
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        final ref = storage.ref().child('request_images/${user.uid}/$fileName');
        
        debugPrint('Storage reference: ${ref.fullPath}');
        
        // העלאה עם מטא-דאטה לאופטימיזציה
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000', // שנה
        );
        
        debugPrint('Starting upload for image ${i + 1}');
        await ref.putFile(imageFile, metadata).timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            throw Exception('Upload timeout for image ${i + 1}');
          },
        );
        debugPrint('Upload completed for image ${i + 1}');
        
        final downloadUrl = await ref.getDownloadURL();
        debugPrint('Download URL for image ${i + 1}: $downloadUrl');
        _selectedImages.add(downloadUrl);
      }
      
      debugPrint('All images uploaded successfully. Total URLs: ${_selectedImages.length}');
    } catch (e) {
      debugPrint('Error uploading images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorUploadingImages}: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      rethrow; // Re-throw to stop the save process
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך בקשה חדשה
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      _showNewRequestSpecificTutorial();
      }
    });
    
    return NetworkAwareWidget(
      child: Directionality(
        textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'מודעה חדשה',
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
                      
                      // בחירת קטגוריה - שני שלבים
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: TwoLevelCategorySelector(
                          selectedCategories: _selectedCategory != null ? [_selectedCategory!] : [],
                          maxSelections: 1,
                          title: l10n.selectCategory,
                          instruction: l10n.selectMainCategoryThenSub,
                          onSelectionChanged: (categories) {
                            if (categories.isNotEmpty) {
                              setState(() {
                                _selectedCategory = categories.first;
                              });
                              // בדיקת נותני שירות זמינים
                              _checkAvailableHelpers();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // כותרת
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: l10n.title,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.enterTitle;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // תיאור
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n.description,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        // ✅ השדה "תיאור" הוא אופציונאלי - אין וולידציה
                      ),
                      const SizedBox(height: 16),
                      
                      
                      // בחירת תמונות
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.photo_library, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'תמונות למודעה',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'תמונות עוזרות להבין את המודעה טוב יותר',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _selectedImageFiles.length >= 5 ? null : _pickImages,
                                      icon: const Icon(Icons.photo_library),
                                      label: Text(_selectedImageFiles.length >= 5 ? l10n.limit5Images : l10n.selectImages),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedImageFiles.length >= 5 ? Colors.grey : const Color(0xFF03A9F4),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onLongPress: _selectedImageFiles.length >= 5 ? null : _takeMultiplePhotos,
                                      child: ElevatedButton.icon(
                                        onPressed: _selectedImageFiles.length >= 5 ? null : _takePhoto,
                                        icon: const Icon(Icons.camera_alt),
                                        label: Text(_selectedImageFiles.length >= 5 ? l10n.limit5Images : l10n.takePhoto),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _selectedImageFiles.length >= 5 ? Colors.grey : const Color(0xFFE91E63),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedImageFiles.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l10n.selectedImagesCount(_selectedImageFiles.length),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedImageFiles.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                _selectedImageFiles[index],
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedImageFiles.removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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
                          // אימות אופציונלי - רק אם הוזן חלק מהמספר
                          if (_selectedPhonePrefix.isNotEmpty || _selectedPhoneNumber.isNotEmpty) {
                            if (_selectedPhonePrefix.isEmpty || _selectedPhoneNumber.isEmpty) {
                              return l10n.enterFullPrefixAndNumber;
                            }
                            String fullNumber = '$_selectedPhonePrefix$_selectedPhoneNumber';
                            if (!PhoneValidation.isValidIsraeliPhone(fullNumber)) {
                              return l10n.invalidPhoneNumber;
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      
                      // בחירת סוג בקשה
                      FutureBuilder<DocumentSnapshot?>(
                        future: () async {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) return null;
                          return FirebaseFirestore.instance
                            .collection('users')
                              .doc(currentUser.uid)
                              .get();
                        }(),
                        builder: (context, snapshot) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<RequestType>(
                                initialValue: _selectedType,
                                decoration: const InputDecoration(
                                  labelText: 'סוג המודעה',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.payment),
                                ),
                                items: RequestType.values.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(_getTypeDisplayName(type)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedType = value!;
                                  });
                                  // בדיקת נותני שירות אחרי שינוי סוג בקשה
                                  if (_selectedCategory != null) {
                                    _checkAvailableHelpers();
                                  }
                                },
                              ),
                              // שדה מחיר (רק אם סוג הבקשה הוא בתשלום)
                              if (_selectedType == RequestType.paid) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                  controller: _priceController,
                                        enabled: !_isCustomPrice,
                                  decoration: InputDecoration(
                                    labelText: 'מחיר',
                                    hintText: 'לדוגמה: 100',
                                    border: const OutlineInputBorder(),
                                    suffixText: '₪',
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (value) {
                                    if (value.isEmpty) {
                                      setState(() {
                                        _price = null;
                                      });
                                    } else {
                                      final parsedPrice = double.tryParse(value);
                                      setState(() {
                                        _price = parsedPrice;
                                              // אם המשתמש מזין מחיר, בטל את הצ'קבוקס
                                              if (parsedPrice != null && _isCustomPrice) {
                                                _isCustomPrice = false;
                                              }
                                      });
                                    }
                                  },
                                  validator: (value) {
                                          if (!_isCustomPrice && value != null && value.isNotEmpty) {
                                      final parsedPrice = double.tryParse(value);
                                      if (parsedPrice == null || parsedPrice < 0) {
                                        return 'אנא הזן מחיר תקין';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                    ),
                                    const SizedBox(width: 16),
                                    Checkbox(
                                      value: _isCustomPrice,
                                      onChanged: (value) {
                                        setState(() {
                                          _isCustomPrice = value ?? false;
                                          if (_isCustomPrice) {
                                            // אם בוחרים "בהתאמה אישית", נקה את שדה המחיר
                                            _priceController.clear();
                                            _price = null;
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('בהתאמה אישית'),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // שדה דורש תור
                      Card(
                        child: CheckboxListTile(
                          title: Text(l10n.serviceRequiresAppointment),
                          subtitle: Text(l10n.serviceRequiresAppointmentHint),
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
                          title: Text(l10n.canReceiveByDelivery),
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
                            color: _selectedCategory == null 
                                ? Colors.grey 
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedAddress ?? l10n.selectLocation,
                                  style: TextStyle(
                                    color: _selectedCategory == null 
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
                          subtitle: _selectedCategory == null
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
                            color: _selectedCategory == null 
                                ? Colors.grey 
                                : null,
                          ),
                          enabled: _selectedCategory != null,
                          onTap: _selectedCategory == null 
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
                              : Text(l10n.publishAd),
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
        _selectedLocation = RequestLocation.custom;
      });
    }
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



  String _getTypeDisplayName(RequestType type) {
    switch (type) {
      case RequestType.free:
        return 'חינם';
      case RequestType.paid:
        return 'בתשלום';
    }
  }
  
  // הצגת אזהרה על מספר נותני שירות נמוך
  // הפונקציה הוסרה - לא נדרש יותר
  // ignore: unused_element
  void _showHelperCountWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: const Text(
                'המלצה',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'נמצאו רק $_availableHelpersCount נותני שירות זמינים בתחום זה.\n\n'
            'מומלץ לבחור "כל הדירוגים" כדי להגדיל את הסיכוי לקבל עזרה.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('בחר "כל הדירוגים"'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // לא נדרש יותר - הפונקציה הוסרה
            },
            child: const Text('בחר "דירוגים מפורטים"'),
          ),
        ],
      ),
    );
  }
  
  // ✅ הצגת דיאלוג עם מספר נותני שירות בתחום
  void _showHelpersCountDialog(int count) {
    final l10n = AppLocalizations.of(context);
    final hasHelpers = count > 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              hasHelpers ? Icons.check_circle_outline : Icons.info_outline,
              color: hasHelpers ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasHelpers
                    ? l10n.serviceProvidersInCategory(count)
                    : l10n.noServiceProvidersInCategory,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                  color: hasHelpers ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasHelpers ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasHelpers
                          ? l10n.serviceProvidersInCategoryMessage(count)
                          : l10n.noServiceProvidersInCategoryMessage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasHelpers ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (!hasHelpers) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.continueCreatingRequestMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ✅ חלק "עזור לנו למצוא נותני שירות, שתף את האפליקציה"
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.share, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.helpGrowCommunity,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.shareAppToGrowProviders,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
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
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.understood),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // פתיחת מסך שיתוף
              AppSharingService.shareApp(context);
            },
            icon: const Icon(Icons.share, size: 18),
            label: Text(l10n.shareNow),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _saveAd() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    // בדיקת קטגוריה נבחרת
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseSelectCategory),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // בדיקת חיבור לאינטרנט
    if (!isConnected) {
      showNetworkMessage(context);
      return;
    }

      debugPrint('🚀 ===== START _saveAd =====');
      debugPrint('📝 Ad title: ${_titleController.text.trim()}');
      debugPrint('📝 Selected category: ${_selectedCategory?.categoryDisplayName}');
      debugPrint('📝 Selected location: $_selectedLatitude, $_selectedLongitude');
      debugPrint('📝 Exposure radius: $_exposureRadius km');
      debugPrint('📝 Requires appointment: $_requiresAppointment');
      debugPrint('📝 Requires delivery: $_requiresDelivery');
    debugPrint('Starting to save ad...');
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('User is null, cannot save request');
        return;
      }

      // בדיקת הגבלות (לא נדרש למודעות - אין הגבלות)
      // await _checkRequestLimits(user.uid); // לא נדרש למודעות

      // Guard context usage after async gap
      if (!mounted) return;

      // בדיקת מיקום וטווח חשיפה
      if (_selectedLatitude == null || _selectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseSelectLocation),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      
      // בדיקת טווח חשיפה - מותר לטווח המקסימלי של המנוי
      // (הגבלת התראות תהיה בצד הסינון)

      debugPrint('User authenticated: ${user.uid}');

      // העלאת תמונות אם נבחרו
      if (_selectedImageFiles.isNotEmpty) {
        debugPrint('Uploading ${_selectedImageFiles.length} images...');
        try {
          await _uploadImages();
          debugPrint('Images uploaded successfully');
        } catch (e) {
          debugPrint('Error uploading images: $e');
          // אם יש שגיאה בהעלאת תמונות, נמשיך ללא תמונות
          _selectedImages.clear();
        }
      } else {
        debugPrint('No images to upload');
        // נוודא שהרשימה ריקה
        _selectedImages.clear();
      }

      // תאריך יעד - לא בשימוש (הוסר מהממשק)
      DateTime? finalDeadline = null;

      // בדיקת מספר טלפון לפני יצירת הבקשה
      debugPrint('📞 _saveRequest: _selectedPhonePrefix: "$_selectedPhonePrefix"');
      debugPrint('📞 _saveRequest: _selectedPhoneNumber: "$_selectedPhoneNumber"');
      debugPrint('📞 _saveRequest: _selectedPhonePrefix.isNotEmpty: ${_selectedPhonePrefix.isNotEmpty}');
      debugPrint('📞 _saveRequest: _selectedPhoneNumber.isNotEmpty: ${_selectedPhoneNumber.isNotEmpty}');
      
      final finalPhoneNumber = _selectedPhonePrefix.isNotEmpty && _selectedPhoneNumber.isNotEmpty 
          ? '$_selectedPhonePrefix-$_selectedPhoneNumber' 
          : null;
      debugPrint('📞 _saveRequest: finalPhoneNumber: $finalPhoneNumber');
      
      var ad = Ad(
        adId: '', // יוגדר ב-Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        location: _selectedLocation,
        isUrgent: false, // לא נדרש למודעות
        images: _selectedImages,
        createdAt: DateTime.now(),
        createdBy: user.uid,
        interestedUsers: [],
        phoneNumber: finalPhoneNumber,
        type: _selectedType,
        deadline: finalDeadline,
        targetAudience: TargetAudience.all,
        maxDistance: null,
        targetVillage: null,
        targetCategories: _selectedTargetCategories.isNotEmpty ? _selectedTargetCategories : null,
        urgencyLevel: UrgencyLevel.normal, // ברירת מחדל
        tags: [], // לא נדרש למודעות
        customTag: null, // לא נדרש למודעות
        minRating: _minRating,
        minReliability: _minReliability,
        minAvailability: _minAvailability,
        minAttitude: _minAttitude,
        minFairPrice: _minFairPrice,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        address: _selectedAddress,
        exposureRadius: _exposureRadius,
        showToProvidersOutsideRange: null, // לא נדרש למודעות
        showToAllUsers: null, // לא נדרש למודעות
        price: _isCustomPrice ? null : _price, // מחיר (אופציונלי) - null אם "בהתאמה אישית"
        requiresAppointment: _requiresAppointment, // האם השירות דורש תור
        requiresDelivery: _requiresDelivery, // האם השירות דורש משלוח
        deliveryLocation: _requiresDelivery ? _selectedAddress : null, // שימוש במיקום הראשי
        deliveryLatitude: _requiresDelivery ? _selectedLatitude : null, // שימוש במיקום הראשי
        deliveryLongitude: _requiresDelivery ? _selectedLongitude : null, // שימוש במיקום הראשי
        deliveryRadius: _requiresDelivery ? _exposureRadius : null, // שימוש ברדius הראשי
      );

      debugPrint('Creating ad in Firestore...');
      debugPrint('Ad data: ${ad.toFirestore()}');
      
      // שימוש ב-NetworkService עם retry
      final docRef = await NetworkService.executeWithRetry(
        () => FirebaseFirestore.instance
            .collection('ads')
            .add(ad.toFirestore())
            .timeout(
              const Duration(minutes: 1),
              onTimeout: () {
                throw Exception('Firestore timeout');
              },
            ),
        operationName: 'יצירת מודעה',
        maxRetries: 3,
      );
      
      debugPrint('Ad created successfully with ID: ${docRef.id}');

      // שליחת התראות למשתמשים הרלוונטיים (לא נדרש למודעות - נשאיר ריק כרגע)
      // TODO: להוסיף התראות למודעות אם נדרש

      debugPrint('Ad saved successfully, showing success message');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('המודעה נשמרה בהצלחה'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        debugPrint('Navigating back to previous screen');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving ad: $e');
      if (mounted) {
        showError(context, e, onRetry: () {
          _saveAd();
        });
      }
    } finally {
      debugPrint('Setting loading to false');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// שליחת התראות למשתמשים הרלוונטיים

  // בדיקת הגבלות בקשות - לא נדרש למודעות
  // ignore: unused_element
  Future<void> _checkRequestLimits(String userId) async {
    try {
      debugPrint('🔍 _checkRequestLimits: Starting check for user $userId');
      
      // בדיקה אם המשתמש הוא מנהל
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userEmail = user.email;
        if (userEmail == 'haitham.ay82@gmail.com' || userEmail == 'admin@gmail.com') {
          debugPrint('🔍 _checkRequestLimits: Admin user detected, bypassing limits');
          return;
        }
      }
      
      // קבלת פרופיל המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('פרופיל משתמש לא נמצא');
      }
      
      final userData = userDoc.data()!;
      final maxRequestsPerMonth = userData['maxRequestsPerMonth'] ?? 1;
      final createdAt = userData['createdAt'] as Timestamp?;
      
      debugPrint('🔍 _checkRequestLimits: maxRequestsPerMonth = $maxRequestsPerMonth');
      debugPrint('🔍 _checkRequestLimits: createdAt = $createdAt');
      
      if (createdAt == null) {
        debugPrint('🔍 _checkRequestLimits: No createdAt, allowing request creation');
        return; // אם אין תאריך יצירה, אפשר ליצור
      }

      // חישוב החודש הנוכחי
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      debugPrint('🔍 _checkRequestLimits: now = $now');
      debugPrint('🔍 _checkRequestLimits: currentMonthKey = $currentMonthKey');
      
      // בדיקת מספר הבקשות שנוצרו החודש
      final monthlyRequestsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('monthly_requests_count')
          .doc(currentMonthKey)
          .get();

      final currentMonthRequests = monthlyRequestsDoc.exists 
          ? (monthlyRequestsDoc.data()?['count'] ?? 0) 
          : 0;

      debugPrint('🔍 _checkRequestLimits: monthlyRequestsDoc.exists = ${monthlyRequestsDoc.exists}');
      debugPrint('🔍 _checkRequestLimits: currentMonthRequests = $currentMonthRequests');
      debugPrint('🔍 _checkRequestLimits: Checking if $currentMonthRequests >= $maxRequestsPerMonth');

      if (currentMonthRequests >= maxRequestsPerMonth) {
        debugPrint('🔍 _checkRequestLimits: LIMIT REACHED! Blocking request creation');
        
        // חישוב תאריך החודש הבא
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final nextMonthFormatted = '${nextMonth.day}/${nextMonth.month}/${nextMonth.year}';
        
        String message = 'הגעת למגבלת הבקשות החודשית ($maxRequestsPerMonth בקשות). המתן עד $nextMonthFormatted או שדרג את המנוי שלך.';
        
        throw Exception(message);
      }

      debugPrint('🔍 _checkRequestLimits: Limit not reached, allowing request creation');
      
    } catch (e) {
      debugPrint('🔍 _checkRequestLimits: Error: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      rethrow;
    }
  }
  
  
}
