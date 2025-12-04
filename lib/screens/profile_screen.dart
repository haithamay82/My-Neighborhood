import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payme_payment_service.dart';
import '../services/manual_payment_service.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../models/request.dart';
import '../models/week_availability.dart';
import '../l10n/app_localizations.dart';
import '../services/admin_auth_service.dart';
import '../services/location_service.dart';
import '../services/app_sharing_service.dart';
import '../services/tutorial_service.dart';
import '../services/audio_service.dart';
import '../services/auto_login_service.dart';
import '../services/monthly_requests_tracker.dart';
import '../widgets/tutorial_dialog.dart';
import '../widgets/two_level_category_selector.dart';
import 'order_management_screen.dart';
import '../widgets/trial_extension_process_dialog.dart';
import 'location_picker_screen.dart';
import 'contact_screen.dart';
import 'terms_and_privacy_screen.dart';
import 'about_app_screen.dart';
import 'admin_contact_inquiries_screen.dart';
import 'admin_guest_management_screen.dart';
import 'admin_requests_statistics_screen.dart';
import 'appointment_settings_screen.dart';
import 'business_management_screen.dart';
import 'business_services_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AudioMixin {
  List<RequestCategory> _selectedBusinessCategories = [];
  bool _isCreatingProfile = false;
  bool? _isAdmin;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  
  // שדות טלפון
  final TextEditingController _phoneController = TextEditingController();
  bool _allowPhoneDisplay = false;
  
  // מעקב אחרי הצגת הדיאלוג במהלך הפעלה זו
  bool _profileTutorialShown = false;
  String? _phoneError;
  String _selectedEditPrefix = '';
  
  // שדות שם פרטי ומשפחה/חברה/עסק/כינוי
  final TextEditingController _displayNameController = TextEditingController();
  String? _displayNameError;
  
  // שדה לא נותן שירותים בתשלום
  bool _noPaidServices = false;
  
  // מעקב אחרי עדכון נתוני קטגוריות - למניעת הופעה חוזרת של ההודעה
  bool _categoryDataUpdated = false;

  // הגדרת תורים - null = לא נטען, true = תורים, false = זמינות
  bool? _useAppointments;

  // שדות עבור שירותים עסקיים
  bool _requiresAppointment = false; // האם השירות דורש תור
  bool _requiresDelivery = false; // האם השירות ניתן במשלוח
  bool _isUpdatingSettings = false; // דגל למניעת עדכונים כפולים

  @override
  void initState() {
    super.initState();
    // בדיקה אם המשתמש הוא מנהל פעם אחת
    _isAdmin = AdminAuthService.isCurrentUserAdmin();
    
    // התראה למשתמש אורח בכניסה הראשונה
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      _checkGuestCategories();
      _loadAppointmentSettings();
      _loadServiceSettings();
      }
    });
  }
  
  // בדיקת תחומי עיסוק למשתמש אורח
  Future<void> _checkGuestCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final userType = userData['userType'] as String?;
      
      // טעינת סטטוס לא נותן שירותים בתשלום
      if (mounted) {
        setState(() {
          _noPaidServices = userData['noPaidServices'] ?? false;
        });
      }
      
      // רק למשתמשי אורח
      if (userType != 'guest') return;
      
      final businessCategories = userData['businessCategories'] as List<dynamic>?;
      final noPaidServices = userData['noPaidServices'] ?? false;
      
      // אם אין תחומי עיסוק ולא בחר "לא נותן שירותים" - הצג התראה
      if ((businessCategories == null || businessCategories.isEmpty) && !noPaidServices) {
        if (mounted) {
          _showGuestCategoriesNotification();
        }
      }
    } catch (e) {
      debugPrint('Error checking guest categories: $e');
    }
  }
  
  // הצגת התראה למשתמש אורח להגדרת תחומי עיסוק
  void _showGuestCategoriesNotification() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.work, color: Theme.of(context).colorScheme.tertiary),
            const SizedBox(width: 8),
            Text(l10n.setBusinessFields),
          ],
        ),
        content: Text(
          l10n.ifYouProvideService,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // קבלת הפרופיל הנוכחי והצגת דיאלוג בחירת תחומים
              _showGuestCategoriesDialogFromNotification();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
            ),
            child: Text(l10n.chooseNow),
          ),
        ],
      ),
    );
  }
  
  // הצגת דיאלוג בחירת תחומים מהתראה
  Future<void> _showGuestCategoriesDialogFromNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return;
      
      final userProfile = UserProfile.fromFirestore(userDoc);
      await _showGuestCategoriesDialog(userProfile);
    } catch (e) {
      debugPrint('Error showing guest categories dialog: $e');
    }
  }
  
  // פונקציה לבניית שורת דירוג מפורט
  Widget _buildDetailedRatingRow(
    String title,
    double rating,
    IconData icon,
    Color color,
  ) {
    return Row(
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
        const Spacer(),
        // כוכבים
        Row(
          children: List.generate(5, (index) {
            if (index < rating.floor()) {
              return Icon(
                Icons.star,
                color: color,
                size: 16,
              );
            } else if (index < rating) {
              return Icon(
                Icons.star_half,
                color: color,
                size: 16,
              );
            } else {
              return Icon(
                Icons.star_border,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              );
            }
          }),
        ),
        const SizedBox(width: 8),
        // מספר
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            rating > 0 ? rating.toStringAsFixed(1) : '0.0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  
  // איפוס הודעות הדרכה
  Future<void> _resetTutorials() async {
    final l10n = AppLocalizations.of(context);
    await TutorialService.resetAllTutorials();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tutorialsResetSuccess),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // DEBUG: שינוי סוג מנוי (לא בשימוש - שמור לעתיד)
  // ignore: unused_element
  Future<void> _switchToSubscriptionType(String type, UserProfile userProfile) async {
    final l10n = AppLocalizations.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Map<String, dynamic> updateData = {};
      
      switch (type) {
        case 'private_free':
          updateData = {
            'userType': 'personal',
            'isSubscriptionActive': false,
            'subscriptionStatus': 'private_free',
            'requestedSubscriptionType': null,
          };
          break;
        case 'personal':
          updateData = {
            'userType': 'personal',
            'isSubscriptionActive': true,
            'subscriptionStatus': 'active',
            'subscriptionExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
          };
          break;
        case 'business':
          updateData = {
            'userType': 'business',
            'isSubscriptionActive': true,
            'subscriptionStatus': 'active',
            'subscriptionExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))),
          };
          break;
        case 'guest':
          updateData = {
            'userType': 'guest',
            'isSubscriptionActive': true,
            'subscriptionStatus': 'guest_trial',
            'guestTrialStartDate': Timestamp.fromDate(DateTime.now()),
            'guestTrialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 60))),
            'maxRequestsPerMonth': 5,
            'maxRadius': 1.0,
          };
          break;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.subscriptionTypeChanged(type)),
            backgroundColor: Colors.green,
          ),
        );
      }

      // עדכון הפרופיל במסך
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorChangingSubscriptionType(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // עדכון נתונים ישנים של קטגוריות
  Future<void> _updateOldCategoryData(UserProfile userProfile) async {
    // אם כבר עדכנו בפעם זו - אל תעדכן שוב
    if (_categoryDataUpdated) return;
    
    if (userProfile.businessCategories == null) return;
    
    bool needsUpdate = false;
    List<String> updatedCategories = [];
    Set<String> addedCategories = {}; // מניעת כפילויות
    
    for (RequestCategory category in userProfile.businessCategories!) {
      // בדיקה אם זה נתונים ישנים (אנגלית)
      if (category.name == 'maintenance' || category.name == 'education' || category.name == 'transport' || 
          category.name == 'shopping' || category.name == 'other') {
        needsUpdate = true;
        // המרה לעברית
        String hebrewCategory = '';
        switch (category.name) {
          case 'maintenance':
            hebrewCategory = 'תחזוקה';
            break;
          case 'education':
            hebrewCategory = 'חינוך';
            break;
          case 'transport':
            hebrewCategory = 'הובלה';
            break;
          case 'shopping':
            hebrewCategory = 'קניות';
            break;
          case 'other':
            hebrewCategory = 'אחר';
            break;
        }
        
        // הוספה רק אם לא קיימת כבר
        if (hebrewCategory.isNotEmpty && !addedCategories.contains(hebrewCategory)) {
          updatedCategories.add(hebrewCategory);
          addedCategories.add(hebrewCategory);
        }
      } else {
        // נתונים חדשים - כבר בעברית
        String categoryName = category.categoryDisplayName;
        if (!addedCategories.contains(categoryName)) {
          updatedCategories.add(categoryName);
          addedCategories.add(categoryName);
        }
      }
    }
    
    if (needsUpdate) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          debugPrint('❌ Cannot update business categories: User is not logged in');
          return;
        }
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'businessCategories': updatedCategories,
        });
        
        // סמן שכבר עדכנו בפעם זו
        _categoryDataUpdated = true;
        
        // הודעה הוסרה - אין צורך להציג אותה
      } catch (e) {
        debugPrint('Error updating category data: $e');
      }
    }
  }

  // הודעת הדרכה ספציפית לפרופיל - רק כשצריך
  Future<void> _showProfileSpecificTutorial() async {
    // בדיקה אם כבר הוצג הדיאלוג במהלך הפעלה זו
    if (_profileTutorialShown) {
      debugPrint('🏠 PROFILE SCREEN - Profile tutorial already shown in this session, returning');
      return;
    }
    
    // רק אם המשתמש לא ראה את ההדרכה הזו קודם
    final hasSeenTutorial = await TutorialService.hasSeenTutorial('profile_specific_tutorial');
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
    
    // הצג הודעה רק אם המשתמש לא השלים את הפרופיל
    final isProfileComplete = userData['isProfileComplete'] ?? false;
    if (isProfileComplete) return;
    
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TutorialDialog(
        tutorialKey: 'profile_specific_tutorial',
        title: l10n.completeYourProfile,
        message: l10n.completeProfileMessage,
        features: [
          '📸 ${l10n.uploadProfilePicture}',
          '✏️ ${l10n.updatePersonalDetails}',
          '📍 ${l10n.updateLocationAndExposureRange}',
          '👤 ${l10n.selectSubscriptionTypeIfRelevant}',
        ],
      ),
    );
    
    // סימון שהדיאלוג הוצג
    _profileTutorialShown = true;
  }

  // Helper function to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  // העלאת תמונת פרופיל
  Future<void> _uploadProfileImage() async {
    try {
      // בדיקת הרשאות
      PermissionStatus permission = PermissionStatus.denied;
      
      try {
        permission = await Permission.photos.status;
        if (permission == PermissionStatus.denied) {
          permission = await Permission.photos.request();
        }
      } catch (e) {
        debugPrint('Photos permission not supported: $e');
      }

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

      if (permission != PermissionStatus.granted) {
        // Guard context usage after async gap
        if (!mounted) return;
        // נסה לפתוח הגדרות אפליקציה
        if (permission == PermissionStatus.permanentlyDenied) {
          final l10n = AppLocalizations.of(context);
          showDialog(
      context: context,
      builder: (BuildContext context) {
              return AlertDialog(
                title: Text(l10n.permissionsRequired),
                content: Text(l10n.imagePermissionRequired),
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
                            // Guard context usage after async gap
                            if (!mounted) return;
                            final l10n = AppLocalizations.of(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
              content: Text(l10n.imagePermissionRequiredTryAgain),
              backgroundColor: Colors.red,
                              ),
                            );
                          }
        return;
      }

      // קבלת פרופיל המשתמש הנוכחי
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final profileDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
      
      if (!profileDoc.exists) return;
      
      final userData = profileDoc.data()!;
      final hasProfileImage = userData['profileImageUrl'] != null && userData['profileImageUrl'].toString().isNotEmpty;
      
      // Guard context usage after async gap
      if (!mounted) return;
      
      // בחירת מקור התמונה או מחיקה
      dynamic result = await showDialog<dynamic>(
        context: context,
        builder: (BuildContext context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.chooseAction),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(l10n.chooseFromGallery),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(l10n.takePhoto),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                if (hasProfileImage)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: Text(l10n.deletePhoto, style: const TextStyle(color: Colors.red)),
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
              ],
            ),
          );
        },
      );

      if (result == null) return;
      
      // אם בחר למחוק
      if (result == 'delete') {
        _deleteProfileImage();
        return;
      }
      
      final ImageSource source = result;

      // בחירת תמונה
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

                  setState(() {
        _isUploadingImage = true;
      });

      // העלאה ל-Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(user.uid);

      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();
      
      debugPrint('=== UPLOADING PROFILE IMAGE ===');
      debugPrint('Download URL: $downloadUrl');
      debugPrint('User ID: ${user.uid}');

      // עדכון הפרופיל ב-Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImageUrl': downloadUrl});
          
      debugPrint('Profile image URL saved to Firestore successfully');

                  setState(() {
        _isUploadingImage = false;
      });

      // Guard context usage after async gap
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileImageUpdatedSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      
      // Guard context usage after async gap
      if (!mounted) return;
      
      String errorMessage = 'שגיאה בהעלאת תמונה';
      if (e.toString().contains('Permission denied') || e.toString().contains('403')) {
        errorMessage = 'אין הרשאה להעלות תמונות. אנא פנה למנהל המערכת.';
      } else if (e.toString().contains('network') || e.toString().contains('timeout')) {
        errorMessage = 'שגיאת רשת. אנא בדוק את החיבור לאינטרנט.';
      } else if (e.toString().contains('storage')) {
        errorMessage = 'שגיאה באחסון התמונה. אנא נסה שוב.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // מחיקת תמונת פרופיל
  Future<void> _deleteProfileImage() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // מחיקה מ-Firebase Storage
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(user.uid);
      
      try {
        await ref.delete();
        debugPrint('Profile image deleted from Storage');
      } catch (e) {
        debugPrint('Error deleting image from Storage: $e');
        // המשך גם אם יש שגיאה בסטורג' - נעדכן את Firestore
      }

      // עדכון Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImageUrl': null});
      
      debugPrint('Profile image deleted from Firestore successfully');

      setState(() {
        _isUploadingImage = false;
      });

      // Guard context usage after async gap
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileImageDeletedSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      
      debugPrint('Error deleting profile image: $e');
      
      // Guard context usage after async gap
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorDeletingProfileImage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createUserProfileWithType(UserType userType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final displayNameValue = user.displayName ?? user.email?.split('@')[0] ?? 'משתמש';
      final userProfile = UserProfile(
        userId: user.uid,
        displayName: displayNameValue,
        email: user.email ?? '',
        userType: userType,
        createdAt: DateTime.now(),
      );

      final firestoreData = userProfile.toFirestore();
      firestoreData['name'] = displayNameValue; // שמירת השם המקורי ב-name גם כן
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(firestoreData);

      debugPrint('User profile created successfully with type: $userType');
      
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileCreatedSuccess(userType.displayName)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorCreatingProfile(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createUserProfileIfNeeded() async {
    if (_isCreatingProfile) return;
    
    setState(() {
      _isCreatingProfile = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        return;
      }

      // בדיקה אם הפרופיל כבר קיים
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        debugPrint('User profile already exists');
        return;
      }

      // יצירת פרופיל חדש - פרטי כברירת מחדל
      debugPrint('Creating new user profile for: ${user.email}');
      
      if (mounted) {
        await _createUserProfileWithType(UserType.personal);
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorCreatingProfileAlt(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingProfile = false;
        });
      }
    }
  }





  Future<void> _updateLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.userNotConnected),
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

      // הצגת הודעת טעינה
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkingLocationPermissions),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // בקשת הרשאות מיקום לפני פתיחת המפה
      bool hasPermission = await LocationService.checkLocationPermission();
      debugPrint('Initial permission check: $hasPermission');
      
      if (!hasPermission) {
        hasPermission = await LocationService.requestLocationPermission();
        debugPrint('After requesting permission: $hasPermission');
        
        if (!hasPermission) {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.locationPermissionsRequired),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }

      // בדיקה אם שירותי המיקום מופעלים
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.locationServicesDisabled),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // קבלת מיקום נוכחי אם אפשר
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.gettingCurrentLocation),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      Position? currentPosition = await LocationService.getCurrentPosition();
      debugPrint('Current position: $currentPosition');
      
      // קבלת מקסימום טווח חשיפה לפי סוג המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      double? maxExposureRadius;
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final userType = userData['userType'] as String? ?? 'personal';
        final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
        final recommendationsCount = userData['recommendationsCount'] as int? ?? 0;
        final averageRating = userData['averageRating'] as double? ?? 0.0;
        final isAdmin = userData['isAdmin'] as bool? ?? false;
        
        // חישוב הטווח המקסימלי לפי סוג המנוי (במטרים)
        final maxRadiusMeters = LocationService.calculateMaxRadiusForUser(
          userType: userType,
          isSubscriptionActive: isSubscriptionActive,
          recommendationsCount: recommendationsCount,
          averageRating: averageRating,
          isAdmin: isAdmin,
        );
        
        // המרה לקילומטרים
        maxExposureRadius = maxRadiusMeters / 1000;
      }
      
      // Guard context usage after async gap
      if (!mounted) return;
      
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLatitude: currentPosition?.latitude,
            initialLongitude: currentPosition?.longitude,
            initialExposureRadius: userDoc.data()?['exposureRadius']?.toDouble(),
            maxExposureRadius: maxExposureRadius,
            showExposureCircle: true, // להציג מעגל חשיפה במסך פרופיל
          ),
        ),
      );

      if (result != null) {
        // הצגת הודעת שמירה
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.savingLocationAndRadius),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // עדכון המיקום וטווח החשיפה ב-Firestore
        final updateData = {
          'latitude': result['latitude'],
          'longitude': result['longitude'],
          'village': result['address'],
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // הוספת טווח חשיפה אם נבחר
        if (result.containsKey('exposureRadius')) {
          updateData['exposureRadius'] = result['exposureRadius'];
        }
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);

        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.fixedLocationAndRadiusUpdated),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noLocationSelected),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _updateLocation: $e');
      if (mounted) {
        String errorMessage = 'שגיאה בעדכון המיקום';
        
        if (e.toString().contains('permission')) {
          errorMessage = 'שגיאה בהרשאות מיקום. אנא בדוק את ההגדרות';
        } else if (e.toString().contains('network')) {
          errorMessage = 'שגיאת רשת. אנא בדוק את החיבור לאינטרנט';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'פסק זמן. אנא נסה שוב';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// מחיקת מיקום קבוע
  Future<void> _deleteLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.userNotConnected),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // בדיקה אם המשתמש הוא עסקי מנוי
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final isBusinessUser = userDoc.exists && 
          userDoc.data()?['userType'] == 'business' &&
          userDoc.data()?['isSubscriptionActive'] == true;
      
      final locationTitle = isBusinessUser ? 'מחיקת מיקום העסק' : 'מחיקת מיקום קבוע';
      final locationMessage = isBusinessUser 
          ? 'האם אתה בטוח שברצונך למחוק את מיקום העסק?\n\n'
            'לאחר המחיקה, תופיע במפות רק כששירות המיקום פעיל בטלפון.'
          : 'האם אתה בטוח שברצונך למחוק את המיקום הקבוע?\n\n'
            'לאחר המחיקה, תופיע במפות רק כששירות המיקום פעיל בטלפון.';

      // הצגת דיאלוג אישור
      final bool? shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(locationTitle),
          content: Text(locationMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('מחק'),
            ),
          ],
        ),
      );

      if (shouldDelete != true) return;

      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);

      // הצגת הודעת טעינה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deletingLocation),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // מחיקת המיקום מ-Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'latitude': FieldValue.delete(),
        'longitude': FieldValue.delete(),
        'village': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.fixedLocationDeletedSuccess),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting location: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingLocation(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }





  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך הפרופיל
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      _showProfileSpecificTutorial();
      }
    });

    if (user == null) {
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.profile),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
        body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                l10n.notConnectedToSystem,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pleaseLoginToSeeProfile,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .distinct((prev, next) => 
            prev.data() == next.data() && 
            prev.metadata.isFromCache == next.metadata.isFromCache),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.profile),
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
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
                          l10n.loadingProfile,
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
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Profile Screen Error: ${snapshot.error}');
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.profile),
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    l10n.errorLoadingProfile,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
            Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text(l10n.tryAgain),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.profile),
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
            Text(
                    l10n.userProfileNotFound,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isCreatingProfile ? null : () async {
                      await playButtonSound();
                      _createUserProfileIfNeeded();
                    },
                    child: _isCreatingProfile 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.creatingProfile),
                            ],
                          )
                        : Text(l10n.createProfile),
                  ),
                ],
              ),
            ),
          );
        }

        final userProfile = UserProfile.fromFirestore(snapshot.data!);
        
        // עדכון נתונים ישנים של קטגוריות
        _updateOldCategoryData(userProfile);
        
        // עדכון כל הנתונים בקריאה אחת כדי למנוע ריטוט
        final newCategories = userProfile.businessCategories ?? [];
        final newPhoneNumber = userProfile.phoneNumber ?? '';
        final newAllowPhoneDisplay = userProfile.allowPhoneDisplay ?? false;
        
        bool needsUpdate = false;
        
        // בדיקה אם יש שינויים
        if (!_listEquals(_selectedBusinessCategories, newCategories)) {
          needsUpdate = true;
        }
        
        if (_phoneController.text.isEmpty && newPhoneNumber.isNotEmpty) {
          needsUpdate = true;
        }
        
        // עדכון רק אם יש שינויים
        if (mounted && needsUpdate) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedBusinessCategories = newCategories;
                if (_phoneController.text.isEmpty) {
                  _phoneController.text = newPhoneNumber;
                }
                // עדכון allowPhoneDisplay רק אם הוא באמת השתנה מ-Firestore
                if (_allowPhoneDisplay != newAllowPhoneDisplay) {
                  _allowPhoneDisplay = newAllowPhoneDisplay;
                }
                _phoneError = null;
              });
            }
          });
        }
        
        // Debug: Print user profile data
        debugPrint('Profile Screen - User Profile Data:');
        debugPrint('Raw Firestore data: ${snapshot.data!.data()}');
        debugPrint('userType: ${userProfile.userType}');
        debugPrint('userType.name: ${userProfile.userType.name}');
        debugPrint('subscriptionStatus: ${userProfile.subscriptionStatus}');
        debugPrint('isSubscriptionActive: ${userProfile.isSubscriptionActive}');
        debugPrint('subscriptionExpiry: ${userProfile.subscriptionExpiry}');
        debugPrint('profileImageUrl: ${userProfile.profileImageUrl}');
        debugPrint('displayName: ${userProfile.displayName}');
        debugPrint('email: ${userProfile.email}');

        // טעינת שם התצוגה ל-controller
        // למשתמש עסקי מנוי - טען את שם העסק (displayName)
        // למשתמשים אחרים - טען את השם המקורי מההרשמה (name)
        String newDisplayName;
        if (userProfile.userType == UserType.business && userProfile.isSubscriptionActive) {
          // למשתמש עסקי - טען את שם העסק (displayName)
          newDisplayName = userProfile.displayName.isNotEmpty 
              ? userProfile.displayName 
              : userProfile.email.split('@')[0];
        } else {
          // למשתמשים אחרים - טען את השם המקורי מההרשמה (name)
          final userDoc = snapshot.data;
          if (userDoc != null && userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final originalName = userData['name'] as String?;
            if (originalName != null && originalName.isNotEmpty) {
              newDisplayName = originalName;
            } else {
              // אם אין name, נשתמש ב-displayName או במייל
              newDisplayName = userProfile.displayName.isNotEmpty 
                  ? userProfile.displayName 
                  : userProfile.email.split('@')[0];
            }
          } else {
            newDisplayName = userProfile.displayName.isNotEmpty 
                ? userProfile.displayName 
                : userProfile.email.split('@')[0];
          }
        }
        
        // עדכון ה-controller רק אם השם השתנה
        if (_displayNameController.text != newDisplayName) {
          _displayNameController.text = newDisplayName;
        }

        return Directionality(
          textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.profile,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          toolbarHeight: 50,
          actions: [
            Builder(
              builder: (builderContext) {
                // שמירת l10n ב-closure כדי למנוע בעיות עם deactivated widget
                final currentL10n = l10n;
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (!mounted) return;
                    
                    if (value == 'share') {
                      AppSharingService.shareApp(context);
                    } else if (value == 'rate') {
                      AppSharingService.rateApp(context);
                    } else if (value == 'recommend') {
                      AppSharingService.showRecommendationDialog(context);
                    } else if (value == 'rewards') {
                      AppSharingService.showRewardsDialog(context);
                    } else if (value == 'reset_tutorials') {
                      _resetTutorials();
                    } else if (value == 'contact') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactScreen(),
                        ),
                      );
                    } else if (value == 'terms') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TermsAndPrivacyScreen(
                            onAccept: () {},
                            onDecline: () {},
                            readOnly: true, // קריאה בלבד - לא להציג לחצנים
                          ),
                        ),
                      );
                    } else if (value == 'privacy') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TermsAndPrivacyScreen(
                            onAccept: () {},
                            onDecline: () {},
                            readOnly: true, // קריאה בלבד - לא להציג לחצנים
                          ),
                        ),
                      );
                    } else if (value == 'about') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutAppScreen(),
                        ),
                      );
                    } else if (value == 'delete_account') {
                      _showDeleteAccountDialog(currentL10n);
                    } else if (value == 'logout') {
                      _showLogoutDialog(currentL10n);
                    }
                    // DEBUG: שינוי סוג מנוי - מוסתר זמנית
                    // else if (value == 'debug_free') {
                    //   final userProfile = UserProfile.fromFirestore(snapshot.data!);
                    //   _switchToSubscriptionType('private_free', userProfile);
                    // } else if (value == 'debug_personal') {
                    //   final userProfile = UserProfile.fromFirestore(snapshot.data!);
                    //   _switchToSubscriptionType('personal', userProfile);
                    // } else if (value == 'debug_business') {
                    //   final userProfile = UserProfile.fromFirestore(snapshot.data!);
                    //   _switchToSubscriptionType('business', userProfile);
                    // } else if (value == 'debug_guest') {
                    //   final userProfile = UserProfile.fromFirestore(snapshot.data!);
                    //   _switchToSubscriptionType('guest', userProfile);
                    // }
                  },
                  itemBuilder: (context) {
                    // Guard: בדיקה אם ה-context עדיין valid
                    if (!mounted) return [];
                    // שימוש ב-l10n שכבר נשמר מחוץ ל-itemBuilder
                    return [
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            const Icon(Icons.share, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(currentL10n.shareAppTitle),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rate',
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(currentL10n.rateAppTitle),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'recommend',
                        child: Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(currentL10n.recommendToFriendsTitle),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rewards',
                        child: Row(
                          children: [
                            const Icon(Icons.card_giftcard, color: Colors.purple),
                            const SizedBox(width: 8),
                            Text(currentL10n.rewardsForRecommenders),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'reset_tutorials',
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(currentL10n.resetTutorialMessages),
                          ],
                        ),
                      ),
                  // DEBUG: שינוי סוג מנוי - מוסתר זמנית
                  // const PopupMenuDivider(),
                  // const PopupMenuItem(
                  //   value: 'debug_free',
                  //   child: Row(
                  //     children: [
                  //       Icon(Icons.person, color: Colors.blue),
                  //       SizedBox(width: 8),
                  //       Text('🔧 עבור לפרטי חינם'),
                  //     ],
                  //   ),
                  // ),
                  // const PopupMenuItem(
                  //   value: 'debug_personal',
                  //   child: Row(
                  //     children: [
                  //       Icon(Icons.person_outline, color: Colors.green),
                  //       SizedBox(width: 8),
                  //       Text('🔧 עבור לפרטי מנוי'),
                  //     ],
                  //   ),
                  // ),
                  // const PopupMenuItem(
                  //   value: 'debug_business',
                  //   child: Row(
                  //     children: [
                  //       Icon(Icons.business, color: Colors.purple),
                  //       SizedBox(width: 8),
                  //       Text('🔧 עבור לעסקי מנוי'),
                  //     ],
                  //   ),
                  // ),
                  // const PopupMenuItem(
                  //   value: 'debug_guest',
                  //   child: Row(
                  //     children: [
                  //       Icon(Icons.person_add, color: Colors.orange),
                  //       SizedBox(width: 8),
                  //       Text('🔧 עבור לאורח'),
                  //     ],
                  //   ),
                  // ),
                      PopupMenuItem(
                        value: 'contact',
                        child: Row(
                          children: [
                            const Icon(Icons.contact_support, color: Color(0xFF03A9F4)),
                            const SizedBox(width: 8),
                            Text(currentL10n.contact),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            const Icon(Icons.logout, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(currentL10n.logoutTitle),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'terms',
                        child: Row(
                          children: [
                            const Icon(Icons.description, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(currentL10n.termsButton),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'privacy',
                        child: Row(
                          children: [
                            const Icon(Icons.privacy_tip, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(currentL10n.privacyButton),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'about',
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(currentL10n.aboutButton),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete_account',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_forever, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(currentL10n.deleteAccount),
                          ],
                        ),
                      ),
                    ];
                  },
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // כרטיס פרופיל
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _isUploadingImage ? null : _uploadProfileImage,
                            child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
                                  child: userProfile.profileImageUrl != null
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: userProfile.profileImageUrl!,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              width: 60,
                                              height: 60,
                                              color: Theme.of(context).colorScheme.primary,
                                              child: Center(
                                                child: Text(
                              userProfile.displayName.isNotEmpty 
                                  ? userProfile.displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                                                ),
                                              ),
                                          ),
                                            errorWidget: (context, url, error) => Builder(
                                              builder: (context) {
                                                // למשתמש עסקי מנוי - השתמש בשם המקורי (name) לאות הראשונה
                                                String firstChar = '?';
                                                if (userProfile.userType == UserType.business && userProfile.isSubscriptionActive) {
                                                  final userDoc = snapshot.data;
                                                  if (userDoc != null && userDoc.exists) {
                                                    final userData = userDoc.data() as Map<String, dynamic>;
                                                    final originalName = userData['name'] as String?;
                                                    if (originalName != null && originalName.isNotEmpty) {
                                                      firstChar = originalName[0].toUpperCase();
                                                    } else if (userProfile.email.isNotEmpty) {
                                                      firstChar = userProfile.email[0].toUpperCase();
                                                    }
                                                  } else if (userProfile.email.isNotEmpty) {
                                                    firstChar = userProfile.email[0].toUpperCase();
                                                  }
                                                } else if (userProfile.displayName.isNotEmpty) {
                                                  firstChar = userProfile.displayName[0].toUpperCase();
                                                } else if (userProfile.email.isNotEmpty) {
                                                  firstChar = userProfile.email[0].toUpperCase();
                                                }
                                                
                                                return Container(
                                                  width: 60,
                                                  height: 60,
                                                  color: Theme.of(context).colorScheme.primary,
                                                  child: Center(
                                                    child: Text(
                                                      firstChar,
                                                      style: TextStyle(
                                                        fontSize: 24,
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).colorScheme.onPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          child: Center(
                                            child: Builder(
                                              builder: (context) {
                                                // למשתמש עסקי מנוי - השתמש בשם המקורי (name) לאות הראשונה
                                                String firstChar = '?';
                                                if (userProfile.userType == UserType.business && userProfile.isSubscriptionActive) {
                                                  final userDoc = snapshot.data;
                                                  if (userDoc != null && userDoc.exists) {
                                                    final userData = userDoc.data() as Map<String, dynamic>;
                                                    final originalName = userData['name'] as String?;
                                                    if (originalName != null && originalName.isNotEmpty) {
                                                      firstChar = originalName[0].toUpperCase();
                                                    } else if (userProfile.email.isNotEmpty) {
                                                      firstChar = userProfile.email[0].toUpperCase();
                                                    }
                                                  } else if (userProfile.email.isNotEmpty) {
                                                    firstChar = userProfile.email[0].toUpperCase();
                                                  }
                                                } else if (userProfile.displayName.isNotEmpty) {
                                                  firstChar = userProfile.displayName[0].toUpperCase();
                                                } else if (userProfile.email.isNotEmpty) {
                                                  firstChar = userProfile.email[0].toUpperCase();
                                                }
                                                
                                                return Text(
                                                  firstChar,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                ),
                                if (_isUploadingImage)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!_isUploadingImage)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 2),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    // תמיד הצג את השם המקורי מההרשמה (name) מעל המייל
                                    // זה השם שהמשתמש הזין במסך התחברות/הרשמה
                                    String displayText;
                                    final userDoc = snapshot.data;
                                    if (userDoc != null && userDoc.exists) {
                                      final userData = userDoc.data() as Map<String, dynamic>;
                                      final originalName = userData['name'] as String?;
                                      if (originalName != null && originalName.isNotEmpty) {
                                        displayText = originalName;
                                      } else {
                                        // אם אין name, השתמש במייל
                                        displayText = userProfile.email.split('@')[0];
                                      }
                                    } else {
                                      displayText = userProfile.email.split('@')[0];
                                    }
                                    
                                    return Text(
                                      displayText,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : Colors.grey[900], // כהה מאוד (כמעט שחור) בערכה כהה
                                      ),
                                    );
                                  },
                                ),
                                Text(
                                  userProfile.email,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        // בדיקה אם זה משתמש אורח
                                        if (userProfile.userType == UserType.guest) {
                                          _showGuestSubscriptionDetailsDialog(userProfile);
                                        } else if (userProfile.isSubscriptionActive && 
                                            userProfile.businessCategories != null && 
                                            userProfile.businessCategories!.isNotEmpty) {
                                          // אם המשתמש כבר עסקי מנוי - הצג דיאלוג פירוט
                                          _showBusinessSubscriptionDetailsDialog(userProfile);
                                        } else if (userProfile.isSubscriptionActive && 
                                                   (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty)) {
                                          // אם המשתמש פרטי מנוי - הצג דיאלוג פרטי מנוי
                                          _showPersonalSubscriptionDetailsDialog(userProfile);
                                        } else if (!userProfile.isSubscriptionActive) {
                                          // אם המשתמש חינם - הצג דיאלוג פירוט עם אפשרות שדרוג
                                          _showFreeSubscriptionDetailsDialog(userProfile);
                                        } else {
                                          // אחרת - הצג דיאלוג בחירת סוג מנוי
                                          _showSubscriptionTypeDialog(userProfile);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getSubscriptionTypeColor(userProfile),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _getSubscriptionTypeDisplayName(userProfile),
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit,
                                              color: Theme.of(context).colorScheme.onPrimary,
                                              size: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // כפתור ניהול הזמנות למשתמש עסקי
                                    if (userProfile.userType == UserType.business && userProfile.isSubscriptionActive) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const OrderManagementScreen(),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green[600],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.green[700]!, width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.shopping_cart,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'ניהול הזמנות',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    // כפתור שדרג מנוי למשתמשי אורח ומשתמשי פרטי מנוי - ליד הלחצן
                                    if ((userProfile.userType == UserType.guest && userProfile.isTemporaryGuest != true) ||
                                        (userProfile.isSubscriptionActive && 
                                         (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty))) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _showSubscriptionTypeDialog(userProfile),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[600],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.blue[700]!, width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.upgrade,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'פרסם עסק',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // כפתור הארכת תקופת ניסיון למשתמשי אורח
                      if (userProfile.userType == UserType.guest && userProfile.isTemporaryGuest != true) ...[
                        const SizedBox(height: 12),
                        _buildTrialExtensionButton(userProfile),
                      ],
                      
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // שדה שם פרטי ומשפחה/חברה/עסק/כינוי - לכל סוגי המשתמשים (לא לאורח זמני)
              // למשתמש עסקי מנוי - מציג "שם העסק/חברה/כינוי" במקום "שם פרטי ומשפחה"
              if (userProfile.isTemporaryGuest != true) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          userProfile.userType == UserType.business && userProfile.isSubscriptionActive
                              ? Icons.business
                              : Icons.person, 
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          userProfile.userType == UserType.business && userProfile.isSubscriptionActive
                              ? 'שם העסק/חברה/כינוי'
                              : l10n.firstNameLastName,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _displayNameController,
                                keyboardType: TextInputType.text,
                                enabled: false, // שדה read-only
                                decoration: InputDecoration(
                                  hintText: userProfile.userType == UserType.business && userProfile.isSubscriptionActive
                                      ? 'הזן שם העסק/חברה/כינוי'
                                      : l10n.enterFirstNameLastName,
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  errorText: _displayNameError,
                                  prefixIcon: Icon(
                                    userProfile.userType == UserType.business && userProfile.isSubscriptionActive
                                        ? Icons.business
                                        : Icons.person,
                                    color: Theme.of(context).colorScheme.primary
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.grey[900], // כהה מאוד (כמעט שחור) בערכה כהה
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await playButtonSound();
                                _editDisplayName();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(l10n.update),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      Text(
                        l10n.nameDisplayInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.light 
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.clickUpdateToChangeName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ],

              // שדה טלפון - לכל סוגי המשתמשים (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.outlineVariant
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.phoneNumber,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                enabled: false, // שדה read-only
                                onChanged: (value) {
                                  // עדכון הצ'יקבוקס כשמשנים את הטלפון
                                  setState(() {
                                    if (value.trim().isEmpty) {
                                      _allowPhoneDisplay = false;
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: l10n.enterPhoneNumber,
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  errorText: _phoneError,
                                  prefixIcon: Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceContainer,
                                ),
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.grey[900], // כהה מאוד (כמעט שחור) בערכה כהה
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                await playButtonSound();
                                _editPhoneNumber();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(l10n.update),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.validPrefixes,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.light 
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _allowPhoneDisplay,
                          onChanged: _phoneController.text.trim().isNotEmpty ? (value) async {
                            setState(() {
                              _allowPhoneDisplay = value ?? false;
                            });
                            // שמירה אוטומטית של ההגדרה
                            await _savePhoneDisplaySetting(_allowPhoneDisplay);
                          } : null,
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            l10n.agreeToDisplayPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.light 
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ],

              // תמונת עסק (רק למשתמש עסקי) - אחרי הצ'יקבוקס ולפני תחומי עיסוק
              if (userProfile.userType == UserType.business && userProfile.businessImageUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'תמונת עסק',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _editBusinessImage(userProfile),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('ערוך'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _editBusinessImage(userProfile),
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: userProfile.businessImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) {
                                return const Center(
                                  child: Icon(Icons.error, color: Colors.red),
                                );
                              },
                              placeholder: (context, url) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // תחומי עיסוק - מנהל, עסקי מנוי או אורח (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true &&
                  (_isAdmin == true || 
                  userProfile.userType == UserType.guest || 
                  userProfile.userType == UserType.business)) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.work, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isAdmin == true ? l10n.allBusinessFields : l10n.businessFields,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // כפתור עריכה רק למשתמש עסקי מנוי (לא למנהל)
                          if (_isAdmin != true)
                            GestureDetector(
                              onTap: () => _showBusinessCategoriesDialog(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.edit,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _isAdmin == true 
                            ? [
                                // עבור מנהל - הצג רק "כל תחומי העיסוק"
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                        : Theme.of(context).colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.outlineVariant
                                          : Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.allBusinessFields,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).colorScheme.onSurface,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ]
                            : (userProfile.businessCategories != null && userProfile.businessCategories!.isNotEmpty)
                                ? userProfile.businessCategories!.map((category) {
                                // בדיקה נוספת לוודא שהקטגוריה קיימת
                                try {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                          : Theme.of(context).colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? Theme.of(context).colorScheme.outlineVariant
                                            : Theme.of(context).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      category.categoryDisplayName,
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? Theme.of(context).colorScheme.onSurface
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint('Error displaying category $category: $e');
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                          : Theme.of(context).colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? Theme.of(context).colorScheme.outlineVariant
                                            : Theme.of(context).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      category.toString(),
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? Theme.of(context).colorScheme.onSurface
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                              }).toList()
                                : [
                                  Text(
                                    l10n.noBusinessFieldsDefined,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.onSurfaceVariant
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // שירותים - רק למשתמש עסקי מנוי
              if (userProfile.userType == UserType.business && 
                  userProfile.isSubscriptionActive &&
                  userProfile.businessCategories != null &&
                  userProfile.businessCategories!.isNotEmpty) ...[
                _buildBusinessServicesSection(userProfile),
                const SizedBox(height: 16),
              ],

              // התראה למשתמש אורח או עסקי מנוי שאין לו תחומי עיסוק (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true &&
                  (userProfile.userType == UserType.guest || userProfile.userType == UserType.business) && 
                  (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty)) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning, 
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.setBusinessFields,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.toReceiveRelevantNotifications,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // צ'קבוקס לא נותן שירותים בתשלום
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.outlineVariant
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              value: _noPaidServices,
                              onChanged: (value) {
                                setState(() {
                                  _noPaidServices = value ?? false;
                                });
                                _updateNoPaidServicesStatus(_noPaidServices);
                              },
                              title: Text(
                                l10n.iDoNotProvidePaidServices,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'אם תסמן אפשרות זו, תוכל לראות רק בקשות חינמיות במסך הבקשות.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                                    : Colors.black87,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _noPaidServices ? null : () {
                            _showGuestCategoriesDialog(userProfile);
                          },
                          icon: const Icon(Icons.work, size: 18),
                          label: Text(l10n.selectBusinessCategories),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _noPaidServices ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.tertiary,
                            foregroundColor: Theme.of(context).colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // זמינות - מוצג למשתמשי אורח ועסקי מנוי (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true &&
                  (_isAdmin == true || 
                  userProfile.userType == UserType.guest || 
                  userProfile.userType == UserType.business)) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.availability,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // כפתור עריכה רק למשתמש אורח או עסקי מנוי (לא למנהל) - רק אם לא בחרו תורים
                          if (_isAdmin != true && _useAppointments != true)
                            GestureDetector(
                              onTap: () => _showAvailabilityDialog(userProfile),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.edit,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Radio buttons לבחירה בין זמינות/תורים - רק לאורחים עם קטגוריות או עסקיים מנויים
                      // תורים זמינים רק אם המשתמש סימן "שירותים דורשים קביעת תור"
                      if (_isAdmin != true && 
                          ((userProfile.userType == UserType.guest && 
                            userProfile.businessCategories != null && 
                            userProfile.businessCategories!.isNotEmpty) ||
                           (userProfile.userType == UserType.business && 
                            userProfile.isSubscriptionActive == true))) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Radio<bool>(
                              value: false,
                              groupValue: _useAppointments,
                              onChanged: (value) {
                                if (value != null) {
                                  _saveAppointmentPreference(false);
                                }
                              },
                            ),
                            const Text('זמינות'),
                            const SizedBox(width: 24),
                            Radio<bool>(
                              value: true,
                              groupValue: _useAppointments,
                              onChanged: _requiresAppointment 
                                  ? (value) {
                                      if (value != null) {
                                        _saveAppointmentPreference(true);
                                      }
                                    }
                                  : null, // לא ניתן לבחור תורים אם לא סומן הצ'קבוקס
                            ),
                            Text(
                              'תורים',
                              style: TextStyle(
                                color: _requiresAppointment 
                                    ? null 
                                    : Colors.grey, // טקסט אפור אם לא ניתן לבחור
                              ),
                            ),
                          ],
                        ),
                        if (!_requiresAppointment) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(right: 32),
                            child: Text(
                              'כדי להגדיר תורים, יש לסמן "השירותים דורשים קביעת תור" בחלק השירותים',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // כפתור "הגדר תורים" אם בחרו תורים והצ'קבוקס מסומן
                        if (_useAppointments == true && _requiresAppointment) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AppointmentSettingsScreen(),
                                  ),
                                ).then((_) {
                                  // רענון הפרופיל אחרי חזרה
                                  setState(() {});
                                });
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('הגדר תורים'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      const SizedBox(height: 4),
                      Text(
                        l10n.availabilityDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (userProfile.availableAllWeek == true) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                : Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                l10n.availableAllWeek,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (userProfile.weekAvailability != null && 
                                 userProfile.weekAvailability!.days.any((d) => d.isAvailable)) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: userProfile.weekAvailability!.days
                              .where((day) => day.isAvailable)
                              .map((day) {
                            final timeText = day.startTime != null && day.endTime != null
                                ? ' ${day.startTime} - ${day.endTime}'
                                : '';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Theme.of(context).colorScheme.surfaceContainerHighest 
                                    : Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Theme.of(context).colorScheme.outlineVariant
                                      : Theme.of(context).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                '${l10n.getDayName(day.day)}$timeText',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        Text(
                          l10n.noAvailabilityDefined,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // כרטיס מיקום - מוצג רק למשתמשים נותני שירות (אורח, עסקי, מנהל) (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true &&
                  (userProfile.userType == UserType.guest || 
                  userProfile.userType == UserType.business ||
                  _isAdmin == true)) ...[
                Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            userProfile.userType == UserType.business && userProfile.isSubscriptionActive
                                ? 'מיקום העסק'
                                : l10n.fixedLocation,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await playButtonSound();
                              _updateLocation();
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(l10n.updateLocationAndRadius),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF9C27B0) // סגול יפה
                : Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // הודעה מיוחדת למנהל
                      if (_isAdmin == true) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings, 
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white
                                    : Colors.black87,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.adminCanUpdateLocation,
                                  style: TextStyle(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (userProfile.latitude != null && userProfile.longitude != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle, 
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurface,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.fixedLocationDefined,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.my_location, 
                                    size: 16,
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${userProfile.latitude!.toStringAsFixed(6)}, ${userProfile.longitude!.toStringAsFixed(6)}',
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_city, 
                                    size: 16,
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Theme.of(context).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    userProfile.village ?? l10n.villageNotDefined,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.youWillAppearInRange,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                                      : Colors.black87,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _updateLocation,
                                      icon: const Icon(Icons.edit_location, size: 16),
                                      label: Text(l10n.updateLocationAndRadius),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _deleteLocation,
                                      icon: const Icon(Icons.location_off, size: 16),
                                      label: Text(l10n.deleteLocation),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning, 
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.onSurface,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.noFixedLocationDefined,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white
                                          : Colors.grey[900],
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.asServiceProvider,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white
                                      : Colors.grey[900],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.locationBenefits,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white
                                      : Colors.grey[900],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                const SizedBox(height: 16),
              ],

              // קישורים חברתיים (רק למשתמש עסקי) - אחרי מיקום העסק ולפני הדירוג
              if (userProfile.userType == UserType.business && 
                  userProfile.socialLinks != null && 
                  userProfile.socialLinks!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'קישורים חברתיים',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _editSocialLinks(userProfile),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('ערוך'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (userProfile.socialLinks!.containsKey('instagram'))
                            _buildSocialLinkChip(
                              'instagram',
                              userProfile.socialLinks!['instagram']!,
                              Icons.camera_alt,
                              Colors.purple,
                            ),
                          if (userProfile.socialLinks!.containsKey('facebook'))
                            _buildSocialLinkChip(
                              'facebook',
                              userProfile.socialLinks!['facebook']!,
                              Icons.facebook,
                              Colors.blue,
                            ),
                          if (userProfile.socialLinks!.containsKey('tiktok'))
                            _buildSocialLinkChip(
                              'tiktok',
                              userProfile.socialLinks!['tiktok']!,
                              Icons.music_video,
                              Colors.black,
                            ),
                          if (userProfile.socialLinks!.containsKey('website'))
                            _buildSocialLinkChip(
                              'website',
                              userProfile.socialLinks!['website']!,
                              Icons.language,
                              Colors.blue[700]!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // דירוג המשתמש - מוצג רק למשתמשים נותני שירות (אורח, עסקי, מנהל) (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true &&
                  (userProfile.userType == UserType.guest || 
                  userProfile.userType == UserType.business ||
                  _isAdmin == true)) ...[
                _buildRatingCard(userProfile),
                const SizedBox(height: 16),
              ],

              // הודעה מיוחדת למנהל
              if (_isAdmin == true) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                    child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                              'מנהל מערכת - גישה מלאה לכל הפונקציות (עסקי מנוי)',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ),
                ),
                        const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),

              // כפתורי ניהול למנהל
              if (_isAdmin == true) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.systemManagement,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  AudioService().playSound(AudioEvent.buttonClick);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdminContactInquiriesScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.contact_support),
                                label: Text(l10n.manageInquiries),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF03A9F4),
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  AudioService().playSound(AudioEvent.buttonClick);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdminGuestManagementScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.people),
                                label: const Text('ניהול משתמשים'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9C27B0),
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  AudioService().playSound(AudioEvent.buttonClick);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AdminRequestsStatisticsScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.bar_chart),
                                label: const Text('סטטיסטיקות בקשות'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF03A9F4),
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showDeleteAllUsersConfirmation(context),
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('מחיקת כל המשתמשים'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showDeleteAllRequestsConfirmation(context),
                                icon: const Icon(Icons.delete_sweep),
                                label: const Text('מחק כל הבקשות'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showDeleteAllCollectionsConfirmation(context),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('מחק כל הקולקציות'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // מידע נוסף (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.additionalInfo,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(l10n.joinDate),
                        subtitle: Text(
                          '${userProfile.createdAt.day}/${userProfile.createdAt.month}/${userProfile.createdAt.year}',
                        ),
                      ),
                      if (_isAdmin != true) ...[
                        ListTile(
                          leading: const Icon(Icons.payment),
                          title: Text(l10n.subscriptionStatus),
                          subtitle: _buildSubscriptionStatus(userProfile),
                          trailing: _buildSubscriptionButton(userProfile),
                        ),
                        if (userProfile.subscriptionExpiry != null)
                          ListTile(
                            leading: const Icon(Icons.schedule),
                            title: Text(l10n.expiryDate),
                            subtitle: Text(
                              '${userProfile.subscriptionExpiry!.day}/${userProfile.subscriptionExpiry!.month}/${userProfile.subscriptionExpiry!.year}',
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ],

              // כרטיס מונה בקשות חודשיות - מוצג לכל המשתמשים (לא לאורח זמני)
              if (userProfile.isTemporaryGuest != true) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.monthlyRequests,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMonthlyRequestsCounter(userProfile),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ],
              
              // כרטיס שיתוף והמלצה
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.share,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.helpUsGrow,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.recommendAppToFriends,
                        style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await playButtonSound();
                                // Guard context usage after async gap
                                if (!context.mounted) return;
                                AppSharingService.shareApp(context);
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: Text(l10n.shareApp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await playButtonSound();
                                // Guard context usage after async gap
                                if (!context.mounted) return;
                                AppSharingService.rateApp(context);
                              },
                              icon: const Icon(Icons.star, size: 18),
                              label: Text(l10n.rateApp),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => AppSharingService.showRecommendationDialog(context),
                              icon: const Icon(Icons.favorite, size: 18),
                              label: Text(l10n.recommendToFriends),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.error,
                                side: BorderSide(color: Theme.of(context).colorScheme.error),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => AppSharingService.showRewardsDialog(context),
                              icon: const Icon(Icons.card_giftcard, size: 18),
                              label: Text(l10n.rewards),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.tertiary,
                                side: BorderSide(color: Theme.of(context).colorScheme.tertiary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
            ],
          ),
        ),
          ),
        );
      },
    );
  }

  /// בניית סטטוס המנוי
  Widget _buildSubscriptionStatus(UserProfile userProfile) {
    final subscriptionStatus = userProfile.subscriptionStatus ?? 'private_free';
    
    // Debug: Print subscription status
    debugPrint('_buildSubscriptionStatus - subscriptionStatus: $subscriptionStatus');
    debugPrint('_buildSubscriptionStatus - isSubscriptionActive: ${userProfile.isSubscriptionActive}');
    
    switch (subscriptionStatus) {
      case 'active':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'פעיל',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '✅ מאושר',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case 'pending_approval':
        // קביעת סוג המנוי המבוקש
        String requestedType = 'מנוי';
        if (userProfile.requestedSubscriptionType == 'personal') {
          requestedType = 'פרטי מנוי';
        } else if (userProfile.requestedSubscriptionType == 'business') {
          requestedType = 'עסקי מנוי';
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$requestedType בתהליך אישור',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '⏳ ממתין לאישור מנהל',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case 'rejected':
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('payment_requests')
              .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
              .where('status', isEqualTo: 'rejected')
              .orderBy('rejectedAt', descending: true)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final paymentData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
              final rejectionReason = paymentData['rejectionReason'] as String?;
              
              if (rejectionReason != null && rejectionReason.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'נדחה',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'סיבה: $rejectionReason',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                );
              }
            }
            
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'נדחה',
                  style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
                ),
                SizedBox(height: 4),
                Text(
                  '❌ בקשת השדרוג נדחתה',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        );
      case 'private_free':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'פרטי חינם',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
            ),
            const SizedBox(height: 4),
            Text(
              '🆓 גישה לבקשות חינמיות',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }
  }
  
  /// בניית מונה בקשות חודשיות
  Widget _buildMonthlyRequestsCounter(UserProfile userProfile) {
    return StreamBuilder<String?>(
      stream: _getRequestDeletionStream(),
      builder: (context, deletionSnapshot) {
        return FutureBuilder<int>(
          future: _getMonthlyRequestsCount(),
          builder: (context, snapshot) {
            final l10n = AppLocalizations.of(context);
            
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Text(
            '${l10n.errorLoadingData}: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }
        
        final requestsUsed = snapshot.data ?? 0;
        final maxRequests = _getMaxRequestsForUser(userProfile);
        
        // בדיקה אם זה מנהל (ללא הגבלה)
        if (maxRequests == -1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // מונה בקשות למנהל
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.publishedRequestsThisMonth(requestsUsed),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Theme.of(context).colorScheme.outlineVariant
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      '$requestsUsed/∞',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // בר התקדמות למנהל (תמיד ירוק)
              LinearProgressIndicator(
                value: 0.0, // תמיד 0 כי אין הגבלה
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            ],
          );
        }
        
        // משתמש רגיל - עם הגבלות
        final remainingRequests = (maxRequests - requestsUsed).clamp(0, maxRequests);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // מונה בקשות
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  remainingRequests > 0 
                    ? l10n.remainingRequestsThisMonth(remainingRequests)
                    : l10n.reachedMonthlyRequestLimit,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: remainingRequests > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '$requestsUsed/$maxRequests',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // בר התקדמות
            LinearProgressIndicator(
              value: requestsUsed / maxRequests,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                remainingRequests > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            
            // כפתור שדרוג אם נשארו מעט בקשות
            if (remainingRequests <= 2 && remainingRequests > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Theme.of(context).colorScheme.tertiary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'נשארו לך רק $remainingRequests בקשות!',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // כפתור שדרוג - רק אם יכול לשדרג
            if (_canUpgradeSubscription(userProfile)) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showSubscriptionTypeDialog(userProfile),
                  icon: const Icon(Icons.upgrade, size: 18),
                  label: const Text('פרסם עסק'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
          },
        );
      },
    );
  }

  /// Stream למעקב אחר שינויים בבקשות (יצירה ומחיקה)
  Stream<String?> _getRequestDeletionStream() {
    return Stream.periodic(const Duration(seconds: 2), (index) async {
      final prefs = await SharedPreferences.getInstance();
      final deletionTime = prefs.getString('last_request_deletion');
      final creationTime = prefs.getString('last_request_creation');
      
      // החזר את הזמן האחרון של שינוי
      if (deletionTime != null && creationTime != null) {
        final deletion = DateTime.parse(deletionTime);
        final creation = DateTime.parse(creationTime);
        return deletion.isAfter(creation) ? deletionTime : creationTime;
      } else if (deletionTime != null) {
        return deletionTime;
      } else if (creationTime != null) {
        return creationTime;
      }
      return null;
    }).asyncMap((future) => future).distinct();
  }

  /// קבלת מספר בקשות חודשיות
  Future<int> _getMonthlyRequestsCount() async {
    try {
      // שימוש בשירות המעקב החדש שמזכיר בקשות שנוצרו (כולל כאלה שנמחקו)
      return await MonthlyRequestsTracker.getCurrentMonthRequestsCount();
    } catch (e) {
      debugPrint('Error getting monthly requests count: $e');
      return 0;
    }
  }

  /// קבלת מספר בקשות מקסימלי למשתמש
  int _getMaxRequestsForUser(UserProfile userProfile) {
    // בדיקה אם זה מנהל (עסקי מנוי)
    if (_isAdmin == true) {
      return -1; // ללא הגבלה
    }
    
    // בדיקה לפי סוג המנוי
    if (userProfile.isSubscriptionActive) {
      // בדיקה אם יש תחומי עיסוק - זה עסקי מנוי
      if (userProfile.businessCategories != null && userProfile.businessCategories!.isNotEmpty) {
        return 10; // עסקי מנוי
      } else {
        return 5; // פרטי מנוי
      }
    } else {
      return 1; // פרטי חינם
    }
  }

  /// בדיקה אם המשתמש יכול לשדרג מנוי
  bool _canUpgradeSubscription(UserProfile userProfile) {
    // מנהל לא יכול לשדרג
    if (_isAdmin == true) return false;
    
    // ✅ משתמש אורח תמיד יכול לשדרג (גם אם תקופת הניסיון לא הסתיימה)
    // if (userProfile.userType == UserType.guest) return false; // הוסר - משתמש אורח יכול לשדרג תמיד
    
    // אם יש בקשה בתהליך אישור - לא יכול לשלוח בקשה נוספת
    if (userProfile.subscriptionStatus == 'pending_approval') return false;
    
    // קביעת רמת המנוי הנוכחית
    int currentLevel = _getSubscriptionLevel(userProfile);
    
    // אם ברמה הנמוכה ביותר (פרטי חינם או אורח) - יכול לשדרג
    if (currentLevel == 0 || currentLevel == -1) return true;
    
    // אם ברמה הגבוהה ביותר (עסקי מנוי) - לא יכול לשדרג
    if (currentLevel >= 2) return false;
    
    // אם ברמה בינונית (פרטי מנוי) - יכול לשדרג לעסקי
    return currentLevel == 1;
  }
  
  /// קביעת רמת המנוי הנוכחית
  int _getSubscriptionLevel(UserProfile userProfile) {
    // ✅ משתמש אורח = -1 (יכול לשדרג לפרטי מנוי או עסקי)
    if (userProfile.userType == UserType.guest) return -1;
    
    // פרטי חינם = 0
    if (!userProfile.isSubscriptionActive) return 0;
    
    // פרטי מנוי = 1 (יש מנוי פעיל אבל אין תחומי עיסוק)
    if (userProfile.isSubscriptionActive && 
        (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty)) {
      return 1;
    }
    
    // עסקי מנוי = 2 (יש מנוי פעיל ויש תחומי עיסוק)
    if (userProfile.isSubscriptionActive && 
        userProfile.businessCategories != null && 
        userProfile.businessCategories!.isNotEmpty) {
      return 2;
    }
    
    return 0; // ברירת מחדל
  }
  
  /// קביעת רמת המנוי המבוקשת
  int _getTargetSubscriptionLevel(UserType newType, bool isActive) {
    if (!isActive) return 0; // פרטי חינם
    if (newType == UserType.personal) return 1; // פרטי מנוי
    if (newType == UserType.business) return 2; // עסקי מנוי
    return 0; // ברירת מחדל
  }
  
  /// קבלת שם רמת המנוי
  String _getSubscriptionLevelName(int level) {
    switch (level) {
      case -1: return 'אורח';
      case 0: return 'פרטי חינם';
      case 1: return 'פרטי מנוי';
      case 2: return 'עסקי מנוי';
      default: return 'לא ידוע';
    }
  }

  /// הצגת דיאלוג שדרוג מנוי (לא בשימוש - שמור לעתיד)
  // ignore: unused_element
  void _showUpgradeDialog(UserProfile userProfile) {
    // בדיקה אם יש בקשה בתהליך אישור
    if (userProfile.subscriptionStatus == 'pending_approval') {
      String requestedType = 'מנוי';
      if (userProfile.requestedSubscriptionType == 'personal') {
        requestedType = 'פרטי מנוי';
      } else if (userProfile.requestedSubscriptionType == 'business') {
        requestedType = 'עסקי מנוי';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('בקשה בתהליך אישור ⏳'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'יש לך בקשה ל$requestedType והיא בטיפול.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'לא ניתן לשלוח בקשה נוספת עד שהמנהל יאשר או ידחה את הבקשה הנוכחית.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('הבנתי'),
            ),
          ],
        ),
      );
      return;
    }
    
    // קביעת רמת המנוי הנוכחית
    int currentLevel = _getSubscriptionLevel(userProfile);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרסם את העסק שלך'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // הצגת אפשרות פרסום עסק בלבד
              _buildUpgradeOption(
              title: 'הפרסום כולל:',
              description: '• בחירת תחומי עיסוק\n• הגדרת מחירים\n• הגדרת מיקום\n• הגדרת טווח חשיפה\n• קידום\n• שירותים נלווים\n• ניהול עסק\n\n• עלות הפרסום: 90 ש"ח/שנה',
                onTap: () {
                  Navigator.pop(context);
                  _updateSubscriptionType(UserType.business, true, userProfile: userProfile);
                },
              ),
            if (currentLevel >= 2) ...[
              // עסקי מנוי - לא יכול לשדרג
              const Text('אין אפשרויות שדרוג זמינות'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'יש לך כבר את המנוי הגבוה ביותר (עסקי מנוי)',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }

  /// בניית אפשרות שדרוג
  Widget _buildUpgradeOption({
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// בניית כפתור המנוי
  Widget? _buildSubscriptionButton(UserProfile userProfile) {
    final subscriptionStatus = userProfile.subscriptionStatus ?? 'private_free';
    
    switch (subscriptionStatus) {
      case 'active':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary),
          ),
          child: Text(
            'פעיל',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case 'pending_approval':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.tertiary),
          ),
          child: Text(
            'בתהליך אישור',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white
                  : Theme.of(context).colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.error),
          ),
          child: Text(
            'נדחה',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white
                  : Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case 'private_free':
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary),
          ),
          child: Text(
            'פרטי חינם',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
    }
  }

  Widget _buildRatingCard(UserProfile userProfile) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.yourRating,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userProfile.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('שגיאה בטעינת הדירוג');
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Text('אין דירוג זמין');
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                final averageRating = (userData?['averageRating'] as num?)?.toDouble() ?? 0.0;
                final ratingCount = (userData?['ratingCount'] as int?) ?? 0;

                // דירוגים מפורטים - נטען מ-detailed_rating_stats
                double reliability = 0.0;
                double availability = 0.0;
                double attitude = 0.0;
                double fairPrice = 0.0;

                // תמיד נציג את הדירוגים המפורטים, גם אם הם 0.0

                return FutureBuilder<Map<String, double>>(
                  future: _loadDetailedRatings(userProfile.userId),
                  builder: (context, detailedSnapshot) {
                    if (detailedSnapshot.hasData) {
                      final detailedRatings = detailedSnapshot.data!;
                      reliability = detailedRatings['reliability'] ?? 0.0;
                      availability = detailedRatings['availability'] ?? 0.0;
                      attitude = detailedRatings['attitude'] ?? 0.0;
                      fairPrice = detailedRatings['fairPrice'] ?? 0.0;
                    }

                return Column(
                  children: [
                    // דירוג כללי
                    if (ratingCount > 0) ...[
                    Row(
                      children: [
                        // כוכבים
                        Row(
                          children: List.generate(5, (index) {
                            if (index < averageRating.floor()) {
                              return Icon(
                                Icons.star,
                                color: Theme.of(context).colorScheme.tertiary,
                                size: 20,
                              );
                            } else if (index < averageRating) {
                              return Icon(
                                Icons.star_half,
                                color: Theme.of(context).colorScheme.tertiary,
                                size: 20,
                              );
                            } else {
                              return Icon(
                                Icons.star_border,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 20,
                              );
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        // ממוצע
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.basedOnRatings(ratingCount),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: List.generate(5, (index) => Icon(
                          Icons.star_border,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        )),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Text(
                            l10n.noRatingsYet,
                            style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // דירוגים מפורטים
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.detailedRatings}:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // אמינות
                              _buildDetailedRatingRow(
                                l10n.reliability,
                                reliability,
                                Icons.verified_user,
                                Colors.blue,
                              ),
                              const SizedBox(height: 8),
                              
                              // זמינות
                              _buildDetailedRatingRow(
                                l10n.availability,
                                availability,
                                Icons.access_time,
                                Colors.green,
                              ),
                              const SizedBox(height: 8),
                              
                              // יחס
                              _buildDetailedRatingRow(
                                l10n.attitude,
                                attitude,
                                Icons.people,
                                Colors.orange,
                              ),
                              const SizedBox(height: 8),
                              
                              // מחיר הוגן
                              _buildDetailedRatingRow(
                                l10n.fairPrice,
                                fairPrice,
                                Icons.attach_money,
                                Colors.purple,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// טעינת דירוגים מפורטים מ-detailed_rating_stats
  Future<Map<String, double>> _loadDetailedRatings(String userId) async {
    try {
      // טעינת כל הדירוגים המפורטים של המשתמש מכל הקטגוריות
      final allStatsSnapshot = await FirebaseFirestore.instance
          .collection('detailed_rating_stats')
          .get();
      
      // סינון לפי userId (המפתח הוא ${userId}_${category})
      final userStatsDocs = allStatsSnapshot.docs.where((doc) {
        final docId = doc.id;
        return docId.startsWith('${userId}_');
      }).toList();
      
      if (userStatsDocs.isEmpty) {
        return {
          'reliability': 0.0,
          'availability': 0.0,
          'attitude': 0.0,
          'fairPrice': 0.0,
        };
      }
      
      // חישוב ממוצע מכל הקטגוריות
      double totalReliability = 0.0;
      double totalAvailability = 0.0;
      double totalAttitude = 0.0;
      double totalFairPrice = 0.0;
      int count = 0;
      
      for (var doc in userStatsDocs) {
        final statsData = doc.data();
        final rel = (statsData['averageReliability'] as num?)?.toDouble();
        final avail = (statsData['averageAvailability'] as num?)?.toDouble();
        final att = (statsData['averageAttitude'] as num?)?.toDouble();
        final fp = (statsData['averageFairPrice'] as num?)?.toDouble();
        
        if (rel != null && avail != null && att != null && fp != null) {
          totalReliability += rel;
          totalAvailability += avail;
          totalAttitude += att;
          totalFairPrice += fp;
          count++;
        }
      }
      
      if (count > 0) {
        return {
          'reliability': totalReliability / count,
          'availability': totalAvailability / count,
          'attitude': totalAttitude / count,
          'fairPrice': totalFairPrice / count,
        };
      }
      
      return {
        'reliability': 0.0,
        'availability': 0.0,
        'attitude': 0.0,
        'fairPrice': 0.0,
      };
    } catch (e) {
      debugPrint('❌ Error loading detailed ratings: $e');
      return {
        'reliability': 0.0,
        'availability': 0.0,
        'attitude': 0.0,
        'fairPrice': 0.0,
      };
    }
  }

  /// דיאלוג התנתקות
  Future<void> _showLogoutDialog(AppLocalizations l10n) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(dialogL10n.logoutTitle),
          content: Text(dialogL10n.logoutMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              child: Text(
                dialogL10n.logoutButton,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ביצוע התנתקות מלאה
  Future<void> _performLogout() async {
    try {
      // התנתקות מלאה - מוחקת את כל המידע השמור
      await AutoLoginService.logout();
      
      // חזרה למסך התחברות
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתנתקות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ביצוע התנתקות לצורך הרשמה (למשתמש אורח זמני)
  Future<void> _performLogoutForRegistration() async {
    try {
      // התנתקות מלאה - מוחקת את כל המידע השמור
      await AutoLoginService.logout();
      
      // חזרה למסך התחברות
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout for registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהתנתקות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// מחיקת משתמש אורח זמני והעברה למסך התחברות
  Future<void> _deleteTemporaryGuestAndNavigateToAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // אם אין משתמש מחובר, פשוט מעביר למסך התחברות
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
        }
        return;
      }

      // הצגת אינדיקטור טעינה
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('מוחק חשבון...'),
              ],
            ),
          ),
        );
      }

      final userId = user.uid;

      // מחיקה מקבילה של נתונים מ-Firestore ו-Storage
      await Future.wait([
        _deleteUserDataFromFirestore(userId),
        _deleteUserImagesFromStorage(userId),
        _clearLocalData(),
      ]);

      // מחיקת החשבון מ-Firebase Auth (אחרון)
      await user.delete();

      // סגירת דיאלוג הטעינה
      if (mounted) {
        Navigator.of(context).pop();
      }

      // חזרה למסך התחברות
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error deleting temporary guest: $e');
      
      // סגירת דיאלוג הטעינה אם עדיין פתוח
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // גם אם יש שגיאה, ננסה להתנתק ולהעביר למסך התחברות
      try {
        await AutoLoginService.logout();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
        }
      } catch (logoutError) {
        debugPrint('Error during logout: $logoutError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה במחיקת החשבון. אנא נסה שוב.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// דיאלוג מחיקת חשבון
  Future<void> _showDeleteAccountDialog(AppLocalizations l10n) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Theme.of(context).colorScheme.error, size: 28),
              const SizedBox(width: 8),
              Text(dialogL10n.deleteAccountTitle),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dialogL10n.deleteAccountConfirm,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.error),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dialogL10n.thisActionWillDeletePermanently,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDeleteWarningPoint(dialogL10n.yourLoginCredentials),
                      _buildDeleteWarningPoint(dialogL10n.yourPersonalInfo),
                      _buildDeleteWarningPoint(dialogL10n.allYourPublishedRequests),
                      _buildDeleteWarningPoint(dialogL10n.allYourInterestedRequests),
                      _buildDeleteWarningPoint(dialogL10n.allYourChats),
                      _buildDeleteWarningPoint(dialogL10n.allYourMessages),
                      _buildDeleteWarningPoint(dialogL10n.allYourImages),
                      _buildDeleteWarningPoint(dialogL10n.allYourData),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.tertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogL10n.thisActionCannotBeUndone,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
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
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _showPasswordConfirmationDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(dialogL10n.deleteAccount),
            ),
          ],
        );
      },
    );
  }

  /// דיאלוג אישור סיסמה למחיקת חשבון
  Future<void> _showPasswordConfirmationDialog() async {
    // בדיקה מוקדמת אם המשתמש התחבר דרך Google
    final user = FirebaseAuth.instance.currentUser;
    if (user?.providerData.any((provider) => provider.providerId == 'google.com') == true) {
      // משתמש Google - אין סיסמה לאמת, עובר ישירות לדיאלוג Google
      await _showGoogleUserDeleteConfirmation();
      return;
    }

    // בדיקה אם המשתמש הוא אורח זמני
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isTemporaryGuest = userData['isTemporaryGuest'] ?? false;
          
          if (isTemporaryGuest == true) {
            // אורח זמני - אין סיסמה, עובר ישירות למחיקה
            await _performAccountDeletion();
            return;
          }
        }
      } catch (e) {
        debugPrint('Error checking temporary guest status: $e');
        // אם יש שגיאה, נמשיך לדיאלוג סיסמה רגיל
      }
    }

    // משתמש שכונתי - מציג דיאלוג סיסמה
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? errorText;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dialogL10n = AppLocalizations.of(context);
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.security, color: Theme.of(context).colorScheme.error, size: 28),
                  const SizedBox(width: 8),
                  Text(dialogL10n.passwordConfirmation),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dialogL10n.passwordConfirmationMessage,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: dialogL10n.password,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onChanged: (value) {
                      if (errorText != null) {
                        setState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.error),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dialogL10n.thisActionWillDeleteAccountPermanently,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onErrorContainer,
                            ),
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
                  child: Text(dialogL10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (passwordController.text.isEmpty) {
                      setState(() {
                        errorText = dialogL10n.passwordRequired;
                      });
                      return;
                    }

                    // משתמש שכונתי - אמת סיסמה
                    final user = FirebaseAuth.instance.currentUser;
                    final credential = EmailAuthProvider.credential(
                      email: user?.email ?? '',
                      password: passwordController.text,
                    );
                    
                    try {
                      await user?.reauthenticateWithCredential(credential);
                      // Guard context usage after async gap
                      if (!context.mounted) return;
                      // סיסמה נכונה - ממשיך למחיקה
                      Navigator.of(context).pop();
                      await _performAccountDeletion();
                    } catch (e) {
                      setState(() {
                        errorText = dialogL10n.wrongPassword;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text(dialogL10n.deleteAccount),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// דיאלוג אישור למשתמש Google
  Future<void> _showGoogleUserDeleteConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final dialogL10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error, size: 28),
              const SizedBox(width: 8),
              Text(dialogL10n.googleUserDeleteTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                dialogL10n.loggedInWithGoogle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dialogL10n.clickConfirmToDeletePermanently,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
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
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performGoogleAccountDeletion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(dialogL10n.confirm),
            ),
          ],
        );
      },
    );
  }

  /// מחיקת חשבון למשתמשי Google עם reauthentication
  Future<void> _performGoogleAccountDeletion() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // הצגת אינדיקטור טעינה
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('מוחק את החשבון...'),
              ],
            ),
          ),
        );
      }

      // Reauthentication למשתמשי Google
      try {
        // נסה reauthentication עם Google
        final googleUser = await GoogleSignIn.standard().signInSilently();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await user.reauthenticateWithCredential(credential);
        } else {
          // אם לא ניתן להתחבר בשקט, נסה התחברות רגילה
          final googleUser = await GoogleSignIn.standard().signIn();
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            final credential = GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            await user.reauthenticateWithCredential(credential);
          }
        }
      } catch (e) {
        debugPrint('Google reauthentication failed: $e');
        // נסה להמשיך ללא reauthentication
      }

      // ביצוע מחיקת החשבון (ללא דיאלוג טעינה נוסף)
      await _performAccountDeletionWithoutDialog();

    } catch (e) {
      debugPrint('Error in Google account deletion: $e');
      
      // סגירת דיאלוג הטעינה אם עדיין פתוח
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        String errorMessage = 'שגיאה במחיקת החשבון';
        
        if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'נדרשת התחברות מחדש לפני מחיקת החשבון. אנא התחבר שוב לאפליקציה.';
        } else if (e.toString().contains('user-not-found')) {
          errorMessage = 'המשתמש לא נמצא';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ביצוע מחיקת חשבון ללא דיאלוג טעינה (למשתמשי Google)
  Future<void> _performAccountDeletionWithoutDialog() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noUserFound),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userId = user.uid;

      // מחיקה מקבילה של נתונים מ-Firestore ו-Storage
      await Future.wait([
        _deleteUserDataFromFirestore(userId),
        _deleteUserImagesFromStorage(userId),
        _clearLocalData(),
      ]);

      // מחיקת החשבון מ-Firebase Auth (אחרון)
      await user.delete();

      // סגירת דיאלוג הטעינה
      if (mounted) {
        Navigator.of(context).pop();
      }

      // הצגת הודעת הצלחה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('החשבון נמחק בהצלחה'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // חזרה למסך התחברות
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      
      // סגירת דיאלוג הטעינה אם פתוח
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        String errorMessage = 'שגיאה במחיקת החשבון';
        
        if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'נדרשת התחברות מחדש לפני מחיקת החשבון. אנא התחבר שוב לאפליקציה.';
        } else if (e.toString().contains('user-not-found')) {
          errorMessage = 'המשתמש לא נמצא';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDeleteWarningPoint(String text) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onErrorContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: textColor, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// ביצוע מחיקת חשבון מלאה
  Future<void> _performAccountDeletion() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noUserFound),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // הצגת אינדיקטור טעינה
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('מוחק חשבון...'),
            ],
          ),
        ),
      );

      final userId = user.uid;

      // מחיקה מקבילה של נתונים מ-Firestore ו-Storage
      await Future.wait([
        _deleteUserDataFromFirestore(userId),
        _deleteUserImagesFromStorage(userId),
        _clearLocalData(),
      ]);

      // מחיקת החשבון מ-Firebase Auth (אחרון)
      await user.delete();

      // סגירת דיאלוג הטעינה
      if (mounted) {
        Navigator.of(context).pop();
      }

      // הצגת הודעת הצלחה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('החשבון נמחק בהצלחה'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // חזרה למסך התחברות
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      
      // סגירת דיאלוג הטעינה אם פתוח
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        String errorMessage = 'שגיאה במחיקת החשבון';
        
        if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'נדרשת התחברות מחדש לפני מחיקת החשבון';
        } else if (e.toString().contains('user-not-found')) {
          errorMessage = 'המשתמש לא נמצא';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// מחיקת כל נתוני המשתמש מ-Firestore
  Future<void> _deleteUserDataFromFirestore(String userId) async {
    try {
      // קבלת כל הבקשות שהמשתמש יצר לפני המחיקה (כדי למחוק את התמונות שלהן)
      final userRequestsSnapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('createdBy', isEqualTo: userId)
          .get();
      
      // מחיקת תמונות הבקשות שהמשתמש יצר מ-Storage
      final storage = FirebaseStorage.instance;
      for (var requestDoc in userRequestsSnapshot.docs) {
        final requestId = requestDoc.id;
        try {
          final requestImagesRef = storage.ref().child('request_images/$requestId');
          final listResult = await requestImagesRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
          debugPrint('Deleted images for request $requestId');
        } catch (e) {
          debugPrint('Error deleting images for request $requestId: $e');
          // נמשיך גם אם יש שגיאה במחיקת תמונות
        }
      }
      
      // מחיקת תמונות המודעות שהמשתמש פרסם מ-Storage
      // המודעות משתמשות באותה תיקייה כמו בקשות: request_images/{userId}/
      // אבל התמונות נשמרות עם שם קובץ ייחודי, אז נמחק את כל התמונות של המשתמש
      try {
        // מחיקת כל התמונות של המשתמש מהתיקייה request_images (כולל תמונות מודעות)
        final userImagesRef = storage.ref().child('request_images/$userId');
        try {
          final listResult = await userImagesRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
          debugPrint('Deleted all images for user $userId from request_images folder');
        } catch (e) {
          debugPrint('Error deleting user images from request_images folder: $e');
          // נמשיך גם אם יש שגיאה במחיקת תמונות
        }
      } catch (e) {
        debugPrint('Error accessing request_images folder for user $userId: $e');
        // נמשיך גם אם יש שגיאה
      }
      
      // מחיקה מקבילה של כל הנתונים
      await Future.wait([
        // מחיקת פרופיל המשתמש
        FirebaseFirestore.instance.collection('users').doc(userId).delete(),
        
        // מחיקת בקשות שהמשתמש יצר
        _deleteCollectionData('requests', 'createdBy', userId),
        
        // מחיקת מודעות שהמשתמש פרסם
        _deleteCollectionData('ads', 'createdBy', userId),
        
        // מחיקת בקשות שהמשתמש פנה אליהן
        _deleteCollectionData('applications', 'applicantId', userId),
        
        // מחיקת צ'אטים של המשתמש
        _deleteCollectionData('chats', 'participants', userId, isArrayContains: true),
        
        // מחיקת הודעות של המשתמש
        _deleteCollectionData('messages', 'senderId', userId),
        
        // מחיקת דירוגים שהמשתמש נתן
        _deleteCollectionData('ratings', 'raterId', userId),
        
        // מחיקת דירוגים שקיבל המשתמש
        _deleteCollectionData('ratings', 'ratedUserId', userId),
        
        // מחיקת התראות של המשתמש
        _deleteCollectionData('notifications', 'toUserId', userId),
      ]);

      debugPrint('Successfully deleted user data from Firestore');
    } catch (e) {
      debugPrint('Error deleting user data from Firestore: $e');
      rethrow;
    }
  }

  /// פונקציה עזר למחיקת נתונים מקולקציה
  Future<void> _deleteCollectionData(String collection, String field, String value, {bool isArrayContains = false}) async {
    try {
      Query query = FirebaseFirestore.instance.collection(collection);
      
      if (isArrayContains) {
        query = query.where(field, arrayContains: value);
      } else {
        query = query.where(field, isEqualTo: value);
      }
      
      final querySnapshot = await query.get();
      
      // מחיקה מקבילה של כל המסמכים
      if (querySnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      
      debugPrint('Deleted ${querySnapshot.docs.length} documents from $collection');
    } catch (e) {
      debugPrint('Error deleting from $collection: $e');
      // לא נזרוק שגיאה כאן כי זה לא קריטי
    }
  }

  /// מחיקת תמונות המשתמש מ-Firebase Storage
  Future<void> _deleteUserImagesFromStorage(String userId) async {
    try {
      final storage = FirebaseStorage.instance;
      final userImagesRef = storage.ref().child('user_images/$userId');
      
      // מחיקת כל התמונות של המשתמש
      final listResult = await userImagesRef.listAll();
      for (var item in listResult.items) {
        await item.delete();
      }

      debugPrint('Successfully deleted user images from Storage');
    } catch (e) {
      debugPrint('Error deleting user images from Storage: $e');
      // לא נזרוק שגיאה כאן כי זה לא קריטי
    }
  }

  /// מחיקת נתונים מקומיים
  Future<void> _clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      debugPrint('Successfully cleared local data');
    } catch (e) {
      debugPrint('Error clearing local data: $e');
      // לא נזרוק שגיאה כאן כי זה לא קריטי
    }
  }

  /// הצגת דיאלוג אישור למחיקת כל המשתמשים
  Future<void> _showDeleteAllUsersConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת כל המשתמשים'),
        content: const Text(
          'האם אתה בטוח שברצונך למחוק את כל המשתמשים מהמערכת?\n\n'
          'פעולה זו תמחק את כל המשתמשים חוץ ממנהלים.\n'
          'פעולה זו אינה הפיכה!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('מחק הכל'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      await _deleteAllUsers(context);
    }
  }

  /// מחיקת כל המשתמשים חוץ ממנהלים
  Future<void> _deleteAllUsers(BuildContext context) async {
    // הצגת דיאלוג טעינה
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // מחיקת כל המשתמשים מ-Firebase Authentication דרך Cloud Function
      int authDeletedCount = 0;
      List<dynamic>? authErrors;
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser == null) {
          debugPrint('No current user - cannot call Cloud Function');
          throw Exception('No user logged in');
        }
        
        debugPrint('Current user: ${currentUser.email}');
        final functions = FirebaseFunctions.instance;
        final deleteAllUsersFunction = functions.httpsCallable('deleteAllUsersFromAuth');
        
        // הוספת timeout ארוך יותר למחיקה של הרבה משתמשים
        final result = await deleteAllUsersFunction.call().timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            throw TimeoutException('Cloud Function call timed out after 10 minutes');
          },
        );
        
        authDeletedCount = result.data['deletedCount'] as int? ?? 0;
        authErrors = result.data['errors'] as List<dynamic>?;

        if (authErrors != null && authErrors.isNotEmpty) {
          debugPrint('Errors deleting some users from Auth: $authErrors');
        }
        
        debugPrint('Successfully deleted $authDeletedCount users from Authentication');
      } catch (e) {
        debugPrint('Error calling deleteAllUsersFromAuth Cloud Function: $e');
        if (e.toString().contains('UNAUTHENTICATED')) {
          debugPrint('Authentication error - user may not be logged in or token expired');
          debugPrint('Please log out and log back in, then try again.');
        } else {
          debugPrint('This might mean the Cloud Function is not deployed yet.');
          debugPrint('To deploy the Cloud Functions, run: firebase deploy --only functions');
        }
        // נמשיך למחוק מ-Firestore גם אם יש שגיאה ב-Authentication
      }

      // קבלת כל המשתמשים מ-Firestore
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      int firestoreDeletedCount = 0;
      final batch = FirebaseFirestore.instance.batch();

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userEmail = userData['email'] as String?;
        final isAdmin = userData['isAdmin'] ?? false;
        
        // בדיקה אם המשתמש הוא מנהל (לפי אימייל או שדה isAdmin)
        if (userEmail == 'haitham.ay82@gmail.com' || userEmail == 'admin@gmail.com' || isAdmin == true) {
          continue; // דילוג על מנהלים
        }
        
        // משתמשים אורחים זמניים יימחקו גם כן (אין צורך לסנן אותם)

        final userId = userDoc.id;

        // מחיקת פרופיל המשתמש
        batch.delete(userDoc.reference);

        // מחיקת נתונים קשורים
        await _deleteCollectionData('requests', 'createdBy', userId);
        await _deleteCollectionData('chats', 'participants', userId, isArrayContains: true);
        await _deleteCollectionData('messages', 'senderId', userId);
        await _deleteCollectionData('ratings', 'raterId', userId);
        await _deleteCollectionData('ratings', 'ratedUserId', userId);
        await _deleteCollectionData('notifications', 'toUserId', userId);

        // מחיקת תמונות מ-Storage
        try {
          final storage = FirebaseStorage.instance;
          final userImagesRef = storage.ref().child('user_images/$userId');
          final listResult = await userImagesRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
        } catch (e) {
          debugPrint('Error deleting user images: $e');
        }

        firestoreDeletedCount++;
      }

      // ביצוע המחיקה מ-Firestore
      await batch.commit();

      // סגירת דיאלוג הטעינה
      if (!context.mounted) return;
      if (mounted) {
        Navigator.of(context).pop();
      }

      // הצגת הודעת הצלחה
      if (!context.mounted) return;
      if (mounted) {
        final authMessage = authDeletedCount > 0 
            ? 'נמחקו $authDeletedCount משתמשים מ-Authentication ו-'
            : '';
        final errorMessage = authErrors != null && authErrors.isNotEmpty
            ? '\n\nשגיאות ב-Authentication: ${authErrors.length} משתמשים לא נמחקו'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$authMessage$firestoreDeletedCount משתמשים מ-Firestore בהצלחה.$errorMessage'),
            backgroundColor: authErrors != null && authErrors.isNotEmpty ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting all users: $e');
      
      // סגירת דיאלוג הטעינה
      if (!context.mounted) return;
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingUsers(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// הצגת דיאלוג אישור למחיקת כל הבקשות
  Future<void> _showDeleteAllRequestsConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת כל הבקשות'),
        content: const Text(
          'האם אתה בטוח שברצונך למחוק את כל הבקשות מהמערכת?\n\n'
          'פעולה זו תמחק את כל הבקשות.\n'
          'פעולה זו אינה הפיכה!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('מחק הכל'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      await _deleteAllRequests(context);
    }
  }

  /// מחיקת כל הבקשות
  Future<void> _deleteAllRequests(BuildContext context) async {
    // הצגת דיאלוג טעינה
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // קבלת כל הבקשות
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('requests')
          .get();

      int deletedCount = 0;
      final batch = FirebaseFirestore.instance.batch();

      for (var requestDoc in requestsSnapshot.docs) {
        final requestId = requestDoc.id;

        // מחיקת הבקשה
        batch.delete(requestDoc.reference);

        // מחיקת נתונים קשורים
        await _deleteCollectionData('chats', 'requestId', requestId);
        await _deleteCollectionData('ratings', 'requestId', requestId);
        await _deleteCollectionData('notifications', 'requestId', requestId);

        // מחיקת תמונות מ-Storage
        try {
          final storage = FirebaseStorage.instance;
          final requestImagesRef = storage.ref().child('request_images/$requestId');
          final listResult = await requestImagesRef.listAll();
          for (var item in listResult.items) {
            await item.delete();
          }
        } catch (e) {
          debugPrint('Error deleting request images: $e');
        }

        deletedCount++;
      }

      // ביצוע המחיקה
      await batch.commit();

      // סגירת דיאלוג הטעינה
      if (!context.mounted) return;
      if (mounted) {
        Navigator.of(context).pop();
      }

      // הצגת הודעת הצלחה
      if (!context.mounted) return;
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.requestsDeletedSuccessfully(deletedCount)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting all requests: $e');
      
      // סגירת דיאלוג הטעינה
      if (!context.mounted) return;
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingRequests(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// הצגת דיאלוג אישור למחיקת כל הקולקציות
  Future<void> _showDeleteAllCollectionsConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת כל הקולקציות'),
        content: const Text(
          'האם אתה בטוח שברצונך למחוק את כל הקולקציות מ-Firestore?\n\n'
          'פעולה זו תמחק את כל הקולקציות (requests, chats, messages, ratings, notifications וכו\')\n'
          'וב-users ישארו רק המנהלים.\n\n'
          'פעולה זו אינה הפיכה!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('מחק הכל'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      await _deleteAllCollections(context);
    }
  }

  /// מחיקת כל הקולקציות מ-Firestore (חוץ מ-users - שם ישארו רק מנהלים)
  Future<void> _deleteAllCollections(BuildContext context) async {
    // הצגת דיאלוג טעינה
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // רשימת כל הקולקציות למחיקה
      final collectionsToDelete = [
        'requests',
        'chats',
        'messages',
        'ratings',
        'notifications',
        'contact_inquiries',
        'push_notifications',
        'user_interests',
        'user_states',
        'monthly_requests_tracker',
        'notification_preferences',
        'detailed_rating_stats',
        'detailed_ratings', // קולקציה נוספת
        'applications',
        'chat_notifications', // קולקציה נוספת
        'filter_preferences', // קולקציה נוספת
        'likes', // קולקציה נוספת
        'notification_queue', // קולקציה נוספת
        'appointments', // קולקציית תורים
        'orders', // קולקציית הזמנות
        'order_counters', // קולקציית מונים להזמנות
        'ads', // קולקציית מודעות
      ];

      int totalDeleted = 0;
      final errors = <String>[];

      // מחיקת כל הקולקציות
      for (final collectionName in collectionsToDelete) {
        try {
          debugPrint('Deleting collection: $collectionName');
          
          // קבלת כל המסמכים בקולקציה (Source.server כדי לעקוף cache)
          // עבור chats, נשתמש ב-Source.server כדי לוודא שאנחנו מקבלים את הנתונים מהשרת
          final getOptions = collectionName == 'chats' 
              ? const GetOptions(source: Source.server)
              : const GetOptions(source: Source.server);
          
          QuerySnapshot snapshot;
          try {
            snapshot = await FirebaseFirestore.instance
                .collection(collectionName)
                .get(getOptions);
          } catch (e) {
            debugPrint('Error getting collection $collectionName: $e');
            // ננסה שוב עם Source.defaultSource
            try {
              snapshot = await FirebaseFirestore.instance
                  .collection(collectionName)
                  .get();
            } catch (e2) {
              debugPrint('Error getting collection $collectionName with default source: $e2');
              errors.add('$collectionName: $e2');
              continue;
            }
          }

          debugPrint('Collection $collectionName: Found ${snapshot.docs.length} documents (source: ${getOptions.source})');

          if (snapshot.docs.isEmpty) {
            debugPrint('Collection $collectionName is empty, skipping');
            continue;
          }

          debugPrint('Found ${snapshot.docs.length} documents in collection $collectionName');

          // אם זו קולקציית chats, צריך למחוק גם את ה-subcollections (messages)
          if (collectionName == 'chats') {
            debugPrint('Deleting chats with subcollections (messages)');
            int chatsDeleted = 0;
            int chatsFailed = 0;
            for (var chatDoc in snapshot.docs) {
              try {
                debugPrint('Processing chat ${chatDoc.id}...');
                
                // מחיקת כל ההודעות בכל צ'אט (subcollection)
                try {
                  final messagesSnapshot = await chatDoc.reference
                      .collection('messages')
                      .get();
                  
                  if (messagesSnapshot.docs.isNotEmpty) {
                    debugPrint('Found ${messagesSnapshot.docs.length} messages in chat ${chatDoc.id}');
                    // מחיקת הודעות בקבוצות של 500
                    const batchSize = 500;
                    int messagesDeleted = 0;
                    for (int i = 0; i < messagesSnapshot.docs.length; i += batchSize) {
                      final messagesBatch = FirebaseFirestore.instance.batch();
                      final end = (i + batchSize < messagesSnapshot.docs.length) 
                          ? i + batchSize 
                          : messagesSnapshot.docs.length;
                      
                      for (int j = i; j < end; j++) {
                        messagesBatch.delete(messagesSnapshot.docs[j].reference);
                      }
                      
                      await messagesBatch.commit();
                      messagesDeleted += (end - i);
                      debugPrint('Deleted $messagesDeleted/${messagesSnapshot.docs.length} messages from chat ${chatDoc.id}');
                    }
                    debugPrint('Successfully deleted all ${messagesSnapshot.docs.length} messages from chat ${chatDoc.id}');
                  } else {
                    debugPrint('No messages found in chat ${chatDoc.id}');
                  }
                } catch (e) {
                  debugPrint('Error deleting messages from chat ${chatDoc.id}: $e');
                  // נמשיך למחוק את הצ'אט גם אם יש שגיאה במחיקת ההודעות
                }
                
                // מחיקת הצ'אט עצמו
                await chatDoc.reference.delete();
                chatsDeleted++;
                totalDeleted++;
                debugPrint('✅ Successfully deleted chat ${chatDoc.id}');
              } catch (e) {
                chatsFailed++;
                debugPrint('❌ Error deleting chat ${chatDoc.id} with subcollections: $e');
                errors.add('chats/${chatDoc.id}: $e');
                // נמשיך למחוק את שאר הצ'אטים גם אם יש שגיאה
              }
            }
            debugPrint('✅ Successfully deleted $chatsDeleted out of ${snapshot.docs.length} chats (failed: $chatsFailed)');
          } else {
            // מחיקה רגילה בקבוצות של 500 (מגבלת Firestore batch)
            const batchSize = 500;
            for (int i = 0; i < snapshot.docs.length; i += batchSize) {
              final deleteBatch = FirebaseFirestore.instance.batch();
              final end = (i + batchSize < snapshot.docs.length) 
                  ? i + batchSize 
                  : snapshot.docs.length;
              
              for (int j = i; j < end; j++) {
                deleteBatch.delete(snapshot.docs[j].reference);
              }
              
              await deleteBatch.commit();
              totalDeleted += (end - i);
            }

            debugPrint('Successfully deleted collection: $collectionName (${snapshot.docs.length} documents)');
          }
        } catch (e) {
          debugPrint('Error deleting collection $collectionName: $e');
          errors.add('$collectionName: $e');
        }
      }

      // מחיקת כל המשתמשים חוץ ממנהלים מ-users collection
      try {
        debugPrint('Cleaning users collection - keeping only admins');
        
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .get();

        int usersDeleted = 0;
        final usersBatch = FirebaseFirestore.instance.batch();

        for (var userDoc in usersSnapshot.docs) {
          final userData = userDoc.data();
          final userEmail = userData['email'] as String?;
          final isAdmin = userData['isAdmin'] ?? false;
          
          // שמירה על מנהלים בלבד (לפי אימייל או שדה isAdmin)
          if (userEmail == 'haitham.ay82@gmail.com' || userEmail == 'admin@gmail.com' || isAdmin == true) {
            continue;
          }
          
          // משתמשים אורחים זמניים יימחקו גם כן (אין צורך לסנן אותם)

          usersBatch.delete(userDoc.reference);
          usersDeleted++;
        }

        if (usersDeleted > 0) {
          await usersBatch.commit();
          debugPrint('Successfully deleted $usersDeleted non-admin users from users collection');
        }
      } catch (e) {
        debugPrint('Error cleaning users collection: $e');
        errors.add('users: $e');
      }

      // מחיקת כל המשתמשים מ-Firebase Authentication דרך Cloud Function
      int authDeletedCount = 0;
      try {
        debugPrint('Deleting all users from Authentication (except admins)');
        final currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser == null) {
          debugPrint('No current user - cannot call Cloud Function');
          errors.add('Authentication: No user logged in');
        } else {
          debugPrint('Current user: ${currentUser.email}');
          final functions = FirebaseFunctions.instance;
          final deleteAllUsersFunction = functions.httpsCallable('deleteAllUsersFromAuth');
          
          // הוספת timeout ארוך יותר למחיקה של הרבה משתמשים
          final result = await deleteAllUsersFunction.call().timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              throw TimeoutException('Cloud Function call timed out after 5 minutes');
            },
          );
          
          authDeletedCount = result.data['deletedCount'] as int? ?? 0;
          debugPrint('Successfully deleted $authDeletedCount users from Authentication');
        }
      } catch (e) {
        debugPrint('Error deleting users from Authentication: $e');
        if (e.toString().contains('UNAUTHENTICATED')) {
          debugPrint('Authentication error - user may not be logged in or token expired');
          errors.add('Authentication: User not authenticated. Please log out and log back in.');
        } else {
          debugPrint('This might mean the Cloud Function is not deployed yet.');
          debugPrint('To deploy the Cloud Functions, run: firebase deploy --only functions');
          errors.add('Authentication: $e');
        }
      }

      // מחיקת כל התמונות מ-Firebase Storage
      try {
        debugPrint('Deleting all images from Storage');
        final storage = FirebaseStorage.instance;
        
        // מחיקת תמונות משתמשים
        try {
          final userImagesRef = storage.ref().child('user_images');
          final userImagesList = await userImagesRef.listAll();
          
          // מחיקת כל הקבצים
          for (var file in userImagesList.items) {
            await file.delete();
          }
          
          // מחיקת כל התיקיות (prefixes)
          for (var prefix in userImagesList.prefixes) {
            final prefixList = await prefix.listAll();
            for (var file in prefixList.items) {
              await file.delete();
            }
            // נסיון למחוק את התיקייה עצמה (אם אפשר)
            try {
              await prefix.listAll();
            } catch (e) {
              // לא ניתן למחוק תיקיות ב-Storage, זה בסדר
            }
          }
          
          debugPrint('Successfully deleted user images from Storage');
        } catch (e) {
          debugPrint('Error deleting user images from Storage: $e');
        }

        // מחיקת תמונות בקשות
        try {
          final requestImagesRef = storage.ref().child('request_images');
          final requestImagesList = await requestImagesRef.listAll();
          
          // מחיקת כל הקבצים
          for (var file in requestImagesList.items) {
            await file.delete();
          }
          
          // מחיקת כל התיקיות (prefixes)
          for (var prefix in requestImagesList.prefixes) {
            final prefixList = await prefix.listAll();
            for (var file in prefixList.items) {
              await file.delete();
            }
            // נסיון למחוק את התיקייה עצמה (אם אפשר)
            try {
              await prefix.listAll();
            } catch (e) {
              // לא ניתן למחוק תיקיות ב-Storage, זה בסדר
            }
          }
          
          debugPrint('Successfully deleted request images from Storage');
        } catch (e) {
          debugPrint('Error deleting request images from Storage: $e');
        }
      } catch (e) {
        debugPrint('Error deleting images from Storage: $e');
        errors.add('Storage: $e');
      }

      // סגירת דיאלוג הטעינה
      if (!context.mounted) return;
      if (mounted) {
        Navigator.of(context).pop();
      }

      // הצגת הודעת הצלחה
      if (!context.mounted) return;
      if (mounted) {
        final errorMessage = errors.isNotEmpty 
            ? '\n\nשגיאות:\n${errors.join('\n')}'
            : '';
        
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.documentsDeletedSuccessfully(totalDeleted, errorMessage),
            ),
            backgroundColor: errors.isNotEmpty ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting all collections: $e');
      
      // סגירת דיאלוג הטעינה
      if (!context.mounted) return;
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!context.mounted) return;
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingCollections(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  
  // פונקציה לקבלת שם התצוגה של סוג המנוי
  String _getSubscriptionTypeDisplayName(UserProfile userProfile) {
    // בדיקה אם זה מנהל (עסקי מנוי)
    if (_isAdmin == true) {
      return 'מנהל (עסקי מנוי)';
    }
    
    // Debug: Print user profile data
    debugPrint('🔍 _getSubscriptionTypeDisplayName:');
    debugPrint('   - isSubscriptionActive: ${userProfile.isSubscriptionActive}');
    debugPrint('   - businessCategories: ${userProfile.businessCategories}');
    debugPrint('   - userType: ${userProfile.userType}');
    
    // בדיקה לפי סוג המשתמש
    switch (userProfile.userType) {
      case UserType.guest:
        // אורח ללא הגבלת זמן - תמיד הצג רק "אורח"
          return 'אורח';
      case UserType.personal:
    if (userProfile.isSubscriptionActive) {
          return 'פרטי (מנוי)';
        } else {
          return 'פרטי (חינם)';
        }
      case UserType.business:
        if (userProfile.isSubscriptionActive) {
        return 'עסקי (מנוי)';
      } else {
          return 'עסקי (חינם)';
        }
      case UserType.admin:
        return 'מנהל';
    }
  }

  // פונקציה לקבלת צבע התצוגה של סוג המנוי
  Color _getSubscriptionTypeColor(UserProfile userProfile) {
    // בדיקה אם זה מנהל
    if (_isAdmin == true) {
      return Theme.of(context).colorScheme.tertiary;
    }
    
    // בדיקה לפי סוג המשתמש
    switch (userProfile.userType) {
      case UserType.guest:
        return Theme.of(context).colorScheme.tertiary; // צהוב לאורח (ללא הגבלת זמן)
      case UserType.personal:
        if (userProfile.isSubscriptionActive) {
          return Theme.of(context).colorScheme.primary; // כחול לפרטי מנוי
        } else {
          return Theme.of(context).colorScheme.onSurfaceVariant; // אפור לפרטי חינם
        }
      case UserType.business:
        if (userProfile.isSubscriptionActive) {
          return Theme.of(context).colorScheme.primary; // ירוק לעסקי מנוי
        } else {
          return Theme.of(context).colorScheme.tertiary; // כתום לעסקי חינם
        }
      case UserType.admin:
        return Theme.of(context).colorScheme.tertiary; // סגול למנהל
    }
  }
  
  // דיאלוג פירוט מנוי חינם
  void _showFreeSubscriptionDetailsDialog(UserProfile userProfile) {
    // בדיקה אם יש בקשה ממתינה לאישור
    if (userProfile.subscriptionStatus == 'pending_approval') {
      String requestedType = 'מנוי';
      if (userProfile.requestedSubscriptionType == 'personal') {
        requestedType = 'פרטי מנוי';
      } else if (userProfile.requestedSubscriptionType == 'business') {
        requestedType = 'עסקי מנוי';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('בקשה בתהליך אישור ⏳'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'יש לך בקשה ל$requestedType והיא בטיפול.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'לא ניתן לשלוח בקשה נוספת עד שהמנהל יאשר או ידחה את הבקשה הנוכחית.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('הבנתי'),
            ),
          ],
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.yourFreeSubscription),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.yourFreeSubscriptionIncludes,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי המנוי
            _buildSubscriptionDetailItem(
              icon: Icons.assignment,
              title: l10n.requestsPerMonth(1),
              description: l10n.publishOneRequestPerMonth,
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.location_on,
              title: '${l10n.range}: 0-3 ק"מ',
              description: l10n.exposureUpToKm(3),
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.visibility,
              title: l10n.seesOnlyFreeRequests,
              description: l10n.accessToFreeRequestsOnly,
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.payment,
              title: l10n.noPayment,
              description: l10n.freeSubscriptionAvailable,
            ),
            const SizedBox(height: 16),
            
            // הודעת הגבלה
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Theme.of(context).colorScheme.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'המנוי החינם מוגבל - שקול לשדרג לקבלת יותר אפשרויות',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // כפתורי שדרוג
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSubscriptionTypeDialog(userProfile);
                    },
                    icon: const Icon(Icons.upgrade),
                    label: const Text('פרסם עסק'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSubscriptionTypeDialog(userProfile);
                    },
                    icon: const Icon(Icons.work),
                    label: const Text('עסקי'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }

  // דיאלוג פירוט מנוי עסקי
  void _showGuestSubscriptionDetailsDialog(UserProfile userProfile) {
    // אם זה אורח זמני - הצג הודעה שונה
    if (userProfile.isTemporaryGuest == true) {
      final l10n = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('שלום אורח'),
          content: const Text(
            'על מנת שתוכל לפרסם בקשות שירות/ לפרסם עסק, עליך להירשם.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('סגור'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // סגירת הדיאלוג הנוכחי
                await _performLogoutForRegistration();
              },
              child: Text(l10n.register),
            ),
          ],
        ),
      );
      return;
    }
    
    final l10n = AppLocalizations.of(context);
    final businessAreas = userProfile.businessCategories?.map((c) => c.categoryDisplayName).join(', ') ?? l10n.noBusinessAreasSelected;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מצב אורח'),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'אתה משתמש אורח ללא הגבלת זמן',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי המנוי
            _buildSubscriptionDetailItem(
              icon: Icons.assignment,
              title: l10n.requestsPerMonth(10),
              description: l10n.publishUpToRequestsPerMonth(10),
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.location_on,
              title: l10n.rangeWithBonuses('0-3'),
              description: l10n.exposureUpToKm(3),
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.visibility,
              title: l10n.seesFreeAndPaidRequests,
              description: l10n.accessToAllRequestTypes,
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.work,
              title: l10n.selectedBusinessAreas,
              description: l10n.yourBusinessAreas(businessAreas),
            ),
            const SizedBox(height: 16),
            
            // סטטוס המנוי
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.tertiary),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'אורח פעיל ללא הגבלת זמן',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
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
            child: Text(l10n.close),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // סגירת הדיאלוג הנוכחי
              _showSubscriptionTypeDialog(userProfile); // פתיחת דיאלוג בחירת סוג מנוי
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('פרסם עסק'),
          ),
        ],
      ),
    );
  }

  // דיאלוג פירוט מנוי פרטי
  void _showPersonalSubscriptionDetailsDialog(UserProfile userProfile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('כמשתמש פרטי אתה יכול'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• לפרסם בקשות שירות (חינם/בתשלום)',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'מכל התחומים בשכונה שלך ובכל מקום בארץ.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                '• לחפש עסקים בשכונה ובכל מקום בארץ.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                '• ליצור הזמנות (אפשרות למשלוח / אפשרות לתור).',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('הבנתי'),
          ),
        ],
      ),
    );
  }

  void _showBusinessSubscriptionDetailsDialog(UserProfile userProfile) {
    final l10n = AppLocalizations.of(context);
    final expiryDate = userProfile.subscriptionExpiry != null 
        ? '${userProfile.subscriptionExpiry!.day}/${userProfile.subscriptionExpiry!.month}/${userProfile.subscriptionExpiry!.year}'
        : l10n.unknown;
    final businessAreas = userProfile.businessCategories?.map((c) => c.categoryDisplayName).join(', ') ?? l10n.noBusinessAreasSelected;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרסום עסק'),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'הפרסום כולל:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי המנוי
            _buildSubscriptionDetailItem(
              icon: Icons.work,
              title: 'בחירת תחומי עיסוק',
              description: l10n.yourBusinessAreas(businessAreas),
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.attach_money,
              title: 'הגדרת מחירים',
              description: 'הגדרת מחירים לשירותים שלך',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.location_on,
              title: 'הגדרת מיקום',
              description: 'הגדרת מיקום העסק שלך',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.visibility,
              title: 'הגדרת טווח חשיפה',
              description: 'הגדרת טווח החשיפה של העסק',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.trending_up,
              title: 'קידום',
              description: 'קידום העסק שלך בפלטפורמה',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.build,
              title: 'שירותים נלווים',
              description: 'ניהול שירותים נלווים',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.business,
              title: 'ניהול עסק',
              description: 'כלי ניהול מתקדמים לעסק',
            ),
            const SizedBox(height: 16),
            
            _buildSubscriptionDetailItem(
              icon: Icons.payment,
              title: 'עלות הפרסום: 90 ש"ח/שנה',
              description: 'תשלום חד-פעמי לשנה מלאה',
            ),
            const SizedBox(height: 16),
            
            // סטטוס המנוי
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[800]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700]!
                    : Colors.grey[400]!,
              ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.yourSubscriptionActiveUntil(expiryDate),
                      style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  // widget לפרטי מנוי
  Widget _buildSubscriptionDetailItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // דיאלוג לבחירת סוג מנוי
  void _showSubscriptionTypeDialog(UserProfile userProfile) {
    // בדיקה אם יש בקשה ממתינה לאישור
    if (userProfile.subscriptionStatus == 'pending_approval') {
      String requestedType = 'מנוי';
      if (userProfile.requestedSubscriptionType == 'personal') {
        requestedType = 'פרטי מנוי';
      } else if (userProfile.requestedSubscriptionType == 'business') {
        requestedType = 'עסקי מנוי';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('בקשה בתהליך אישור ⏳'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'יש לך בקשה ל$requestedType והיא בטיפול.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'לא ניתן לשלוח בקשה נוספת עד שהמנהל יאשר או ידחה את הבקשה הנוכחית.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('הבנתי'),
            ),
          ],
        ),
      );
      return;
    }

    // אם זה מנהל - הצג הודעה שהוא לא יכול לשנות
    if (_isAdmin == true) {
      final l10n = AppLocalizations.of(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.systemAdministrator),
          content: Text(l10n.adminFullAccessMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.understood),
            ),
          ],
        ),
      );
      return;
    }

    // בדיקה אם המשתמש הוא אורח זמני
    final isTemporaryGuest = userProfile.isTemporaryGuest == true;
    // בדיקה אם המשתמש הוא פרטי מנוי (יש מנוי פעיל אבל אין תחומי עיסוק)
    final isPrivateUser = userProfile.isSubscriptionActive && 
        (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרסם את העסק שלך'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // עסקי מנוי בלבד
              _buildSubscriptionOption(
              title: 'הפרסום כולל:',
              description: '• בחירת תחומי עיסוק\n• הגדרת מחירים\n• הגדרת מיקום\n• הגדרת טווח חשיפה\n• קידום\n• שירותים נלווים\n• ניהול עסק\n\n• עלות הפרסום: 90 ש"ח/שנה',
              isSelected: userProfile.isSubscriptionActive && (userProfile.businessCategories != null && userProfile.businessCategories!.isNotEmpty),
              onTap: () {
                debugPrint('🔍 User selected BUSINESS subscription');
                // אם זה אורח זמני - לא להציג דיאלוג בחירת תחומי עיסוק
                if (isTemporaryGuest) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context);
                _showBusinessCategoriesSelectionDialog(userProfile);
              },
            ),
            ],
          ),
        ),
        actions: [
          // אם זה אורח זמני - הוסף לחצן "לפרסום העסק עליך להירשם" משמאל ל"ביטול"
          if (isTemporaryGuest)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteTemporaryGuestAndNavigateToAuth();
              },
              child: const Text('לפרסום העסק עליך להירשם'),
            ),
          // אם זה משתמש פרטי - הוסף לחצן "פרסם עכשיו"
          if (isPrivateUser)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BusinessManagementScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('פרסם עכשיו'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }
  
  // widget לבחירת סוג מנוי
  Widget _buildSubscriptionOption({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // עדכון סוג המנוי
  Future<void> _updateSubscriptionType(UserType newType, bool isActive, {UserProfile? userProfile}) async {
    try {
      debugPrint('🔍 _updateSubscriptionType called with:');
      debugPrint('   - newType: $newType');
      debugPrint('   - isActive: $isActive');
      debugPrint('   - userProfile: ${userProfile?.email}');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // מנהל לא יכול לשנות את סוג המנוי
      if (_isAdmin == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('מנהל מערכת לא יכול לשנות את סוג המנוי'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // בדיקה אם יש בקשה ממתינה לאישור
      if (userProfile != null && userProfile.subscriptionStatus == 'pending_approval') {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.pendingRequestExists),
              backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
      // בדיקת הגבלות מעבר - רק שדרוג מותר
      if (userProfile != null) {
        int currentLevel = _getSubscriptionLevel(userProfile);
        int newLevel = _getTargetSubscriptionLevel(newType, isActive);
        
        // בדיקה אם זה ניסיון לרדת ברמה או להישאר באותה רמה
        if (newLevel <= currentLevel) {
          String currentLevelName = _getSubscriptionLevelName(currentLevel);
          String newLevelName = _getSubscriptionLevelName(newLevel);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('לא ניתן לשדרג מ$currentLevelName ל$newLevelName'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      // אם עוברים למנוי - צריך לשלם (גם פרטי וגם עסקי)
      if (isActive) {
        // סגירת דיאלוג "בחירת סוג מנוי" אם הוא פתוח
        if (mounted) {
          Navigator.pop(context); // סגירת דיאלוג "בחירת סוג מנוי"
        }
        // פתיחת דיאלוג התשלום
        if (mounted) {
          await _showPaymentDialog(newType);
        }
        return;
      }
      
      // עדכון רגיל - רק מנוי פעיל/לא פעיל
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isSubscriptionActive': isActive,
        'subscriptionStatus': isActive ? 'active' : 'private_free',
        // אם לא עסקי - מחק תחומי עיסוק
        if (newType != UserType.business) 'businessCategories': FieldValue.delete(),
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('סוג המנוי עודכן ל-${_getSubscriptionTypeDisplayName(UserProfile(
              userId: user.uid,
              displayName: '',
              email: '',
              userType: newType,
              createdAt: DateTime.now(),
              isSubscriptionActive: isActive,
            ))}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating subscription type: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון סוג המנוי: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // דיאלוג לבחירת תחומי עיסוק לעסקי מנוי
  // דיאלוג לבחירת תחומי עיסוק עבור עסקי מנוי חדש
  Future<void> _showBusinessCategoriesSelectionDialog(UserProfile userProfile) async {
    // מנהל לא יכול לשנות את תחומי העיסוק (אלא אם כן זה לצורך בדיקה)
    if (_isAdmin == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('מנהל מערכת - בחירת תחומי עיסוק לצורך בדיקה'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      // נמשיך עם הדיאלוג גם למנהל לצורך בדיקה
    }

    List<RequestCategory> selectedCategories = [];
    
    await showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(_isAdmin == true ? '${l10n.selectBusinessCategories} - עסקי מנוי (מנהל)' : '${l10n.selectBusinessCategories} - עסקי מנוי'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.65,
              child: TwoLevelCategorySelector(
                selectedCategories: selectedCategories,
                maxSelections: 999,
                title: '${l10n.selectBusinessCategories} - עסקי מנוי',
                instruction: 'בחר תחומי עיסוק כדי להמשיך לעסקי מנוי:',
                onSelectionChanged: (categories) {
                  debugPrint('🔍 DEBUG: TwoLevelCategorySelector (admin) onSelectionChanged called');
                  debugPrint('🔍 DEBUG: categories.length = ${categories.length}');
                  setState(() {
                    selectedCategories = categories;
                  });
                },
              ),
            ),
          actions: [
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                );
              },
            ),
            ElevatedButton(
              onPressed: selectedCategories.isNotEmpty 
                  ? () async {
                      if (mounted) {
                        Navigator.pop(context);
                      }
                      await _updateSubscriptionTypeWithCategories(UserType.business, true, selectedCategories, userProfile);
                    }
                  : null,
              child: Text(_isAdmin == true ? 'המשך (${selectedCategories.length} תחומים)' : 'המשך לתשלום (${selectedCategories.length} תחומים)'),
            ),
          ],
        ),
        );
      },
    );
  }

  Future<void> _showBusinessCategoriesDialog() async {
    // מנהל לא יכול לשנות את תחומי העיסוק
    if (_isAdmin == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('מנהל מערכת לא יכול לשנות את תחומי העיסוק'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // בדיקה אם המשתמש הוא אורח זמני
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
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
    }
    
    // התחל עם הקטגוריות הקיימות של המשתמש
    List<RequestCategory> selectedCategories = List.from(_selectedBusinessCategories);
    bool noPaidServices = _noPaidServices;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Text(l10n.selectBusinessCategories);
            },
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.65,
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return TwoLevelCategorySelector(
                  selectedCategories: selectedCategories,
                  maxSelections: 999,
                  title: l10n.selectBusinessCategories,
                  instruction: 'בחר תחומי עיסוק:',
                  onSelectionChanged: (categories) {
                    debugPrint('🔍 DEBUG: TwoLevelCategorySelector (business) onSelectionChanged called');
                    debugPrint('🔍 DEBUG: categories.length = ${categories.length}');
                    debugPrint('🔍 DEBUG: categories = ${categories.map((c) => c.name).toList()}');
                    debugPrint('🔍 DEBUG: noPaidServices before = $noPaidServices');
                    debugPrint('🔍 DEBUG: About to call setState...');
                    
                    setState(() {
                      selectedCategories = categories;
                      if (categories.isNotEmpty) {
                        noPaidServices = false; // בטל בחירת "לא נותן שירותים"
                        debugPrint('🔍 DEBUG: Categories not empty - setting noPaidServices = false');
                      } else {
                        // אם נוקו כל התחומים, הגדר כ"לא נותן שירותים"
                        noPaidServices = true;
                        debugPrint('🔍 DEBUG: Categories empty - setting noPaidServices = true');
                      }
                    });
                    
                    debugPrint('🔍 DEBUG: noPaidServices after = $noPaidServices');
                    debugPrint('🔍 DEBUG: selectedCategories.length after = ${selectedCategories.length}');
                  },
                );
              },
            ),
          ),
          actions: [
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                );
              },
            ),
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return ElevatedButton(
                  onPressed: () async {
                    // אם אין תחומי עיסוק נבחרים, הגדר כ"לא נותן שירותים"
                    if (selectedCategories.isEmpty) {
                      await _updateNoPaidServicesStatus(true);
                      // עדכון הפרופיל המקומי
                      setState(() {
                        _noPaidServices = true;
                        _selectedBusinessCategories = [];
                      });
                    } else {
                      await _updateToBusinessWithCategories(selectedCategories);
                    }
                    // Guard context usage after async gap
                    if (!context.mounted) return;
                      Navigator.pop(context);
                  },
                  child: Text('${l10n.save} (${selectedCategories.length} תחומים)'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // עדכון סטטוס לא נותן שירותים בתשלום
  Future<void> _updateNoPaidServicesStatus(bool noPaidServices) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'noPaidServices': noPaidServices,
        'businessCategories': noPaidServices ? [] : null, // נקה תחומי עיסוק אם בחר לא נותן שירותים
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(noPaidServices 
                ? 'הגדרת שלא אתה נותן שירותים בתשלום'
                : 'הגדרת שאתה נותן שירותים בתשלום - תוכל לראות בקשות בתשלום'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating no paid services status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון ההגדרה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // טעינת הגדרות תורים
  Future<void> _loadAppointmentSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _useAppointments = data?['useAppointments'] ?? false;
        });
      } else if (mounted) {
        // אם אין הגדרה, ברירת מחדל = זמינות (false)
        setState(() {
          _useAppointments = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading appointment settings: $e');
      if (mounted) {
        setState(() {
          _useAppointments = false; // ברירת מחדל
        });
      }
    }
  }

  // טעינת הגדרות שירותים (משלוח ותור)
  Future<void> _loadServiceSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data()!;
        setState(() {
          _requiresAppointment = userData['requiresAppointment'] as bool? ?? false;
          _requiresDelivery = userData['requiresDelivery'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading service settings: $e');
    }
  }

  // עדכון הגדרות שירותים (משלוח ותור)
  Future<void> _updateServiceSettings({bool? requiresAppointment, bool? requiresDelivery}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // מניעת עדכונים כפולים
    if (_isUpdatingSettings) return;
    _isUpdatingSettings = true;

    // חישוב הערכים החדשים
    bool newRequiresAppointment = requiresAppointment ?? _requiresAppointment;
    bool newRequiresDelivery = requiresDelivery ?? _requiresDelivery;
    
    // אם מנסים להפעיל אחד כשהשני כבר פעיל, יש לבטל את השני אוטומטית
    bool willCancelOther = false;
    bool? finalRequiresAppointment = requiresAppointment;
    bool? finalRequiresDelivery = requiresDelivery;
    
    if (requiresAppointment == true && _requiresDelivery) {
      finalRequiresDelivery = false;
      newRequiresDelivery = false;
      willCancelOther = true;
    }
    if (requiresDelivery == true && _requiresAppointment) {
      finalRequiresAppointment = false;
      newRequiresAppointment = false;
      willCancelOther = true;
    }

    // בדיקה סופית - לא ניתן ששניהם יהיו פעילים
    if (newRequiresAppointment && newRequiresDelivery) {
      _isUpdatingSettings = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא ניתן לבחור גם שירותים דורשים קביעת תור וגם שירות במשלוח. יש לבחור אחד מהם בלבד.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // הצגת דיאלוג אישור לפני כל שינוי
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('אישור שינוי הגדרות'),
            ),
          ],
        ),
        content: Text(
          _getConfirmationMessage(finalRequiresAppointment, finalRequiresDelivery, willCancelOther),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('אישור'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      // אם המשתמש ביטל, החזרת הערכים הקודמים
      _isUpdatingSettings = false;
      if (mounted) {
        setState(() {
          // לא משנים כלום - הערכים נשארים כמו שהיו
        });
      }
      return;
    }

    try {
      // אם מסירים את הסימון של "שירותים דורשים קביעת תור" והמשתמש כבר בחר תורים, החזר לזמינות
      bool shouldResetToAvailability = false;
      if (finalRequiresAppointment == false && _useAppointments == true) {
        shouldResetToAvailability = true;
        await _saveAppointmentPreference(false);
      }

      // עדכון הערכים המקומיים
      if (mounted) {
        setState(() {
          if (finalRequiresAppointment != null) {
            _requiresAppointment = finalRequiresAppointment;
          }
          if (finalRequiresDelivery != null) {
            _requiresDelivery = finalRequiresDelivery;
          }
        });
      }

      // עדכון ב-Firestore
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (finalRequiresAppointment != null) {
        updateData['requiresAppointment'] = finalRequiresAppointment;
      }
      if (finalRequiresDelivery != null) {
        updateData['requiresDelivery'] = finalRequiresDelivery;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(shouldResetToAvailability
                ? 'ההגדרות עודכנו בהצלחה. הגדרת התורים הוחזרה לזמינות'
                : 'ההגדרות עודכנו בהצלחה'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating service settings: $e');
      if (mounted) {
        // החזרת הערכים הקודמים במקרה של שגיאה
        if (mounted) {
          setState(() {
            // לא משנים כלום - הערכים נשארים כמו שהיו לפני הניסיון
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון ההגדרות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isUpdatingSettings = false;
    }
  }

  // יצירת הודעת אישור לשינוי הגדרות
  String _getConfirmationMessage(bool? requiresAppointment, bool? requiresDelivery, bool willCancelOther) {
    List<String> changes = [];
    
    if (requiresAppointment != null) {
      if (requiresAppointment) {
        changes.add('הפעלת שירותים דורשים קביעת תור');
        if (_requiresDelivery) {
          changes.add('ביטול שירות במשלוח (אוטומטי)');
        }
      } else {
        changes.add('ביטול שירותים דורשים קביעת תור');
      }
    }
    
    if (requiresDelivery != null) {
      if (requiresDelivery) {
        changes.add('הפעלת שירות במשלוח');
        if (_requiresAppointment) {
          changes.add('ביטול שירותים דורשים קביעת תור (אוטומטי)');
        }
      } else {
        changes.add('ביטול שירות במשלוח');
      }
    }
    
    if (changes.isEmpty) {
      return 'האם אתה בטוח שברצונך לשנות את ההגדרות?';
    }
    
    String message = 'האם אתה בטוח שברצונך לבצע את השינויים הבאים?\n\n${changes.join('\n')}';
    
    if (willCancelOther) {
      message += '\n\nשימו לב: לא ניתן לבחור גם שירותים דורשים קביעת תור וגם שירות במשלוח יחד.';
    }
    
    return message;
  }

  // שמירת העדפת תורים/זמינות
  Future<void> _saveAppointmentPreference(bool useAppointments) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _useAppointments = useAppointments;
    });

    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(user.uid)
          .set({
        'useAppointments': useAppointments,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving appointment preference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת ההגדרה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // דיאלוג לעריכת זמינות
  Future<void> _showAvailabilityDialog(UserProfile userProfile) async {
    // בדיקה אם המשתמש הוא אורח זמני
    if (userProfile.isTemporaryGuest == true) {
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
    
    final l10n = AppLocalizations.of(context);
    bool availableAllWeek = userProfile.availableAllWeek ?? false;
    WeekAvailability weekAvailability = userProfile.weekAvailability ?? 
        WeekAvailability(days: DayOfWeek.values
            .map((day) => DayAvailability(day: day, isAvailable: false))
            .toList());

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editAvailability),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // צ'קבוקס "זמין כל השבוע"
                  CheckboxListTile(
                    value: availableAllWeek,
                    onChanged: (value) {
                      setState(() {
                        availableAllWeek = value ?? false;
                        if (availableAllWeek) {
                          // אם בוחרים "זמין כל השבוע", מנקים את הזמינות הספציפית
                          weekAvailability = WeekAvailability(
                            days: DayOfWeek.values
                                .map((day) => DayAvailability(day: day, isAvailable: false))
                                .toList(),
                          );
                        }
                      });
                    },
                    title: Text(
                      l10n.availableAllWeek,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectDaysAndHours,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // רשימת ימים
                  ...weekAvailability.days.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dayAvailability = entry.value;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Checkbox(
                              value: weekAvailability.days[index].isAvailable && !availableAllWeek,
                              onChanged: (value) {
                                setState(() {
                                  // אם "זמין כל השבוע" מסומן ומנסים לסמן יום - בטל את "זמין כל השבוע"
                                  if (availableAllWeek && value == true) {
                                    availableAllWeek = false;
                                  }
                                  
                                  weekAvailability.days[index] = weekAvailability.days[index].copyWith(
                                    isAvailable: value ?? false,
                                    startTime: value == false ? null : weekAvailability.days[index].startTime,
                                    endTime: value == false ? null : weekAvailability.days[index].endTime,
                                  );
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.getDayName(dayAvailability.day)),
                          ],
                        ),
                        children: [
                          if (dayAvailability.isAvailable && !availableAllWeek) ...[
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(l10n.startTime),
                                    trailing: TextButton(
                                      onPressed: () async {
                                        final TimeOfDay? picked = await showTimePicker(
                                          context: context,
                                          initialTime: weekAvailability.days[index].startTime != null
                                              ? TimeOfDay(
                                                  hour: int.parse(weekAvailability.days[index].startTime!.split(':')[0]),
                                                  minute: int.parse(weekAvailability.days[index].startTime!.split(':')[1]),
                                                )
                                              : const TimeOfDay(hour: 9, minute: 0),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                            weekAvailability.days[index] = weekAvailability.days[index].copyWith(
                                              startTime: timeStr,
                                            );
                                          });
                                        }
                                      },
                                      child: Text(
                                        weekAvailability.days[index].startTime ?? l10n.selectTime,
                                        style: TextStyle(
                                          color: weekAvailability.days[index].startTime != null
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ListTile(
                                    title: Text(l10n.endTime),
                                    trailing: TextButton(
                                      onPressed: () async {
                                        final TimeOfDay? picked = await showTimePicker(
                                          context: context,
                                          initialTime: weekAvailability.days[index].endTime != null
                                              ? TimeOfDay(
                                                  hour: int.parse(weekAvailability.days[index].endTime!.split(':')[0]),
                                                  minute: int.parse(weekAvailability.days[index].endTime!.split(':')[1]),
                                                )
                                              : const TimeOfDay(hour: 17, minute: 0),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                            weekAvailability.days[index] = weekAvailability.days[index].copyWith(
                                              endTime: timeStr,
                                            );
                                          });
                                        }
                                      },
                                      child: Text(
                                        weekAvailability.days[index].endTime ?? l10n.selectTime,
                                        style: TextStyle(
                                          color: weekAvailability.days[index].endTime != null
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateAvailability(availableAllWeek, weekAvailability);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  // עדכון זמינות ב-Firestore
  Future<void> _updateAvailability(bool availableAllWeek, WeekAvailability weekAvailability) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final l10n = AppLocalizations.of(context);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'availableAllWeek': availableAllWeek,
        'weekAvailability': availableAllWeek ? null : weekAvailability.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.availabilityUpdated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating availability: $e');
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorUpdatingAvailability),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // דיאלוג לבחירת תחומי עיסוק למשתמש אורח
  Future<void> _showGuestCategoriesDialog(UserProfile userProfile) async {
    // בדיקה אם המשתמש הוא אורח זמני
    if (userProfile.isTemporaryGuest == true) {
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
    // התחל עם הקטגוריות הקיימות של המשתמש
    List<RequestCategory> selectedCategories = List.from(userProfile.businessCategories ?? []);
    bool noPaidServices = userProfile.noPaidServices ?? false;
    
    debugPrint('🔍 DEBUG: _showGuestCategoriesDialog started');
    debugPrint('🔍 DEBUG: Initial selectedCategories.length = ${selectedCategories.length}');
    debugPrint('🔍 DEBUG: Initial selectedCategories = ${selectedCategories.map((c) => c.name).toList()}');
    debugPrint('🔍 DEBUG: Initial noPaidServices = $noPaidServices');
    
    await showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l10n.setBusinessFields),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.7, // הגבל גובה
              child: SingleChildScrollView( // הוסף גלילה
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // אפשרות לא נותן שירותים בתשלום
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.grey[700]!
                                  : Colors.grey[400]!,
                            ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          value: noPaidServices,
                          onChanged: (value) {
                            debugPrint('🔍 DEBUG: Checkbox changed!');
                            debugPrint('🔍 DEBUG: value = $value');
                            debugPrint('🔍 DEBUG: noPaidServices before = $noPaidServices');
                            debugPrint('🔍 DEBUG: selectedCategories.length before = ${selectedCategories.length}');
                            
                            setState(() {
                              noPaidServices = value ?? false;
                              if (noPaidServices) {
                                selectedCategories.clear(); // נקה בחירת תחומים
                                debugPrint('🔍 DEBUG: Checkbox checked - clearing selectedCategories');
                              }
                            });
                            
                            debugPrint('🔍 DEBUG: noPaidServices after = $noPaidServices');
                            debugPrint('🔍 DEBUG: selectedCategories.length after = ${selectedCategories.length}');
                          },
                          title: Text(
                            l10n.iDoNotProvidePaidServices,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.ifYouSelectThisOption,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // בחירת תחומי עיסוק (רק אם לא בחר "לא נותן שירותים")
                  if (!noPaidServices) ...[
                    Text(
                      l10n.orSelectBusinessAreas,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TwoLevelCategorySelector(
                      selectedCategories: selectedCategories,
                      maxSelections: 999,
                      title: l10n.selectBusinessCategories,
                      instruction: l10n.selectBusinessAreasToReceiveRelevantRequests,
                    onSelectionChanged: (categories) {
                      debugPrint('🔍 DEBUG: onSelectionChanged called');
                      debugPrint('🔍 DEBUG: categories.length = ${categories.length}');
                      debugPrint('🔍 DEBUG: categories = ${categories.map((c) => c.name).toList()}');
                      debugPrint('🔍 DEBUG: noPaidServices before = $noPaidServices');
                      debugPrint('🔍 DEBUG: About to call setState...');
                      
                      setState(() {
                        selectedCategories = categories;
                        if (categories.isNotEmpty) {
                          noPaidServices = false; // בטל בחירת "לא נותן שירותים"
                          debugPrint('🔍 DEBUG: Categories not empty - setting noPaidServices = false');
                        } else {
                          // אם נוקו כל התחומים, הגדר כ"לא נותן שירותים"
                          noPaidServices = true;
                          debugPrint('🔍 DEBUG: Categories empty - setting noPaidServices = true');
                        }
                      });
                      
                      debugPrint('🔍 DEBUG: noPaidServices after = $noPaidServices');
                      debugPrint('🔍 DEBUG: selectedCategories.length after = ${selectedCategories.length}');
                    },
                  ),
                ],
              ],
            ),
          ),
            ),
          actions: [
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                );
              },
            ),
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return ElevatedButton(
                  onPressed: () async {
                    debugPrint('🔍 DEBUG: Save button pressed!');
                    debugPrint('🔍 DEBUG: selectedCategories.length = ${selectedCategories.length}');
                    debugPrint('🔍 DEBUG: selectedCategories = ${selectedCategories.map((c) => c.name).toList()}');
                    debugPrint('🔍 DEBUG: noPaidServices = $noPaidServices');
                    
                    // אם אין תחומי עיסוק נבחרים, הגדר כ"לא נותן שירותים"
                    final finalNoPaidServices = selectedCategories.isEmpty ? true : noPaidServices;
                    debugPrint('🔍 DEBUG: finalNoPaidServices = $finalNoPaidServices');
                    
                    await _updateGuestCategories(selectedCategories, finalNoPaidServices);
                    // Guard context usage after async gap
                    if (!context.mounted) return;
                      Navigator.pop(context);
                  },
                  child: Text(selectedCategories.isEmpty 
                      ? '${l10n.save} (לא נותן שירותים)' 
                      : '${l10n.save} (${selectedCategories.length} תחומים)'),
                );
              },
            ),
          ],
        ),
        );
      },
    );
  }

  // עדכון תחומי עיסוק למשתמש אורח
  Future<void> _updateGuestCategories(List<RequestCategory> categories, bool noPaidServices) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // עדכון תחומי העיסוק ב-Firestore
      debugPrint('🔄 Updating guest categories: ${categories.map((c) => c.name).toList()}');
      debugPrint('🔄 No paid services: $noPaidServices');
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'businessCategories': noPaidServices ? [] : categories.map((c) => c.categoryDisplayName).toList(),
        'noPaidServices': noPaidServices,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Guest categories updated successfully');
      
      if (mounted) {
        String message = noPaidServices 
            ? 'הגדרת שלא אתה נותן שירותים בתשלום'
            : 'תחומי העיסוק עודכנו בהצלחה! (${categories.length} תחומים)';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        
        // עדכון הפרופיל המקומי
        setState(() {
          _selectedBusinessCategories = categories;
          _noPaidServices = noPaidServices;
        });
      }
    } catch (e) {
      debugPrint('Error updating guest categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון תחומי העיסוק: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // עדכון סוג מנוי עם תחומי עיסוק
  Future<void> _updateSubscriptionTypeWithCategories(UserType newType, bool isActive, List<RequestCategory> categories, UserProfile userProfile) async {
    try {
      debugPrint('🔍 _updateSubscriptionTypeWithCategories called with:');
      debugPrint('   - newType: $newType');
      debugPrint('   - isActive: $isActive');
      debugPrint('   - categories: ${categories.map((c) => c.name).toList()}');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // מנהל לא יכול לשנות את סוג המנוי
      if (_isAdmin == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('מנהל מערכת לא יכול לשנות את סוג המנוי'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // בדיקה אם יש בקשה ממתינה לאישור
      if (userProfile.subscriptionStatus == 'pending_approval') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('יש לך בקשה ממתינה לאישור. לא ניתן לשלוח בקשה נוספת.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // בדיקת הגבלות מעבר - רק שדרוג מותר
      bool isCurrentBusiness = userProfile.isSubscriptionActive && 
          (userProfile.businessCategories != null && userProfile.businessCategories!.isNotEmpty);
      bool isCurrentPersonal = userProfile.isSubscriptionActive && 
          (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty);
      
      // בדיקה אם זה ניסיון לרדת ברמה
      if (isCurrentBusiness && newType == UserType.personal) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא ניתן לרדת מעסקי מנוי לפרטי מנוי'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      if (isCurrentPersonal && !isActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא ניתן לרדת מפרטי מנוי לפרטי חינם'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // אם זה מנוי פעיל - הצג דיאלוג תשלום (בלי לעדכן את הפרופיל לפני התשלום)
      if (isActive) {
        // שמירת הקטגוריות זמנית ב-SharedPreferences כדי להשתמש בהן אחרי התשלום
        if (newType == UserType.business && categories.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final categoriesJson = categories.map((c) => c.categoryDisplayName).toList();
          await prefs.setStringList('pending_business_categories_${user.uid}', categoriesJson);
          debugPrint('💾 Saved pending business categories: $categoriesJson');
        }
        
        // סגירת דיאלוג "בחירת סוג מנוי" אם הוא עדיין פתוח
        if (mounted) {
          Navigator.pop(context); // סגירת דיאלוג "בחירת סוג מנוי"
        }
        // המתנה קצרה כדי שהדיאלוג ייסגר
        await Future.delayed(const Duration(milliseconds: 100));
        // בדיקה אם ה-widget עדיין פעיל
        if (mounted) {
          await _showPaymentDialog(newType, categories);
        }
      } else {
        // אם זה לא מנוי פעיל - עדכן את הפרופיל ישירות
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'isSubscriptionActive': isActive,
          'subscriptionStatus': isActive ? 'active' : 'private_free',
          'businessCategories': newType == UserType.business ? categories.map((c) => c.categoryDisplayName).toList() : null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('עודכן ל${newType == UserType.business ? 'עסקי מנוי' : 'פרטי מנוי'} בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating subscription type with categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון סוג המנוי: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // עדכון לעסקי מנוי עם תחומי עיסוק
  Future<void> _updateToBusinessWithCategories(List<RequestCategory> categories) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isSubscriptionActive': true,
        'subscriptionStatus': 'active',
        'requestedSubscriptionType': 'business',
        'businessCategories': categories.map((c) => c.categoryDisplayName).toList(),
      });
      
      if (mounted) {
        // עדכון הפרופיל המקומי
        setState(() {
          _selectedBusinessCategories = categories;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('עודכן לעסקי מנוי עם תחומי עיסוק נבחרים'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating to business with categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון לעסקי מנוי: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // דיאלוג תשלום למנוי
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



  Future<void> _showPaymentDialog(UserType subscriptionType, [List<RequestCategory>? categories]) async {
    debugPrint('💰 _showPaymentDialog called with: $subscriptionType');
    
    // מנהל לא צריך להעלות הוכחת תשלום
    if (_isAdmin == true) {
      debugPrint('❌ Admin user, skipping payment dialog');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('מנהל מערכת לא צריך להעלות הוכחת תשלום'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final l10n = AppLocalizations.of(context);
    final price = subscriptionType == UserType.personal ? 30 : 70;
    final typeName = subscriptionType == UserType.personal ? l10n.privateSubscription : l10n.businessSubscription;
    
    debugPrint('💰 Opening payment dialog for $typeName subscription, price: $price');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('הפעלת מנוי $typeName'),
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
                children: [
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
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
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
    if (userPhone.isNotEmpty) {
      phoneController.text = userPhone;
    }
    String? phoneError;
    final bool hasPhone = userPhone.isNotEmpty;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.cashPaymentTitle),
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
                  enabled: !hasPhone, // אם יש טלפון - לא ניתן לעריכה
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
                        l10n.subscriptionTypeLabel(typeName),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        l10n.priceLabel(price),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
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
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final phoneValue = phoneController.text.trim();
                
                // ולידציה של טלפון
                if (phoneValue.isEmpty) {
                  setState(() {
                    phoneError = 'טלפון הוא שדה חובה';
                  });
                  return;
                }
                
                // ולידציה של טלפון ישראלי (רק אם אין טלפון שמור)
                if (!hasPhone) {
                  final validationError = _validateIsraeliPhoneNumber(phoneValue, context);
                  if (validationError != null) {
                    setState(() {
                      phoneError = validationError;
                    });
                    return;
                  }
                }
                
                // שליחת בקשת התשלום
                final success = await _submitCashPaymentRequest(
                  userId: user.uid,
                  userEmail: userEmail,
                  userName: userName,
                  phone: phoneValue,
                  subscriptionType: subscriptionTypeString,
                  amount: price.toDouble(),
                  businessCategories: categories != null ? categories.map((c) => c.categoryDisplayName).toList() : null,
                );
                
                if (!mounted) return;
                
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.paymentRequestSentSuccessfully),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.errorSendingPaymentRequest),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(l10n.sendPaymentRequestNew),
            ),
          ],
        ),
      ),
    );
  }

  /// שליחת בקשת תשלום במזומן
  Future<bool> _submitCashPaymentRequest({
    required String userId,
    required String userEmail,
    required String userName,
    required String phone,
    required String subscriptionType,
    required double amount,
    List<String>? businessCategories,
  }) async {
    try {
      return await ManualPaymentService.submitCashPaymentRequest(
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        phone: phone,
        subscriptionType: subscriptionType,
        amount: amount,
        businessCategories: businessCategories,
      );
    } catch (e) {
      debugPrint('Error submitting cash payment request: $e');
      return false;
    }
  }

  // ולידציה של שם תצוגה
  String? _validateDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'שם תצוגה הוא שדה חובה';
    }
    
    if (name.trim().length < 2) {
      return 'שם תצוגה חייב להכיל לפחות 2 תווים';
    }
    
    if (name.trim().length > 50) {
      return 'שם תצוגה לא יכול להכיל יותר מ-50 תווים';
    }
    
    return null; // שם תקין
  }

  // ולידציה של מספר טלפון ישראלי
  String? _validateIsraeliPhoneNumber(String? phone, BuildContext context) {
    if (phone == null || phone.trim().isEmpty) {
      return null; // מספר טלפון ריק הוא תקין (אופציונלי)
    }
    
    // הסרת כל התווים שאינם ספרות
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // בדיקת קידומות ישראליות תקפות עם אורך מתאים
    Map<String, int> validPrefixes = {
      '050': 10, '051': 10, '052': 10, '053': 10, '054': 10, '055': 10, '056': 10, '057': 10, '058': 10, '059': 10, // סלולר - 10 ספרות
      '02': 9, '03': 9, '04': 9, '08': 9, '09': 9, // קווי - 9 ספרות
      '077': 10, '072': 10, '073': 10, '074': 10, '076': 10, '079': 10, // קווי נוספים - 10 ספרות
    };
    
    bool isValidPrefix = false;
    int expectedLength = 0;
    
    for (String prefix in validPrefixes.keys) {
      if (cleanPhone.startsWith(prefix)) {
        isValidPrefix = true;
        expectedLength = validPrefixes[prefix]!;
        break;
      }
    }
    
    if (!isValidPrefix) {
      final l10n = AppLocalizations.of(context);
      return '${l10n.invalidPrefix}. ${l10n.validPrefixes}';
    }
    
    // בדיקת אורך לפי הקידומת
    if (cleanPhone.length != expectedLength) {
      if (expectedLength == 10) {
        return 'מספר טלפון עם קידומת ${cleanPhone.substring(0, 3)} חייב להכיל 10 ספרות כולל הקידומת';
      } else {
        return 'מספר טלפון עם קידומת ${cleanPhone.substring(0, 2)} חייב להכיל 9 ספרות כולל הקידומת';
      }
    }
    
    return null; // מספר תקין
  }

  // פונקציה לחלוקת מספר טלפון לקידומת ומספר
  Map<String, String>? _parsePhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return null;
    
    // ניקוי המספר
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // בדיקה אם המספר מתחיל ב-0
    if (cleanNumber.startsWith('0')) {
      // חלוקה לקידומת ומספר
      if (cleanNumber.length >= 9) {
        // קידומות של 3 ספרות (050-059, 072-079)
        if (cleanNumber.startsWith('050') || cleanNumber.startsWith('051') || 
            cleanNumber.startsWith('052') || cleanNumber.startsWith('053') || 
            cleanNumber.startsWith('054') || cleanNumber.startsWith('055') || 
            cleanNumber.startsWith('056') || cleanNumber.startsWith('057') || 
            cleanNumber.startsWith('058') || cleanNumber.startsWith('059') ||
            cleanNumber.startsWith('072') || cleanNumber.startsWith('073') || 
            cleanNumber.startsWith('074') || cleanNumber.startsWith('075') || 
            cleanNumber.startsWith('076') || cleanNumber.startsWith('077') || 
            cleanNumber.startsWith('078') || cleanNumber.startsWith('079')) {
          return {
            'prefix': cleanNumber.substring(0, 3),
            'number': cleanNumber.substring(3),
          };
        }
        // קידומות של 2 ספרות (02, 03, 04, 08, 09)
        else if (cleanNumber.startsWith('02') || cleanNumber.startsWith('03') || 
                 cleanNumber.startsWith('04') || cleanNumber.startsWith('08') || 
                 cleanNumber.startsWith('09')) {
          return {
            'prefix': cleanNumber.substring(0, 2),
            'number': cleanNumber.substring(2),
          };
        }
      }
    }
    
    return null;
  }

  // ולידציה של מספר טלפון (רק המספר ללא קידומת)
  String? _validatePhoneNumber(String number, String prefix) {
    if (number.isEmpty) {
      return 'אנא הזן מספר טלפון';
    }
    
    if (prefix.isEmpty) {
      return 'אנא בחר קידומת';
    }
    
    // בדיקת אורך המספר לפי הקידומת
    if (prefix.length == 3) {
      // קידומות של 3 ספרות (050-059, 072-079) - 7 ספרות
      if (number.length != 7) {
        return 'מספר טלפון עם קידומת $prefix חייב להכיל 7 ספרות';
      }
    } else if (prefix.length == 2) {
      // קידומות של 2 ספרות (02, 03, 04, 08, 09) - 7 ספרות
      if (number.length != 7) {
        return 'מספר טלפון עם קידומת $prefix חייב להכיל 7 ספרות';
      }
    }
    
    return null; // מספר תקין
  }

  // עריכת מספר הטלפון
  void _editPhoneNumber() {
    // חלוקת המספר הקיים לקידומת ומספר
    final currentPhone = _phoneController.text;
    String prefix = '';
    String number = '';
    
    if (currentPhone.isNotEmpty) {
      final phoneParts = _parsePhoneNumber(currentPhone);
      if (phoneParts != null) {
        prefix = phoneParts['prefix'] ?? '';
        number = phoneParts['number'] ?? '';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController editController = TextEditingController(text: number);
        String? tempError;
        _selectedEditPrefix = prefix;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.editPhoneNumber),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // שדה קידומת
              DropdownButtonFormField<String>(
                initialValue: _selectedEditPrefix.isNotEmpty ? _selectedEditPrefix : null,
                decoration: InputDecoration(
                  labelText: l10n.phonePrefix,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone, color: Colors.blue[600]),
                ),
                hint: Text('${l10n.select} ${l10n.phonePrefix}'),
                items: [
                  '050', '051', '052', '053', '054', '055', '056', '057', '058', '059',
                  '02', '03', '04', '08', '09',
                  '072', '073', '074', '075', '076', '077', '078', '079'
                ].map((prefix) => DropdownMenuItem<String>(
                  value: prefix,
                  child: Text(prefix),
                )).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    _selectedEditPrefix = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '${l10n.select} ${l10n.phonePrefix}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // שדה מספר
              TextField(
                controller: editController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  String? error = _validatePhoneNumber(value, _selectedEditPrefix);
                  setDialogState(() {
                    tempError = error;
                  });
                },
                decoration: InputDecoration(
                  labelText: l10n.phoneNumber,
                  hintText: '${l10n.enterPhoneNumber.split('(')[0].trim()} (${l10n.forExample}: 1234567)',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: tempError,
                  prefixIcon: Icon(Icons.phone, color: Colors.blue[600]),
                  helperText: l10n.enterNumberWithoutPrefix,
                  helperMaxLines: 2,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
              ),
            ],
          ),
              actions: [
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    );
                  },
                ),
                TextButton(
                  onPressed: () {
                    _deletePhoneNumber();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: Text(l10n.delete),
                ),
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return ElevatedButton(
                      onPressed: tempError == null ? () {
                        // שמירת המספר המלא (קידומת + מספר)
                        final fullNumber = '$_selectedEditPrefix-${editController.text}';
                    _phoneController.text = fullNumber;
                    if (mounted) {
                      setState(() {
                        _phoneError = null;
                        // אם המספר ריק, בטל את הצ'יקבוקס
                        if (fullNumber.trim().isEmpty) {
                          _allowPhoneDisplay = false;
                        }
                      });
                    }
                    Navigator.of(context).pop();
                    _savePhoneSettings();
                  } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Text(l10n.save),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // שמירת שם תצוגה
  Future<void> _saveDisplayName() async {
    debugPrint('=== SAVING DISPLAY NAME ===');
    debugPrint('Display name to save: ${_displayNameController.text.trim()}');
    
    // ולידציה של שם התצוגה
    String? displayNameError = _validateDisplayName(_displayNameController.text);
    if (displayNameError != null) {
      debugPrint('Display name validation error: $displayNameError');
      setState(() {
        _displayNameError = displayNameError;
      });
      return;
    }
    
    // ניקוי שגיאה אם השם תקין
    setState(() {
      _displayNameError = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Cannot save display name: User is not logged in');
        return;
      }

      debugPrint('Saving display name to Firestore for user: ${currentUser.uid}');
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'displayName': _displayNameController.text.trim(),
        'updatedAt': DateTime.now(),
      });
      
      debugPrint('✅ Display name saved successfully to Firestore');
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שם התצוגה נשמר בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving display name: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת שם התצוגה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // עריכת שם תצוגה
  Future<void> _editDisplayName() async {
    final editController = TextEditingController(text: _displayNameController.text);
    String? tempError;
    
    // טעינת פרופיל המשתמש כדי לבדוק אם זה משתמש עסקי מנוי
    UserProfile? currentUserProfile;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          currentUserProfile = UserProfile.fromFirestore(userDoc);
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
    
    final isBusinessSubscriber = currentUserProfile?.userType == UserType.business && 
                                currentUserProfile?.isSubscriptionActive == true;
    
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final l10n = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(l10n.editDisplayName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editController,
                    onChanged: (value) {
                      final error = _validateDisplayName(value);
                      setDialogState(() {
                        tempError = error;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: isBusinessSubscriber 
                          ? 'הזן שם העסק/חברה/כינוי'
                          : 'הזן שם פרטי ומשפחה/חברה/עסק/כינוי',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      errorText: tempError,
                    ),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.afterSavingNameWillUpdate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return ElevatedButton(
                      onPressed: tempError == null ? () async {
                        debugPrint('=== UPDATING DISPLAY NAME CONTROLLER ===');
                        debugPrint('Old display name: ${_displayNameController.text}');
                        debugPrint('New display name: ${editController.text.trim()}');
                        
                        _displayNameController.text = editController.text.trim();
                        _displayNameError = null;
                        Navigator.pop(context);
                        setState(() {});
                        
                        debugPrint('✅ Display name controller updated');
                        
                        // שמירה אוטומטית ב-Firestore
                        await _saveDisplayName();
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Text(l10n.save),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // מחיקת מספר טלפון
  Future<void> _deletePhoneNumber() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'phoneNumber': '',
        'allowPhoneDisplay': false,
      });
        
      if (mounted) {
        setState(() {
          _phoneController.text = '';
          _phoneError = null;
          _allowPhoneDisplay = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('מספר הטלפון נמחק בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה במחיקת מספר הטלפון: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // בניית chip לקישור חברתי
  Widget _buildSocialLinkChip(String type, String url, IconData icon, Color color) {
    String label;
    switch (type) {
      case 'instagram':
        label = 'אינסטגרם';
        break;
      case 'facebook':
        label = 'פייסבוק';
        break;
      case 'tiktok':
        label = 'טיקטוק';
        break;
      case 'website':
        label = 'אתר';
        break;
      default:
        label = type;
    }
    
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Chip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  // עריכת תמונת עסק
  Future<void> _editBusinessImage(UserProfile userProfile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
                if (userProfile.businessImageUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('מחק תמונה', style: TextStyle(color: Colors.red)),
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      if (source == 'delete') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'businessImageUrl': FieldValue.delete()});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('תמונת העסק נמחקה בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('business_images')
          .child(user.uid)
          .child('business_image.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'businessImageUrl': downloadUrl});

      setState(() {
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('תמונת העסק עודכנה בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון תמונת העסק: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // עריכת קישורים חברתיים
  Future<void> _editSocialLinks(UserProfile userProfile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final socialLinks = userProfile.socialLinks ?? <String, String>{};
    final controllers = <String, TextEditingController>{
      'instagram': TextEditingController(text: socialLinks['instagram'] ?? ''),
      'facebook': TextEditingController(text: socialLinks['facebook'] ?? ''),
      'tiktok': TextEditingController(text: socialLinks['tiktok'] ?? ''),
      'website': TextEditingController(text: socialLinks['website'] ?? ''),
    };

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) {
            // ניקוי controllers רק כשהדיאלוג נסגר
            if (didPop) {
              for (var controller in controllers.values) {
                controller.dispose();
              }
            }
          },
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('עריכת קישורים חברתיים'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controllers['instagram'],
                        decoration: const InputDecoration(
                          labelText: 'אינסטגרם',
                          prefixIcon: Icon(Icons.camera_alt),
                          hintText: 'https://instagram.com/...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controllers['facebook'],
                        decoration: const InputDecoration(
                          labelText: 'פייסבוק',
                          prefixIcon: Icon(Icons.facebook),
                          hintText: 'https://facebook.com/...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controllers['tiktok'],
                        decoration: const InputDecoration(
                          labelText: 'טיקטוק',
                          prefixIcon: Icon(Icons.music_video),
                          hintText: 'https://tiktok.com/@...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controllers['website'],
                        decoration: const InputDecoration(
                          labelText: 'אתר',
                          prefixIcon: Icon(Icons.language),
                          hintText: 'https://...',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('ביטול'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final newLinks = <String, String>{};
                      for (var entry in controllers.entries) {
                        final link = entry.value.text.trim();
                        if (link.isNotEmpty) {
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
                          newLinks[entry.key] = fullLink;
                        }
                      }

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({
                        'socialLinks': newLinks.isEmpty ? FieldValue.delete() : newLinks,
                      });

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('הקישורים עודכנו בהצלחה'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text('שמור'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    
    // ניקוי controllers אחרי שהדיאלוג נסגר (אם לא נמחקו כבר)
    Future.microtask(() {
      for (var controller in controllers.values) {
        try {
          controller.dispose();
        } catch (e) {
          // Controller כבר נמחק, זה בסדר
        }
      }
    });
  }

  // שמירת הגדרת הצגת הטלפון
  Future<void> _savePhoneDisplaySetting(bool allowDisplay) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'allowPhoneDisplay': allowDisplay,
      });
        
      debugPrint('✅ Phone display setting saved: $allowDisplay');
    } catch (e) {
      debugPrint('❌ Error saving phone display setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת הגדרת הטלפון: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // שמירת הגדרות הטלפון
  Future<void> _savePhoneSettings() async {
    // בדיקה אם המספר טלפון ריק
    if (_phoneController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _phoneError = 'אנא הזן מספר טלפון';
        });
      }
      return;
    }
    
    // ולידציה של מספר הטלפון
    String? phoneError = _validateIsraeliPhoneNumber(_phoneController.text, context);
    if (phoneError != null) {
      if (mounted) {
        setState(() {
          _phoneError = phoneError;
        });
      }
      return;
    }
      
    // ניקוי שגיאה אם המספר תקין
    if (mounted) {
      setState(() {
        _phoneError = null;
      });
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'phoneNumber': _phoneController.text.trim(),
        'allowPhoneDisplay': _allowPhoneDisplay,
      });
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('מספר הטלפון נשמר בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בשמירת מספר הטלפון: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // כפתור הארכת תקופת ניסיון למשתמשי אורח
  Widget _buildTrialExtensionButton(UserProfile userProfile) {
    // בדיקה אם המשתמש כבר קיבל הארכה
    final hasReceivedExtension = userProfile.guestTrialExtensionReceived ?? false;
    
    if (hasReceivedExtension) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
            const SizedBox(width: 8),
            const Text(
              'תקופת הניסיון שלך כבר הורחבה בשבועיים',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showTrialExtensionDialog(userProfile),
        icon: const Icon(Icons.schedule, size: 18),
        label: Text(l10n.extendTrialPeriodByTwoWeeks),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // דיאלוג הארכת תקופת ניסיון
  void _showTrialExtensionDialog(UserProfile userProfile) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange[600], size: 28),
            const SizedBox(width: 8),
            Text(l10n.extendTrialPeriod),
          ],
        ),
        content: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.toExtendTrialPeriod,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                
                // דרישה 1: שיתוף
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.shareAppTo5Friends,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // דרישה 2: דירוג
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.rateApp5Stars,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // דרישה 3: פרסום בקשה
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, color: Colors.green[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.publishNewRequest,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.completeAllActionsWithinHour,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
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
        actions: [
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              );
            },
          ),
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startTrialExtensionProcess(userProfile);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(l10n.startProcess),
              );
            },
          ),
        ],
      ),
    );
  }

  // התחלת תהליך הארכת תקופת ניסיון
  void _startTrialExtensionProcess(UserProfile userProfile) {
    // שמירת זמן התחלת התהליך
    final startTime = DateTime.now();
    
    // שמירת זמן התחלת הטיימר ב-SharedPreferences
    _saveTrialExtensionStartTime(startTime);
    
    showDialog(
      context: context,
      builder: (context) => TrialExtensionProcessDialog(
        userProfile: userProfile,
        startTime: startTime,
        onExtensionGranted: () {
          // רענון הפרופיל
          setState(() {});
        },
      ),
    );
  }

  // בניית קטע שירותים עסקיים
  Widget _buildBusinessServicesSection(UserProfile userProfile) {
    final l10n = AppLocalizations.of(context);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadBusinessServices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final services = snapshot.data ?? [];
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Theme.of(context).colorScheme.outlineVariant
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business_center, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'שירותים',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showEditServicesDialog(services),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.edit,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (services.isEmpty)
                Text(
                  'אין שירותים מוגדרים',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...services.asMap().entries.map((entry) {
                  final index = entry.key;
                  final service = entry.value;
                  return _buildServiceCard(service, index);
                }).toList(),
              const SizedBox(height: 16),
              // הגדרות שירותים - משלוח ותור
              const Divider(),
              const SizedBox(height: 12),
              // השירותים דורשים קביעת תור
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'השירותים דורשים קביעת תור',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _requiresAppointment,
                    onChanged: _isUpdatingSettings ? null : (newValue) async {
                      // אם מנסים להפעיל כשהשני כבר פעיל, יש לבטל את השני
                      if (newValue && _requiresDelivery) {
                        await _updateServiceSettings(
                          requiresAppointment: true,
                          requiresDelivery: false,
                        );
                      } else {
                        // עדכון רגיל
                        await _updateServiceSettings(requiresAppointment: newValue);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // אפשר לקבל שירות במשלוח
              Row(
                children: [
                  Icon(Icons.local_shipping, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'אפשר לקבל שירות במשלוח',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _requiresDelivery,
                    onChanged: _isUpdatingSettings ? null : (newValue) async {
                      // אם מנסים להפעיל כשהשני כבר פעיל, יש לבטל את השני
                      if (newValue && _requiresAppointment) {
                        await _updateServiceSettings(
                          requiresAppointment: false,
                          requiresDelivery: true,
                        );
                      } else {
                        // עדכון רגיל
                        await _updateServiceSettings(requiresDelivery: newValue);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 28),
                child: Text(
                  'שימו לב: ניתן לבחור רק אחת מהאפשרויות - או שירותים דורשים קביעת תור או שירות במשלוח',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // טעינת שירותים עסקיים מ-Firestore
  Future<List<Map<String, dynamic>>> _loadBusinessServices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return [];
      
      final userData = userDoc.data()!;
      final services = userData['businessServices'] as List<dynamic>?;
      
      if (services == null) return [];
      
      return services.map((s) => s as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error loading business services: $e');
      return [];
    }
  }

  // בניית כרטיס שירות
  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    final name = service['name'] as String? ?? '';
    final price = service['price'] as double?;
    final isCustomPrice = service['isCustomPrice'] as bool? ?? false;
    final imageUrl = service['imageUrl'] as String?;
    final isAvailable = service['isAvailable'] as bool? ?? true; // ברירת מחדל זמין
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image);
                  },
                ),
              )
            : const Icon(Icons.business),
        title: Text(name),
        subtitle: isCustomPrice
            ? const Text('מחיר בהתאמה אישית')
            : price != null
                ? Text('₪${price.toStringAsFixed(0)}')
                : const Text('ללא מחיר'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isAvailable,
              onChanged: (value) async {
                await _updateServiceAvailability(name, value ?? true);
              },
            ),
            IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteService(index),
            ),
          ],
        ),
      ),
    );
  }

  // עדכון זמינות שירות - משתמש בשם השירות במקום index
  Future<void> _updateServiceAvailability(String serviceName, bool isAvailable) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final services = await _loadBusinessServices();
      
      // מציאת השירות לפי שם
      final serviceIndex = services.indexWhere((s) => (s['name'] as String?) == serviceName);
      if (serviceIndex == -1) {
        debugPrint('Service not found: $serviceName');
        return;
      }
      
      services[serviceIndex]['isAvailable'] = isAvailable;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'businessServices': services,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error updating service availability: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעדכון זמינות השירות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // מחיקת שירות
  Future<void> _deleteService(int index) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final services = await _loadBusinessServices();
      if (index >= services.length) return;
      
      services.removeAt(index);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'businessServices': services,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('השירות נמחק בהצלחה'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה במחיקת השירות: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // דיאלוג עריכת שירותים
  Future<void> _showEditServicesDialog(List<Map<String, dynamic>> currentServices) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessServicesEditScreen(initialServices: currentServices),
      ),
    );
    
    if (mounted) {
      setState(() {});
      // טעינת הגדרות שירותים מחדש לאחר עריכה
      _loadServiceSettings();
    }
  }

  Future<void> _saveTrialExtensionStartTime(DateTime startTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trial_extension_start_time', startTime.toIso8601String());
    } catch (e) {
      debugPrint('Error saving trial extension start time: $e');
    }
  }

}