import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// שירות צלילים פשוט ללא קבצים חיצוניים
class SimpleAudioService {
  static final SimpleAudioService _instance = SimpleAudioService._internal();
  factory SimpleAudioService() => _instance;
  SimpleAudioService._internal();

  bool _isEnabled = true;

  /// הפעלת צליל כפתור (צליל מערכת)
  Future<void> playButtonSound() async {
    if (!_isEnabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error playing button sound: $e');
    }
  }

  /// הפעלת צליל הצלחה (צליל מערכת)
  Future<void> playSuccessSound() async {
    if (!_isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  /// הפעלת צליל שגיאה (צליל מערכת)
  Future<void> playErrorSound() async {
    if (!_isEnabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('Error playing error sound: $e');
    }
  }

  /// הפעלת צליל התראה (צליל מערכת)
  Future<void> playNotificationSound() async {
    if (!_isEnabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  /// הפעלת/כיבוי צלילים
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// בדיקה אם צלילים מופעלים
  bool get isEnabled => _isEnabled;
}
