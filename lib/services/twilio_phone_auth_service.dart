import 'package:twilio_flutter/twilio_flutter.dart';
import 'package:flutter/foundation.dart';

class TwilioPhoneAuthService {
  static final TwilioFlutter _twilioFlutter = TwilioFlutter(
    accountSid: 'YOUR_ACCOUNT_SID', // החלף ב-Account SID שלך
    authToken: 'YOUR_AUTH_TOKEN',   // החלף ב-Auth Token שלך
    twilioNumber: 'YOUR_TWILIO_NUMBER', // החלף במספר הטלפון של Twilio שלך
  );

  /// שליחת קוד אימות לטלפון
  static Future<bool> sendVerificationCode(String phoneNumber) async {
    try {
      // הוסף את קוד המדינה אם לא קיים
      String formattedNumber = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        if (phoneNumber.startsWith('0')) {
          // אם המספר מתחיל ב-0, החלף ב-+972
          formattedNumber = '+972${phoneNumber.substring(1)}';
        } else {
          // אחרת הוסף +972
          formattedNumber = '+972$phoneNumber';
        }
      }

      // שליחת SMS
      await _twilioFlutter.sendSMS(
        toNumber: formattedNumber,
        messageBody: 'קוד האימות שלך: 123456', // בפועל, השתמש בקוד אקראי
      );

      return true;
    } catch (e) {
      debugPrint('שגיאה בשליחת SMS: $e');
      return false;
    }
  }

  /// אימות קוד
  static Future<bool> verifyCode(String phoneNumber, String code) async {
    // בפועל, תצטרך לבדוק את הקוד מול השרת שלך
    // כרגע נחזיר true רק אם הקוד הוא 123456
    return code == '123456';
  }

  /// בדיקת תקינות מספר טלפון
  static bool isValidPhoneNumber(String phoneNumber) {
    // הסר רווחים ותווים מיוחדים
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // בדוק אם המספר תקין
    if (cleanNumber.startsWith('+972')) {
      return cleanNumber.length == 13; // +972 + 9 ספרות
    } else if (cleanNumber.startsWith('0')) {
      return cleanNumber.length == 10; // 0 + 9 ספרות
    }
    
    return false;
  }

  /// פורמט מספר טלפון לתצוגה
  static String formatPhoneNumber(String phoneNumber) {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (cleanNumber.startsWith('+972')) {
      return '+972-${cleanNumber.substring(4, 7)}-${cleanNumber.substring(7)}';
    } else if (cleanNumber.startsWith('0')) {
      return '0${cleanNumber.substring(1, 4)}-${cleanNumber.substring(4)}';
    }
    
    return phoneNumber;
  }
}
