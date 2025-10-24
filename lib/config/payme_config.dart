/// הגדרות PayMe API
class PayMeConfig {
  // TODO: החלף בערכים האמיתיים מ-PayMe
  static const String baseUrl = 'https://api.payme.io/v1';
  static const String apiKey = 'YOUR_PAYME_API_KEY';
  static const String merchantId = 'YOUR_MERCHANT_ID';
  static const String webhookSecret = 'YOUR_WEBHOOK_SECRET';
  
  // URLs לחזרה מהתשלום
  static const String successUrl = 'https://yourapp.com/payment/success';
  static const String cancelUrl = 'https://yourapp.com/payment/cancel';
  static const String webhookUrl = 'https://yourapp.com/webhook/payme';
  
  // סכומי מנוי קבועים
  static const double personalSubscriptionAmount = 10.0;
  static const double businessSubscriptionAmount = 50.0;
  
  // timeout
  static const Duration apiTimeout = Duration(seconds: 30);
  
  /// בדיקה אם ההגדרות מוכנות
  static bool get isConfigured {
    return apiKey != 'YOUR_PAYME_API_KEY' && 
           merchantId != 'YOUR_MERCHANT_ID' &&
           webhookSecret != 'YOUR_WEBHOOK_SECRET';
  }
  
  /// הודעת שגיאה אם ההגדרות לא מוכנות
  static String get configurationErrorMessage {
    return 'PayMe לא מוגדר. אנא הגדר את המפתחות ב-PayMeConfig';
  }
  
  /// קבלת סכום לפי סוג מנוי
  static double getSubscriptionAmount(String subscriptionType) {
    switch (subscriptionType.toLowerCase()) {
      case 'business':
        return businessSubscriptionAmount;
      case 'personal':
      default:
        return personalSubscriptionAmount;
    }
  }
}
