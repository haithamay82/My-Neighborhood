# מדריך בדיקת PayMe Sandbox - שלב אחר שלב

## 🎯 מה אתה צריך לעשות עכשיו:

### שלב 1: קבלת מפתחות Sandbox

#### אופציה A: יש לך חשבון PayMe
1. היכנס ל-PayMe Dashboard
2. עבור ל-**Sandbox/Test Environment**
3. קבל את המפתחות:
   - **API Key** (Sandbox)
   - **Merchant ID** (Sandbox)
   - **Webhook Secret** (Sandbox)

#### אופציה B: אין לך חשבון עדיין
**פתרון זמני - בדיקה עם Mock Server:**
1. עדכן את `payme_config.dart`:
   ```dart
   static const bool useMockServer = true;
   ```
2. השתמש ב-Mock Server URL: `https://stoplight.io/mocks/payme/payments/27034264`
3. זה יאפשר לך לבדוק את הקוד ללא מפתחות אמיתיים

### שלב 2: עדכון הקוד

#### אם יש לך מפתחות Sandbox:
עדכן את `lib/config/payme_config.dart`:

```dart
static const String baseUrl = 'https://sandbox.payme.io/api'; // כבר מעודכן ✅
static const String apiKey = 'המפתח_Sandbox_שלך';
static const String merchantId = 'ה-Merchant_ID_Sandbox_שלך';
static const String webhookSecret = 'ה-Webhook_Secret_Sandbox_שלך';
```

#### אם אין לך מפתחות (Mock Server):
```dart
static const String baseUrl = 'https://stoplight.io/mocks/payme/payments/27034264';
static const bool useMockServer = true;
```

### שלב 3: הגדרת Webhook (לבדיקה)

#### אופציה 1: ngrok (קל ומהיר)
```bash
# התקן ngrok: https://ngrok.com/download
# הרץ:
ngrok http 3000

# תקבל URL כמו: https://abc123.ngrok.io
# עדכן את webhookUrl ב-payme_config.dart:
static const String webhookUrl = 'https://abc123.ngrok.io/webhook/payme';
```

#### אופציה 2: Firebase Cloud Functions (מומלץ לייצור)
```javascript
// functions/index.js
exports.paymeWebhook = functions.https.onRequest(async (req, res) => {
  // טיפול ב-webhook
  const webhookData = req.body;
  await PayMeService.handlePaymentWebhook(webhookData);
  res.status(200).send('OK');
});
```

#### אופציה 3: שירות זמני לבדיקה
- **Webhook.site** - https://webhook.site
- העתק את ה-URL הייחודי שלך
- עדכן את `webhookUrl` ב-`payme_config.dart`

### שלב 4: בדיקת התשלום

1. **הרץ את האפליקציה:**
   ```bash
   flutter run
   ```

2. **נסה ליצור תשלום:**
   - עבור למסך פרופיל
   - לחץ על "רכישת מנוי"
   - בחר BIT או כרטיס אשראי
   - בדוק שהתשלום נוצר

3. **בדוק את הלוגים:**
   - חפש הודעות `💳 Creating PayMe...`
   - חפש הודעות `✅ PayMe payment created successfully`
   - אם יש שגיאה, חפש `❌`

### שלב 5: בדיקת Webhook

1. **אם השתמשת ב-webhook.site:**
   - פתח את ה-URL הייחודי שלך
   - תראה את כל ה-Webhooks שהתקבלו

2. **אם השתמשת ב-ngrok:**
   - בדוק את הלוגים של ngrok
   - תראה את הבקשות שהתקבלו

## 🔍 איך לבדוק שהכל עובד:

### בדיקה 1: האם המפתחות מוגדרים?
```dart
// בקוד, בדוק:
if (PayMeConfig.isConfigured) {
  print('✅ PayMe מוגדר נכון');
} else {
  print('❌ PayMe לא מוגדר - עדכן את המפתחות');
}
```

### בדיקה 2: יצירת תשלום
- נסה ליצור תשלום BIT
- נסה ליצור תשלום כרטיס אשראי
- בדוק שהתגובה מכילה `paymentUrl`

### בדיקה 3: Webhook
- לאחר תשלום (אפילו בדמה), בדוק שה-Webhook התקבל
- בדוק שהמנוי הופעל ב-Firestore

## 📝 רשימת בדיקה מהירה:

- [ ] עדכנתי את `baseUrl` ל-Sandbox
- [ ] עדכנתי את `apiKey` (או הגדרתי Mock Server)
- [ ] עדכנתי את `merchantId` (או הגדרתי Mock Server)
- [ ] עדכנתי את `webhookUrl` (ngrok/webhook.site/Firebase)
- [ ] בדקתי ש-`isConfigured` מחזיר `true`
- [ ] ניסיתי ליצור תשלום BIT
- [ ] ניסיתי ליצור תשלום כרטיס אשראי
- [ ] בדקתי שה-Webhook מתקבל

## ⚠️ הערות חשובות:

1. **Sandbox לא עולה כסף** - כל התשלומים הם בדמה
2. **Mock Server** - מאפשר בדיקה ללא מפתחות אמיתיים
3. **Webhook חייב להיות HTTPS** - אל תשתמש ב-HTTP
4. **שמור את המפתחות בסוד** - אל תעלה אותם ל-Git

## 🐛 פתרון בעיות:

### שגיאה: "PayMe לא מוגדר"
**פתרון:** ודא שהמפתחות לא שווים ל-'YOUR_PAYME_API_KEY' וכו'

### שגיאה: "Network error"
**פתרון:** 
- בדוק את החיבור לאינטרנט
- ודא שה-`baseUrl` נכון (Sandbox: `https://sandbox.payme.io/api`)

### Webhook לא מתקבל
**פתרון:**
- ודא שה-URL הוא HTTPS
- בדוק שה-URL נגיש מהאינטרנט (לא localhost)
- השתמש ב-ngrok או webhook.site לבדיקה

## 🚀 לאחר שהכל עובד ב-Sandbox:

1. **בדוק הכל שוב** - ודא שהכל עובד מושלם
2. **עבור ל-Production** - רק לאחר בדיקה מלאה
3. **עדכן את המפתחות** - השתמש במפתחות Production
4. **עדכן את baseUrl** - ל-`https://live.payme.io/api`

**בהצלחה! 🎉**

