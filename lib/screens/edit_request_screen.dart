import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../models/request.dart';
import '../l10n/app_localizations.dart';
import '../widgets/phone_input_widget.dart';
import '../widgets/two_level_category_selector.dart';
import 'location_picker_screen.dart';
import '../services/app_sharing_service.dart';

class EditRequestScreen extends StatefulWidget {
  final Request request;

  const EditRequestScreen({super.key, required this.request});

  @override
  State<EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends State<EditRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  // משתנים חדשים לטלפון
  String _selectedPhonePrefix = '';
  String _selectedPhoneNumber = '';
  
  RequestCategory _selectedCategory = RequestCategory.plumbing;
  RequestLocation _selectedLocation = RequestLocation.custom;
  final List<String> _selectedImages = [];
  final List<File> _selectedImageFiles = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  
  // שדות חדשים
  RequestType _selectedType = RequestType.free;
  DateTime? _selectedDeadline;
  double? _minRating;
  List<RequestCategory> _selectedTargetCategories = [];
  
  // מחיר (אופציונאלי) - רק לבקשות בתשלום
  final _priceController = TextEditingController();
  double? _price;
  
  // דירוגים מינימליים מפורטים
  double? _minReliability;
  double? _minAvailability;
  double? _minAttitude;
  double? _minFairPrice;
  bool _useDetailedRatings = false; // האם להשתמש בדירוגים מפורטים
  
  // שדות דחיפות חדשים
  UrgencyLevel _selectedUrgency = UrgencyLevel.normal;
  final List<RequestTag> _selectedTags = [];
  String _customTag = '';
  
  // שדות מיקום
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;
  double? _exposureRadius; // רדיוס חשיפה בקילומטרים
  bool? _showToProvidersOutsideRange; // null = לא נבחר, true = כן, false = לא
  bool _showToProvidersOutsideRangeError = false; // האם להציג שגיאה על השדה
  
  // האם להציג בקשה לכל המשתמשים או רק לנותני שירות מתחום X
  bool? _showToAllUsers; // null = לא נבחר, true = לכל המשתמשים, false = רק לנותני שירות מתחום X
  bool _showToAllUsersError = false; // האם להציג שגיאה על השדה

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _titleController.text = widget.request.title;
    _descriptionController.text = widget.request.description;
    // פירוק מספר טלפון
    if (widget.request.phoneNumber != null && widget.request.phoneNumber!.isNotEmpty) {
      final parts = widget.request.phoneNumber!.split('-');
      if (parts.length == 2) {
        _selectedPhonePrefix = parts[0];
        _selectedPhoneNumber = parts[1];
      }
    }
    _selectedCategory = widget.request.category;
    _selectedLocation = widget.request.location ?? RequestLocation.custom;
    _selectedImages.addAll(widget.request.images);
    _selectedType = widget.request.type;
    _selectedDeadline = widget.request.deadline;
    _minRating = widget.request.minRating;
    _selectedTargetCategories = widget.request.targetCategories ?? [];
    _price = widget.request.price;
    if (_price != null) {
      _priceController.text = _price!.toStringAsFixed(0);
    }
    
    // דירוגים מפורטים
    _minReliability = widget.request.minReliability;
    _minAvailability = widget.request.minAvailability;
    _minAttitude = widget.request.minAttitude;
    _minFairPrice = widget.request.minFairPrice;
    _useDetailedRatings = _minReliability != null || _minAvailability != null || 
                         _minAttitude != null || _minFairPrice != null;
    
    // שדות דחיפות חדשים
    _selectedUrgency = widget.request.urgencyLevel;
    _selectedTags.addAll(widget.request.tags);
    _customTag = widget.request.customTag ?? '';
    
