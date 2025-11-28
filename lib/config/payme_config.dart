/// PayMe API Configuration
/// 
/// Production credentials for PayMe Hosted Payment Page integration
class PayMeConfig {
  // Production API endpoint
  static const String baseUrl = 'https://live.payme.io/api';
  
  // API endpoint for generating sales
  static const String generateSaleEndpoint = '/generate-sale';
  
  // Production credentials
  static const String sellerPaymeId = 'MPL17601-96851APW-EG42UA4J-RPUPW2AZ';
  
  static const String apiKey = '0d93a2c3-827f-482e-9cb9-91c659c69e75';
  
  static const String returnUrl = 'https://nearme-970f3.web.app/payment/success';
  
  static const String callbackUrl = 'https://us-central1-nearme-970f3.cloudfunctions.net/paymeWebhook';
  
  // Subscription amounts (in shekels)
  // TODO: Return to production prices after testing: personal=30.0, business=70.0
  static const double personalSubscriptionAmount = 5.0; // Testing price (minimum)
  static const double businessSubscriptionAmount = 5.0; // Testing price (minimum)
  
  // API timeout
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // Language for PayMe checkout
  static const String language = 'he';
  
  // Currency
  static const String currency = 'ILS';
  
  /// Check if configuration is ready
  static bool get isConfigured {
    return sellerPaymeId.isNotEmpty &&
           apiKey.isNotEmpty &&
           returnUrl.isNotEmpty &&
           callbackUrl.isNotEmpty;
  }
  
  /// Get subscription amount based on type
  static double getSubscriptionAmount(String subscriptionType) {
    switch (subscriptionType.toLowerCase()) {
      case 'business':
        return businessSubscriptionAmount;
      case 'personal':
      default:
        return personalSubscriptionAmount;
    }
  }
  
  /// Convert shekels to agorot (multiply by 100)
  static int shekelsToAgorot(double shekels) {
    return (shekels * 100).round();
  }
  
  /// Configuration error message
  static String get configurationErrorMessage {
    return 'תשלום אונליין לא זמין כרגע. אנא פנה למנהל המערכת או השתמש בתשלום ידני.';
  }
}
