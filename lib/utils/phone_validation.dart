class PhoneValidation {
  // קידומות ישראליות נפוצות
  static const List<String> israeliPrefixes = [
    '050', '051', '052', '053', '054', '055', '056', '057', '058', '059', // סלולרי
    '02', '03', '04', '08', '09', // קווי
  ];

  // אורך מספר טלפון ישראלי (ללא קידומת)
  static const int israeliPhoneLength = 7;

  /// בדיקה אם קידומת תקינה
  static bool isValidPrefix(String prefix) {
    return israeliPrefixes.contains(prefix);
  }

  /// בדיקה אם מספר טלפון ישראלי תקין
  static bool isValidIsraeliPhone(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;
    
    // הסרת רווחים וסימנים
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // בדיקה אם מתחיל ב-0
    if (!cleanNumber.startsWith('0')) return false;
    
    // בדיקה אם יש קידומת תקינה
    for (String prefix in israeliPrefixes) {
      if (cleanNumber.startsWith(prefix)) {
        // בדיקה אם האורך נכון
        String numberWithoutPrefix = cleanNumber.substring(prefix.length);
        if (numberWithoutPrefix.length == israeliPhoneLength) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// פירוק מספר טלפון לקידומת ומספר
  static Map<String, String> parsePhoneNumber(String phoneNumber) {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    for (String prefix in israeliPrefixes) {
      if (cleanNumber.startsWith(prefix)) {
        String number = cleanNumber.substring(prefix.length);
        if (number.length == israeliPhoneLength) {
          return {
            'prefix': prefix,
            'number': number,
            'full': cleanNumber,
          };
        }
      }
    }
    
    return {
      'prefix': '',
      'number': cleanNumber,
      'full': cleanNumber,
    };
  }

  /// פורמט מספר טלפון לתצוגה
  static String formatPhoneNumber(String prefix, String number) {
    if (prefix.isEmpty || number.isEmpty) return '';
    return '$prefix-$number';
  }

  /// קבלת רשימת קידומות מקובצות
  static Map<String, List<String>> getGroupedPrefixes() {
    return {
      'סלולרי': [
        '050', '051', '052', '053', '054', '055', '056', '057', '058', '059'
      ],
      'קווי': [
        '02', '03', '04', '08', '09'
      ],
    };
  }
}
