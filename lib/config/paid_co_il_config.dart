/// הגדרות Paid.co.il
class PaidCoIlConfig {
  // יש להחליף את הערכים האלה בנתונים האמיתיים מ-Paid.co.il
  static const String merchantId = '060606035';
  static const String apiKey = 'MPL17601-96851APW-EG42UA4J-RPUPW2AZ';
  static const String baseUrl = 'https://api.paid.co.il/v1';
  
  // URLs לחזרה מהתשלום
  static const String successUrl = 'shkonati://payment/success';
  static const String cancelUrl = 'shkonati://payment/cancel';
  
  // מטבע ברירת מחדל
  static const String defaultCurrency = 'ILS';
  
  // timeout לפעולות API
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // בדיקה אם ההגדרות מוכנות
  static bool get isConfigured {
    return merchantId != 'YOUR_MERCHANT_ID' && 
           apiKey != 'YOUR_API_KEY' &&
           merchantId.isNotEmpty && 
           apiKey.isNotEmpty;
  }
  
  // הודעת שגיאה אם ההגדרות לא מוכנות
  static String get configurationErrorMessage {
    return 'Paid.co.il לא מוגדר. אנא עדכן את ההגדרות בקובץ paid_co_il_config.dart';
  }
}
