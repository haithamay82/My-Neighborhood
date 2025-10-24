class BitConfig {
  // הגדרות BIT - יש להחליף לנתונים האמיתיים שלך
  
  /// מזהה הסוחר שלך ב-BIT
  static const String merchantId = 'YOUR_MERCHANT_ID';
  
  /// מפתח API שלך מ-BIT
  static const String apiKey = 'YOUR_API_KEY';
  
  /// URL בסיס של BIT API
  static const String baseUrl = 'https://api.bit.co.il';
  
  /// URL של האפליקציה שלך (לחזרה אחרי תשלום)
  static const String appUrl = 'https://your-app.com';
  
  /// סכום המנוי השנתי
  static const double subscriptionAmount = 10.0;
  
  /// מטבע התשלום
  static const String currency = 'ILS';
  
  /// תיאור התשלום
  static const String paymentDescription = 'מנוי שנתי - שכונתי';
  
  /// URLs לחזרה
  static String get successUrl => '$appUrl/payment/success';
  static String get cancelUrl => '$appUrl/payment/cancel';
  static String get webhookUrl => '$appUrl/webhook/bit';
  
  /// בדיקת תקינות ההגדרות
  static bool get isConfigured {
    return merchantId != 'YOUR_MERCHANT_ID' && 
           apiKey != 'YOUR_API_KEY' &&
           appUrl != 'https://your-app.com';
  }
  
  /// הודעת שגיאה אם ההגדרות לא מושלמות
  static String get configurationError {
    if (merchantId == 'YOUR_MERCHANT_ID') {
      return 'יש להגדיר מזהה סוחר BIT';
    }
    if (apiKey == 'YOUR_API_KEY') {
      return 'יש להגדיר מפתח API של BIT';
    }
    if (appUrl == 'https://your-app.com') {
      return 'יש להגדיר URL של האפליקציה';
    }
    return 'הגדרות BIT לא מושלמות';
  }
}
