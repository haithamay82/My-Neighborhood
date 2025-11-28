# הסבר על שגיאת 404 ב-PayMe API

## ❓ מה זה אומר?

כשניגשים ל-`https://sandbox.payme.io/api/` בדפדפן ומקבלים שגיאת 404 - **זה נורמלי לחלוטין!**

## ✅ למה זה קורה?

### API Endpoints לא מיועדים לדפדפן

API endpoints (כמו PayMe) **לא מיועדים לגישה ישירה דרך דפדפן**. הם מיועדים לקריאות HTTP מ-API clients (כמו האפליקציה שלך).

### מה קורה בדפדפן:
- דפדפן מבקש דף HTML
- השרת מחזיר 404 כי אין דף HTML ב-`/api/`
- זה נורמלי!

### מה קורה באפליקציה:
- האפליקציה שולחת בקשה HTTP POST עם:
  - Headers (Authorization, Content-Type)
  - Body (JSON עם פרטי התשלום)
- השרת מקבל את הבקשה ומחזיר תגובה JSON
- זה עובד!

## 🔍 איך לבדוק שהכל עובד?

### בדיקה 1: בדוק את הקוד
```dart
// הקוד שלך שולח בקשה ל:
baseUrl + '/payments'
// כלומר: https://sandbox.payme.io/api/payments

// עם headers:
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

// ועם body (JSON):
{
  "merchant_id": "...",
  "amount": 10.0,
  "currency": "ILS",
  ...
}
```

### בדיקה 2: הרץ את האפליקציה
1. הרץ את האפליקציה:
   ```bash
   flutter run
   ```

2. נסה ליצור תשלום:
   - עבור למסך פרופיל
   - לחץ על "רכישת מנוי"
   - בחר BIT או כרטיס אשראי

3. בדוק את הלוגים:
   - חפש: `💳 Creating PayMe...`
   - אם יש שגיאה: `❌ PayMe payment creation failed`
   - אם הצליח: `✅ PayMe payment created successfully`

### בדיקה 3: בדוק את התגובה
אם התשלום נוצר בהצלחה, תראה:
- `payment_id` - מזהה התשלום
- `payment_url` - קישור לדף התשלום
- `status` - סטטוס התשלום

## 📝 מה צריך לעשות?

### 1. ודא שהמפתחות מוגדרים
עדכן את `lib/config/payme_config.dart`:
```dart
static const String apiKey = 'המפתח_האמיתי_שלך';
static const String merchantId = 'ה-Merchant_ID_שלך';
static const String webhookSecret = 'ה-Webhook_Secret_שלך';
```

### 2. בדוק שהכל עובד באפליקציה
- הרץ את האפליקציה
- נסה ליצור תשלום
- בדוק את הלוגים

### 3. אל תנסה לבדוק בדפדפן
- API endpoints לא עובדים בדפדפן
- זה נורמלי שתקבל 404
- הקוד באפליקציה יעבוד נכון

## 🎯 סיכום

| מה | תוצאה | האם זה נורמלי? |
|---|---|---|
| גישה ל-`/api/` בדפדפן | 404 Error | ✅ כן - נורמלי! |
| קריאה מ-API client (אפליקציה) | תגובה JSON | ✅ כן - זה אמור לעבוד |

## ⚠️ אם יש שגיאה באפליקציה

אם אתה מקבל שגיאה באפליקציה (לא בדפדפן), בדוק:

1. **האם המפתחות מוגדרים?**
   ```dart
   if (PayMeConfig.isConfigured) {
     print('✅ מוגדר נכון');
   } else {
     print('❌ עדכן את המפתחות');
   }
   ```

2. **מה השגיאה בלוגים?**
   - חפש `❌` בלוגים
   - בדוק את הודעת השגיאה

3. **האם ה-URL נכון?**
   - Sandbox: `https://sandbox.payme.io/api`
   - Production: `https://live.payme.io/api`

## 🚀 המשך לבדיקה

עכשיו שאתה יודע שזה נורמלי, המשך לבדוק באפליקציה:
1. עדכן את המפתחות
2. הרץ את האפליקציה
3. נסה ליצור תשלום
4. בדוק את הלוגים

**הכל בסדר! 🎉**

