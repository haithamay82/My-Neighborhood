# הגדרת כניסה דרך רשתות חברתיות

## 1. אינסטגרם

### שלב 1: יצירת אפליקציה ב-Facebook for Developers
1. לך ל: https://developers.facebook.com/
2. צור אפליקציה חדשה
3. בחר "Consumer" או "Other"
4. הוסף את Instagram Basic Display API

### שלב 2: קבלת מפתחות
1. העתק את `App ID` ו-`App Secret`
2. עדכן ב-`lib/services/social_auth_service.dart`:
```dart
static const String _instagramClientId = 'YOUR_INSTAGRAM_APP_ID';
static const String _instagramClientSecret = 'YOUR_INSTAGRAM_APP_SECRET';
```

### שלב 3: הגדרת Redirect URI
1. הוסף: `https://your-app.com/auth/instagram`
2. החלף `your-app.com` בכתובת האמיתית של האפליקציה שלך

## 2. טיקטוק

### שלב 1: יצירת אפליקציה ב-TikTok for Developers
1. לך ל: https://developers.tiktok.com/
2. צור אפליקציה חדשה
3. בחר "Web App"

### שלב 2: קבלת מפתחות
1. העתק את `Client Key` ו-`Client Secret`
2. עדכן ב-`lib/services/social_auth_service.dart`:
```dart
static const String _tiktokClientId = 'YOUR_TIKTOK_CLIENT_KEY';
static const String _tiktokClientSecret = 'YOUR_TIKTOK_CLIENT_SECRET';
```

### שלב 3: הגדרת Redirect URI
1. הוסף: `https://your-app.com/auth/tiktok`
2. החלף `your-app.com` בכתובת האמיתית של האפליקציה שלך

## 3. פייסבוק

### שלב 1: הגדרת אפליקציה
1. לך ל: https://developers.facebook.com/
2. צור אפליקציה חדשה
3. הוסף את Facebook Login

### שלב 2: עדכון AndroidManifest.xml
1. עדכן את `facebook_app_id` ו-`facebook_client_token` ב-`android/app/src/main/res/values/strings.xml`
2. הוסף את ה-Hash של המפתח שלך

## 4. גוגל

### שלב 1: הגדרת OAuth
1. לך ל: https://console.developers.google.com/
2. צור פרויקט חדש או בחר קיים
3. הפעל את Google+ API
4. צור OAuth 2.0 credentials

### שלב 2: עדכון google-services.json
1. הורד את הקובץ החדש מ-Firebase Console
2. החלף את הקובץ הישן

## 5. בדיקה

### שלב 1: הרצת האפליקציה
```bash
flutter run --debug -d R5CW32B4RFN
```

### שלב 2: בדיקת כניסה
1. לחץ על כפתור פייסבוק - אמור לפתוח דפדפן ולבקש הרשאות
2. לחץ על כפתור גוגל - אמור לפתוח דפדפן ולבקש הרשאות
3. לחץ על כפתור אינסטגרם - אמור לפתוח דפדפן ולבקש הרשאות
4. לחץ על כפתור טיקטוק - אמור לפתוח דפדפן ולבקש הרשאות

## 6. פתרון בעיות

### בעיה: "Invalid redirect URI"
**פתרון:** ודא שה-Redirect URI זהה בדיוק למה שהגדרת בפלטפורמה

### בעיה: "App not found"
**פתרון:** ודא שה-App ID נכון ושהאפליקציה מופעלת

### בעיה: "Permission denied"
**פתרון:** ודא שהמשתמש אישר את ההרשאות

## 7. הערות חשובות

1. **אבטחה:** לעולם אל תחשוף את ה-Client Secret בקוד
2. **בדיקה:** תמיד בדוק במכשיר אמיתי, לא רק באמולטור
3. **עדכונים:** מפתחות API עלולים להשתנות, בדוק מעת לעת
4. **תיעוד:** שמור את המפתחות במקום בטוח

## 8. קישורים שימושיים

- [Instagram Basic Display API](https://developers.facebook.com/docs/instagram-basic-display-api)
- [TikTok for Developers](https://developers.tiktok.com/)
- [Facebook for Developers](https://developers.facebook.com/)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
