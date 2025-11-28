# מדריך אינטגרציה מלא עם PayMe API

## ✅ מה עודכן בקוד

### 1. **API Requests (שליחה ל-PayMe)**
- ✅ הקוד שולח JSON עם `Content-Type: application/json` (כמו שדורש PayMe)
- ✅ מטפל ב-Authorization header עם API Key
- ✅ מוכן ל-Sandbox ול-Production

**מיקום:** `lib/services/payme_service.dart`

### 2. **Webhook Callbacks (קבלה מ-PayMe)**
- ✅ עודכן לטפל ב-`x-www-form-urlencoded` (לא JSON!)
- ✅ משתמש ב-Express עם bodyParser
- ✅ מטפל בכל הפורמטים האפשריים

**מיקום:** `functions/index.js` - `exports.paymeWebhook`

### 3. **הערות בקוד**
- ✅ נוספו הערות על פורמט ה-API
- ✅ נוספו הערות על פורמט ה-Webhook

---

## 📋 מה שצריך לעשות עכשיו

### שלב 1: פתיחת חשבון PayMe
1. היכנס לאתר PayMe
2. פתח חשבון סוחר
3. מלא פרטים והעלה מסמכים

### שלב 2: קבלת מפתחות API
לאחר אישור החשבון, תקבל:
- **API Key** - מפתח לאימות בקשות API
- **Merchant ID** - מזהה הסוחר שלך
- **Webhook Secret** - סוד לאימות Webhook

### שלב 3: עדכון הקוד
עדכן את `lib/config/payme_config.dart`:

```dart
// החלף את הערכים האלה:
static const String apiKey = 'המפתח_האמיתי_שלך';
static const String merchantId = 'ה-Merchant_ID_שלך';
static const String webhookSecret = 'ה-Webhook_Secret_שלך';

// עדכן את ה-URLs:
static const String successUrl = 'https://nearme-970f3.web.app/payment/success';
static const String cancelUrl = 'https://nearme-970f3.web.app/payment/cancel';
static const String webhookUrl = 'https://us-central1-nearme-970f3.cloudfunctions.net/paymeWebhook';

// שנה ל-false כשיש מפתחות אמיתיים:
static const bool useMockServer = false;
```

### שלב 4: עדכון Firebase Functions
עדכן את `functions/index.js`:

```javascript
// שורה 411 - החלף את ה-Webhook Secret:
const webhookSecret = 'ה-Webhook_Secret_האמיתי_שלך'; // מ-PayMeConfig
```

### שלב 5: פריסת Firebase Functions
```bash
cd functions
npm install
firebase deploy --only functions:paymeWebhook
```

---

## 🔧 פרטים טכניים

### API Requests (שליחה ל-PayMe)
- **פורמט:** JSON
- **Content-Type:** `application/json`
- **Authorization:** `Bearer {API_KEY}`
- **Base URL (Sandbox):** `https://sandbox.payme.io/api`
- **Base URL (Production):** `https://live.payme.io/api`

### Webhook Callbacks (קבלה מ-PayMe)
- **פורמט:** `x-www-form-urlencoded` ⚠️ (לא JSON!)
- **Method:** POST
- **Content-Type:** `application/x-www-form-urlencoded`
- **Signature:** `x-payme-signature` header (אופציונלי)

### Webhook URL
הכתובת של ה-webhook שלך:
```
https://us-central1-nearme-970f3.cloudfunctions.net/paymeWebhook
```

**חשוב:** 
- ה-URL חייב להיות HTTPS
- ה-URL חייב להיות נגיש מ-PayMe
- עדכן את ה-URL ב-PayMe Dashboard

---

## 📝 רשימת בדיקה (Checklist)

### לפני התחלה:
- [ ] פתח חשבון PayMe
- [ ] קבל מפתחות API (API Key, Merchant ID, Webhook Secret)
- [ ] עדכן את `payme_config.dart` עם המפתחות
- [ ] עדכן את `functions/index.js` עם Webhook Secret
- [ ] פרוס את Firebase Functions

### הגדרת Webhook:
- [ ] הוסף את ה-Webhook URL ב-PayMe Dashboard
- [ ] בדוק שהכתובת נגישה (HTTPS)
- [ ] בדוק שהפונקציה מטפלת ב-`x-www-form-urlencoded`

### בדיקות:
- [ ] בדוק יצירת תשלום BIT בסביבת Sandbox
- [ ] בדוק יצירת תשלום כרטיס אשראי בסביבת Sandbox
- [ ] בדוק Webhook מקבל עדכונים
- [ ] בדוק שהמנוי מופעל אוטומטית לאחר תשלום

### לפני ייצור:
- [ ] העבר מ-Sandbox ל-Production
- [ ] עדכן את המפתחות ל-Production
- [ ] עדכן את baseUrl ל-Production
- [ ] בדוק שוב את כל התהליך ב-Production

---

## ⚠️ הערות חשובות

### 1. פורמט Webhook
PayMe שולח callbacks כ-`x-www-form-urlencoded`, לא JSON!
- הקוד עודכן לטפל בזה אוטומטית
- Firebase Functions עם Express bodyParser מטפל בזה

### 2. Content-Type Header
- API requests: `Content-Type: application/json` ✅
- Webhook callbacks: `Content-Type: application/x-www-form-urlencoded` ⚠️

### 3. אבטחה
- אל תחשוף מפתחות API בקוד!
- שמור את המפתחות במקום בטוח
- השתמש ב-Webhook Secret לאימות

### 4. בדיקות
- בדוק בסביבת Sandbox לפני Production
- השתמש ב-Mock Server לבדיקות ללא מפתחות
- ודא שהכל עובד לפני המעבר לייצור

---

## 🚀 לאחר קבלת המפתחות

1. עדכן את `payme_config.dart` עם המפתחות
2. עדכן את `functions/index.js` עם Webhook Secret
3. פרוס את Firebase Functions
4. עדכן את Webhook URL ב-PayMe Dashboard
5. בדוק תשלום בדיקה
6. בדוק שהכל עובד

**הצלחה! 🎉**

