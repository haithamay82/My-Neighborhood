import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/request.dart';
import '../l10n/app_localizations.dart';
import '../widgets/phone_input_widget.dart';
import '../widgets/two_level_category_selector.dart';
import 'location_picker_screen.dart';

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
  
  RequestCategory _selectedCategory = RequestCategory.maintenance;
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
  
  // שדות דחיפות חדשים
  UrgencyLevel _selectedUrgency = UrgencyLevel.normal;
  final List<RequestTag> _selectedTags = [];
  String _customTag = '';
  
  // שדות מיקום
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;
  double? _exposureRadius; // רדיוס חשיפה בקילומטרים

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
    
    // שדות דחיפות חדשים
    _selectedUrgency = widget.request.urgencyLevel;
    _selectedTags.addAll(widget.request.tags);
    _customTag = widget.request.customTag ?? '';
    
    // שדות מיקום
    _selectedLatitude = widget.request.latitude;
    _selectedLongitude = widget.request.longitude;
    _selectedAddress = widget.request.address;
    _exposureRadius = widget.request.exposureRadius;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

  /// מחיקת תמונות מ-Firebase Storage
  Future<void> _deleteImagesFromStorage(List<String> imageUrls) async {
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
            content: Text('נמחקו $deletedCount תמונות מ-Storage'),
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
            content: Text('שגיאה במחיקת תמונות: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('משתמש לא מחובר'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
        'targetAudience': TargetAudience.all.name,
        'maxDistance': null,
        'targetVillage': null,
        'targetCategories': _selectedTargetCategories.isNotEmpty ? _selectedTargetCategories.map((e) => e.name).toList() : null,
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'address': _selectedAddress,
        'exposureRadius': _exposureRadius,
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
          content: Text('שגיאה בעדכון: $e'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('כל התמונות נמחקו בהצלחה'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('שגיאה במחיקת תמונות: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
              ? const Color(0xFFFF9800) // כתום ענתיק
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
                            'מעדכן בקשה...',
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
                          title: 'בחירת קטגוריה',
                          instruction: 'בחר תחום ראשי ואז תחום משנה:',
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
                                      label: const Text('בחר תמונות'),
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
                                      label: const Text('צלם תמונה'),
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
                                      label: const Text('נקה הכל'),
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
                                  '${_selectedImages.length + _selectedImageFiles.length} תמונות נבחרו',
                                  style: TextStyle(color: Colors.grey[600]),
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
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // בחירת מיקום
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(_selectedAddress ?? 'בחר מיקום'),
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
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            _selectedDeadline != null
                                ? 'תאריך יעד: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}'
                                : 'תאריך יעד (אופציונלי)',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: _selectDeadline,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // רמת דחיפות
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'רמת דחיפות',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedUrgency = UrgencyLevel.normal;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedUrgency == UrgencyLevel.normal 
                                            ? Colors.green 
                                            : Colors.grey[300],
                                        foregroundColor: _selectedUrgency == UrgencyLevel.normal 
                                            ? Colors.white 
                                            : Colors.black87,
                                      ),
                                      child: const Text('רגיל'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedUrgency = UrgencyLevel.urgent24h;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedUrgency == UrgencyLevel.urgent24h 
                                            ? Colors.orange 
                                            : Colors.grey[300],
                                        foregroundColor: _selectedUrgency == UrgencyLevel.urgent24h 
                                            ? Colors.white 
                                            : Colors.black87,
                                      ),
                                      child: const Text('תוך 24 שעות'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedUrgency = UrgencyLevel.emergency;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _selectedUrgency == UrgencyLevel.emergency 
                                            ? Colors.red 
                                            : Colors.grey[300],
                                        foregroundColor: _selectedUrgency == UrgencyLevel.emergency 
                                            ? Colors.white 
                                            : Colors.black87,
                                      ),
                                      child: const Text('עכשיו'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                                'תגיות דחיפות',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'בחר תגיות המתאימות לבקשה שלך:',
                                style: TextStyle(
                                  color: Colors.grey[600],
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
                                    label: Text(tag.displayName),
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
                                    backgroundColor: Colors.grey[200],
                                    selectedColor: tag.color.withOpacity(0.3),
                                    checkmarkColor: tag.color,
                                    labelStyle: TextStyle(
                                      color: isSelected ? tag.color : Colors.black87,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: _customTag,
                                decoration: const InputDecoration(
                                  labelText: 'תגית מותאמת אישית',
                                  hintText: 'כתוב תגית קצרה משלך',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  _customTag = value;
                                },
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
                                  'דירוג מינימלי של עוזרים',
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
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _minRating == null 
                                              ? Colors.blue 
                                              : Colors.grey[300],
                                          foregroundColor: _minRating == null 
                                              ? Colors.white 
                                              : Colors.black87,
                                        ),
                                        child: const Text('כל הדירוגים'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _minRating = 4.0;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _minRating == 4.0 
                                              ? Colors.orange 
                                              : Colors.grey[300],
                                          foregroundColor: _minRating == 4.0 
                                              ? Colors.white 
                                              : Colors.black87,
                                        ),
                                        child: const Text('דירוגים מפורטים'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_minRating == 4.0) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'דירוגים מפורטים: 4 כוכבים ומעלה',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),

                      // כפתור שמירה
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFFFF9800) // כתום ענתיק
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
            child: Image.network(
              _selectedImages[index],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.error,
                    color: Colors.red,
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
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
                  builder: (context) => AlertDialog(
                    title: const Text('מחיקת תמונה'),
                    content: const Text('האם אתה בטוח שברצונך למחוק את התמונה?'),
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
                        child: const Text('מחק'),
                      ),
                    ],
                  ),
                );

                if (shouldDelete == true) {
                  try {
                    // מחיקת התמונה מ-Storage
                    await _deleteImagesFromStorage([_selectedImages[index]]);
                    
                    setState(() {
                      _selectedImages.removeAt(index);
                    });
                    
                    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
                          content: Text('תמונה נמחקה בהצלחה'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('שגיאה במחיקת תמונה: $e'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('תמונה הוסרה מהרשימה'),
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
