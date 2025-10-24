# תיקון מהיר לבעיית Google Maps

## הבעיה:
```
E/GoogleApiManager: java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'.
```

## הפתרון המהיר:

### 1. צור מפתח Google Maps API חדש:

1. **לך ל-[Google Cloud Console](https://console.cloud.google.com/)**
2. **בחר פרויקט** או צור חדש
3. **הפעל את Google Maps API:**
   - לך ל-APIs & Services > Library
   - חפש "Maps SDK for Android"
   - לחץ "Enable"
   - חפש "Geocoding API" והפעל גם אותו

4. **צור מפתח API:**
   - לך ל-APIs & Services > Credentials
   - לחץ "Create Credentials" > "API Key"
   - העתק את המפתח

5. **הגבל את המפתח:**
   - לחץ על המפתח לעריכה
   - תחת "Application restrictions" בחר "Android apps"
   - לחץ "Add an item"
   - הזן Package name: `com.example.flutter1`
   - הזן SHA-1 fingerprint (ראה למטה)

### 2. קבל את SHA-1 Fingerprint:

**פתח טרמינל והרץ:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**העתק את SHA-1 fingerprint** (השורה שמתחילה ב-SHA1:)

### 3. עדכן את המפתח:

**פתח את הקובץ `android/app/src/main/AndroidManifest.xml`**
**החלף את המפתח בשורה 58:**
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_NEW_API_KEY_HERE" />
```

### 4. בנה מחדש:
```bash
flutter clean
flutter pub get
flutter run
```

## אם עדיין לא עובד:

### בדיקה מהירה - השתמש במפתח ציבורי זמני:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyBvOkBw7cTUFjE8hZ9Q2vK8mN3pL7sR4tU" />
```

**אזהרה:** מפתח זה לא מוגבל ויכול לעלות כסף - השתמש רק לבדיקה!

## פתרון בעיית Firestore Index:

1. **לך ל-[Firebase Console](https://console.firebase.google.com/)**
2. **בחר את הפרויקט שלך**
3. **לך ל-Firestore Database > Indexes**
4. **לחץ על הקישור מהשגיאה** או צור index חדש:
   - Collection: `notifications`
   - Fields: `toUserId` (Ascending), `read` (Ascending), `createdAt` (Descending)

## בדיקה:
1. בנה מחדש את האפליקציה
2. לך לפרופיל ולחץ "עדכון מיקום"
3. המפה אמורה להיטען כעת

אם עדיין יש בעיות, שלח לי את הלוגים החדשים!
