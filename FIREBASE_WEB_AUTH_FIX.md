# 🔧 תיקון שגיאת Firebase Auth ב-Web

## השגיאה:
```
Error [.firebase_auth/requests-from-this-android-client-application-<empty>-are-blocked[
```

## הסיבה:
Firebase Auth מנסה להשתמש ב-Android client application ID גם ב-Web, מה שגורם לשגיאה.

## הפתרון:

### 1. בדוק את הגדרות Firebase Console:

#### שלב 1: פתח Firebase Console
1. לך ל-[Firebase Console](https://console.firebase.google.com/)
2. בחר את הפרויקט: `nearme-970f3`

#### שלב 2: בדוק שה-Web app מוגדר נכון
1. לחץ על ⚙️ (Settings) > **Project settings**
2. גלול למטה ל-**"Your apps"**
3. ודא שיש **Web app** עם:
   - **App ID:** `1:725875446445:web:1399519fbff5bf9b0aec24`
   - **App nickname:** (אם יש)
   - **Website URL:** `https://nearme-970f3.web.app`

#### שלב 3: אם אין Web app, הוסף אחד:
1. לחץ על **"Add app"** > **Web** (</>)
2. הוסף **App nickname** (למשל: "שכונתי Web")
3. לחץ **"Register app"**
4. העתק את ה-**Firebase configuration** (אם נדרש)
5. לחץ **"Continue to console"**

#### שלב 4: הפעל Email/Password Authentication
1. לך ל-**Authentication** > **Sign-in method**
2. לחץ על **Email/Password**
3. ודא ש-**Enable** מופעל
4. לחץ **"Save"**

#### שלב 5: בדוק את Authorized domains
1. ב-**Authentication** > **Settings** > **Authorized domains**
2. ודא שהדומיין הבא מופיע:
   - `nearme-970f3.web.app`
   - `nearme-970f3.firebaseapp.com`
   - `localhost` (לפיתוח מקומי)

### 2. בדוק את firebase_options.dart:
ודא שה-Web configuration נכון:
```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'AIzaSyBhAEQ7wNaBH1nmtRs51WqZPGHfPoRtFQs',
  appId: '1:725875446445:web:1399519fbff5bf9b0aec24',
  messagingSenderId: '725875446445',
  projectId: 'nearme-970f3',
  authDomain: 'nearme-970f3.firebaseapp.com',
  storageBucket: 'nearme-970f3.firebasestorage.app',
);
```

### 3. אם עדיין לא עובד:

#### נסה לרענן את Firebase configuration:
1. ב-Firebase Console, לך ל-**Project settings**
2. בחר את ה-**Web app**
3. לחץ על **"Download configuration"** (אם יש)
4. או **"Regenerate key"** (אם יש)

#### בדוק את ה-API Key:
1. לך ל-[Google Cloud Console](https://console.cloud.google.com/)
2. בחר את הפרויקט: `nearme-970f3`
3. לך ל-**APIs & Services** > **Credentials**
4. מצא את ה-API Key: `AIzaSyBhAEQ7wNaBH1nmtRs51WqZPGHfPoRtFQs`
5. ודא שהוא מופעל עבור:
   - **Firebase Authentication API**
   - **Identity Toolkit API**

### 4. בדיקה:
1. פתח את האתר: https://nearme-970f3.web.app
2. נסה להירשם דרך "התחבר עם שכונתי"
3. ודא שההרשמה עובדת ללא שגיאות

## אם עדיין לא עובד:
1. בדוק את ה-console של הדפדפן (F12) לשגיאות נוספות
2. בדוק את ה-Firebase Console > Authentication > Users (אם המשתמש נוצר למרות השגיאה)
3. פנה לתמיכה של Firebase

## הערות:
- השגיאה מתרחשת כי Firebase מנסה להשתמש ב-Android client application ID גם ב-Web
- זה קורה כש-Firebase Console לא מזהה נכון את ה-Web app
- הפתרון הוא לוודא שה-Web app מוגדר נכון ב-Firebase Console

