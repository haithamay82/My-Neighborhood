# 🔍 בדיקת API Keys ל-Web

## הבעיה:
יש 2 Browser API keys ב-Google Cloud Console, מה שיכול לגרום לקונפליקט.

## API Key שמוגדר בקוד:

### ב-`lib/firebase_options.dart`:
- **API Key:** `AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`
- **App ID:** `1:725875446445:web:a883dc3c1ebbdd960aec24`

## מה לבדוק:

### שלב 1: זהה את ה-API Keys ב-Google Cloud Console
1. לך ל-[Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
2. מצא את 2 ה-Browser keys:
   - אחד מ-**Nov 16, 2025**
   - אחד מ-**Sep 28, 2025**

### שלב 2: בדוק איזה API Key מתאים ל-Web app
1. לך ל-[Firebase Console - Project Settings](https://console.firebase.google.com/project/nearme-970f3/settings/general)
2. גלול למטה ל-**"Your apps"**
3. מצא את ה-**Web app** עם:
   - **App ID:** `1:725875446445:web:a883dc3c1ebbdd960aec24`
4. לחץ על ה-Web app כדי לראות את ה-API Key שלו

### שלב 3: השווה את ה-API Keys
- אם ה-API Key ב-Firebase Console הוא **שונה** מ-`AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`, צריך לעדכן את `firebase_options.dart`
- אם יש 2 Browser keys, ייתכן שאחד מהם לא פעיל או לא מוגדר נכון

### שלב 4: בדוק את ה-Restrictions של כל API Key
לכל Browser key, ודא ש:
- ✅ **Identity Toolkit API** מופעל
- ✅ **Firebase Authentication API** מופעל
- ✅ **Maps JavaScript API** מופעל (אם זה ה-API key של Google Maps)

### שלב 5: אם יש קונפליקט - מחק את ה-API Key הישן
1. אם אחד מה-API keys הוא ישן ולא בשימוש, מחק אותו
2. או שנה את השם שלו כדי להבדיל ביניהם

## פתרון מומלץ:

### אפשרות 1: עדכן את firebase_options.dart עם ה-API Key הנכון
1. ב-Firebase Console, העתק את ה-API Key מה-Web app
2. עדכן את `lib/firebase_options.dart` עם ה-API Key הנכון

### אפשרות 2: מחק את ה-API Key הישן
1. אם אחד מה-API keys הוא ישן ולא בשימוש, מחק אותו
2. זה ימנע קונפליקטים

## קישורים שימושיים:

- [Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
- [Firebase Console - Project Settings](https://console.firebase.google.com/project/nearme-970f3/settings/general)

