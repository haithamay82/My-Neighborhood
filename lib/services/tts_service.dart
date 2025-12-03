import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// שירות להמרת טקסט לדיבור (Text-to-Speech)
class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  
  /// בדיקה אם TTS זמין בפלטפורמה הנוכחית
  static bool get isAvailable => !kIsWeb;

  /// אתחול שירות TTS
  static Future<void> initialize() async {
    if (_initialized) return;
    
    // TTS לא זמין ב-web
    if (kIsWeb) {
      debugPrint('🔊 TTS not available on web platform');
      return;
    }

    try {
      debugPrint('🔊 Initializing TTS Service...');
      
      // בדיקה אם יש engines אחרים זמינים (כמו Google TTS)
      // הערה: getEngines לא עובד ב-web, אז נדלג על זה
      if (!kIsWeb) {
        try {
          final engines = await _tts.getEngines;
          debugPrint('🔊 Available TTS engines: ${engines.map((e) => e.name).toList()}');
          
          if (engines.isNotEmpty) {
            // ניסיון למצוא Google TTS engine (תומך בעברית טוב יותר)
            final googleEngine = engines.firstWhere(
              (engine) => engine.name.toLowerCase().contains('google'),
              orElse: () => engines.first,
            );
            
            if (googleEngine.name.toLowerCase().contains('google')) {
              await _tts.setEngine(googleEngine.name);
              debugPrint('🔊 Using Google TTS engine: ${googleEngine.name}');
            } else {
              debugPrint('🔊 Using default engine: ${googleEngine.name}');
            }
          } else {
            debugPrint('🔊 No engines available, using system default');
          }
        } catch (e) {
          debugPrint('🔊 Could not set engine, using default: $e');
        }
      }
      
      // בדיקה אם TTS זמין
      final languages = await _tts.getLanguages;
      debugPrint('🔊 Available TTS languages: $languages');
      
      // ניסיון להגדיר שפה לעברית
      String? selectedLanguage;
      if (languages.contains("he-IL")) {
        selectedLanguage = "he-IL";
        debugPrint('🔊 Hebrew (he-IL) is available');
      } else if (languages.contains("he")) {
        selectedLanguage = "he";
        debugPrint('🔊 Hebrew (he) is available');
      } else {
        // אם עברית לא זמינה, נשתמש בשפה הראשונה הזמינה
        if (languages.isNotEmpty) {
          selectedLanguage = languages.first;
          debugPrint('🔊 Hebrew not available, using: $selectedLanguage');
        } else {
          debugPrint('❌ No TTS languages available');
          return;
        }
      }
      
      if (selectedLanguage != null) {
        await _tts.setLanguage(selectedLanguage);
        debugPrint('🔊 TTS language set to: $selectedLanguage');
      }
      
      // הגדרת קצב דיבור
      await _tts.setSpeechRate(0.5);
      
      // הגדרת גובה קול
      await _tts.setPitch(1.0);
      
      // הגדרת עוצמת קול
      await _tts.setVolume(1.0);
      
      // בדיקה אם TTS עובד
      final engine = await _tts.getDefaultEngine;
      debugPrint('🔊 TTS Engine: $engine');
      
      _initialized = true;
      debugPrint('✅ TTS Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing TTS service: $e');
      debugPrint('❌ Error stack trace: ${StackTrace.current}');
    }
  }

  /// השמעת טקסט
  static Future<void> speak(String text) async {
    // TTS לא זמין ב-web
    if (kIsWeb) {
      debugPrint('🔊 TTS not available on web platform, skipping: "$text"');
      return;
    }
    
    try {
      debugPrint('🔊 TTS: Attempting to speak "$text"');
      
      if (!_initialized) {
        debugPrint('🔊 TTS not initialized, initializing now...');
        await initialize();
      }
      
      if (!_initialized) {
        debugPrint('❌ TTS initialization failed, cannot speak');
        return;
      }
      
      // עצירת דיבור קודם (אם יש)
      await _tts.stop();
      
      // בדיקה והגדרת שפה עברית לפני כל speak
      final languages = await _tts.getLanguages;
      debugPrint('🔊 Available languages: $languages');
      
      String? selectedLanguage;
      if (languages.contains("he-IL")) {
        selectedLanguage = "he-IL";
        debugPrint('🔊 Setting language to Hebrew (he-IL)');
      } else if (languages.contains("he")) {
        selectedLanguage = "he";
        debugPrint('🔊 Setting language to Hebrew (he)');
      } else {
        // אם עברית לא זמינה, נשתמש בשפה הראשונה הזמינה
        if (languages.isNotEmpty) {
          selectedLanguage = languages.first;
          debugPrint('🔊 Hebrew not available, using: $selectedLanguage');
        }
      }
      
      if (selectedLanguage != null) {
        await _tts.setLanguage(selectedLanguage);
        debugPrint('🔊 TTS language set to: $selectedLanguage');
        
        // בדיקה אם השפה זמינה
        final isAvailable = await _tts.isLanguageAvailable(selectedLanguage);
        debugPrint('🔊 Language "$selectedLanguage" available: $isAvailable');
      }
      
      // השמעת הטקסט
      debugPrint('🔊 Calling _tts.speak() with text: "$text"');
      
      // האזנה לאירועי TTS לפני speak
      _tts.setCompletionHandler(() {
        debugPrint('🔊 TTS: Speech completed');
      });
      
      _tts.setErrorHandler((msg) {
        debugPrint('❌ TTS Error: $msg');
        // אם יש שגיאה, ננסה לעצור ולהתחיל מחדש
        _tts.stop();
      });
      
      // המתן קצת כדי לוודא ש-TTS מוכן
      await Future.delayed(const Duration(milliseconds: 100));
      
      final result = await _tts.speak(text);
      debugPrint('🔊 TTS: speak() returned: $result');
      
      if (result != 1) {
        debugPrint('⚠️ TTS speak() returned error code: $result');
        // ננסה שוב אחרי המתנה קצרה
        await Future.delayed(const Duration(milliseconds: 200));
        final retryResult = await _tts.speak(text);
        debugPrint('🔊 TTS: retry speak() returned: $retryResult');
      }
      
      debugPrint('🔊 TTS: Speaking "$text" - should be playing now');
    } catch (e, stackTrace) {
      debugPrint('❌ Error speaking text: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  /// עצירת דיבור
  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('❌ Error stopping TTS: $e');
    }
  }

  /// בדיקה אם TTS זמין (async - בודק שפה ספציפית)
  static Future<bool> isLanguageAvailable(String language) async {
    // TTS לא זמין ב-web
    if (kIsWeb) {
      return false;
    }
    
    try {
      return await _tts.isLanguageAvailable(language) ?? false;
    } catch (e) {
      debugPrint('❌ Error checking TTS language availability: $e');
      return false;
    }
  }

  /// בדיקה אם עברית זמינה
  static Future<bool> isHebrewAvailable() async {
    // TTS לא זמין ב-web
    if (kIsWeb) {
      return false;
    }
    
    try {
      final languages = await _tts.getLanguages;
      return languages.contains("he-IL") || languages.contains("he");
    } catch (e) {
      debugPrint('❌ Error checking Hebrew availability: $e');
      return false;
    }
  }

  /// השמעת טקסט עם שפה ספציפית
  static Future<void> speakWithLanguage(String text, String language) async {
    // TTS לא זמין ב-web
    if (kIsWeb) {
      debugPrint('🔊 TTS not available on web platform, skipping: "$text"');
      return;
    }
    
    try {
      debugPrint('🔊 TTS: Attempting to speak "$text" with language: $language');
      
      if (!_initialized) {
        debugPrint('🔊 TTS not initialized, initializing now...');
        await initialize();
      }
      
      if (!_initialized) {
        debugPrint('❌ TTS initialization failed, cannot speak');
        return;
      }
      
      // עצירת דיבור קודם (אם יש)
      await _tts.stop();
      
      // בדיקה אם השפה זמינה
      final languages = await _tts.getLanguages;
      String? selectedLanguage;
      
      if (languages.contains(language)) {
        selectedLanguage = language;
      } else if (language.startsWith('eng') && languages.any((l) => l.startsWith('eng'))) {
        // אם eng-default לא זמין, נשתמש בכל eng זמין
        selectedLanguage = languages.firstWhere((l) => l.startsWith('eng'));
      } else if (languages.isNotEmpty) {
        selectedLanguage = languages.first;
      }
      
      if (selectedLanguage != null) {
        await _tts.setLanguage(selectedLanguage);
        debugPrint('🔊 TTS language set to: $selectedLanguage');
        
        final isAvailable = await _tts.isLanguageAvailable(selectedLanguage);
        debugPrint('🔊 Language "$selectedLanguage" available: $isAvailable');
      }
      
      // האזנה לאירועי TTS לפני speak
      _tts.setCompletionHandler(() {
        debugPrint('🔊 TTS: Speech completed');
      });
      
      _tts.setErrorHandler((msg) {
        debugPrint('❌ TTS Error: $msg');
        _tts.stop();
      });
      
      // המתן קצת כדי לוודא ש-TTS מוכן
      await Future.delayed(const Duration(milliseconds: 100));
      
      final result = await _tts.speak(text);
      debugPrint('🔊 TTS: speak() returned: $result');
      
      if (result != 1) {
        debugPrint('⚠️ TTS speak() returned error code: $result');
        await Future.delayed(const Duration(milliseconds: 200));
        final retryResult = await _tts.speak(text);
        debugPrint('🔊 TTS: retry speak() returned: $retryResult');
      }
      
      debugPrint('🔊 TTS: Speaking "$text" with language "$selectedLanguage" - should be playing now');
    } catch (e, stackTrace) {
      debugPrint('❌ Error speaking text with language: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }
}

