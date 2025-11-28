# מדריך הגדרת PayMe - שלב אחר שלב

## ✅ מה אפשר לעשות כבר עכשיו (לפני פרסום בחנויות):

### 1. **פיתוח ובדיקה**
- ✅ הקוד כבר מוכן ומחובר ל-PayMe API
- ✅ אפשר לפתח ולבדוק עם סביבת Sandbox/Test
- ✅ אפשר לבדוק את כל הפונקציונליות לפני הפרסום

### 2. **מה שצריך לעשות:**

#### שלב 1: פתיחת חשבון PayMe
1. היכנס לאתר PayMe
2. פתח חשבון סוחר חדש
3. מלא את כל הפרטים הנדרשים
4. העלה מסמכים (אם נדרש)

#### שלב 2: קבלת מפתחות API
לאחר פתיחת החשבון, תקבל:
- **API Key** - מפתח לאימות בקשות API
- **Merchant ID** - מזהה הסוחר שלך
- **Webhook Secret** - סוד לאימות Webhook

#### שלב 3: הגדרת כתובות URL
צריך להגדיר 3 כתובות:

**לבדיקה (Test/Sandbox):**
```dart
successUrl = 'https://your-test-server.com/payment/success'
cancelUrl = 'https://your-test-server.com/payment/cancel'
webhookUrl = 'https://your-test-server.com/webhook/payme'
```

**לייצור (Production):**
```dart
successUrl = 'https://your-app.com/payment/success'
cancelUrl = 'https://your-app.com/payment/cancel'
webhookUrl = 'https://your-app.com/webhook/payme'
```

**הערה:** אם אין לך שרת, אפשר להשתמש ב:
- Firebase Cloud Functions (מומלץ)
- שירותים כמו ngrok לבדיקה מקומית
- או להגדיר URL זמני לבדיקה

#### שלב 4: עדכון הקוד
עדכן את הקובץ `lib/config/payme_config.dart`:

```dart
static const String apiKey = 'המפתח_האמיתי_שלך';
static const String merchantId = 'ה-Merchant_ID_שלך';
static const String webhookSecret = 'ה-Webhook_Secret_שלך';
static const String successUrl = 'הכתובת_האמיתית_שלך';
static const String cancelUrl = 'הכתובת_האמיתית_שלך';
static const String webhookUrl = 'הכתובת_האמיתית_שלך';
```

## 📋 רשימת בדיקה (Checklist):

### לפני התחלה:
- [ ] פתח חשבון PayMe
- [ ] קבל מפתחות API (API Key, Merchant ID, Webhook Secret)
- [ ] הגדר שרת Webhook (או Firebase Cloud Functions)
- [ ] עדכן את `payme_config.dart` עם המפתחות

### בדיקות:
- [ ] בדוק יצירת תשלום BIT בסביבת Test
- [ ] בדוק יצירת תשלום כרטיס אשראי בסביבת Test
- [ ] בדוק Webhook מקבל עדכונים
- [ ] בדוק שהמנוי מופעל אוטומטית לאחר תשלום

### לפני ייצור:
- [ ] העבר מ-Sandbox ל-Production
- [ ] עדכן את המפתחות ל-Production
- [ ] בדוק שוב את כל התהליך ב-Production
- [ ] ודא שהאפליקציה מוכנה לפרסום

## 🔧 פתרונות לבעיות נפוצות:

### אין לי שרת Webhook:
**פתרון 1: Firebase Cloud Functions (מומלץ)**
```javascript
// functions/index.js
exports.paymeWebhook = functions.https.onRequest(async (req, res) => {
  // טיפול ב-webhook
});
```

**פתרון 2: ngrok לבדיקה מקומית**
```bash
ngrok http 3000
# תקבל URL זמני כמו: https://abc123.ngrok.io
```

### איך לבדוק בלי אפליקציה בחנויות:
- ✅ אפשר לבדוק עם APK/IPA מקומי
- ✅ אפשר לבדוק עם TestFlight (iOS) או Internal Testing (Android)
- ✅ אפשר לבדוק עם Emulator/Simulator

## 📞 יצירת קשר עם PayMe:

### דרכים ליצירת קשר:
1. **אתר:** https://www.payme.io (או האתר הרשמי שלהם)
2. **אימייל:** support@payme.io (או האימייל הרשמי שלהם)
3. **טלפון:** [מספר הטלפון שלהם]
4. **צ'אט:** דרך האתר שלהם

### מה לשאול:
- איך פותחים חשבון סוחר?
- מה המסמכים הנדרשים?
- האם יש סביבת Sandbox לבדיקות?
- מה זמן הטיפול בפתיחת חשבון?
- מה העמלות?

## ⚠️ הערות חשובות:

1. **אל תחשוף מפתחות API בקוד!**
   - השתמש ב-environment variables
   - או בקובץ נפרד שלא נשמר ב-Git

2. **בדוק בסביבת Test לפני Production**
   - אל תשתמש במפתחות ייצור בבדיקות
   - ודא שהכל עובד לפני המעבר לייצור

3. **שמור גיבוי של המפתחות**
   - שמור את המפתחות במקום בטוח
   - אל תשתף אותם עם אחרים

4. **Webhook חייב להיות HTTPS**
   - PayMe לא שולח Webhook ל-HTTP
   - ודא שיש לך SSL Certificate

## 🚀 לאחר קבלת המפתחות:

1. עדכן את `payme_config.dart`
2. בדוק שהפונקציה `isConfigured` מחזירה `true`
3. נסה ליצור תשלום בדיקה
4. בדוק שהכל עובד

**הצלחה! 🎉**

