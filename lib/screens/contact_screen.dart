import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/audio_service.dart';
import '../l10n/app_localizations.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> with AudioMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitContactForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // הוספת צליל לשליחה
      await AudioService().playSound(AudioEvent.buttonClick);

      // שמירת הפנייה ב-Firestore
      await FirebaseFirestore.instance.collection('contact_inquiries').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'message': _messageController.text.trim(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'status': 'new', // new, in_progress, resolved
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // הצגת הודעת הצלחה
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.contactSuccess),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // חזרה למסך הקודם
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error submitting contact form: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.contactError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF03A9F4),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            AudioService().playSound(AudioEvent.buttonClick);
            Navigator.pop(context);
          },
        ),
        title: Text(
          l10n.contactScreenTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              AudioService().playSound(AudioEvent.buttonClick);
              // אפשר להוסיף תפריט נוסף כאן
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // כותרת ראשית
              Text(
                l10n.contactScreenTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF03A9F4),
                ),
              ),
              const SizedBox(height: 20),

              // הודעת פתיחה
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF03A9F4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF03A9F4).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  l10n.contactScreenSubtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF03A9F4),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              
              // מידע על המפעיל
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Text(
                  l10n.contactOperatorInfo,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),

              // שדה שם
              Text(
                l10n.contactName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: l10n.contactNameHint,
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF03A9F4), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.contactNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // שדה אימייל
              Text(
                l10n.contactEmail,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: l10n.contactEmailHint,
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF03A9F4), width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.contactEmailRequired;
                  }
                  if (!value.contains('@')) {
                    return l10n.contactEmailInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // שדה הודעה
              Text(
                l10n.contactMessage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: l10n.contactMessageHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF03A9F4), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.contactMessageRequired;
                  }
                  if (value.trim().length < 10) {
                    return l10n.contactMessageTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // כפתורי פעולה
              Row(
                children: [
                  // כפתור ביטול
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () {
                        AudioService().playSound(AudioEvent.buttonClick);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF03A9F4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(
                          color: Color(0xFF03A9F4),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // כפתור שליחה
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitContactForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF03A9F4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              l10n.contactSend,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