    // שדות מיקום
    _selectedLatitude = widget.request.latitude;
    _selectedLongitude = widget.request.longitude;
    _selectedAddress = widget.request.address;
    _exposureRadius = widget.request.exposureRadius;
    _showToProvidersOutsideRange = widget.request.showToProvidersOutsideRange;
    _showToAllUsers = widget.request.showToAllUsers;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }


  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final initialDate = _selectedDeadline ?? now.add(const Duration(days: 1));
    
    // וודא שה-initialDate לא קטן מה-firstDate
    final safeInitialDate = initialDate.isBefore(now) ? now : initialDate;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
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
        _exposureRadius = result['exposureRadius'];
        _selectedLocation = RequestLocation.custom;
      });
    }
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
              content: Text(l10n.imageAccessPermissionRequired),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // בחירת תמונות
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          for (var image in images) {
            _selectedImageFiles.add(File(image.path));
          }
        });
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
              content: Text(l10n.cameraAccessPermissionRequired),
              duration: Duration(seconds: 2),
            ),
          );
          }
        }
        return;
      }

      // צילום תמונה
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
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

  /// מחיקת תמונות מ-Firebase Storage
  Future<void> _deleteImagesFromStorage(List<String> imageUrls) async {
    final l10n = AppLocalizations.of(context);
    try {
      debugPrint('🗑️ Starting to delete ${imageUrls.length} images from Storage');
      
      int deletedCount = 0;
      
      for (String imageUrl in imageUrls) {
        try {
          // חילוץ הנתיב מהקישור
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
          deletedCount++;
          debugPrint('✅ Deleted image: ${ref.fullPath}');
        } catch (e) {
          debugPrint('❌ Failed to delete image $imageUrl: $e');
          // נמשיך למחוק תמונות אחרות גם אם אחת נכשלת
        }
      }
      
      debugPrint('🗑️ Successfully deleted $deletedCount out of ${imageUrls.length} images');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.imagesDeletedFromStorage(deletedCount)),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting images from Storage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorDeletingImages(e.toString())),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateRequest() async {
    final l10n = AppLocalizations.of(context);
    debugPrint('🔍 _updateRequest called');
    debugPrint('🔍 Form key: $_formKey');
    debugPrint('🔍 Form key current state: ${_formKey.currentState}');
    debugPrint('🔍 Form validation: ${_formKey.currentState?.validate()}');
    debugPrint('🔍 Is loading: $_isLoading');
    debugPrint('🔍 Title: ${_titleController.text}');
    debugPrint('🔍 Description: ${_descriptionController.text}');
    debugPrint('🔍 Selected category: ${_selectedCategory.name}');
    debugPrint('🔍 Selected location: ${_selectedLocation.name}');
    debugPrint('🔍 Selected latitude: $_selectedLatitude');
    debugPrint('🔍 Selected longitude: $_selectedLongitude');
    
    // בדיקת שדות ידנית במקום Form validation
    if (_titleController.text.trim().isEmpty) {
      debugPrint('❌ Title is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterTitle),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // ✅ השדה "תיאור" הוא אופציונאלי - אין בדיקה
    
    debugPrint('✅ Manual validation passed');
    if (_isLoading) {
      debugPrint('❌ Already loading');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.userNotLoggedIn),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // בדיקת מיקום וטווח חשיפה
      if (_selectedLatitude == null || _selectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseSelectLocationForRequest),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // ✅ בדיקה שהשדה showToProvidersOutsideRange נבחר (חובה)
      if (_showToProvidersOutsideRange == null) {
        setState(() {
          _showToProvidersOutsideRangeError = true; // הצגת שגיאה על השדה
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('אנא בחר האם להציג את הבקשה לנותני שירות מחוץ לטווח שהגדרת'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // ✅ בדיקה שהשדה showToAllUsers נבחר (חובה אם יש קטגוריה)
      if (_showToAllUsers == null) {
        setState(() {
          _showToAllUsersError = true; // הצגת שגיאה על השדה
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('אנא בחר האם להציג את הבקשה לכל נותני השירות מכל התחומים או רק לנותני שירות מתחום שבחרת'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // בדיקת טווח חשיפה - מותר לטווח המקסימלי של המנוי
      // (הגבלת התראות תהיה בצד הסינון)

      // העלאת תמונות חדשות אם יש
      if (_selectedImageFiles.isNotEmpty) {
        debugPrint('Uploading ${_selectedImageFiles.length} new images...');
        try {
          await _uploadImages();
          debugPrint('New images uploaded successfully');
        } catch (e) {
          debugPrint('Error uploading new images: $e');
          // אם יש שגיאה בהעלאת תמונות, נמשיך ללא תמונות חדשות
        }
      }

      // עדכון רק השדות שהמשתמש שינה
      final updateData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory.name,
        'location': _selectedLocation.name,
        'urgencyLevel': _selectedUrgency.name,
        'tags': _selectedTags.map((tag) => tag.name).toList(),
        'customTag': _customTag.isNotEmpty ? _customTag : null,
        'images': _selectedImages,
        'phoneNumber': _selectedPhonePrefix.isNotEmpty && _selectedPhoneNumber.isNotEmpty 
            ? '$_selectedPhonePrefix-$_selectedPhoneNumber' 
            : null,
        'type': _selectedType.name,
        'deadline': _selectedDeadline != null ? Timestamp.fromDate(_selectedDeadline!) : null,
        'minRating': _minRating,
        'minReliability': _minReliability,
        'minAvailability': _minAvailability,
        'minAttitude': _minAttitude,
        'minFairPrice': _minFairPrice,
        'targetAudience': TargetAudience.all.name,
        'maxDistance': null,
        'targetVillage': null,
        'targetCategories': _selectedTargetCategories.isNotEmpty ? _selectedTargetCategories.map((e) => e.name).toList() : null,
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'address': _selectedAddress,
        'exposureRadius': _exposureRadius,
        'price': _price, // מחיר (אופציונאלי) - רק לבקשות בתשלום
        'showToProvidersOutsideRange': _showToProvidersOutsideRange,
        'showToAllUsers': _showToAllUsers, // null = לא נבחר, true = לכל המשתמשים, false = רק לנותני שירות מתחום X
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.request.requestId)
          .update(updateData);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).requestUpdated),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.errorUpdatingRequest(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearImages() async {
    if (_selectedImages.isEmpty) return;
    
    // הצגת דיאלוג לאישור
    final bool? shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת תמונות'),
        content: const Text('האם אתה בטוח שברצונך למחוק את כל התמונות? התמונות יימחקו גם מ-Storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('מחק הכל'),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      try {
        // מחיקת תמונות מ-Storage
        await _deleteImagesFromStorage(_selectedImages);
        
        setState(() {
          _selectedImages.clear();
          _selectedImageFiles.clear();
        });
        
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.allImagesDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorDeletingImages(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              '${ratingValue.toStringAsFixed(1)} ⭐',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.3),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            valueIndicatorColor: color,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: Slider(
            value: ratingValue,
            min: 0.0,
            max: 5.0,
            divisions: 50, // 0.1 increments
            label: '${ratingValue.toStringAsFixed(1)} ⭐',
            onChanged: (value) {
              onChanged(value);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '0.0 ⭐',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '5.0 ⭐',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // פונקציה לבניית כפתור דחיפות
  Widget _buildUrgencyButton(UrgencyLevel level, String label) {
    final isSelected = _selectedUrgency == level;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUrgency = level;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? level.color : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? level.color : Theme.of(context).colorScheme.outlineVariant,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.editRequest,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _updateRequest,
              child: Text(
                l10n.save,
                style: TextStyle(
                  color: _isLoading ? Colors.grey : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
                            l10n.updatingRequest,
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
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0), // הוספת padding תחתון
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // בחירת קטגוריה - שני שלבים
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: TwoLevelCategorySelector(
                          selectedCategories: [_selectedCategory],
                          maxSelections: 1,
                          title: l10n.selectCategory,
                          instruction: l10n.selectMainCategoryThenSubcategory,
                          onSelectionChanged: (categories) {
                            if (categories.isNotEmpty) {
                              setState(() {
                                _selectedCategory = categories.first;
                              });
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
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          debugPrint('🔍 Title validation: value="$value"');
                          if (value == null || value.isEmpty) {
                            debugPrint('❌ Title validation failed: empty');
                            return l10n.pleaseEnterTitle;
                          }
                          debugPrint('✅ Title validation passed');
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // תיאור
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n.description,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        // ✅ השדה "תיאור" הוא אופציונאלי - אין וולידציה
                      ),
                      const SizedBox(height: 16),
                      
                      // ✅ שאלה: האם להציג לכל נותני השירות מכל התחומים או רק לנותני שירות מתחום X
                      // מופיע רק אם נבחרה קטגוריה
                      ...[
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            final categoryName = _selectedCategory.categoryDisplayName;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.showToAllUsersOrProviders(categoryName),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _showToAllUsersError 
                                        ? Theme.of(context).colorScheme.error
                                        : (Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.white 
                                            : Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Radio<bool>(
                                      value: true,
                                      groupValue: _showToAllUsers,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _showToAllUsers = value;
                                          _showToAllUsersError = false; // הסרת שגיאה אחרי בחירה
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(l10n.yesToAllUsers),
                                    ),
                                    const SizedBox(width: 24),
                                    Radio<bool>(
                                      value: false,
                                      groupValue: _showToAllUsers,
                                      onChanged: (bool? value) async {
                                        setState(() {
                                          _showToAllUsers = value;
                                          _showToAllUsersError = false; // הסרת שגיאה אחרי בחירה
                                        });
                                        // ✅ הצגת דיאלוג עם מספר נותני שירות כשמשתמש בוחר "רק לנותני שירות מתחום X"
                                        if (value == false) {
                                          await _checkAvailableHelpers();
                                        }
                                      },
                                    ),
                                    Expanded(
                                      child: Text(l10n.onlyToProvidersInCategory(categoryName)),
                                    ),
                                  ],
                                ),
                                if (_showToAllUsersError) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'אנא בחר האם להציג את הבקשה לכל נותני השירות מכל התחומים או רק לנותני שירות מתחום $categoryName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // תמונות
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.images,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                    onPressed: _pickImages,
                                      icon: const Icon(Icons.photo_library),
                                      label: Text(l10n.selectImages),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF03A9F4),
                                      foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _takePhoto,
                                      icon: const Icon(Icons.camera_alt),
                                      label: Text(l10n.takePhoto),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE91E63),
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
                                    child: ElevatedButton.icon(
                                    onPressed: _clearImages,
                                    icon: const Icon(Icons.clear),
                                      label: Text(l10n.clearAll),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedImages.isNotEmpty || _selectedImageFiles.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  l10n.imagesSelected(_selectedImages.length + _selectedImageFiles.length),
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _selectedImages.length + _selectedImageFiles.length,
                                    itemBuilder: (context, index) {
                                      // תמונות קיימות
                                      if (index < _selectedImages.length) {
                                        return _buildExistingImage(index);
                                      } else {
                                        // תמונות חדשות
                                        return _buildNewImage(index - _selectedImages.length);
                                      }
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
                      ),
                      const SizedBox(height: 16),


                      // סוג בקשה
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
                          return DropdownButtonFormField<RequestType>(
                            initialValue: _selectedType,
                            decoration: InputDecoration(
                              labelText: l10n.requestType,
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
                            },
                          );
                        },
                      ),
                      // שדה מחיר (רק אם סוג הבקשה הוא בתשלום)
                      if (_selectedType == RequestType.paid) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: l10n.howMuchWillingToPay,
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
                              });
                            }
                          },
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final parsedPrice = double.tryParse(value);
                              if (parsedPrice == null || parsedPrice < 0) {
                                return 'אנא הזן מחיר תקין';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // בחירת מיקום
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(_selectedAddress ?? l10n.selectLocation),
                          subtitle: _selectedLatitude != null 
                              ? Text('${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}${_exposureRadius != null ? ' • רדיוס: ${_exposureRadius!.toStringAsFixed(1)} ק"מ' : ''}')
                              : Text(l10n.clickToSelectLocation),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: _selectLocation,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // ✅ האם להציג בקשה לנותני שירות שלא בטווח שהגדרת
                      // מופיע רק אם נבחר מיקום
                      if (_selectedLatitude != null && _selectedLongitude != null) ...[
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            // זיהוי האיזור לפי קו רוחב
                            final region = getGeographicRegion(_selectedLatitude);
                            final regionName = region.getDisplayName(l10n);
                            // אם יש קטגוריה נבחרת, נציג את שמה, אחרת נציג "התחום שבחרת"
                            final categoryName = _selectedCategory.categoryDisplayName;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.showToProvidersOutsideRange(regionName, categoryName),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _showToProvidersOutsideRangeError 
                                        ? Theme.of(context).colorScheme.error
                                        : (Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.white 
                                            : Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Radio<bool>(
                                      value: true,
                                      groupValue: _showToProvidersOutsideRange,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _showToProvidersOutsideRange = value;
                                          _showToProvidersOutsideRangeError = false; // הסרת שגיאה אחרי בחירה
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(l10n.yesAllProvidersInRegion(regionName)),
                                    ),
                                    const SizedBox(width: 24),
                                    Radio<bool>(
                                      value: false,
                                      groupValue: _showToProvidersOutsideRange,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _showToProvidersOutsideRange = value;
                                          _showToProvidersOutsideRangeError = false; // הסרת שגיאה אחרי בחירה
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(l10n.noOnlyInRange),
                                    ),
                                  ],
                                ),
                                if (_showToProvidersOutsideRangeError) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'אנא בחר האם להציג את הבקשה לנותני שירות מחוץ לטווח שהגדרת',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // תאריך יעד
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            _selectedDeadline != null
                                ? l10n.deadlineDateSelected(_selectedDeadline!.day, _selectedDeadline!.month, _selectedDeadline!.year)
                                : l10n.deadlineLabel,
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: _selectDeadline,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // רמת דחיפות
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.urgencyLevel,
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildUrgencyButton(UrgencyLevel.normal, '🕓 ${l10n.normal}'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildUrgencyButton(UrgencyLevel.urgent24h, '⏰ ${l10n.within24Hours}'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildUrgencyButton(UrgencyLevel.emergency, '🚨 ${l10n.now}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // תגיות דחיפות
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.urgencyTags,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.selectTagsForRequest,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _getTagsForCategory(_selectedCategory).map((tag) {
                                  final isSelected = _selectedTags.contains(tag);
                                  return FilterChip(
                                    label: Text(tag.displayName(l10n)),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                  setState(() {
                                        if (selected) {
                                          _selectedTags.add(tag);
                                        } else {
                                          _selectedTags.remove(tag);
                                        }
                                  });
                                },
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                    selectedColor: tag.color.withValues(alpha: 0.3),
                                    checkmarkColor: tag.color,
                                    labelStyle: TextStyle(
                                      color: isSelected ? tag.color : Colors.black87,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        ),
                        const SizedBox(height: 16),

                      // דירוג מינימלי (רק לבקשות בתשלום)
                      if (_selectedType == RequestType.paid) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.minRatingForHelpers,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _minRating = null;
                                            _useDetailedRatings = false;
                                            // איפוס כל השדות המפורטים
                                            _minReliability = null;
                                            _minAvailability = null;
                                            _minAttitude = null;
                                            _minFairPrice = null;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _minRating == null 
                                              ? Colors.blue 
                                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                                          foregroundColor: _minRating == null 
                                              ? Colors.white 
                                              : Colors.black87,
                                        ),
                                        child: Text(l10n.allRatings),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _useDetailedRatings = true;
                                            _minRating = 4.0;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _minRating == 4.0 
                                              ? Colors.orange 
                                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                                          foregroundColor: _minRating == 4.0 
                                              ? Colors.white 
                                              : Colors.black87,
                                        ),
                                        child: Text(l10n.detailedRatings),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_useDetailedRatings && _minRating == 4.0) ...[
                                  const SizedBox(height: 20),
                                  
                                  // אמינות
                                  _buildDetailedRatingField(
                                    l10n.reliability,
                                    '',
                                    _minReliability,
                                    (value) => setState(() => _minReliability = value),
                                    Icons.verified_user,
                                    Colors.blue,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // זמינות
                                  _buildDetailedRatingField(
                                    l10n.availability,
                                    '',
                                    _minAvailability,
                                    (value) => setState(() => _minAvailability = value),
                                    Icons.access_time,
                                    Colors.green,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // יחס
                                  _buildDetailedRatingField(
                                    l10n.attitude,
                                    '',
                                    _minAttitude,
                                    (value) => setState(() => _minAttitude = value),
                                    Icons.people,
                                    Colors.orange,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // מחיר הוגן
                                  _buildDetailedRatingField(
                                    l10n.fairPrice,
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
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),

                      // תגית מותאמת אישית
                      if (_selectedTags.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.customTag,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: _customTag,
                                decoration: InputDecoration(
                                  labelText: l10n.customTag,
                                  hintText: l10n.writeCustomTag,
                                  border: OutlineInputBorder(),
                                ),
                        onChanged: (value) {
                                  _customTag = value;
                        },
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: 16),
                      ],

                      // כפתור שמירה
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
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
                            : Text(l10n.save),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildExistingImage(int index) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: _selectedImages[index],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 80,
                height: 80,
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 80,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(
                    Icons.error,
                    color: Colors.red,
                  ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () async {
                // מחיקת תמונה בודדת
                final bool? shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return AlertDialog(
                      title: Text(l10n.deleteImage),
                      content: Text(l10n.deleteImageConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancel),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                          child: Text(l10n.delete),
                      ),
                    ],
                    );
                  },
                );

                if (shouldDelete == true) {
                  final l10n = AppLocalizations.of(context);
                  try {
                    // מחיקת התמונה מ-Storage
                    await _deleteImagesFromStorage([_selectedImages[index]]);
                    
                    setState(() {
                      _selectedImages.removeAt(index);
                    });
                    
                    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
                          content: Text(l10n.imageDeletedSuccessfully),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.errorDeletingImage(e.toString())),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
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
  }

  Widget _buildNewImage(int index) {
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
                
                if (mounted) {
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.imageRemovedFromList),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.orange,
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
  }


  // ✅ בדיקת מספר נותני שירות זמינים בתחום
  Future<void> _checkAvailableHelpers() async {
    debugPrint('🔍 Checking available helpers for category: ${_selectedCategory.toString()}');
    
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
      
      // איחוד כל התוצאות
      final allUsers = [
        ...businessQuery.docs,
        ...guestQuery.docs,
        ...adminQuery.docs,
      ];
      
      int count = 0;
      final selectedCategoryName = _selectedCategory.name;
      final selectedCategoryDisplayName = _selectedCategory.categoryDisplayName;
      
      for (var doc in allUsers) {
        final data = doc.data();
        final businessCategories = data['businessCategories'] as List<dynamic>? ?? [];
        
        // בדיקה אם המשתמש הוא משתמש אמיתי (לא משתמש בדיקה עם כל הקטגוריות)
        bool isRealUser = businessCategories.length < 20;
        
        if (!isRealUser) {
          continue;
        }
        
        bool canProvideService = false;
        
        if (businessCategories.isNotEmpty) {
          for (var category in businessCategories) {
            bool matches = false;
            
            if (category is Map) {
              final mapCategoryName = category['category']?.toString() ?? '';
              final mapCategoryDisplayName = category['categoryDisplayName']?.toString();
              
              if (mapCategoryName == selectedCategoryName) {
                matches = true;
              } else if (mapCategoryDisplayName != null && mapCategoryDisplayName == selectedCategoryDisplayName) {
                matches = true;
              }
            } else if (category is String) {
              if (category == selectedCategoryName || category == selectedCategoryDisplayName) {
                matches = true;
              } else {
                try {
                  final cat = RequestCategory.values.firstWhere(
                    (c) => c.name == category || c.categoryDisplayName == category,
                    orElse: () => RequestCategory.plumbing,
                  );
                  if (cat == _selectedCategory) {
                    matches = true;
                  }
                } catch (e) {
                  // Continue
                }
              }
            }
            
            if (matches) {
              canProvideService = true;
              break;
            }
          }
        }
        
        if (canProvideService) {
          count++;
        }
      }
      
      debugPrint('🎯 Total helpers found: $count');
      
      // ✅ הצגת דיאלוג עם מספר נותני שירות רק כשמשתמש בוחר "רק לנותני שירות מתחום X"
      debugPrint('📊 Showing dialog with helpers count: $count');
      _showHelpersCountDialog(count);
    } catch (e) {
      debugPrint('Error checking available helpers: $e');
    }
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

  String _getTypeDisplayName(RequestType type) {
    switch (type) {
      case RequestType.free:
        return 'חינם';
      case RequestType.paid:
        return 'בתשלום';
    }
  }

  List<RequestTag> _getTagsForCategory(RequestCategory category) {
    return RequestTagExtension.getTagsForCategory(category);
  }

}
