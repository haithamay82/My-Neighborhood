# הגדרת Google Maps API

## שלב 1: יצירת פרויקט ב-Google Cloud Console

1. לך ל-[Google Cloud Console](https://console.cloud.google.com/)
2. התחבר עם חשבון Google שלך
3. לחץ על "Select a project" או "בחר פרויקט"
4. לחץ על "New Project" או "פרויקט חדש"
5. הזן שם לפרויקט (למשל: "flutter1-maps")
6. לחץ על "Create" או "צור"

## שלב 2: הפעלת Google Maps API

1. בפרויקט החדש, לך ל-"APIs & Services" > "Library"
2. חפש "Maps SDK for Android"
3. לחץ על "Maps SDK for Android"
4. לחץ על "Enable" או "הפעל"
5. חזור ל-Library וחפש "Geocoding API"
6. לחץ על "Geocoding API" והפעל גם אותו

## שלב 3: יצירת מפתח API

1. לך ל-"APIs & Services" > "Credentials"
2. לחץ על "Create Credentials" > "API Key"
3. העתק את המפתח שנוצר
4. לחץ על המפתח כדי לערוך אותו
5. תחת "Application restrictions" בחר "Android apps"
6. לחץ על "Add an item"
7. הזן את Package name: `com.example.flutter1` (או השם שלך)
8. הזן את SHA-1 certificate fingerprint (ראה למטה)
9. תחת "API restrictions" בחר "Restrict key"
10. בחר "Maps SDK for Android" ו-"Geocoding API"
11. לחץ על "Save"

## שלב 4: קבלת SHA-1 Fingerprint

### עבור Debug (פיתוח):
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### עבור Release (ייצור):
```bash
keytool -list -v -keystore path/to/your/keystore.jks -alias your-key-alias
```

## שלב 5: עדכון הקוד

1. פתח את הקובץ `android/app/src/main/AndroidManifest.xml`
2. החלף את המפתח בשורה 58:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE" />
```

## שלב 6: בדיקה

1. בנה מחדש את האפליקציה:
```bash
flutter clean
flutter pub get
flutter run
```

2. לך לפרופיל ולחץ על "עדכון מיקום"
3. המפה אמורה להיטען כעת

## פתרון בעיות נפוצות

### אם המפה עדיין לא נטענת:

1. **בדוק את הלוגים:**
```bash
flutter logs
```

2. **ודא שהמפתח נכון:**
   - בדוק שהמפתח לא מכיל רווחים
   - ודא שהמפתח מוגבל לאפליקציה שלך

3. **בדוק הרשאות:**
   - ודא שהמפתח מוגבל ל-Android apps
   - ודא שה-SHA-1 fingerprint נכון

4. **בדוק חיבור לאינטרנט:**
   - ודא שיש חיבור לאינטרנט
   - נסה על רשת אחרת

### שגיאות נפוצות:

- **"This app is not authorized to use this API"** - המפתח לא מוגבל לאפליקציה שלך
- **"API key not found"** - המפתח לא נכון או לא הוגדר
- **"Quota exceeded"** - חרגת מהמגבלה החינמית

## הערות חשובות:

1. **אל תשתף את המפתח** - הוא רגיש ויכול לעלות כסף
2. **הגבל את המפתח** - תמיד הגבל את המפתח לאפליקציה שלך
3. **עקוב אחר השימוש** - בדוק את הדשבורד של Google Cloud Console
4. **השתמש במפתח נפרד** - עבור פיתוח וייצור

## קישורים שימושיים:

- [Google Cloud Console](https://console.cloud.google.com/)
- [Maps SDK for Android Documentation](https://developers.google.com/maps/documentation/android-sdk)
- [Geocoding API Documentation](https://developers.google.com/maps/documentation/geocoding)
