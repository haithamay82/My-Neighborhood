# הגדרת תשלומי BIT באפליקציה

## שלב 1: רישום ב-BIT

1. היכנס לאתר [BIT](https://bit.co.il)
2. צור חשבון סוחר חדש
3. השלם את תהליך האימות
4. קבל את פרטי החשבון:
   - **Merchant ID** - מזהה הסוחר שלך
   - **API Key** - מפתח API לתשלומים

## שלב 2: הגדרת האפליקציה

### עדכון קובץ ההגדרות

ערוך את הקובץ `lib/config/bit_config.dart`:

```dart
class BitConfig {
  // החלף את הערכים הבאים לנתונים האמיתיים שלך
  static const String merchantId = 'YOUR_ACTUAL_MERCHANT_ID';
  static const String apiKey = 'YOUR_ACTUAL_API_KEY';
  static const String appUrl = 'https://your-actual-app.com';
  
  // שאר ההגדרות נשארות כמו שהן
}
```

### הגדרת URLs

1. **Success URL**: `https://your-app.com/payment/success`
2. **Cancel URL**: `https://your-app.com/payment/cancel`
3. **Webhook URL**: `https://your-app.com/webhook/bit`

## שלב 3: הגדרת Webhook

### יצירת Cloud Function (מומלץ)

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { WebhookHandler } = require('./webhook_handler');

exports.bitWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const result = await WebhookHandler.handleBitWebhook(req.body);
    res.status(200).json(result);
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

### או שרת פשוט

```javascript
const express = require('express');
const app = express();

app.post('/webhook/bit', async (req, res) => {
  try {
    const result = await WebhookHandler.handleBitWebhook(req.body);
    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});
```

## שלב 4: בדיקת התשלום

1. הרץ את האפליקציה
2. עבור למסך פרופיל
3. בחר "עסקי" כסוג משתמש
4. לחץ על "הפעל מנוי"
5. בדוק שהדפדפן נפתח עם דף התשלום של BIT

## שלב 5: מעקב אחר תשלומים

### ב-Firestore

התשלומים נשמרים ב-2 אוספים:

1. **payments** - פרטי התשלומים
2. **payment_logs** - לוגים של webhooks

### שאילתות לדוגמה

```javascript
// כל התשלומים של משתמש
db.collection('payments')
  .where('userId', '==', 'USER_ID')
  .orderBy('createdAt', 'desc')
  .get();

// תשלומים ממתינים
db.collection('payments')
  .where('status', '==', 'pending')
  .get();

// תשלומים מוצלחים
db.collection('payments')
  .where('status', '==', 'completed')
  .get();
```

## שלב 6: אבטחה

### הגנת Webhook

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  return signature === expectedSignature;
}
```

### הגבלת גישה

```javascript
// בדיקת IP של BIT
const allowedIPs = ['1.2.3.4', '5.6.7.8']; // IPs של BIT
if (!allowedIPs.includes(req.ip)) {
  return res.status(403).json({ error: 'Forbidden' });
}
```

## שלב 7: ניטור ושגיאות

### לוגים

```javascript
console.log('Payment created:', {
  paymentId: paymentId,
  userId: userId,
  amount: amount,
  timestamp: new Date()
});
```

### התראות

```javascript
// שליחת התראה על תשלום מוצלח
await admin.messaging().send({
  token: userToken,
  notification: {
    title: 'תשלום הושלם',
    body: 'המנוי שלך הופעל בהצלחה!'
  }
});
```

## בעיות נפוצות

### 1. שגיאת הגדרות
```
BIT configuration error: יש להגדיר מזהה סוחר BIT
```
**פתרון**: עדכן את `merchantId` ב-`bit_config.dart`

### 2. שגיאת API
```
BIT Payment Error: 401 - Unauthorized
```
**פתרון**: בדוק את `apiKey` ב-`bit_config.dart`

### 3. Webhook לא עובד
**פתרון**: 
- בדוק שה-URL נגיש
- וודא שהפונקציה מחזירה 200
- בדוק את הלוגים

### 4. תשלום לא מתעדכן
**פתרון**: 
- בדוק את ה-webhook
- הרץ `checkPendingPayments()` ידנית
- בדוק את Firestore

## תמיכה

לבעיות נוספות:
- [תיעוד BIT](https://bit.co.il/docs)
- [תמיכה טכנית BIT](https://bit.co.il/support)
- [Firebase Functions](https://firebase.google.com/docs/functions)
