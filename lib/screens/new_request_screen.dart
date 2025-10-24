import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/request.dart';
import '../l10n/app_localizations.dart';
import 'location_picker_screen.dart';
import '../services/tutorial_service.dart';
import '../widgets/tutorial_dialog.dart';
import '../widgets/phone_input_widget.dart';
import '../widgets/two_level_category_selector.dart';
import '../widgets/network_aware_widget.dart';
import '../utils/phone_validation.dart';
import '../services/notification_service.dart';
import '../services/network_service.dart';
import '../services/location_service.dart';
import '../services/app_sharing_service.dart';
import '../services/monthly_requests_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> with NetworkAwareMixin {
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
  bool _useDetailedRatings = false; // האם להשתמש בדירוגים מפורטים
  
  bool _isLoading = false;
  
  // שדות חדשים
  RequestType _selectedType = RequestType.free;
  DateTime? _selectedDeadline;
  final List<RequestCategory> _selectedTargetCategories = [];
  
  // שדות דחיפות חדשים
  UrgencyLevel _selectedUrgency = UrgencyLevel.normal;
  final List<RequestTag> _selectedTags = [];
  String _customTag = '';
  
  // בדיקת מספר נותני שירות
  int _availableHelpersCount = 0;
  bool _isCheckingHelpers = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('🔍 NewRequestScreen initState called');
    // טעינת מספר הטלפון אחרי שה-widget נבנה
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPhoneNumber();
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
              debugPrint('🔍 _loadUserPhoneNumber: Set prefix: ${_selectedPhonePrefix}, number: ${_selectedPhoneNumber}');
            }
          } else {
            debugPrint('🔍 _loadUserPhoneNumber: Failed to parse phone number');
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
    
    debugPrint('🔍 Checking available helpers for category: ${_selectedCategory.toString()}');
    debugPrint('🔍 Looking for: ${_selectedCategory.toString().split('.').last}');
    debugPrint('🔍 Request type: ${_selectedType.toString()}');
    
    setState(() {
      _isCheckingHelpers = true;
    });
    
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
      
      int count = 0;
      for (var doc in allUsers) {
        final data = doc.data();
        final businessCategories = data['businessCategories'] as List<dynamic>? ?? [];
        final userType = data['userType'] as String? ?? '';
        
        debugPrint('👤 User ${doc.id} (${userType}) has categories: $businessCategories');
        
        // בדיקה אם המשתמש עוסק בתחום הרלוונטי
        // בדיקה אם המשתמש הוא משתמש אמיתי (לא משתמש בדיקה עם כל הקטגוריות)
        bool isRealUser = businessCategories.length < 20; // משתמש אמיתי לא יהיה לו 20+ קטגוריות
        
        if (isRealUser) {
          // בדיקה מיוחדת למשתמשי אורח
          if (userType == 'guest') {
            bool canProvideService = false;
            
            // בקשות חינם: כל משתמשי אורח יכולים לספק שירות
            if (_selectedType == RequestType.free) {
              canProvideService = true;
              debugPrint('✅ Guest user can provide FREE service (no category restriction)');
            }
            // בקשות בתשלום: רק אם יש קטגוריות מתאימות
            else if (_selectedType == RequestType.paid) {
              if (businessCategories.isNotEmpty) {
                final selectedCategoryName = _selectedCategory.toString().split('.').last;
                
                for (var category in businessCategories) {
                  String categoryName = '';
                  
                  // אם category הוא Map, נגש ל'category'
                  if (category is Map) {
                    categoryName = category['category'] ?? '';
                  }
                  // אם category הוא String, נשווה ישירות
                  else if (category is String) {
                    categoryName = category;
                  }
                  
                  // בדיקה אם הקטגוריות תואמות
                  if (_isCategoryMatch(categoryName, selectedCategoryName)) {
                    canProvideService = true;
                    debugPrint('✅ Guest user has matching category for PAID service: $categoryName');
                    break;
                  }
                }
              }
              
              if (!canProvideService) {
                debugPrint('❌ Guest user has no matching categories for PAID service');
              }
            }
            
            if (canProvideService) {
              count++;
              debugPrint('✅ Guest user can provide service in this category');
            } else {
              debugPrint('❌ Guest user cannot provide service in this category');
            }
            continue; // עבור למשתמש הבא
          }
          
          // בדיקה רגילה למשתמשים עסקיים ומנהלים
          bool canProvideService = false;
          
          // בקשות חינם: כל המשתמשים יכולים לספק שירות
          if (_selectedType == RequestType.free) {
            canProvideService = true;
            debugPrint('✅ ${userType} user can provide FREE service (no category restriction)');
          }
          // בקשות בתשלום: רק אם יש קטגוריות מתאימות
          else if (_selectedType == RequestType.paid) {
            final selectedCategoryName = _selectedCategory.toString().split('.').last;
            
            for (var category in businessCategories) {
              String categoryName = '';
              
              // אם category הוא Map, נגש ל'category'
              if (category is Map) {
                categoryName = category['category'] ?? '';
              }
              // אם category הוא String, נשווה ישירות
              else if (category is String) {
                categoryName = category;
              }
              
              // בדיקה אם הקטגוריות תואמות
              if (_isCategoryMatch(categoryName, selectedCategoryName)) {
                canProvideService = true;
                debugPrint('✅ Found match: $categoryName == $selectedCategoryName');
                break;
              } else {
                debugPrint('❌ No match: $categoryName != $selectedCategoryName');
              }
            }
          }
          
          if (canProvideService) {
            count++;
            debugPrint('✅ ${userType} user can provide service in this category');
          } else {
            debugPrint('❌ ${userType} user cannot provide service in this category');
          }
        } else {
          debugPrint('🚫 Skipping test user with ${businessCategories.length} categories');
        }
      }
      
      debugPrint('🎯 Total helpers found: $count');
      
      setState(() {
        _availableHelpersCount = count;
        _isCheckingHelpers = false;
      });
      
      // הצגת דיאלוג מנומס אם אין נותני שירות בתחום
      if (count == 0) {
        debugPrint('❌ No helpers found, showing dialog');
        _showNoHelpersInCategoryDialog();
      } else {
        debugPrint('✅ Helpers found, no dialog needed');
      }
    } catch (e) {
      debugPrint('Error checking available helpers: $e');
      setState(() {
        _isCheckingHelpers = false;
      });
    }
  }
  
  // פונקציה לבניית שדה דירוג מפורט עם סליידר
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
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
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
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${ratingValue.toStringAsFixed(1)}',
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
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: color,
                overlayColor: color.withOpacity(0.2),
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
        title: 'יצירת בקשה חדשה',
        message: 'כאן תוכל ליצור בקשה חדשה ולקבל עזרה מהקהילה. כתוב תיאור ברור ופרט את הפרטים החשובים.',
        features: [
          '📝 כתיבת תיאור הבקשה',
          '🏷️ בחירת קטגוריה מתאימה',
          '📍 בחירת מיקום',
          '📤 פרסום הבקשה',
        ],
      ),
    );
  }
  
  // שדות מיקום
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;
  double? _exposureRadius; // רדיוס חשיפה בקילומטרים

  // בדיקת התראות סינון
  Future<void> _checkFilterNotifications(Request request) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationKeys = prefs.getStringList('filter_notification_keys') ?? [];
      
      if (notificationKeys.isEmpty) {
        debugPrint('No custom filter notifications - using default notification system');
        return;
      }
      
      debugPrint('Checking ${notificationKeys.length} custom filter notifications');
      
      // רשימת משתמשים שקיבלו התראה מותאמת אישית
      Set<String> usersWithCustomNotifications = {};
      
      for (String key in notificationKeys) {
        try {
          final filterDataString = prefs.getString(key);
          if (filterDataString == null) continue;
          
          // פענוח נתוני הסינון (זה דוגמה פשוטה - בפועל צריך JSON)
          debugPrint('Checking filter: $key');
          
          // בדיקה אם הבקשה מתאימה לסינון
          bool matchesFilter = await _doesRequestMatchFilter(request, filterDataString);
          
          if (matchesFilter) {
            debugPrint('Request matches filter: $key');
            // כאן אפשר לשלוח התראה למשתמש
            // await _sendFilterNotification(request, key);
            // usersWithCustomNotifications.add(userId);
          }
        } catch (e) {
          debugPrint('Error checking filter $key: $e');
        }
      }
      
      // אם יש משתמשים עם סינון מותאם אישית, נשלח להם התראות מותאמות
      // ואחר כך נשלח התראות רגילות לשאר המשתמשים
      if (usersWithCustomNotifications.isNotEmpty) {
        debugPrint('Sending custom notifications to ${usersWithCustomNotifications.length} users');
        await _sendCustomFilterNotifications(request, usersWithCustomNotifications);
      }
      
      // נשלח התראות רגילות לשאר המשתמשים
      debugPrint('Sending default notifications to remaining users');
      await _sendDefaultNotifications(request, usersWithCustomNotifications);
      
    } catch (e) {
      debugPrint('Error in _checkFilterNotifications: $e');
      // במקרה של שגיאה, נשלח התראות רגילות
      await _sendDefaultNotifications(request, {});
    }
  }

  // בדיקה אם בקשה מתאימה לסינון
  Future<bool> _doesRequestMatchFilter(Request request, String filterDataString) async {
    try {
      // פענוח נתוני הסינון
      final filterData = _parseFilterData(filterDataString);
      if (filterData == null) return false;
      
      debugPrint('Checking if request matches filter: ${request.title}');
      debugPrint('Filter data: $filterData');
      
      // בדיקת סוג בקשה
      if (filterData['requestType'] != null) {
        final filterRequestType = filterData['requestType'] as String?;
        if (filterRequestType != null && filterRequestType != request.type.toString()) {
          debugPrint('❌ Request type mismatch: ${request.type} vs $filterRequestType');
          return false;
        }
      }
      
      // בדיקת קטגוריה (תת-קטגוריה)
      if (filterData['subCategory'] != null) {
        final filterSubCategory = filterData['subCategory'] as String?;
        if (filterSubCategory != null && filterSubCategory != request.category.toString()) {
          debugPrint('❌ Sub-category mismatch: ${request.category} vs $filterSubCategory');
          return false;
        }
      }
      
      // בדיקת קטגוריה ראשית (אם לא נבחרה תת-קטגוריה)
      if (filterData['mainCategory'] != null && filterData['subCategory'] == null) {
        final filterMainCategory = filterData['mainCategory'] as String?;
        if (filterMainCategory != null) {
          // כאן צריך להוסיף לוגיקה שמתאימה בין קטגוריה ראשית לקטגוריות
          // כרגע נבדוק אם הקטגוריה של הבקשה שייכת לתחום הראשי
          bool categoryMatches = _isCategoryInMainCategory(request.category, filterMainCategory);
          if (!categoryMatches) {
            debugPrint('❌ Main category mismatch: ${request.category} not in $filterMainCategory');
            return false;
          }
        }
      }
      
      // בדיקת דחיפות
      if (filterData['urgency'] != null) {
        final filterUrgency = filterData['urgency'] as String?;
        if (filterUrgency != null) {
          final isUrgent = filterUrgency == 'true';
          if (isUrgent != request.isUrgent) {
            debugPrint('❌ Urgency mismatch: ${request.isUrgent} vs $isUrgent');
            return false;
          }
        }
      }
      
      // בדיקת מרחק וגבולות ישראל
      if (filterData['maxDistance'] != null && 
          filterData['userLatitude'] != null && 
          filterData['userLongitude'] != null) {
        
        final maxDistance = filterData['maxDistance'] as double?;
        final userLat = filterData['userLatitude'] as double?;
        final userLng = filterData['userLongitude'] as double?;
        
        if (maxDistance != null && userLat != null && userLng != null &&
            request.latitude != null && request.longitude != null) {
          
          // בדיקה 1: מיקום הסינון של המשתמש בתוך ישראל
          if (!LocationService.isLocationInIsrael(userLat, userLng)) {
            debugPrint('❌ User filter location outside Israel: $userLat, $userLng');
            return false;
          }
          
          // בדיקה 2: מיקום הבקשה בתוך ישראל
          if (!LocationService.isLocationInIsrael(request.latitude!, request.longitude!)) {
            debugPrint('❌ Request location outside Israel: ${request.latitude}, ${request.longitude}');
            return false;
          }
          
          // בדיקה 3: מיקום הבקשה בטווח של המשתמש
          if (!LocationService.isLocationInRange(userLat, userLng, request.latitude!, request.longitude!, maxDistance)) {
            debugPrint('❌ Request outside user range: ${request.latitude}, ${request.longitude}');
            return false;
          }
        }
      }
      
      debugPrint('✅ Request matches filter: ${request.title}');
      return true;
    } catch (e) {
      debugPrint('Error in _doesRequestMatchFilter: $e');
      return false;
    }
  }

  // בדיקה אם קטגוריה שייכת לתחום ראשי
  bool _isCategoryInMainCategory(RequestCategory category, String mainCategory) {
    // כאן צריך להוסיף לוגיקה שמתאימה בין קטגוריות לתחומים ראשיים
    // כרגע נחזיר true לכל הקטגוריות (לצורך הדגמה)
    debugPrint('Checking if ${category.name} belongs to main category: $mainCategory');
    return true; // דוגמה - תמיד נחזיר true
  }

  // שליחת התראות מותאמות אישית
  Future<void> _sendCustomFilterNotifications(Request request, Set<String> userIds) async {
    try {
      debugPrint('Sending custom filter notifications for request: ${request.title}');
      
      for (String userId in userIds) {
        try {
          // קבלת פרטי המשתמש
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (!userDoc.exists) continue;
          
          final userData = userDoc.data()!;
          final userName = userData['displayName'] as String? ?? 'משתמש';
          
          // שליחת התראה מותאמת אישית
          await NotificationService.sendNewRequestNotification(
            toUserId: userId,
            requestTitle: request.title,
            requestCategory: request.category.categoryDisplayName,
            requestId: request.requestId,
            creatorName: userName,
          );
          
          debugPrint('Custom filter notification sent to user: $userId');
        } catch (e) {
          debugPrint('Error sending custom notification to user $userId: $e');
        }
      }
      
      debugPrint('Custom filter notifications sent successfully');
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

  // שליחת התראות רגילות למשתמשים שלא קיבלו התראות מותאמות אישית
  Future<void> _sendDefaultNotifications(Request request, Set<String> usersWithCustomNotifications) async {
    try {
      debugPrint('Sending default notifications for request: ${request.title}');
      
      // קבלת כל המשתמשים שיש להם את הקטגוריה הזו בתחומי העיסוק שלהם
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('businessCategories', arrayContains: request.category.categoryDisplayName)
          .get();

      for (final userDoc in usersQuery.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;
        final userType = userData['userType'] as String? ?? 'personal';
        
        // דילוג על משתמשים שכבר קיבלו התראה מותאמת אישית
        if (usersWithCustomNotifications.contains(userId)) {
          debugPrint('Skipping user $userId - already received custom notification');
          continue;
        }
        
        // רק משתמשים עסקיים עם מנוי פעיל או משתמשים פרטיים
        if (userType == 'business') {
          final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
          if (!isSubscriptionActive) continue; // דילוג על משתמשים עסקיים ללא מנוי פעיל
        }
        
        // לא לשלוח התראה למשתמש שיצר את הבקשה
        if (userId == FirebaseAuth.instance.currentUser?.uid) continue;
        
        await NotificationService.sendNewRequestNotification(
          toUserId: userId,
          requestTitle: request.title,
          requestCategory: request.category.categoryDisplayName,
          requestId: request.requestId,
          creatorName: request.createdBy,
        );
        
        debugPrint('Default notification sent to user: $userId');
      }
      
      debugPrint('Default notifications sent successfully');
    } catch (e) {
      debugPrint('Error sending default notifications: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
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
            const SnackBar(
              content: Text('נדרשת הרשאת גישה לתמונות'),
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
              const SnackBar(
                content: Text('כבר יש 5 תמונות. מחק תמונות כדי להוסיף חדשות.'),
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
                content: Text('נוספו $availableSlots תמונות (מגבלת 5 תמונות)'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('נוספו ${imagesToAdd.length} תמונות'),
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
            content: Text('שגיאה בבחירת תמונות: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      // בדיקת הרשאות מצלמה
      PermissionStatus permission = await Permission.camera.status;
      if (permission == PermissionStatus.denied) {
        permission = await Permission.camera.request();
      }

      if (permission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('נדרשת הרשאת גישה למצלמה'),
              duration: Duration(seconds: 2),
            ),
          );
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
              const SnackBar(
                content: Text('לא ניתן להוסיף יותר מ-5 תמונות'),
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
            const SnackBar(
              content: Text('תמונה נוספה בהצלחה'),
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
            content: Text('שגיאה בצילום תמונה: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _takeMultiplePhotos() async {
    try {
      // בדיקת הרשאות מצלמה
      PermissionStatus permission = await Permission.camera.status;
      if (permission == PermissionStatus.denied) {
        permission = await Permission.camera.request();
      }

      if (permission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('נדרשת הרשאת גישה למצלמה'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // הצגת דיאלוג לאישור
      final bool? shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('צילום תמונות מרובות'),
          content: const Text('לחץ "אישור" כדי לצלם תמונה נוספת'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('אישור'),
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
                const SnackBar(
                  content: Text('לא ניתן להוסיף יותר מ-5 תמונות'),
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
              const SnackBar(
                content: Text('תמונה נוספה בהצלחה'),
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
            content: Text('שגיאה בהעלאת תמונות: $e'),
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
      _showNewRequestSpecificTutorial();
    });
    
    return NetworkAwareWidget(
      child: Directionality(
        textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.newRequest,
            style: const TextStyle(
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
                            color: Colors.black.withOpacity(0.1),
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
                            'יוצר בקשה...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
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
                            final userType = data['userType'] as String?;
                            final isSubscriptionActive = data['isSubscriptionActive'] as bool? ?? false;
                            final recommendationsCount = data['recommendationsCount'] as int? ?? 0;
                            final averageRating = data['averageRating'] as double? ?? 0.0;
                            
                            // חישוב הגבלות
                            int maxRequests = 1;
                            double maxRadius = 10.0;
                            
                            if (userType == 'business' && isSubscriptionActive) {
                              maxRequests = 10;
                              maxRadius = 50.0;
                            } else if (userType == 'personal' && isSubscriptionActive) {
                              maxRequests = 5;
                              maxRadius = 10.0;
                            }
                            
                            // בונוסים
                            maxRadius += (recommendationsCount * 2.0);
                            if (averageRating >= 4.5) {
                              maxRadius += 15.0;
                            } else if (averageRating >= 4.0) {
                              maxRadius += 10.0;
                            } else if (averageRating >= 3.5) {
                              maxRadius += 5.0;
                            }
                            
                            maxRadius = maxRadius.clamp(10.0, 500.0);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'הגבלות הבקשות שלך',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '• מקסימום בקשות בחודש: $maxRequests\n• טווח חיפוש מקסימלי: ${maxRadius.toStringAsFixed(0)} ק"מ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                  if (userType != 'business' || !isSubscriptionActive) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '⚠️ בקשות בתשלום זמינות רק למשתמשים עסקיים עם מנוי פעיל',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  if (maxRequests < 10) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '💡 איך להגדיל: המלץ על האפליקציה, שפר דירוג, או הירשם כמנוי',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[500],
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
                          title: 'בחירת קטגוריה',
                          instruction: 'בחר תחום ראשי ואז תחום משנה:',
                          onSelectionChanged: (categories) {
                            if (categories.isNotEmpty) {
                              setState(() {
                                _selectedCategory = categories.first;
                                // איפוס התגיות כשמשנים קטגוריה
                                _selectedTags.clear();
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
                        decoration: const InputDecoration(
                          labelText: 'כותרת',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'אנא הזן כותרת';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // תיאור
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'תיאור',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'אנא הזן תיאור';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // בחירת רמת דחיפות
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'רמת דחיפות',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildUrgencyButton(UrgencyLevel.normal, '🕓 רגיל'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildUrgencyButton(UrgencyLevel.urgent24h, '⏰ תוך 24 שעות'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildUrgencyButton(UrgencyLevel.emergency, '🚨 עכשיו'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // בחירת תגיות דחיפות (רק אם נבחרה קטגוריה)
                      if (_selectedCategory != null)
                        _buildTagSelector(),
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
                                    'תמונות לבקשה',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'באפשרותך להוסיף תמונות שיעזרו להבין את הבקשה טוב יותר',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '🗑️ תוכל למחוק תמונות על ידי לחיצה על X האדום',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '✨ התמונות יוצגו כקטנות במסך הבית ויוכלו להגדלה',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '🚀 התמונות יועלו ל-Firebase Storage ויוצגו במהירות',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _selectedImageFiles.length >= 5 ? null : _pickImages,
                                      icon: const Icon(Icons.photo_library),
                                      label: Text(_selectedImageFiles.length >= 5 ? 'מגבלת 5 תמונות' : 'בחר תמונות'),
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
                                        label: Text(_selectedImageFiles.length >= 5 ? 'מגבלת 5 תמונות' : 'צלם תמונה'),
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
                                  'נבחרו ${_selectedImageFiles.length} תמונות',
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
                              return 'הזן קידומת ומספר מלאים';
                            }
                            String fullNumber = '$_selectedPhonePrefix$_selectedPhoneNumber';
                            if (!PhoneValidation.isValidIsraeliPhone(fullNumber)) {
                              return 'מספר טלפון לא תקין';
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
                                value: _selectedType,
                                decoration: const InputDecoration(
                                  labelText: 'סוג בקשה',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.payment),
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
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _selectedType == RequestType.free 
                                      ? Colors.green[50] 
                                      : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedType == RequestType.free 
                                        ? Colors.green[200]! 
                                        : Colors.blue[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedType == RequestType.free 
                                          ? Icons.people 
                                          : Icons.business,
                                      color: _selectedType == RequestType.free 
                                          ? Colors.green[700] 
                                          : Colors.blue[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedType == RequestType.free
                                            ? 'בקשות חינם: כל סוגי המשתמשים יכולים לעזור (ללא הגבלת קטגוריה)'
                                            : 'בקשות בתשלום: רק משתמשים עם קטגוריות מתאימות יכולים לעזור',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _selectedType == RequestType.free 
                                              ? Colors.green[700] 
                                              : Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // בחירת מיקום
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(_selectedAddress ?? 'בחר מיקום'),
                              ),
                              GestureDetector(
                                onTap: () => _showLocationInfoDialog(),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[700],
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: _selectedLatitude != null 
                              ? Text('${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}${_exposureRadius != null ? ' • רדיוס: ${_exposureRadius!.toStringAsFixed(1)} ק"מ' : ''}')
                              : const Text('לחץ לבחירת מיקום'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: _selectLocation,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // תאריך יעד
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text(_selectedDeadline != null 
                              ? 'תאריך יעד: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}'
                              : 'בחר תאריך יעד (אופציונלי)'),
                          subtitle: Text(_getDeadlineSubtitle()),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: _selectDeadline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      
                      // דירוגים מינימליים מפורטים - רק לבקשות בתשלום
                      if (_selectedType == RequestType.paid) ...[
                        Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'דירוגים מינימליים של עוזרים',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'הבקשה תוצג רק למשתמשים עם הדירוגים הבאים ומעלה:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // בחירה בין "כל הדירוגים" לדירוגים מפורטים
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _useDetailedRatings = false;
                                      _minReliability = null;
                                      _minAvailability = null;
                                      _minAttitude = null;
                                      _minFairPrice = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: !_useDetailedRatings ? Colors.blue[600] : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: !_useDetailedRatings ? Colors.blue[600]! : Colors.grey[400]!,
                                        ),
                                      ),
                                      child: Text(
                                        'כל הדירוגים',
                                        style: TextStyle(
                                          color: !_useDetailedRatings ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      // המלצה על "כל הדירוגים" אם אין מספיק נותני שירות
                                      if (_availableHelpersCount < 3) {
                                        _showHelperCountWarning();
                                        return;
                                      }
                                      setState(() => _useDetailedRatings = true);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: _useDetailedRatings ? Colors.blue[600] : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _useDetailedRatings ? Colors.blue[600]! : Colors.grey[400]!,
                                        ),
                                      ),
                                      child: Text(
                                        'דירוגים מפורטים',
                                        style: TextStyle(
                                          color: _useDetailedRatings ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            if (_useDetailedRatings) ...[
                              const SizedBox(height: 20),
                              
                              // אמינות
                              _buildDetailedRatingField(
                                'אמינות',
                                '',
                                _minReliability,
                                (value) => setState(() => _minReliability = value),
                                Icons.verified_user,
                                Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              
                              // זמינות
                              _buildDetailedRatingField(
                                'זמינות',
                                '',
                                _minAvailability,
                                (value) => setState(() => _minAvailability = value),
                                Icons.access_time,
                                Colors.green,
                              ),
                              const SizedBox(height: 12),
                              
                              // יחס
                              _buildDetailedRatingField(
                                'יחס',
                                '',
                                _minAttitude,
                                (value) => setState(() => _minAttitude = value),
                                Icons.people,
                                Colors.orange,
                              ),
                              const SizedBox(height: 12),
                              
                              // מחיר הוגן
                              _buildDetailedRatingField(
                                'מחיר הוגן',
                                '',
                                _minFairPrice,
                                (value) => setState(() => _minFairPrice = value),
                                Icons.attach_money,
                                Colors.purple,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // כפתור שמירה
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveRequest,
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
                              : const Text('שמור'),
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
              color: Colors.blue[600],
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'מידע על בחירת מיקום',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'איך לבחור מיקום נכון:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📍 בחר מיקום מדויק ככל האפשר\n'
                    '🎯 הטווח יקבע כמה אנשים יראו את הבקשה\n'
                    '📱 השתמש במפה כדי לבחור את המיקום המדויק',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'טיפים לבחירת מיקום:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🏠 בחר את הכתובת המדויקת\n'
                    '🚗 אם זה ברחוב, בחר את הצד הנכון\n'
                    '🏢 אם זה בבניין, בחר את הכניסה הראשית\n'
                    '📍 השתמש בחיפוש כתובת לדיוק מקסימלי\n'
                    '📏 הטווח המינימלי הוא 0.1 ק"מ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('הבנתי'),
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

  /// הודעה למסך הפרופיל על יצירת בקשה
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

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    
    // הגבלת תאריכים לפי רמת דחיפות
    DateTime lastDate;
    DateTime initialDate;
    
    switch (_selectedUrgency) {
      case UrgencyLevel.emergency:
        // "עכשיו" - מקסימום 3 שעות מהיום
        lastDate = now.add(const Duration(hours: 3));
        initialDate = now.add(const Duration(hours: 1));
        break;
      case UrgencyLevel.urgent24h:
        // "תוך 24 שעות" - מקסימום 24 שעות מהיום
        lastDate = now.add(const Duration(hours: 24));
        initialDate = now.add(const Duration(hours: 6));
        break;
      case UrgencyLevel.normal:
        // "רגיל" - עד שנה מהיום
        lastDate = now.add(const Duration(days: 365));
        initialDate = _selectedDeadline ?? now.add(const Duration(days: 1));
        break;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: lastDate,
    );
    
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }
  
  // פונקציה להצגת הודעת עזרה לתאריך יעד
  String _getDeadlineSubtitle() {
    switch (_selectedUrgency) {
      case UrgencyLevel.emergency:
        return 'עד 3 שעות מהיום (בקשה דחופה)';
      case UrgencyLevel.urgent24h:
        return 'עד 24 שעות מהיום (בקשה דחופה)';
      case UrgencyLevel.normal:
        return 'עד שנה מהיום (בקשה רגילה)';
    }
  }
  
  // פונקציה לאיפוס תאריך יעד אם הוא לא תואם לרמת הדחיפות
  void _resetDeadlineIfNeeded(UrgencyLevel newUrgency) {
    if (_selectedDeadline == null) return;
    
    final now = DateTime.now();
    bool shouldReset = false;
    
    switch (newUrgency) {
      case UrgencyLevel.emergency:
        // אם התאריך הוא יותר מ-3 שעות מהיום
        shouldReset = _selectedDeadline!.isAfter(now.add(const Duration(hours: 3)));
        break;
      case UrgencyLevel.urgent24h:
        // אם התאריך הוא יותר מ-24 שעות מהיום
        shouldReset = _selectedDeadline!.isAfter(now.add(const Duration(hours: 24)));
        break;
      case UrgencyLevel.normal:
        // אין הגבלה לבקשות רגילות
        shouldReset = false;
        break;
    }
    
    if (shouldReset) {
      _selectedDeadline = null;
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
  void _showHelperCountWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600]),
            const SizedBox(width: 8),
            const Text('המלצה'),
          ],
        ),
        content: Text(
          'נמצאו רק $_availableHelpersCount נותני שירות זמינים בתחום זה.\n\n'
          'מומלץ לבחור "כל הדירוגים" כדי להגדיל את הסיכוי לקבל עזרה.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('בחר "כל הדירוגים"'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _useDetailedRatings = true);
            },
            child: const Text('בחר "דירוגים מפורטים"'),
          ),
        ],
      ),
    );
  }
  
  // הצגת דיאלוג מנומס כאשר אין נותני שירות בתחום
  void _showNoHelpersInCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[600], size: 28),
            const SizedBox(width: 8),
            const Text(
              'אין עדיין נותני שירות בתחום זה',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'אין עדיין נותני שירות מהתחום שבחרת.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'תמשיך ליצור את הבקשה - בעתיד יתווספו נותני שירות מתחום זה.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.share, color: Colors.green[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'עזור לנו להגדיל את הקהילה!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'שתף את האפליקציה עם חברים ועמיתים כדי שיותר נותני שירות יוכלו להצטרף.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('הבנתי'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // פתיחת מסך שיתוף
              _openSharingOptions();
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('שתף עכשיו'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  // פתיחת אפשרויות שיתוף
  void _openSharingOptions() {
    AppSharingService.shareApp(context);
  }


  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // בדיקת קטגוריה נבחרת
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא בחר קטגוריה לבקשה'),
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

    debugPrint('Starting to save request...');
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('User is null, cannot save request');
        return;
      }

      // בדיקת הגבלות בקשות
      await _checkRequestLimits(user.uid);

      // בדיקת מיקום וטווח חשיפה
      if (_selectedLatitude == null || _selectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('נא לבחור מיקום לבקשה'),
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

      var request = Request(
        requestId: '', // יוגדר ב-Firestore
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        location: _selectedLocation,
        isUrgent: _selectedUrgency != UrgencyLevel.normal, // דחוף אם לא רגיל
        images: _selectedImages,
        createdAt: DateTime.now(),
        createdBy: user.uid,
        status: RequestStatus.open,
        helpers: [],
        phoneNumber: _selectedPhonePrefix.isNotEmpty && _selectedPhoneNumber.isNotEmpty 
            ? '$_selectedPhonePrefix-$_selectedPhoneNumber' 
            : null,
        type: _selectedType,
        deadline: _selectedDeadline,
        targetAudience: TargetAudience.all,
        maxDistance: null,
        targetVillage: null,
        targetCategories: _selectedTargetCategories.isNotEmpty ? _selectedTargetCategories : null,
        urgencyLevel: _selectedUrgency,
        tags: _selectedTags,
        customTag: _customTag.isNotEmpty ? _customTag : null,
        minRating: _minRating,
        minReliability: _minReliability,
        minAvailability: _minAvailability,
        minAttitude: _minAttitude,
        minFairPrice: _minFairPrice,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        address: _selectedAddress,
        exposureRadius: _exposureRadius,
      );

      debugPrint('Creating request in Firestore...');
      debugPrint('Request data: ${request.toFirestore()}');
      
      // שימוש ב-NetworkService עם retry
      final docRef = await NetworkService.executeWithRetry(
        () => FirebaseFirestore.instance
            .collection('requests')
            .add(request.toFirestore())
            .timeout(
              const Duration(minutes: 1),
              onTimeout: () {
                throw Exception('Firestore timeout');
              },
            ),
        operationName: 'יצירת בקשה',
        maxRetries: 3,
      );
      
      debugPrint('Request created successfully with ID: ${docRef.id}');

      // רישום יצירת בקשה במעקב החודשי
      await MonthlyRequestsTracker.recordRequestCreation();

      // עדכון מונה הבקשות החודשיות בפרופיל
      await _notifyProfileScreenOfRequestCreation();

      // שליחת התראות למשתמשים הרלוונטיים
      try {
        debugPrint('Sending notifications to relevant users...');
        
        // עדכון ה-ID של הבקשה
        request = Request(
          requestId: docRef.id,
          title: request.title,
          description: request.description,
          category: request.category,
          location: request.location,
          isUrgent: request.isUrgent,
          images: request.images,
          createdAt: request.createdAt,
          createdBy: request.createdBy,
          status: request.status,
          helpers: request.helpers,
          phoneNumber: request.phoneNumber,
          type: request.type,
          deadline: request.deadline,
          targetAudience: request.targetAudience,
          maxDistance: request.maxDistance,
          targetVillage: request.targetVillage,
          targetCategories: request.targetCategories,
          urgencyLevel: request.urgencyLevel,
          tags: request.tags,
          minRating: request.minRating,
          latitude: request.latitude,
          longitude: request.longitude,
          address: request.address,
          exposureRadius: request.exposureRadius,
        );
        
        // בדיקת התראות סינון (כולל התראות רגילות)
        await _checkFilterNotifications(request);
        debugPrint('All notifications sent successfully');
      } catch (e) {
        debugPrint('Error sending notifications: $e');
        // לא נעצור את התהליך בגלל שגיאה בהתראות
      }

      debugPrint('Request saved successfully, showing success message');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הבקשה נשמרה בהצלחה'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        debugPrint('Navigating back to previous screen');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving request: $e');
      if (mounted) {
        showError(context, e, onRetry: () {
          _saveRequest();
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

  // בדיקת הגבלות בקשות
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
  
  // פונקציה לבדיקת התאמה בין קטגוריות (עברית/אנגלית)
  bool _isCategoryMatch(String categoryName, String selectedCategoryName) {
    // מיפוי קטגוריות עברית לאנגלית
    final Map<String, String> categoryMapping = {
      'תיקון רכב': 'carRepair',
      'שמרטפות': 'babysitting',
      'גינון': 'gardening',
      'ניקיון': 'cleaningServices',
      'צבע וטיח': 'paintingAndPlaster',
      'ריצוף וקרמיקה': 'flooringAndCeramics',
      'אינסטלציה': 'plumbing',
      'חשמל': 'electrical',
      'נגרות': 'carpentry',
      'מעבר דירה': 'movingAndTransport',
      'שיעורים פרטיים': 'privateLessons',
      'שירותי משרד': 'officeServices',
      'ייעוץ': 'consulting',
      'אירועים': 'events',
      'אבטחה': 'security',
      'אמנות': 'art',
      'מוזיקה': 'music',
      'צילום': 'photography',
      'עיצוב': 'design',
      'בריאות': 'health',
      'יופי': 'beauty',
      'טכנולוגיה': 'technology',
      'חינוך': 'education',
      'ספורט': 'sports',
      'תיירות': 'tourism',
    };
    
    // בדיקה ישירה
    if (categoryName == selectedCategoryName) {
      return true;
    }
    // בדיקה דרך מיפוי עברית-אנגלית
    else if (categoryMapping[categoryName] == selectedCategoryName) {
      return true;
    }
    // בדיקה הפוכה - אנגלית לעברית
    else if (categoryMapping.entries.any((entry) => 
        entry.value == selectedCategoryName && entry.key == categoryName)) {
      return true;
    }
    
    return false;
  }
  
  // פונקציה לבניית כפתור דחיפות
  Widget _buildUrgencyButton(UrgencyLevel level, String label) {
    final isSelected = _selectedUrgency == level;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUrgency = level;
          // איפוס תאריך יעד אם הוא לא תואם לרמת הדחיפות החדשה
          _resetDeadlineIfNeeded(level);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? level.color : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? level.color : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  // פונקציה לבניית בחירת תגיות
  Widget _buildTagSelector() {
    final availableTags = RequestTagExtension.getTagsForCategory(_selectedCategory!);
    
    if (availableTags.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'תגיות דחיפות',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'בחר תגיות שמתארות את המצב שלך:',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? tag.color : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? tag.color : Colors.grey[400]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tag.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // תגית מותאמת אישית
          const Text(
            'תגית מותאמת אישית',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _customTag,
            onChanged: (value) {
              setState(() {
                _customTag = value;
              });
            },
            decoration: const InputDecoration(
              hintText: 'כתוב תגית דחופה מותאמת אישית...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            maxLength: 50,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
