# 🔍 מדריך לבדיקת Redirect URI ב-Google Cloud Console

## שלב 1: כניסה ל-Google Cloud Console

1. לך ל-[Google Cloud Console](https://console.cloud.google.com/)
2. בחר את הפרויקט: **`nearme-970f3`**
3. אם אתה לא רואה את הפרויקט, לחץ על התפריט הנפתח למעלה ובחר אותו

## שלב 2: מעבר ל-APIs & Services > Credentials

1. בתפריט השמאלי, לחץ על **"APIs & Services"**
2. לחץ על **"Credentials"** (או "מאשרים" בעברית)

## שלב 3: מציאת OAuth 2.0 Client ID

1. במסך Credentials, חפש את **"OAuth 2.0 Client IDs"**
2. מצא את ה-Client ID: **`725875446445-jlfrijsk12skri7j948on9c1jflksee4`**
3. לחץ עליו כדי לפתוח את ההגדרות

## שלב 4: בדיקת Authorized redirect URIs

ב-OAuth 2.0 Client ID, גלול למטה ל-**"Authorized redirect URIs"**

### ✅ ודא שיש את ה-URIs הבאים (כל אחד בשורה נפרדת):

```
https://nearme-970f3.web.app/__/auth/handler
https://nearme-970f3.firebaseapp.com/__/auth/handler
https://nearme-970f3.web.app
https://nearme-970f3.firebaseapp.com
```

**חשוב:**
- Firebase Auth משתמש ב-`/__/auth/handler` כ-redirect URI אוטומטי
- כל URI צריך להיות בשורה נפרדת
- אין רווחים מיותרים לפני או אחרי ה-URI

### אם אין את ה-URIs האלה:

1. לחץ על **"ADD URI"** (או "הוסף URI")
2. הוסף כל URI בנפרד:
   - `https://nearme-970f3.web.app/__/auth/handler`
   - `https://nearme-970f3.firebaseapp.com/__/auth/handler`
   - `https://nearme-970f3.web.app`
   - `https://nearme-970f3.firebaseapp.com`
3. לחץ על **"SAVE"** (או "שמור")

## שלב 5: בדיקת Authorized JavaScript origins

גלול למטה ל-**"Authorized JavaScript origins"**

### ✅ ודא שיש את ה-origins הבאים:

```
https://nearme-970f3.web.app
https://nearme-970f3.firebaseapp.com
http://localhost
```

**חשוב:**
- `http://localhost` רק לפיתוח מקומי
- כל origin צריך להיות בשורה נפרדת
- אין רווחים מיותרים

### אם אין את ה-origins האלה:

1. לחץ על **"ADD URI"** (או "הוסף URI")
2. הוסף כל origin בנפרד
3. לחץ על **"SAVE"** (או "שמור")

## שלב 6: בדיקת Firebase Console - Authorized domains

1. לך ל-[Firebase Console](https://console.firebase.google.com/project/nearme-970f3/authentication/settings)
2. בחר את הפרויקט: **`nearme-970f3`**
3. בתפריט השמאלי, לחץ על **"Authentication"**
4. לחץ על **"Settings"** (או "הגדרות")
5. גלול למטה ל-**"Authorized domains"**

### ✅ ודא שיש את הדומיינים הבאים:

- ✅ `nearme-970f3.web.app`
- ✅ `nearme-970f3.firebaseapp.com`
- ✅ `localhost` (לפיתוח מקומי)

### אם אין את הדומיינים האלה:

1. לחץ על **"ADD DOMAIN"** (או "הוסף דומיין")
2. הוסף כל דומיין בנפרד
3. לחץ על **"ADD"** (או "הוסף")

## שלב 7: בדיקת API Key

1. חזור ל-[Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
2. ב-**"API keys"**, מצא את ה-API Key: **`AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`**
3. לחץ עליו כדי לפתוח את ההגדרות

### ✅ ודא שה-API מופעל עבור:

1. לחץ על **"API restrictions"** (או "הגבלות API")
2. ודא ש-**"Identity Toolkit API"** מופעל
3. ודא ש-**"Firebase Authentication API"** מופעל

### אם ה-APIs לא מופעלים:

1. לחץ על **"Restrict key"** (או "הגבל מפתח")
2. בחר **"Restrict key to selected APIs"** (או "הגבל מפתח ל-APIs נבחרים")
3. חפש והוסף:
   - **Identity Toolkit API**
   - **Firebase Authentication API**
4. לחץ על **"SAVE"** (או "שמור")

## שלב 8: בדיקת Web app ב-Firebase Console

1. לך ל-[Firebase Console](https://console.firebase.google.com/project/nearme-970f3/settings/general)
2. בחר את הפרויקט: **`nearme-970f3`**
3. לחץ על ⚙️ (Settings) > **"Project settings"**
4. גלול למטה ל-**"Your apps"**

### ✅ ודא שיש Web app עם:

- **App ID:** `1:725875446445:web:a883dc3c1ebbdd960aec24`
- **Website URL:** `https://nearme-970f3.web.app`

### אם אין Web app:

1. לחץ על **"Add app"** > **Web** (</>)
2. הוסף **App nickname** (למשל: "שכונתי Web")
3. לחץ **"Register app"**
4. לחץ **"Continue to console"**

## ✅ סיכום - מה צריך להיות מוגדר:

### ב-Google Cloud Console - OAuth 2.0 Client ID:
- ✅ Authorized redirect URIs:
  - `https://nearme-970f3.web.app/__/auth/handler`
  - `https://nearme-970f3.firebaseapp.com/__/auth/handler`
  - `https://nearme-970f3.web.app`
  - `https://nearme-970f3.firebaseapp.com`
- ✅ Authorized JavaScript origins:
  - `https://nearme-970f3.web.app`
  - `https://nearme-970f3.firebaseapp.com`
  - `http://localhost`

### ב-Firebase Console:
- ✅ Authorized domains:
  - `nearme-970f3.web.app`
  - `nearme-970f3.firebaseapp.com`
  - `localhost`
- ✅ Web app קיים עם App ID: `1:725875446445:web:a883dc3c1ebbdd960aec24`

### ב-Google Cloud Console - API Key:
- ✅ Identity Toolkit API מופעל
- ✅ Firebase Authentication API מופעל

## 🐛 אם עדיין לא עובד אחרי הבדיקות:

1. נסה לנקות את ה-cache של הדפדפן (Ctrl+Shift+Delete)
2. נסה בדפדפן אחר או בחלון גלישה בסתר
3. בדוק את ה-console של הדפדפן (F12) לשגיאות
4. ודא שהאתר נטען מ-`https://nearme-970f3.web.app` ולא מ-`http://localhost`

## 📝 הערות חשובות:

- שינויים ב-Google Cloud Console יכולים לקחת כמה דקות להיכנס לתוקף
- אם שינית משהו, המתן 2-3 דקות לפני שתנסה שוב
- ודא שאין שגיאות כתיב ב-URIs (למשל: `nearme` ולא `near-me`)

