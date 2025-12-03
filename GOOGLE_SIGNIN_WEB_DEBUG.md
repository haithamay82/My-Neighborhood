# 🔍 בדיקת הגדרות Google Sign-In ב-Web

## API Keys ו-Client IDs מוגדרים:

### 1. Firebase Web API Key:
- **API Key:** `AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`
- **מיקום:** `lib/firebase_options.dart` (שורה 43)
- **שימוש:** Firebase Authentication ב-Web

### 2. Google Sign-In Client ID:
- **Client ID:** `725875446445-jlfrijsk12skri7j948on9c1jflksee4.apps.googleusercontent.com`
- **מיקום:** `web/index.html` (שורה 36)
- **שימוש:** Google OAuth 2.0 ב-Web

### 3. Google Maps API Key:
- **API Key:** `AIzaSyAGALOMmVVNl1f_xYDRXoFrgX_Z0B5HjQQ`
- **מיקום:** `web/index.html` (שורה 42)
- **שימוש:** Google Maps JavaScript API

## 🔧 בדיקות שצריך לעשות ב-Google Cloud Console:

### שלב 1: בדוק את OAuth 2.0 Client ID
1. לך ל-[Google Cloud Console](https://console.cloud.google.com/)
2. בחר את הפרויקט: `nearme-970f3`
3. לך ל-**APIs & Services** > **Credentials**
4. מצא את ה-OAuth 2.0 Client ID: `725875446445-jlfrijsk12skri7j948on9c1jflksee4`
5. לחץ עליו לעריכה

### שלב 2: בדוק את Authorized redirect URIs
ב-OAuth 2.0 Client ID, ודא שיש את ה-URIs הבאים:
- `https://nearme-970f3.web.app/__/auth/handler`
- `https://nearme-970f3.firebaseapp.com/__/auth/handler`
- `https://nearme-970f3.web.app`
- `https://nearme-970f3.firebaseapp.com`

**חשוב:** Firebase Auth משתמש ב-`/__/auth/handler` כ-redirect URI אוטומטי.

### שלב 3: בדוק את Authorized JavaScript origins
ודא שיש את ה-origins הבאים:
- `https://nearme-970f3.web.app`
- `https://nearme-970f3.firebaseapp.com`
- `http://localhost` (לפיתוח מקומי)

### שלב 4: בדוק את Firebase API Key
1. ב-**APIs & Services** > **Credentials**
2. מצא את ה-API Key: `AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`
3. ודא שהוא מופעל עבור:
   - ✅ **Identity Toolkit API**
   - ✅ **Firebase Authentication API**

### שלב 5: בדוק את Authorized domains ב-Firebase Console
1. לך ל-[Firebase Console](https://console.firebase.google.com/)
2. בחר את הפרויקט: `nearme-970f3`
3. לך ל-**Authentication** > **Settings** > **Authorized domains**
4. ודא שיש את הדומיינים הבאים:
   - ✅ `nearme-970f3.web.app`
   - ✅ `nearme-970f3.firebaseapp.com`
   - ✅ `localhost` (לפיתוח מקומי)

### שלב 6: בדוק את ה-Web app ב-Firebase Console
1. ב-Firebase Console, לך ל-**Project settings** (⚙️)
2. גלול למטה ל-**"Your apps"**
3. ודא שיש **Web app** עם:
   - **App ID:** `1:725875446445:web:a883dc3c1ebbdd960aec24`
   - **Website URL:** `https://nearme-970f3.web.app`

## 🐛 בעיות נפוצות ופתרונות:

### בעיה 1: "redirect_uri_mismatch"
**פתרון:** ודא שה-redirect URI מוגדר נכון ב-OAuth 2.0 Client ID:
- `https://nearme-970f3.web.app/__/auth/handler`
- `https://nearme-970f3.firebaseapp.com/__/auth/handler`

### בעיה 2: "access_denied"
**פתרון:** ודא שה-API key מופעל עבור Identity Toolkit API ו-Firebase Authentication API

### בעיה 3: המשתמש לא נכנס אחרי redirect
**פתרון:** 
1. בדוק את ה-console של הדפדפן (F12) לשגיאות
2. ודא ש-`getRedirectResult()` נקרא אחרי שהמשתמש חזר
3. בדוק שהדומיין מופיע ב-Authorized domains

## 📝 לוגים לבדיקה:

כאשר אתה מנסה להתחבר עם Google, בדוק את ה-console של הדפדפן (F12) לראות:
- האם יש שגיאות CORS
- האם יש שגיאות redirect_uri_mismatch
- מה ה-URL אחרי החזרה מ-Google
- האם `getRedirectResult()` מחזיר user

## 🔗 קישורים שימושיים:

- [Firebase Console](https://console.firebase.google.com/project/nearme-970f3)
- [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
- [Firebase Authentication Settings](https://console.firebase.google.com/project/nearme-970f3/authentication/settings)
- [OAuth 2.0 Client ID Settings](https://console.cloud.google.com/apis/credentials/oauthclient/725875446445-jlfrijsk12skri7j948on9c1jflksee4?project=nearme-970f3)

## 📖 מדריך מפורט לבדיקת Redirect URI:

ראה את הקובץ `GOOGLE_SIGNIN_REDIRECT_URI_CHECK.md` למדריך שלב-אחר-שלב מפורט.

