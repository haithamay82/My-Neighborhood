import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../services/manual_payment_service.dart';
import '../l10n/app_localizations.dart';

class ManualPaymentScreen extends StatefulWidget {
  final String? subscriptionType;
  final int? amount;
  final VoidCallback? onPaymentSuccess;
  
  const ManualPaymentScreen({
    super.key,
    this.subscriptionType,
    this.amount,
    this.onPaymentSuccess,
  });

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  final _noteController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  String? _selectedImagePath;
  Map<String, dynamic>? _paymentData;

  @override
  void initState() {
    super.initState();
    _createPaymentRequest();
  }
  
  // הצגת הודעת הדרכה למסך תשלום
  // הודעת הדרכה הוסרה - רק במסך הבית

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _createPaymentRequest() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final paymentData = await ManualPaymentService.createPaymentRequest(
        userId: user.uid,
        userEmail: user.email ?? '',
        userName: user.displayName ?? 'משתמש',
        subscriptionType: widget.subscriptionType,
      );
      
      setState(() {
        _paymentData = paymentData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה ביצירת בקשת התשלום: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    debugPrint('🖼️ _pickImage called');
    try {
      // בדיקת הרשאות תמונות - ננסה מספר אפשרויות
      PermissionStatus permission = PermissionStatus.denied;
      
      debugPrint('🔐 Checking permissions...');
      
      // ננסה קודם עם photos (Android 13+)
      try {
        permission = await Permission.photos.status;
        debugPrint('📸 Photos permission status: $permission');
        if (permission == PermissionStatus.denied) {
          debugPrint('📸 Requesting photos permission...');
          permission = await Permission.photos.request();
          debugPrint('📸 Photos permission after request: $permission');
        }
      } catch (e) {
        debugPrint('Photos permission not supported: $e');
      }
      
      // אם photos לא עובד, ננסה עם storage
      if (permission != PermissionStatus.granted) {
        try {
          permission = await Permission.storage.status;
          debugPrint('💾 Storage permission status: $permission');
          if (permission == PermissionStatus.denied) {
            debugPrint('💾 Requesting storage permission...');
            permission = await Permission.storage.request();
            debugPrint('💾 Storage permission after request: $permission');
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
      
      if (permission == PermissionStatus.permanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('הרשאה נדרשת'),
              content: const Text(
                'נדרשת הרשאת גישה לתמונות כדי לבחור תמונת תשלום.\n'
                'אנא עבור להגדרות האפליקציה והפעל את ההרשאה.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ביטול'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('פתח הגדרות'),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      if (permission != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('נדרשת הרשאת גישה לתמונות'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ננסה קודם מהגלריה
      debugPrint('🖼️ Trying to pick image from gallery...');
      XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      debugPrint('🖼️ Gallery pick result: ${image?.path ?? 'null'}');
      
      // אם לא הצליח מהגלריה, ננסה מהמצלמה
      if (image == null) {
        debugPrint('📷 Trying to pick image from camera...');
        try {
          image = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
          debugPrint('📷 Camera pick result: ${image?.path ?? 'null'}');
        } catch (e) {
          debugPrint('Camera pick failed: $e');
        }
      }
      
      if (image != null) {
        setState(() {
          _selectedImagePath = image!.path;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('תמונה נבחרה בהצלחה!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
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

  Future<void> _submitPayment() async {
    if (_selectedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אנא העלה תמונת תשלום'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // שליחת בקשה למנהל במקום הפעלה ישירה
      final success = await ManualPaymentService.submitSubscriptionRequest(
        subscriptionType: widget.subscriptionType ?? 'personal',
        amount: (widget.amount ?? 0).toDouble(),
        imageFile: XFile(_selectedImagePath!),
        note: _noteController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (success) {
        debugPrint('✅ Payment submission successful, showing confirmation dialog');
        if (mounted) {
          // הצגת דיאלוג אישור
          await _showPaymentConfirmationDialog();
        } else {
          debugPrint('❌ Widget not mounted, cannot show dialog');
        }
      } else {
        debugPrint('❌ Payment submission failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('שגיאה בשליחת בקשת המנוי'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// הצגת דיאלוג אישור לאחר שליחת תמונת תשלום
  Future<void> _showPaymentConfirmationDialog() async {
    debugPrint('🔄 Showing payment confirmation dialog');
    await showDialog(
      context: context,
      barrierDismissible: false, // לא ניתן לסגור בלחיצה מחוץ לדיאלוג
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('בקשת המנוי נקלטה!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_empty,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'הבקשה שלך נשלחה למנהל המערכת ותטופל בהקדם.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'תקבל הודעה באפליקציה לאחר שהמנהל יאשר או ידחה את הבקשה.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                debugPrint('🔄 Closing all dialogs and returning to profile');
                // סגירת כל הדיאלוגים וחזרה למסך הפרופיל
                Navigator.pop(context); // סגירת דיאלוג האישור
                Navigator.pop(context); // סגירת מסך התשלום
                // סגירת דיאלוג השדרוג אם קיים
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                debugPrint('✅ All dialogs closed, should be back to profile');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'אישור',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ ManualPaymentScreen build() called');
    final l10n = AppLocalizations.of(context);
    
    // הצגת הודעת הדרכה רק כשהמשתמש נכנס למסך התשלום
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // הודעת הדרכה הוסרה - רק במסך הבית
    });

    return Directionality(
      textDirection: l10n.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'תשלום מנוי',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF9C27B0) // סגול יפה
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          toolbarHeight: 50,
        ),
        body: _isLoading && _paymentData == null
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
                            'שולח תשלום...',
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
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // כרטיס הוראות תשלום
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'הוראות תשלום',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // הצגת פרטי המנוי החדש
                            if (widget.subscriptionType != null && widget.amount != null) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'מנוי ${widget.subscriptionType == 'personal' ? 'פרטי' : 'עסקי'}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '₪${widget.amount} לשנה',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            if (_paymentData != null) ...[
                              _buildInfoRow('סכום:', '${_paymentData!['amount']} ש״ח'),
                              _buildInfoRow('מספר BIT:', _paymentData!['bitPhoneNumber']),
                              _buildInfoRow('הערה:', _paymentData!['bitAccountName']),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              _paymentData?['instructions'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // בחירת תמונה
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'העלאת תמונת תשלום',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            if (_selectedImagePath != null) ...[
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_selectedImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            ElevatedButton.icon(
                              onPressed: () {
                                debugPrint('🖼️ Button pressed - calling _pickImage');
                                _pickImage();
                              },
                              icon: const Icon(Icons.camera_alt),
                              label: Text(_selectedImagePath == null ? 'בחר תמונה' : 'שנה תמונה'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // הערה
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'הערה (אופציונלי)',
                        labelStyle: const TextStyle(color: Colors.black87),
                        hintText: 'הוסף הערה על התשלום...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // כפתור שליחה
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
                          : const Text(
                              'שלח תמונת תשלום',
                              style: TextStyle(fontSize: 16),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
