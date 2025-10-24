# הגדרת Cloud Functions להתראות

## שלב 1: התקנת Firebase CLI
```bash
npm install -g firebase-tools
```

## שלב 2: התחברות ל-Firebase
```bash
firebase login
```

## שלב 3: אתחול הפרויקט
```bash
firebase init functions
```

## שלב 4: התקנת dependencies
```bash
cd functions
npm install
```

## שלב 5: העלאה ל-Firebase
```bash
firebase deploy --only functions
```

## שלב 6: בדיקה שהפונקציות עובדות
1. פתח את Firebase Console
2. לך ל-Functions
3. בדוק שהפונקציות `sendPushNotification` ו-`sendChatNotification` מופיעות

## הערות חשובות:
- הפונקציות יעבדו רק אחרי שתעלה אותן ל-Firebase
- ודא שיש לך הרשאות לכתוב ל-Firestore
- הפונקציות יעבדו גם כשהאפליקציה סגורה
