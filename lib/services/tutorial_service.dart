import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _tutorialKeyPrefix = 'tutorial_';
  static const String _readTutorialPrefix = 'read_tutorial_';
  
  // מפתחות ההודעות (להתאמה לאחור)
  static const String homeScreenTutorial = 'home_screen_tutorial';
  static const String profileTutorial = 'profile_tutorial';
  static const String newRequestTutorial = 'new_request_tutorial';
  static const String chatTutorial = 'chat_tutorial';
  static const String notificationsTutorial = 'notifications_tutorial';
  static const String paymentTutorial = 'payment_tutorial';
  static const String myRequestsTutorial = 'my_requests_tutorial';
  
  // בדיקה אם ההודעה כבר הוצגה (להתאמה לאחור)
  static Future<bool> hasSeenTutorial(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_tutorialKeyPrefix$tutorialKey') ?? false;
  }
  
  // סימון שההודעה הוצגה (להתאמה לאחור)
  static Future<void> markTutorialAsSeen(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_tutorialKeyPrefix$tutorialKey', true);
  }
  
  // בדיקה אם הדרכה נקראה במדריך המרכזי
  static Future<bool> hasReadTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_readTutorialPrefix$tutorialId') ?? false;
  }
  
  // סימון שהדרכה נקראה במדריך המרכזי
  static Future<void> markTutorialAsRead(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_readTutorialPrefix$tutorialId', true);
  }
  
  // בדיקה אם יש הדרכות שלא נקראו
  static Future<bool> hasUnreadTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    
    // רשימת כל הדרכות
    final allTutorials = [
      'home_basics', 'home_search',
      'create_request', 'manage_requests',
      'chat_basics', 'chat_advanced',
      'profile_setup', 'subscription',
    ];
    
    for (final tutorialId in allTutorials) {
      final hasRead = prefs.getBool('$_readTutorialPrefix$tutorialId') ?? false;
      if (!hasRead) {
        return true; // יש לפחות הדרכה אחת שלא נקראה
      }
    }
    
    return false; // כל ההדרכות נקראו
  }
  
  // איפוס כל ההודעות (לצורך בדיקות)
  static Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      homeScreenTutorial,
      profileTutorial,
      newRequestTutorial,
      chatTutorial,
      notificationsTutorial,
      paymentTutorial,
      myRequestsTutorial,
    ];
    
    for (final key in keys) {
      await prefs.remove('$_tutorialKeyPrefix$key');
    }
    
    // איפוס גם הדרכות המדריך המרכזי
    final allTutorials = [
      'home_basics', 'home_search',
      'create_request', 'manage_requests',
      'chat_basics', 'chat_advanced',
      'profile_setup', 'subscription',
    ];
    
    for (final tutorialId in allTutorials) {
      await prefs.remove('$_readTutorialPrefix$tutorialId');
    }
  }
}
