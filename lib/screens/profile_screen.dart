import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payme_service.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../models/request.dart';
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
import '../widgets/trial_extension_process_dialog.dart';
import 'manual_payment_screen.dart';
import 'location_picker_screen.dart';
import 'contact_screen.dart';
import 'admin_contact_inquiries_screen.dart';
import 'admin_guest_management_screen.dart';

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
  String? _phoneError;
  String _selectedEditPrefix = '';
  
  // שדות שם פרטי ומשפחה/חברה/עסק/כינוי
  final TextEditingController _displayNameController = TextEditingController();
  String? _displayNameError;
  
  // שדה לא נותן שירותים בתשלום
  bool _noPaidServices = false;

  @override
  void initState() {
    super.initState();
    // בדיקה אם המשתמש הוא מנהל פעם אחת
    _isAdmin = AdminAuthService.isCurrentUserAdmin();
    
    // התראה למשתמש אורח בכניסה הראשונה
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGuestCategories();
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.work, color: Colors.amber[700]),
            const SizedBox(width: 8),
            const Text('הגדר תחומי עיסוק'),
          ],
        ),
        content: const Text(
          'כדי לקבל בקשות רלוונטיות, עליך לבחור עד שני תחומי עיסוק.\n\n'
          'תוכל לשנות את הבחירה בכל עת בפרופיל שלך.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('מאוחר יותר'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // קבלת הפרופיל הנוכחי והצגת דיאלוג בחירת תחומים
              _showGuestCategoriesDialogFromNotification();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('בחר עכשיו'),
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
            color: Colors.grey[800],
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
                color: Colors.grey[400],
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
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
    await TutorialService.resetAllTutorials();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הודעות ההדרכה אופסו בהצלחה'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // עדכון נתונים ישנים של קטגוריות
  Future<void> _updateOldCategoryData(UserProfile userProfile) async {
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
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('נתוני הקטגוריות עודכנו בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating category data: $e');
      }
    }
  }

  // הודעת הדרכה ספציפית לפרופיל - רק כשצריך
  Future<void> _showProfileSpecificTutorial() async {
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
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TutorialDialog(
        tutorialKey: 'profile_specific_tutorial',
        title: 'השלם את הפרופיל שלך',
        message: 'כדי לקבל עזרה טובה יותר, מומלץ להשלים את הפרטים בפרופיל שלך: תמונה, תיאור קצר ואזור מגורים.',
        features: [
          '📸 העלאת תמונת פרופיל',
          '✏️ עדכון פרטים אישיים',
          '📍 עדכון מיקום',
        ],
      ),
    );
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
        // נסה לפתוח הגדרות אפליקציה
        if (permission == PermissionStatus.permanentlyDenied) {
          showDialog(
      context: context,
      builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('הרשאות נדרשות'),
                content: const Text('נדרשת הרשאת גישה לתמונות. אנא עבור להגדרות האפליקציה והפעל את ההרשאה.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ביטול'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    child: const Text('פתח הגדרות'),
                  ),
                ],
              );
            },
          );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
              content: Text('נדרשת הרשאת גישה לתמונות. אנא נסה שוב.'),
              backgroundColor: Colors.red,
                              ),
                            );
                          }
        return;
      }

      // בחירת מקור התמונה
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('תמונת הפרופיל עודכנה בהצלחה'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      
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


  Future<void> _createUserProfileWithType(UserType userType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userProfile = UserProfile(
        userId: user.uid,
        displayName: user.displayName ?? user.email?.split('@')[0] ?? 'משתמש',
        email: user.email ?? '',
        userType: userType,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userProfile.toFirestore());

      debugPrint('User profile created successfully with type: $userType');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('פרופיל נוצר בהצלחה כ-${userType.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת פרופיל: $e'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת הפרופיל: $e'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('משתמש לא מחובר'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // הצגת הודעת טעינה
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('בודק הרשאות מיקום...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('נדרשות הרשאות מיקום כדי לעדכן מיקום. אנא הפעל הרשאות מיקום בהגדרות המכשיר'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שירותי המיקום כבויים. אנא הפעל אותם בהגדרות המכשיר'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // קבלת מיקום נוכחי אם אפשר
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('מקבל מיקום נוכחי...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      Position? currentPosition = await LocationService.getCurrentPosition();
      debugPrint('Current position: $currentPosition');
      
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLatitude: currentPosition?.latitude,
            initialLongitude: currentPosition?.longitude,
            showExposureCircle: false, // לא להציג מעגל חשיפה במסך פרופיל
          ),
        ),
      );

      if (result != null) {
        // הצגת הודעת שמירה
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שומר מיקום...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // עדכון המיקום ב-Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'latitude': result['latitude'],
          'longitude': result['longitude'],
          'village': result['address'],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('המיקום עודכן בהצלחה!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא נבחר מיקום'),
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








  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך הפרופיל
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showProfileSpecificTutorial();
    });

    if (user == null) {
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.profile),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
      ),
        body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'לא מחובר למערכת',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'אנא התחבר כדי לראות את הפרופיל שלך',
                style: TextStyle(color: Colors.grey),
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
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: Center(
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
                          'טוען פרופיל...',
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
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Profile Screen Error: ${snapshot.error}');
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.profile),
              backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'שגיאה בטעינת הפרופיל',
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
                    child: const Text('נסה שוב'),
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
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
            Text(
                    'לא נמצא פרופיל משתמש',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isCreatingProfile ? null : () async {
                      await playButtonSound();
                      _createUserProfileIfNeeded();
                    },
                    child: _isCreatingProfile 
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('יוצר פרופיל...'),
                            ],
                          )
                        : const Text('צור פרופיל'),
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
        final newDisplayName = userProfile.displayName.isNotEmpty 
            ? userProfile.displayName 
            : userProfile.email.split('@')[0];
        
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
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
          actions: [
            PopupMenuButton<String>(
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
                } else if (value == 'delete_account') {
                  _showDeleteAccountDialog(l10n);
                } else if (value == 'logout') {
                  _showLogoutDialog(l10n);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('שתף אפליקציה'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'rate',
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('דרג אפליקציה'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'recommend',
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red),
                      SizedBox(width: 8),
                      Text('המלץ לחברים'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'rewards',
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('תגמולים'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset_tutorials',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('איפוס הודעות הדרכה'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'contact',
                  child: Row(
                    children: [
                      Icon(Icons.contact_support, color: Color(0xFF03A9F4)),
                      SizedBox(width: 8),
                      Text('צור קשר'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete_account',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('מחק חשבון'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('התנתקות'),
                    ],
                  ),
                ),
              ],
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
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
                                  child: userProfile.profileImageUrl != null
                                      ? ClipOval(
                                          child: Image.network(
                                            userProfile.profileImageUrl!,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Text(
                              userProfile.displayName.isNotEmpty 
                                  ? userProfile.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                                              );
                                            },
                                          ),
                                        )
                                      : Text(
                                          userProfile.displayName.isNotEmpty 
                                              ? userProfile.displayName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      padding: const EdgeInsets.all(4),
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
                                Text(
                                  userProfile.displayName.isNotEmpty 
                                      ? userProfile.displayName 
                                      : userProfile.email.split('@')[0],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  userProfile.email,
                                  style: TextStyle(
                                    color: Colors.grey[600],
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
                                          // אם המשתמש פרטי מנוי - הצג דיאלוג פירוט
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
                                          border: Border.all(color: Colors.white, width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _getSubscriptionTypeDisplayName(userProfile),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.edit,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // כפתור הארכת תקופת ניסיון למשתמשי אורח
                      if (userProfile.userType == UserType.guest) ...[
                        const SizedBox(height: 12),
                        _buildTrialExtensionButton(userProfile),
                      ],
                      
                      // הודעה מיוחדת למשתמשי אורח
                      if (userProfile.userType == UserType.guest) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
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
                                    'מידע על תקופת הניסיון שלך',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getGuestStatusMessage(userProfile),
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                        ),
                      ],
                      
                      // הצגת תחומי עיסוק - מנהל, עסקי מנוי או אורח
                      if ((_isAdmin == true) || 
                          (userProfile.isSubscriptionActive && 
                           userProfile.businessCategories != null && 
                           userProfile.businessCategories!.isNotEmpty) ||
                          (userProfile.userType == UserType.guest && 
                           userProfile.businessCategories != null && 
                           userProfile.businessCategories!.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.work, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _isAdmin == true ? 'כל תחומי העיסוק' : 'תחומי עיסוק',
                                  style: TextStyle(
                                    color: Colors.green[700],
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
                                        color: Colors.green[700],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'ערוך',
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
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.blue[300]!),
                                        ),
                                        child: Text(
                                          'כל תחומי העיסוק',
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : userProfile.businessCategories!.map((category) {
                                      // בדיקה נוספת לוודא שהקטגוריה קיימת
                                      try {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.green[300]!),
                                          ),
                                          child: Text(
                                          category.categoryDisplayName, // הצגת קטגוריה בעברית
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                  // אם יש שגיאה, נציג את שם הקטגוריה כפי שהוא
                                  debugPrint('Error displaying category $category: $e');
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.green[300]!),
                                    ),
                                    child: Text(
                                      category.toString(),
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ],
                  ),
                ),
              ),
              
              // התראה למשתמש אורח שאין לו תחומי עיסוק
              if (userProfile.userType == UserType.guest && 
                  (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty)) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'הגדר תחומי עיסוק',
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'כדי לקבל התראות על בקשות רלוונטיות, עליך לבחור עד שני תחומי עיסוק:',
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // צ'קבוקס לא נותן שירותים בתשלום
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
                            CheckboxListTile(
                              value: _noPaidServices,
                        onChanged: (value) {
                          debugPrint('🔍 DEBUG: "לא נותן שירותים" checkbox changed');
                          debugPrint('🔍 DEBUG: value = $value');
                          debugPrint('🔍 DEBUG: _noPaidServices before = $_noPaidServices');
                          
                          setState(() {
                            _noPaidServices = value ?? false;
                          });
                          
                          debugPrint('🔍 DEBUG: _noPaidServices after = $_noPaidServices');
                          
                          // עדכון ב-Firestore (גם לסימון וגם לביטול)
                          _updateNoPaidServicesStatus(_noPaidServices);
                        },
                              title: const Text(
                                'אני לא נותן שירות כלשהו תמורת תשלום',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'אם תסמן אפשרות זו, תוכל לראות רק בקשות חינמיות במסך הבקשות.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
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
                            debugPrint('🔍 DEBUG: "בחר תחומי עיסוק" button pressed');
                            debugPrint('🔍 DEBUG: _noPaidServices = $_noPaidServices');
                            _showGuestCategoriesDialog(userProfile);
                          },
                          icon: const Icon(Icons.work, size: 18),
                          label: const Text('בחר תחומי עיסוק'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _noPaidServices ? Colors.grey[400] : Colors.amber[700],
                            foregroundColor: Colors.white,
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
              ],
              
              const SizedBox(height: 16),

              // שדה שם פרטי ומשפחה/חברה/עסק/כינוי - לכל סוגי המשתמשים
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'שם פרטי ומשפחה/חברה/עסק/כינוי',
                          style: TextStyle(
                            color: Colors.green[700],
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
                                  hintText: 'הזן שם פרטי ומשפחה/חברה/עסק/כינוי',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  errorText: _displayNameError,
                                  prefixIcon: Icon(Icons.person, color: Colors.green[600]),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                style: const TextStyle(
                                  color: Colors.black87,
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
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('עדכן'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'השם יופיע בבקשות שלך ובמסך הבית',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
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
                                  'לחץ על "עדכן" כדי לשנות את השם. השם יישמר אוטומטית',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
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

              // שדה טלפון - לכל סוגי המשתמשים
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'מספר טלפון',
                          style: TextStyle(
                            color: Colors.blue[700],
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
                                  hintText: 'הזן מספר טלפון (למשל: 050-1234567)',
                                  hintStyle: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  errorText: _phoneError,
                                  prefixIcon: Icon(Icons.phone, color: Colors.blue[600]),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                style: const TextStyle(
                                  color: Colors.black87,
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
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('עדכן'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'קידומות תקפות: 050-059 (10 ספרות), 02,03,04,08,09 (9 ספרות), 072-079 (10 ספרות)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
                          activeColor: Colors.blue[600],
                        ),
                        Expanded(
                          child: Text(
                            'מסכים להציג את הטלפון שלי במידה ומבקש שירות מעוניין לפנות אלי',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // דירוג המשתמש
              _buildRatingCard(userProfile),

              const SizedBox(height: 16),

              // הודעה מיוחדת למנהל
              if (_isAdmin == true) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                    child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                              'מנהל מערכת - גישה מלאה לכל הפונקציות (עסקי מנוי)',
                                  style: TextStyle(
                                    color: Colors.blue[700],
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
                        const Text(
                          'ניהול מערכת',
                          style: TextStyle(
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
                                label: const Text('ניהול פניות'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF03A9F4),
                                  foregroundColor: Colors.white,
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
                                label: const Text('ניהול אורחים'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9C27B0),
                                  foregroundColor: Colors.white,
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

              // מידע נוסף
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'מידע נוסף',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('תאריך הצטרפות'),
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

              // כרטיס מונה בקשות חודשיות - מוצג לכל המשתמשים
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
                            'בקשות חודשיות',
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

              // כרטיס מיקום
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
                            'מיקום קבוע',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await playButtonSound();
                              _updateLocation();
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('עדכן מיקום'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
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
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.admin_panel_settings, color: Colors.blue[700], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'מנהל - ניתן לעדכן מיקום כמו כל משתמש אחר',
                                  style: TextStyle(
                                    color: Colors.blue[700],
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
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'מיקום קבוע מוגדר',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.my_location, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${userProfile.latitude!.toStringAsFixed(6)}, ${userProfile.longitude!.toStringAsFixed(6)}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_city, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Text(
                                    userProfile.village ?? 'לא הוגדר כפר',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '✅ אתה תופיע במפות של בקשות בטווח שלך גם אם שירות המיקום כובה',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.orange[700], size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'לא הוגדר מיקום קבוע',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'כנותן שירות, הגדרת מיקום קבוע חיונית כדי:',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• להופיע במפות של בקשות בטווח שלך\n• לקבל התראות על בקשות רלוונטיות לתחום העיסוק שלך\n• לפעול גם כששירות המיקום כובה בטלפון',
                                style: TextStyle(
                                  color: Colors.orange[600],
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
                            'עזור לנו לצמוח',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'המלץ על האפליקציה לחברים וקבל תגמולים!',
                        style: TextStyle(
                          color: Colors.grey[600],
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
                                AppSharingService.shareApp(context);
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('שתף'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await playButtonSound();
                                AppSharingService.rateApp(context);
                              },
                              icon: const Icon(Icons.star, size: 18),
                              label: const Text('דרג'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[600],
                                foregroundColor: Colors.white,
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
                              label: const Text('המלץ לחברים'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red[300]!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => AppSharingService.showRewardsDialog(context),
                              icon: const Icon(Icons.card_giftcard, size: 18),
                              label: const Text('תגמולים'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.purple,
                                side: BorderSide(color: Colors.purple[300]!),
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
            const Text(
              'פרטי חינם',
              style: TextStyle(
                color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
            ),
            const SizedBox(height: 4),
            const Text(
              '🆓 גישה לבקשות חינמיות',
              style: TextStyle(
                color: Colors.blue,
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Text(
            'שגיאה בטעינת נתונים: ${snapshot.error}',
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
                    'פורסמו $requestsUsed בקשות החודש (ללא הגבלה)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue[300]!,
                      ),
                    ),
                    child: Text(
                      '$requestsUsed/∞',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // בר התקדמות למנהל (תמיד ירוק)
              LinearProgressIndicator(
                value: 0.0, // תמיד 0 כי אין הגבלה
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
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
                    ? 'נשאר לך $remainingRequests בקשות לפרסום החודש'
                    : 'הגעת למגבלת הבקשות החודשית',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: remainingRequests > 0 ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: remainingRequests > 0 ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: remainingRequests > 0 ? Colors.green[300]! : Colors.red[300]!,
                    ),
                  ),
                  child: Text(
                    '$requestsUsed/$maxRequests',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: remainingRequests > 0 ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // בר התקדמות
            LinearProgressIndicator(
              value: requestsUsed / maxRequests,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                remainingRequests > 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            
            // כפתור שדרוג אם נשארו מעט בקשות
            if (remainingRequests <= 2 && remainingRequests > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'נשארו לך רק $remainingRequests בקשות!',
                        style: TextStyle(
                          color: Colors.orange[700],
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
                  onPressed: () => _showUpgradeDialog(userProfile),
                  icon: const Icon(Icons.upgrade, size: 18),
                  label: const Text('רוצה יותר? שדרג מנוי'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
              : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
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
    return Stream.periodic(const Duration(seconds: 2), (count) async {
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
    
    // משתמש אורח לא יכול לשדרג במהלך תקופת הניסיון
    if (userProfile.userType == UserType.guest) return false;
    
    // אם יש בקשה בתהליך אישור - לא יכול לשלוח בקשה נוספת
    if (userProfile.subscriptionStatus == 'pending_approval') return false;
    
    // קביעת רמת המנוי הנוכחית
    int currentLevel = _getSubscriptionLevel(userProfile);
    
    // אם ברמה הנמוכה ביותר (פרטי חינם) - יכול לשדרג
    if (currentLevel == 0) return true;
    
    // אם ברמה הגבוהה ביותר (עסקי מנוי) - לא יכול לשדרג
    if (currentLevel >= 2) return false;
    
    // אם ברמה בינונית (פרטי מנוי) - יכול לשדרג לעסקי
    return currentLevel == 1;
  }
  
  /// קביעת רמת המנוי הנוכחית
  int _getSubscriptionLevel(UserProfile userProfile) {
    // משתמש אורח = 3 (לא יכול לשדרג)
    if (userProfile.userType == UserType.guest) return 3;
    
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
      case 0: return 'פרטי חינם';
      case 1: return 'פרטי מנוי';
      case 2: return 'עסקי מנוי';
      case 3: return 'אורח';
      default: return 'לא ידוע';
    }
  }

  /// הצגת דיאלוג שדרוג מנוי
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
        title: const Text('שדרוג מנוי 🚀'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentLevel == 0) ...[
              // פרטי חינם - יכול לשדרג לפרטי מנוי או עסקי
              const Text('בחר סוג מנוי:'),
              const SizedBox(height: 16),
              _buildUpgradeOption(
                title: 'פרטי מנוי - 10₪/שנה',
                description: '• 5 בקשות בחודש\n• טווח: 0-10 ק"מ + בונוסים\n• רואה רק בקשות חינם',
                onTap: () {
                  Navigator.pop(context);
                  _updateSubscriptionType(UserType.personal, true, userProfile: userProfile);
                },
              ),
              const SizedBox(height: 8),
              _buildUpgradeOption(
                title: 'עסקי מנוי - 50₪/שנה',
                description: '• 10 בקשות בחודש\n• טווח: 0-50 ק"מ + בונוסים\n• רואה בקשות חינם ובתשלום\n• בחירת תחומי עיסוק',
                onTap: () {
                  Navigator.pop(context);
                  _updateSubscriptionType(UserType.business, true, userProfile: userProfile);
                },
              ),
            ] else if (currentLevel == 1) ...[
              // פרטי מנוי - יכול לשדרג לעסקי בלבד
              const Text('שדרוג לעסקי מנוי:'),
              const SizedBox(height: 16),
              _buildUpgradeOption(
                title: 'עסקי מנוי - 50₪/שנה',
                description: '• 10 בקשות בחודש (במקום 5)\n• טווח: 0-50 ק"מ + בונוסים\n• רואה בקשות חינם ובתשלום\n• בחירת תחומי עיסוק',
                onTap: () {
                  Navigator.pop(context);
                  _updateSubscriptionType(UserType.business, true, userProfile: userProfile);
                },
              ),
            ] else if (currentLevel >= 2) ...[
              // עסקי מנוי - לא יכול לשדרג
              const Text('אין אפשרויות שדרוג זמינות'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
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
          border: Border.all(color: Colors.grey[300]!),
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
                color: Colors.grey[600],
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
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green),
          ),
          child: const Text(
            'פעיל',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case 'pending_approval':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange),
          ),
          child: const Text(
            'בתהליך אישור',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red),
          ),
          child: const Text(
            'נדחה',
            style: TextStyle(
              color: Colors.red,
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
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue),
          ),
          child: const Text(
            'פרטי חינם',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
    }
  }

  Widget _buildRatingCard(UserProfile userProfile) {
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
                  color: Colors.amber[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'הדירוג שלך',
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

                // דירוגים מפורטים
                final reliability = (userData?['reliability'] as num?)?.toDouble() ?? 0.0;
                final availability = (userData?['availability'] as num?)?.toDouble() ?? 0.0;
                final attitude = (userData?['attitude'] as num?)?.toDouble() ?? 0.0;
                final fairPrice = (userData?['fairPrice'] as num?)?.toDouble() ?? 0.0;

                // תמיד נציג את הדירוגים המפורטים, גם אם הם 0.0

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
                                color: Colors.amber[600],
                                size: 20,
                              );
                            } else if (index < averageRating) {
                              return Icon(
                                Icons.star_half,
                                color: Colors.amber[600],
                                size: 20,
                              );
                            } else {
                              return Icon(
                                Icons.star_border,
                                color: Colors.grey[400],
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
                      'מבוסס על $ratingCount דירוג${ratingCount == 1 ? '' : 'ים'}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: List.generate(5, (index) => Icon(
                          Icons.star_border,
                          color: Colors.grey[400],
                          size: 20,
                        )),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'עדיין לא קיבלת דירוגים',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // דירוגים מפורטים
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'דירוגים מפורטים:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // אמינות
                          _buildDetailedRatingRow(
                            'אמינות',
                            reliability,
                            Icons.verified_user,
                            Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          
                          // זמינות
                          _buildDetailedRatingRow(
                            'זמינות',
                            availability,
                            Icons.access_time,
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                          
                          // יחס
                          _buildDetailedRatingRow(
                            'יחס',
                            attitude,
                            Icons.people,
                            Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          
                          // מחיר הוגן
                          _buildDetailedRatingRow(
                            'מחיר הוגן',
                            fairPrice,
                            Icons.attach_money,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// דיאלוג התנתקות
  Future<void> _showLogoutDialog(AppLocalizations l10n) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('התנתקות'),
          content: const Text('האם אתה בטוח שברצונך להתנתק?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ביטול'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              child: const Text(
                'התנתקות',
                style: TextStyle(color: Colors.red),
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

  /// דיאלוג מחיקת חשבון
  Future<void> _showDeleteAccountDialog(AppLocalizations l10n) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[600], size: 28),
              const SizedBox(width: 8),
              const Text('מחיקת חשבון'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'האם אתה בטוח שברצונך למחוק את החשבון שלך?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.red[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'פעולה זו תמחק לצמיתות:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDeleteWarningPoint('פרטי הכניסה שלך'),
                      _buildDeleteWarningPoint('המידע האישי בפרופיל'),
                      _buildDeleteWarningPoint('כל הבקשות שפרסמת'),
                      _buildDeleteWarningPoint('כל הפניות שפנית אליהן'),
                      _buildDeleteWarningPoint('כל הצ\'אטים שלך'),
                      _buildDeleteWarningPoint('כל ההודעות ששלחת וקיבלת'),
                      _buildDeleteWarningPoint('כל התמונות והקבצים'),
                      _buildDeleteWarningPoint('כל הנתונים וההיסטוריה'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'פעולה זו איננה ניתנת לשחזור!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
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
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _showPasswordConfirmationDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('מחק חשבון'),
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
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.security, color: Colors.red[600], size: 28),
                  const SizedBox(width: 8),
                  const Text('אישור סיסמה'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'כדי למחוק את החשבון, אנא הזן את הסיסמה שלך לאישור:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'סיסמה',
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
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'פעולה זו תמחק את החשבון לצמיתות!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
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
                  child: const Text('ביטול'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (passwordController.text.isEmpty) {
                      setState(() {
                        errorText = 'אנא הזן את הסיסמה';
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
                      // סיסמה נכונה - ממשיך למחיקה
                      Navigator.of(context).pop();
                      await _performAccountDeletion();
                    } catch (e) {
                      setState(() {
                        errorText = 'סיסמה שגויה';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('מחק חשבון'),
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
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red[600], size: 28),
              const SizedBox(width: 8),
              const Text('מחיקת משתמש'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle,
                color: Colors.blue,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'התחברת דרך Google',
                style: TextStyle(
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
                    const Expanded(
                      child: Text(
                        'לחץ "אישור" כדי למחוק את החשבון לצמיתות.\nפעולה זו איננה ניתנת לשחזור!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
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
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performGoogleAccountDeletion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('אישור'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('לא נמצא משתמש מחובר'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.red[600], fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.red[700], fontSize: 13),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא נמצא משתמש מחובר'),
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
      // מחיקה מקבילה של כל הנתונים
      await Future.wait([
        // מחיקת פרופיל המשתמש
        FirebaseFirestore.instance.collection('users').doc(userId).delete(),
        
        // מחיקת בקשות שהמשתמש יצר
        _deleteCollectionData('requests', 'userId', userId),
        
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
  
  // פונקציה לקבלת הודעת סטטוס למשתמש אורח
  String _getGuestStatusMessage(UserProfile userProfile) {
    if (userProfile.userType != UserType.guest) return '';
    
    final now = DateTime.now();
    final trialStart = userProfile.guestTrialStartDate ?? now;
    final daysSinceStart = now.difference(trialStart).inDays;
    final hasCategories = userProfile.businessCategories != null && 
                         userProfile.businessCategories!.isNotEmpty;
    
    if (daysSinceStart < 7) {
      return '🎉 אתה נמצא בשבוע הראשון שלך! תוכל לראות כל הבקשות (חינם ובתשלום) מכל הקטגוריות.';
    } else if (hasCategories) {
      return '📋 שבוע הניסיון שלך הסתיים. אתה רואה בקשות בתשלום רק מתחומי העיסוק שבחרת.';
    } else {
      return '⚠️ שבוע הניסיון שלך הסתיים. כדי לראות בקשות בתשלום, בחר תחומי עיסוק למעלה.';
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
        final daysLeft = userProfile.guestTrialEndDate?.difference(DateTime.now()).inDays ?? 0;
        if (daysLeft > 0) {
          return 'אורח ($daysLeft ימים)';
        } else {
          return 'אורח (פג תוקף)';
        }
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
      return Colors.purple;
    }
    
    // בדיקה לפי סוג המשתמש
    switch (userProfile.userType) {
      case UserType.guest:
        final daysLeft = userProfile.guestTrialEndDate?.difference(DateTime.now()).inDays ?? 0;
        if (daysLeft > 0) {
          return Colors.amber; // צהוב לאורח פעיל
    } else {
          return Colors.red; // אדום לאורח שפג תוקף
        }
      case UserType.personal:
        if (userProfile.isSubscriptionActive) {
          return Colors.blue; // כחול לפרטי מנוי
        } else {
          return Colors.grey; // אפור לפרטי חינם
        }
      case UserType.business:
        if (userProfile.isSubscriptionActive) {
          return Colors.green; // ירוק לעסקי מנוי
        } else {
          return Colors.orange; // כתום לעסקי חינם
        }
      case UserType.admin:
        return Colors.purple; // סגול למנהל
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('המנוי החינם שלך'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'המנוי החינם שלך כולל:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי המנוי
            _buildSubscriptionDetailItem(
              icon: Icons.assignment,
              title: '1 בקשה בחודש',
              description: 'פרסום בקשה אחת בלבד בחודש',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.location_on,
              title: 'טווח: 0-10 ק"מ',
              description: 'חשיפה עד 10 קילומטר מהמיקום שלך',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.visibility,
              title: 'רואה רק בקשות חינם',
              description: 'גישה לבקשות חינם בלבד',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.payment,
              title: 'ללא תשלום',
              description: 'המנוי החינם זמין ללא עלות',
            ),
            const SizedBox(height: 16),
            
            // הודעת הגבלה
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'המנוי החינם מוגבל - שקול לשדרג לקבלת יותר אפשרויות',
                      style: TextStyle(
                        color: Colors.orange[700],
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
                    label: const Text('שדרג'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
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
                      foregroundColor: Colors.green[600],
                      side: BorderSide(color: Colors.green[600]!),
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

  // דיאלוג פירוט מנוי פרטי
  void _showPersonalSubscriptionDetailsDialog(UserProfile userProfile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרטי המנוי הפרטי שלך'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'המנוי הפרטי שלך כולל:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי המנוי
            _buildSubscriptionDetailItem(
              icon: Icons.assignment,
              title: '5 בקשות בחודש',
              description: 'פרסום עד 5 בקשות בחודש',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.location_on,
              title: 'טווח: 0-10 ק"מ + בונוסים',
              description: 'חשיפה עד 10 קילומטר מהמיקום שלך',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.visibility,
              title: 'רואה רק בקשות חינם',
              description: 'גישה לבקשות חינם בלבד',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.payment,
              title: 'תשלום: 10₪ לשנה',
              description: 'תשלום חד-פעמי לשנה שלמה',
            ),
            const SizedBox(height: 16),
            
            // סטטוס המנוי
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'המנוי שלך פעיל עד ${userProfile.subscriptionExpiry != null ? '${userProfile.subscriptionExpiry!.day}/${userProfile.subscriptionExpiry!.month}/${userProfile.subscriptionExpiry!.year}' : 'לא ידוע'}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // כפתור שדרוג - רק אם לא משתמש אורח
            if (userProfile.userType != UserType.guest) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showSubscriptionTypeDialog(userProfile);
                },
                icon: const Icon(Icons.upgrade),
                label: const Text('שדרג לעסקי מנוי'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            ],
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
    // חישוב ימים נותרים
    final now = DateTime.now();
    final trialEndDate = userProfile.guestTrialEndDate ?? now.add(const Duration(days: 30));
    final daysRemaining = trialEndDate.difference(now).inDays;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרטי המנוי האורח שלך'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'תקופת הניסיון שלך כוללת:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי המנוי
            _buildSubscriptionDetailItem(
              icon: Icons.assignment,
              title: '10 בקשות בחודש',
              description: 'פרסום עד 10 בקשות בחודש',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.location_on,
              title: 'טווח: 0-3 ק"מ + בונוסים',
              description: 'חשיפה עד 3 קילומטר מהמיקום שלך',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.visibility,
              title: 'רואה בקשות חינם ובתשלום',
              description: 'גישה לכל סוגי הבקשות באפליקציה',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.work,
              title: 'תחומי עיסוק נבחרים',
              description: 'תחומי העיסוק שלך: ${userProfile.businessCategories?.map((c) => c.categoryDisplayName).join(', ') ?? 'לא נבחרו'}',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.schedule,
              title: 'תקופת ניסיון: 30 ימים',
              description: 'גישה מלאה לכל התכונות ללא תשלום',
            ),
            const SizedBox(height: 16),
            
            // סטטוס המנוי
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: daysRemaining > 0 ? Colors.amber[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: daysRemaining > 0 ? Colors.amber[200]! : Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    daysRemaining > 0 ? Icons.schedule : Icons.warning,
                    color: daysRemaining > 0 ? Colors.amber[700] : Colors.red[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      daysRemaining > 0 
                          ? 'תקופת הניסיון שלך פעילה עוד $daysRemaining ימים'
                          : 'תקופת הניסיון שלך הסתיימה',
                      style: TextStyle(
                        color: daysRemaining > 0 ? Colors.amber[700] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // הודעה על המעבר האוטומטי
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'אחרי תקופת הניסיון, תעבור אוטומטית למנוי פרטי חינם. תוכל לשדרג בכל עת.',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }

  void _showBusinessSubscriptionDetailsDialog(UserProfile userProfile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('פרטי המנוי העסקי שלך'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'המנוי העסקי שלך כולל:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי המנוי
            _buildSubscriptionDetailItem(
              icon: Icons.assignment,
              title: '10 בקשות בחודש',
              description: 'פרסום עד 10 בקשות בחודש',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.location_on,
              title: 'טווח: 0-50 ק"מ + בונוסים',
              description: 'חשיפה עד 50 קילומטר מהמיקום שלך',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.visibility,
              title: 'רואה בקשות חינם ובתשלום',
              description: 'גישה לכל סוגי הבקשות באפליקציה',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.work,
              title: 'תחומי עיסוק נבחרים',
              description: 'תחומי העיסוק שלך: ${userProfile.businessCategories?.map((c) => c.categoryDisplayName).join(', ') ?? 'לא נבחרו'}',
            ),
            const SizedBox(height: 12),
            
            _buildSubscriptionDetailItem(
              icon: Icons.payment,
              title: 'תשלום: 50₪ לשנה',
              description: 'תשלום חד-פעמי לשנה שלמה',
            ),
            const SizedBox(height: 16),
            
            // סטטוס המנוי
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'המנוי שלך פעיל עד ${userProfile.subscriptionExpiry != null ? '${userProfile.subscriptionExpiry!.day}/${userProfile.subscriptionExpiry!.month}/${userProfile.subscriptionExpiry!.year}' : 'לא ידוע'}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('סגור'),
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
        Icon(icon, color: Colors.blue[700], size: 20),
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
                  color: Colors.grey[600],
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('מנהל מערכת'),
          content: const Text(
            'כמנהל מערכת, יש לך גישה מלאה לכל הפונקציות ללא צורך בתשלום.\n\n'
            'סוג המנוי שלך קבוע: עסקי מנוי עם גישה לכל תחומי העיסוק.',
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('בחירת סוג מנוי'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('בחר את סוג המנוי שלך:'),
            const SizedBox(height: 8),
            
            // הודעת הסבר על הגבלות
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ניתן לשדרג בלבד: פרטי חינם → פרטי מנוי → עסקי מנוי',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // פרטי חינם - רק אם המשתמש לא במנוי
            if (!userProfile.isSubscriptionActive) ...[
              _buildSubscriptionOption(
                title: 'פרטי (חינם)',
                description: '• 1 בקשה בחודש\n• טווח: 0-10 ק"מ\n• רואה רק בקשות חינם\n• ללא תחומי עיסוק',
                isSelected: true,
                onTap: () => _updateSubscriptionType(UserType.personal, false, userProfile: userProfile),
              ),
              const SizedBox(height: 8),
            ],
            
            // פרטי מנוי - רק אם המשתמש לא עסקי מנוי
            if (!(userProfile.isSubscriptionActive && userProfile.businessCategories != null && userProfile.businessCategories!.isNotEmpty)) ...[
              _buildSubscriptionOption(
                title: 'פרטי (מנוי) - 10₪/שנה',
                description: '• 5 בקשות בחודש\n• טווח: 0-10 ק"מ + בונוסים\n• רואה רק בקשות חינם\n• ללא תחומי עיסוק\n• תשלום: 10₪ לשנה',
                isSelected: userProfile.isSubscriptionActive && (userProfile.businessCategories == null || userProfile.businessCategories!.isEmpty),
                onTap: () {
                  debugPrint('🔍 User selected PERSONAL subscription');
                  _updateSubscriptionType(UserType.personal, true, userProfile: userProfile);
                },
              ),
              const SizedBox(height: 8),
            ],
            
            // עסקי מנוי - תמיד זמין
            _buildSubscriptionOption(
              title: 'עסקי (מנוי) - 50₪/שנה',
              description: '• 10 בקשות בחודש\n• טווח: 0-50 ק"מ + בונוסים\n• רואה בקשות חינם ובתשלום\n• בחירת עד 2 תחומי עיסוק\n• תשלום: 50₪ לשנה',
              isSelected: userProfile.isSubscriptionActive && (userProfile.businessCategories != null && userProfile.businessCategories!.isNotEmpty),
              onTap: () {
                debugPrint('🔍 User selected BUSINESS subscription');
                _showBusinessCategoriesSelectionDialog(userProfile);
              },
            ),
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
          color: isSelected ? Colors.blue[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
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
                color: isSelected ? Colors.blue[700] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue[600] : Colors.grey[600],
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
        // לא סוגרים את הדיאלוג כאן - _showPaymentDialog תטפל בזה
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(_isAdmin == true ? 'בחירת תחומי עיסוק - עסקי מנוי (מנהל)' : 'בחירת תחומי עיסוק - עסקי מנוי'),
          content: SizedBox(
            width: double.maxFinite,
            child: TwoLevelCategorySelector(
              selectedCategories: selectedCategories,
              maxSelections: 2,
              title: 'בחירת תחומי עיסוק - עסקי מנוי',
              instruction: 'עליך לבחור תחום ראשי ואז עד 2 תחומי משנה כדי להמשיך לעסקי מנוי:',
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: selectedCategories.length > 0 
                  ? () async {
                      if (mounted) {
                        Navigator.pop(context);
                      }
                      await _updateSubscriptionTypeWithCategories(UserType.business, true, selectedCategories, userProfile);
                    }
                  : null,
              child: Text(_isAdmin == true ? 'המשך (${selectedCategories.length}/2)' : 'המשך לתשלום (${selectedCategories.length}/2)'),
            ),
          ],
        ),
      ),
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
    
    // התחל עם הקטגוריות הקיימות של המשתמש
    List<RequestCategory> selectedCategories = List.from(_selectedBusinessCategories);
    bool noPaidServices = _noPaidServices;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('בחירת תחומי עיסוק'),
          content: SizedBox(
            width: double.maxFinite,
            child: TwoLevelCategorySelector(
              selectedCategories: selectedCategories,
              maxSelections: 2,
              title: 'בחירת תחומי עיסוק',
              instruction: 'בחר תחום ראשי ואז עד 2 תחומי משנה:',
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
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
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text('שמור (${selectedCategories.length}/2)'),
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

  // דיאלוג לבחירת תחומי עיסוק למשתמש אורח
  Future<void> _showGuestCategoriesDialog(UserProfile userProfile) async {
    // התחל עם הקטגוריות הקיימות של המשתמש
    List<RequestCategory> selectedCategories = List.from(userProfile.businessCategories ?? []);
    bool noPaidServices = userProfile.noPaidServices ?? false;
    
    debugPrint('🔍 DEBUG: _showGuestCategoriesDialog started');
    debugPrint('🔍 DEBUG: Initial selectedCategories.length = ${selectedCategories.length}');
    debugPrint('🔍 DEBUG: Initial selectedCategories = ${selectedCategories.map((c) => c.name).toList()}');
    debugPrint('🔍 DEBUG: Initial noPaidServices = $noPaidServices');
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('הגדר תחומי עיסוק'),
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
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
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
                        title: const Text(
                          'אני לא נותן שירות כלשהו תמורת תשלום',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'אם תסמן אפשרות זו, תוכל לראות רק בקשות חינמיות במסך הבקשות.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // בחירת תחומי עיסוק (רק אם לא בחר "לא נותן שירותים")
                if (!noPaidServices) ...[
                  const Text(
                    'או בחר תחומי עיסוק:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TwoLevelCategorySelector(
                    selectedCategories: selectedCategories,
                    maxSelections: 2,
                    title: 'בחירת תחומי עיסוק',
                    instruction: 'בחר תחום ראשי ואז עד 2 תחומי משנה כדי לקבל בקשות רלוונטיות:',
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () async {
                debugPrint('🔍 DEBUG: Save button pressed!');
                debugPrint('🔍 DEBUG: selectedCategories.length = ${selectedCategories.length}');
                debugPrint('🔍 DEBUG: selectedCategories = ${selectedCategories.map((c) => c.name).toList()}');
                debugPrint('🔍 DEBUG: noPaidServices = $noPaidServices');
                
                // אם אין תחומי עיסוק נבחרים, הגדר כ"לא נותן שירותים"
                final finalNoPaidServices = selectedCategories.isEmpty ? true : noPaidServices;
                debugPrint('🔍 DEBUG: finalNoPaidServices = $finalNoPaidServices');
                
                await _updateGuestCategories(selectedCategories, finalNoPaidServices);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(selectedCategories.isEmpty 
                  ? 'שמור (לא נותן שירותים)' 
                  : 'שמור (${selectedCategories.length}/2)'),
            ),
          ],
        ),
      ),
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
        'businessCategories': noPaidServices ? [] : categories.map((c) => c.name).toList(),
        'noPaidServices': noPaidServices,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Guest categories updated successfully');
      
      if (mounted) {
        String message = noPaidServices 
            ? 'הגדרת שלא אתה נותן שירותים בתשלום'
            : 'תחומי העיסוק עודכנו בהצלחה! (${categories.length}/2)';
            
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

      // עדכון הפרופיל
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

      // אם זה מנוי פעיל - הצג דיאלוג תשלום
      if (isActive) {
        // המתנה קצרה כדי שהדיאלוג ייסגר
        await Future.delayed(const Duration(milliseconds: 100));
        // בדיקה אם ה-widget עדיין פעיל
        if (mounted) {
          await _showPaymentDialog(newType, categories);
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
        'businessCategories': categories.map((c) => c.name).toList(),
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
  /// פתיחת תשלום BIT דרך PayMe API
  Future<void> _openPayMeBitPayment(UserType subscriptionType, int price) async {
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

      final typeName = subscriptionType == UserType.personal ? 'פרטי' : 'עסקי';
      final subscriptionTypeString = subscriptionType == UserType.personal ? 'personal' : 'business';
      
      debugPrint('🔗 Creating PayMe BIT payment for $typeName subscription, price: $price');
      
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

      // קבלת פרטי המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userName = userDoc.exists 
          ? (userDoc.data()!['displayName'] ?? userDoc.data()!['name'] ?? user.email ?? 'משתמש')
          : (user.email ?? 'משתמש');

      // יצירת התשלום דרך PayMe API
      final response = await PayMeService.createBitPayment(
        subscriptionType: subscriptionTypeString,
        userId: user.uid,
        userEmail: user.email ?? '',
        userName: userName,
      );

      // סגירת אינדיקטור הטעינה
      if (mounted) {
        Navigator.pop(context);
      }

      if (response.success && response.paymentUrl != null) {
        debugPrint('✅ PayMe BIT payment created successfully: ${response.paymentId}');
        
        // פתיחת דף התשלום BIT
        final uri = Uri.parse(response.paymentUrl!);
          final result = await launchUrl(
            uri, 
            mode: LaunchMode.externalApplication,
          );
          
          if (result) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('פתחתי את דף התשלום BIT עבור ₪$price'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'בדוק סטטוס',
                  onPressed: () => _checkPayMePaymentStatus(response.paymentId!),
                ),
              ),
            );
          }
        } else {
          debugPrint('❌ Failed to open PayMe BIT payment URL');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('שגיאה בפתיחת דף התשלום BIT'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ PayMe BIT payment creation failed: ${response.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה ביצירת תשלום BIT: ${response.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in PayMe BIT payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בתשלום BIT: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  /// פתיחת תשלום דרך PayMe API (כרטיס אשראי)
  Future<void> _openPayMeCreditCardPayment(UserType subscriptionType, int price) async {
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

      final typeName = subscriptionType == UserType.personal ? 'פרטי' : 'עסקי';
      final subscriptionTypeString = subscriptionType == UserType.personal ? 'personal' : 'business';
      
      debugPrint('💳 Creating PayMe Credit Card payment for $typeName subscription, price: $price');
      
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

      // קבלת פרטי המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userName = userDoc.exists 
          ? (userDoc.data()!['displayName'] ?? userDoc.data()!['name'] ?? user.email ?? 'משתמש')
          : (user.email ?? 'משתמש');

      // יצירת התשלום דרך PayMe API
      final response = await PayMeService.createCreditCardPayment(
        subscriptionType: subscriptionTypeString,
        userId: user.uid,
        userEmail: user.email ?? '',
        userName: userName,
      );

      // סגירת אינדיקטור הטעינה
      if (mounted) {
        Navigator.pop(context);
      }

      if (response.success && response.paymentUrl != null) {
        debugPrint('✅ Payment created successfully: ${response.paymentId}');
        
        // פתיחת דף התשלום
        final uri = Uri.parse(response.paymentUrl!);
        final result = await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
        
        if (result) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('פתחתי את דף התשלום עבור ₪$price'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'בדוק סטטוס',
                  onPressed: () => _checkPayMePaymentStatus(response.paymentId!),
                ),
              ),
            );
          }
        } else {
          debugPrint('❌ Failed to open payment URL');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('שגיאה בפתיחת דף התשלום'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Payment creation failed: ${response.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה ביצירת התשלום: ${response.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in Paid.co.il payment: $e');
      if (mounted) {
        // סגירת אינדיקטור הטעינה אם הוא פתוח
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה לא צפויה: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// בדיקת סטטוס תשלום PayMe
  Future<void> _checkPayMePaymentStatus(String paymentId) async {
    try {
      debugPrint('🔍 Checking PayMe payment status: $paymentId');
      
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

      final status = await PayMeService.checkPaymentStatus(paymentId);
      
      // סגירת אינדיקטור הטעינה
      if (mounted) {
        Navigator.pop(context);
      }

      if (status.success) {
        String statusText = '';
        Color statusColor = Colors.blue;
        
        switch (status.status) {
          case 'pending':
            statusText = 'התשלום ממתין לאישור';
            statusColor = Colors.orange;
            break;
          case 'completed':
          case 'paid':
            statusText = 'התשלום אושר! המנוי הופעל';
            statusColor = Colors.green;
            break;
          case 'failed':
          case 'cancelled':
            statusText = 'התשלום נכשל או בוטל';
            statusColor = Colors.red;
            break;
          default:
            statusText = 'סטטוס: ${status.status}';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusText),
              backgroundColor: statusColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה בבדיקת סטטוס: ${status.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking PayMe payment status: $e');
      if (mounted) {
        Navigator.pop(context); // סגירת אינדיקטור הטעינה
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בבדיקת סטטוס: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _showPaymentDialog(UserType subscriptionType, [List<RequestCategory>? categories]) async {
    print('💰 _showPaymentDialog called with: $subscriptionType');
    
    // מנהל לא צריך להעלות הוכחת תשלום
    if (_isAdmin == true) {
      print('❌ Admin user, skipping payment dialog');
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

    final price = subscriptionType == UserType.personal ? 10 : 50;
    final typeName = subscriptionType == UserType.personal ? 'פרטי' : 'עסקי';
    
    print('💰 Opening payment dialog for $typeName subscription, price: $price');
    
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
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    'מנוי $typeName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₪$price לשנה',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  if (categories != null && categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'תחומי עיסוק: ${categories.map((c) => c.categoryDisplayName).join(', ')}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[600],
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
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'איך לשלם:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. בחר דרך תשלום: BIT (PayMe) או כרטיס אשראי (PayMe)\n'
                    '2. השלם את הסכום (₪$price) - המנוי יופעל אוטומטית\n'
                    '3. אם יש בעיה, השתמש בכפתור "העלה הוכחת תשלום"',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.amber[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'BIT (PayMe): יפתח דף תשלום מאובטח של PayMe\n'
                            'כרטיס אשראי (PayMe): יפתח דף תשלום מאובטח של PayMe\n'
                            'המנוי יופעל אוטומטית לאחר התשלום - אין צורך בהעלאת הוכחה',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[700],
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
            
            // כפתור PayMe BIT
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _openPayMeBitPayment(subscriptionType, price);
                },
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text('שלם ב-BIT (PayMe)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            // כפתור PayMe כרטיס אשראי
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _openPayMeCreditCardPayment(subscriptionType, price);
                },
                icon: const Icon(Icons.credit_card, color: Colors.white),
                label: const Text('שלם בכרטיס אשראי (PayMe)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            
            // כפתור העלאת הוכחת תשלום
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  print('🖼️ Payment button pressed for $subscriptionType, price: $price');
                  // הסרנו את סגירת הדיאלוג מכאן - _processPayment תטפל בזה
                  if (mounted) {
                    print('🖼️ Widget still mounted, calling _processPayment...');
                    await _processPayment(subscriptionType, price);
                  } else {
                    print('❌ Widget not mounted, skipping _processPayment');
                  }
                },
                icon: const Icon(Icons.upload),
                label: const Text('העלה הוכחת תשלום'),
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
  
  // עיבוד התשלום
  Future<void> _processPayment(UserType subscriptionType, int price) async {
    print('💰 _processPayment called with: $subscriptionType, $price');
    try {
      // בדיקה אם ה-widget עדיין פעיל
      if (!mounted) {
        print('❌ Widget not mounted, returning');
        return;
      }
      
      // פתיחת מסך העלאת הוכחת תשלום
      if (!mounted) {
        print('❌ Widget not mounted before Navigator.push, returning');
        return; // בדיקה נוספת לפני Navigator.push
      }
      
      print('🚀 Opening ManualPaymentScreen...');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManualPaymentScreen(
            subscriptionType: subscriptionType.name,
            amount: price,
            onPaymentSuccess: () {
              // הפונקציה submitSubscriptionRequest כבר מטפלת בשליחת הבקשה למנהל
              // אין צורך בקריאה נוספת
            },
          ),
        ),
      );
      
      print('🔙 Navigator.push completed with result: $result');
      
      // סגירת הדיאלוג אחרי ש-ManualPaymentScreen נסגרת
      if (mounted) {
        Navigator.pop(context);
      }
      
      // הסרנו את ה-SnackBar כי הדיאלוג האישור כבר מוצג ב-ManualPaymentScreen
    } catch (e) {
      // הדפסה ללא context קודם
      print('Error processing payment: $e');
      
      // בדיקה אם ה-widget עדיין פעיל לפני פעולות UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בעיבוד התשלום: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
  String? _validateIsraeliPhoneNumber(String? phone) {
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
      return 'קידומת לא תקפה. קידומות תקפות: 050-059, 02, 03, 04, 08, 09, 072-079';
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
        return AlertDialog(
          title: const Text('עריכת מספר טלפון'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // שדה קידומת
              DropdownButtonFormField<String>(
                value: _selectedEditPrefix.isNotEmpty ? _selectedEditPrefix : null,
                decoration: InputDecoration(
                  labelText: 'קידומת',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone, color: Colors.blue[600]),
                ),
                hint: const Text('בחר קידומת'),
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
                    return 'בחר קידומת';
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
                  labelText: 'מספר טלפון',
                  hintText: 'הזן מספר (למשל: 1234567)',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: tempError,
                  prefixIcon: Icon(Icons.phone, color: Colors.blue[600]),
                  helperText: 'הזן את המספר ללא הקידומת',
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ביטול'),
                ),
                TextButton(
                  onPressed: () {
                    _deletePhoneNumber();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('מחק'),
                ),
                ElevatedButton(
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
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('שמור'),
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
    
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('עריכת שם תצוגה'),
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
                      hintText: 'הזן שם פרטי ומשפחה/חברה/עסק/כינוי',
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
                            'לאחר השמירה, השם יתעדכן בכל מקום באפליקציה',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ביטול'),
                ),
                ElevatedButton(
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
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('שמור'),
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
    String? phoneError = _validateIsraeliPhoneNumber(_phoneController.text);
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
          border: Border.all(color: Colors.grey[300]!),
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

    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showTrialExtensionDialog(userProfile),
        icon: const Icon(Icons.schedule, size: 18),
        label: const Text('הארך תקופת ניסיון בשבועיים'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange[600], size: 28),
            const SizedBox(width: 8),
            const Text('הארכת תקופת ניסיון'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'כדי להאריך את תקופת הניסיון שלך בשבועיים, עליך לבצע את הפעולות הבאות:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  const Expanded(
                    child: Text(
                      'שתף את האפליקציה ל-5 חברים (WhatsApp, SMS, Email)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'דרג את האפליקציה בחנות 5 כוכבים',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'פרסם בקשה חדשה בכל תחום שתרצה',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.orange[600], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'יש לבצע את כל הפעולות תוך שעה אחת',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTrialExtensionProcess(userProfile);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('התחל תהליך'),
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

  Future<void> _saveTrialExtensionStartTime(DateTime startTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trial_extension_start_time', startTime.toIso8601String());
    } catch (e) {
      debugPrint('Error saving trial extension start time: $e');
    }
  }


}