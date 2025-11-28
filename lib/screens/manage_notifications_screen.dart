import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_preferences.dart';
import '../services/notification_preferences_service.dart';
import '../models/user_profile.dart';
import '../l10n/app_localizations.dart';

class ManageNotificationsScreen extends StatefulWidget {
  const ManageNotificationsScreen({super.key});

  @override
  State<ManageNotificationsScreen> createState() => _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState extends State<ManageNotificationsScreen> {
  NotificationPreferences? _preferences;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final preferences = await NotificationPreferencesService
          .getNotificationPreferencesWithDefaults(user.uid);
      
      // טעינת פרופיל המשתמש
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        _userProfile = UserProfile.fromFirestore(userDoc);
        
        // בדיקה אם המשתמש הוא מנהל
        _isAdmin = _userProfile?.userType == UserType.admin;
      }
      
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorLoadingPreferences(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.allNotificationsInNeighborhood),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_preferences == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.allNotificationsInNeighborhood),
        ),
        body: Center(child: Text(l10n.errorLoadingPreferences(''))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.allNotificationsInNeighborhood,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // בחירת מיקום לבקשות חדשות - Radio Buttons - רק למשתמשי אורח, עסקי מנוי או מנהל
            if (_userProfile?.userType == UserType.guest || 
                _userProfile?.userType == UserType.business ||
                _isAdmin) ...[
              _buildSection(
                title: l10n.notificationOptions,
                children: [
                _buildCheckbox(
                  title: l10n.requestLocationInRangeFixed,
                  value: true,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.requestLocationInRangeMobile,
                  value: true,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.requestLocationInRangeFixedOrMobile,
                  value: true,
                  enabled: false,
                  onChanged: null,
                ),
                const Divider(),
                _buildCheckbox(
                  title: l10n.notInterestedInPaidRequestNotifications,
                  value: true,
                  enabled: false,
                  onChanged: null,
                ),
              ],
              ),
            ],
            
            // התראות מנויים
            _buildSection(
              title: l10n.subscriptionNotifications,
              children: [
                _buildCheckbox(
                  title: l10n.whenSubscriptionExpires,
                  value: _preferences!.subscriptionExpiry,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.subscriptionReminderBeforeExpiry,
                  value: _preferences!.subscriptionReminder,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.guestPeriodExtensionTwoWeeks,
                  value: _preferences!.subscriptionExtension,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.subscriptionUpgrade,
                  value: _preferences!.subscriptionUpgrade,
                  enabled: false,
                  onChanged: null,
                ),
              ],
            ),
            
            // התראות מערכת
            _buildSection(
              title: l10n.requestStatusNotifications,
              children: [
                _buildCheckbox(
                  title: l10n.interestInRequest,
                  value: _preferences!.requestInterest,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.newChatMessages,
                  value: _preferences!.chatMessages,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.serviceCompletionAndRating,
                  value: _preferences!.requestCompletion,
                  enabled: false,
                  onChanged: null,
                ),
                _buildCheckbox(
                  title: l10n.radiusExpansionShareRating,
                  value: _preferences!.radiusExpansion,
                  enabled: false,
                  onChanged: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87, // טקסט כהה לראות טוב על רקע בהיר
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required String title,
    required bool value,
    ValueChanged<bool>? onChanged,
    String? subtitle,
    bool enabled = true,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: enabled ? Colors.black87 : Colors.grey,
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ) : null,
      leading: Checkbox(
        value: value,
        onChanged: enabled && onChanged != null
            ? (newValue) => onChanged(newValue ?? false)
            : null,
      ),
      onTap: enabled && onChanged != null
          ? () => onChanged(!value)
          : null,
    );
  }
}

