import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

/// שירות לניהול צלילים באפליקציה
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isEnabled = true;
  double _volume = 0.7;

  void _setupAudioPlayer() {
    // הגדרת AudioPlayer
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
  }

  /// אתחול השירות
  Future<void> initialize() async {
    _setupAudioPlayer();
    await _loadSettings();
    debugPrint('🎵 AudioService initialized - enabled: $_isEnabled, volume: $_volume');
  }

  /// טעינת הגדרות צליל
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('audio_enabled') ?? true;
      _volume = prefs.getDouble('audio_volume') ?? 0.7;
    } catch (e) {
      debugPrint('Error loading audio settings: $e');
    }
  }

  /// שמירת הגדרות צליל
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio_enabled', _isEnabled);
      await prefs.setDouble('audio_volume', _volume);
    } catch (e) {
      debugPrint('Error saving audio settings: $e');
    }
  }

  /// הפעלת צליל
  Future<void> playSound(AudioEvent event) async {
    debugPrint('🎵 AudioService.playSound called: ${event.fileName}, enabled: $_isEnabled');
    
    if (!_isEnabled) {
      debugPrint('🔇 Audio disabled, skipping sound');
      return;
    }

    // ב-Web, השתמש רק בצלילי מערכת
    if (kIsWeb) {
      debugPrint('🌐 Web platform detected, using fallback sounds');
      await _playFallbackSound(event);
      return;
    }

    try {
      debugPrint('🔊 Setting volume to $_volume and playing ${event.fileName}');
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play(AssetSource('sounds/${event.fileName}'));
      debugPrint('✅ Sound played successfully');
    } catch (e) {
      debugPrint('❌ Error playing sound ${event.fileName}: $e');
      // Fallback to system sounds if audio file not found
      await _playFallbackSound(event);
    }
  }

  /// צלילי גיבוי (מערכת)
  Future<void> _playFallbackSound(AudioEvent event) async {
    try {
      switch (event) {
        case AudioEvent.buttonClick:
          await HapticFeedback.lightImpact();
          break;
        case AudioEvent.success:
        case AudioEvent.loginSuccess:
        case AudioEvent.paymentSuccess:
          await HapticFeedback.mediumImpact();
          break;
        case AudioEvent.error:
        case AudioEvent.paymentFailed:
          await HapticFeedback.heavyImpact();
          break;
        case AudioEvent.newMessage:
        case AudioEvent.newRequest:
          await HapticFeedback.mediumImpact();
          break;
        default:
          await HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error playing fallback sound: $e');
    }
  }

  /// הפעלת צליל עם חזרה
  Future<void> playSoundWithRepeat(AudioEvent event, {int repeatCount = 1}) async {
    if (!_isEnabled) return;

    try {
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play(AssetSource('sounds/${event.fileName}'));
      
      if (repeatCount > 1) {
        for (int i = 1; i < repeatCount; i++) {
          await Future.delayed(Duration(milliseconds: event.duration));
          await _audioPlayer.play(AssetSource('sounds/${event.fileName}'));
        }
      }
    } catch (e) {
      debugPrint('Error playing repeated sound ${event.fileName}: $e');
    }
  }

  /// הפעלת צליל רקע
  Future<void> playBackgroundMusic() async {
    if (!_isEnabled) return;

    try {
      await _audioPlayer.setVolume(_volume * 0.3); // נמוך יותר למוזיקת רקע
      await _audioPlayer.play(AssetSource('sounds/background_music.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  /// עצירת צליל רקע
  Future<void> stopBackgroundMusic() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping background music: $e');
    }
  }

  /// הפעלת/כיבוי צלילים
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _saveSettings();
    
    if (!enabled) {
      await stopBackgroundMusic();
    }
  }

  /// הגדרת עוצמת קול
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _saveSettings();
    await _audioPlayer.setVolume(_volume);
  }

  /// בדיקה אם צלילים מופעלים
  bool get isEnabled => _isEnabled;

  /// קבלת עוצמת קול נוכחית
  double get volume => _volume;

  /// סגירת השירות
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}

/// רשימת צלילי אירועים
enum AudioEvent {
  // UI Sounds
  buttonClick('button_click.mp3', 200),
  buttonHover('button_hover.mp3', 150),
  pageTransition('page_transition.mp3', 300),
  dropdownOpen('dropdown_open.mp3', 250),
  dropdownClose('dropdown_close.mp3', 200),
  
  // Success/Error Sounds
  success('success.mp3', 800),
  error('error.mp3', 600),
  warning('warning.mp3', 500),
  info('info.mp3', 400),
  
  // Notification Sounds
  newRequest('new_request.mp3', 1000),
  newMessage('new_message.mp3', 800),
  requestAccepted('request_accepted.mp3', 900),
  requestCompleted('request_completed.mp3', 1000),
  
  // Authentication Sounds
  loginSuccess('login_success.mp3', 800),
  logout('logout.mp3', 500),
  registrationSuccess('registration_success.mp3', 1000),
  
  // Payment Sounds
  paymentSuccess('payment_success.mp3', 1200),
  paymentFailed('payment_failed.mp3', 700),
  
  // Background Music
  backgroundMusic('background_music.mp3', 0);

  const AudioEvent(this.fileName, this.duration);
  final String fileName;
  final int duration; // משך הצליל במילישניות
}

/// Mixin להוספת צלילים ל-Widgets
mixin AudioMixin {
  final AudioService _audioService = AudioService();

  /// הפעלת צליל כפתור
  Future<void> playButtonSound() async {
    await _audioService.playSound(AudioEvent.buttonClick);
  }

  /// הפעלת צליל הצלחה
  Future<void> playSuccessSound() async {
    await _audioService.playSound(AudioEvent.success);
  }

  /// הפעלת צליל שגיאה
  Future<void> playErrorSound() async {
    await _audioService.playSound(AudioEvent.error);
  }

  /// הפעלת צליל התראה
  Future<void> playNotificationSound() async {
    await _audioService.playSound(AudioEvent.newMessage);
  }

  /// הפעלת צליל מעבר דף
  Future<void> playPageTransitionSound() async {
    await _audioService.playSound(AudioEvent.pageTransition);
  }
}
