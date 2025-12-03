# 🔧 תיקון בעיית 2 Browser API Keys

## הבעיה:
יש 2 Browser API keys ב-Google Cloud Console, מה שיכול לגרום לקונפליקט ב-Google Sign-In.

## API Key שמוגדר בקוד:

### ב-`lib/firebase_options.dart`:
- **API Key:** `AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`
- **App ID:** `1:725875446445:web:a883dc3c1ebbdd960aec24`

## מה לעשות:

### שלב 1: בדוק איזה API Key מוגדר ב-Firebase Console
1. לך ל-[Firebase Console - Project Settings](https://console.firebase.google.com/project/nearme-970f3/settings/general)
2. גלול למטה ל-**"Your apps"**
3. מצא את ה-**Web app** עם:
   - **App ID:** `1:725875446445:web:a883dc3c1ebbdd960aec24`
4. לחץ על ה-Web app כדי לראות את ה-API Key שלו
5. **העתק את ה-API Key** שמוצג שם

### שלב 2: השווה את ה-API Keys
- אם ה-API Key ב-Firebase Console הוא **שונה** מ-`AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`, צריך לעדכן את `firebase_options.dart`
- אם ה-API Key ב-Firebase Console הוא **זהה** ל-`AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`, אז הקוד נכון

### שלב 3: בדוק את ה-API Keys ב-Google Cloud Console
1. לך ל-[Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
2. מצא את 2 ה-Browser keys:
   - אחד מ-**Nov 16, 2025**
   - אחד מ-**Sep 28, 2025**
3. לחץ על כל אחד מהם ובדוק:
   - איזה API Key זה (לחץ על "Show key")
   - איזה Restrictions יש לו
   - האם הוא מופעל עבור **Identity Toolkit API** ו-**Firebase Authentication API**

### שלב 4: פתרון - בחר את ה-API Key הנכון

#### אפשרות 1: עדכן את firebase_options.dart
אם ה-API Key ב-Firebase Console שונה מהקוד:
1. העתק את ה-API Key מה-Firebase Console
2. עדכן את `lib/firebase_options.dart`:
   ```dart
   static const FirebaseOptions web = FirebaseOptions(
     apiKey: 'YOUR_API_KEY_FROM_FIREBASE_CONSOLE', // עדכן כאן
     appId: '1:725875446445:web:a883dc3c1ebbdd960aec24',
     // ...
   );
   ```

#### אפשרות 2: מחק את ה-API Key הישן
אם אחד מה-API keys הוא ישן ולא בשימוש:
1. ב-Google Cloud Console, לחץ על ה-API Key הישן
2. לחץ על "DELETE" (מחק)
3. זה ימנע קונפליקטים

#### אפשרות 3: ודא ששני ה-API Keys מוגדרים נכון
אם שני ה-API keys פעילים:
1. ודא ששניהם מופעלים עבור:
   - ✅ **Identity Toolkit API**
   - ✅ **Firebase Authentication API**
2. ודא ששניהם מוגדרים עם ה-Restrictions הנכונים

## ⚠️ חשוב:
- Firebase Auth צריך להשתמש ב-API Key שמוגדר ב-`firebase_options.dart`
- אם יש קונפליקט בין 2 API keys, זה יכול לגרום לבעיות ב-Google Sign-In
- עדיף להשתמש ב-API Key אחד בלבד ל-Web

## קישורים שימושיים:

- [Firebase Console - Project Settings](https://console.firebase.google.com/project/nearme-970f3/settings/general)
- [Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)

