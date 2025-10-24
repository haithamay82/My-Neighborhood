# הוראות הגדרת מערכת המיקום

## 1. הגדרת Google Maps API Key

### שלב 1: יצירת API Key
1. היכנס ל-[Google Cloud Console](https://console.cloud.google.com/)
2. בחר פרויקט או צור פרויקט חדש
3. הפעל את Google Maps API:
   - לך ל-APIs & Services > Library
   - חפש "Maps SDK for Android" והפעל
   - חפש "Geocoding API" והפעל
4. צור API Key:
   - לך ל-APIs & Services > Credentials
   - לחץ על "Create Credentials" > "API Key"
   - העתק את ה-API Key

### שלב 2: הגבלת API Key
1. לחץ על ה-API Key שיצרת
2. ב-"Application restrictions" בחר "Android apps"
3. הוסף את ה-package name: `com.example.flutter1`
4. הוסף את ה-SHA-1 fingerprint של האפליקציה
5. ב-"API restrictions" בחר "Restrict key" ובחר:
   - Maps SDK for Android
   - Geocoding API

### שלב 3: עדכון AndroidManifest.xml
1. פתח את `android/app/src/main/AndroidManifest.xml`
2. החלף את `YOUR_GOOGLE_MAPS_API_KEY` ב-API Key שיצרת

## 2. הרשאות Android

הרשאות המיקום כבר נוספו ל-AndroidManifest.xml:
- `ACCESS_FINE_LOCATION` - מיקום מדויק
- `ACCESS_COARSE_LOCATION` - מיקום גס
- `ACCESS_BACKGROUND_LOCATION` - מיקום ברקע

## 3. הגדרת iOS (אם נדרש)

### שלב 1: הוספת הרשאות
1. פתח את `ios/Runner/Info.plist`
2. הוסף את ההרשאות הבאות:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>האפליקציה זקוקה למיקום כדי להציג בקשות קרובות אליך</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>האפליקציה זקוקה למיקום כדי להציג בקשות קרובות אליך</string>
```

### שלב 2: Google Maps API Key ל-iOS
1. הוסף את ה-API Key ל-`ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 4. תכונות המערכת

### בחירת מיקום מותאם אישית
- במסך יצירת בקשה, בחר "מיקום מותאם אישית"
- לחץ על "בחר מיקום" לפתיחת המפה
- בחר מיקום על המפה או השתמש במיקום הנוכחי
- המיקום יישמר עם הקואורדינטות והכתובת

### סינון לפי מרחק
- במסך הבית, לחץ על "סינון מתקדם"
- הזן מרחק מקסימלי בקילומטרים
- הבקשות יסוננו לפי המרחק מהמיקום שלך

### הצגת מרחק
- כל בקשה עם קואורדינטות תציג את המרחק ממך
- המרחק מחושב בקילומטרים

### מיקום קבוע בפרופיל
- במסך הפרופיל, לחץ על "עדכן מיקום"
- בחר מיקום קבוע שישמש לסינון
- המיקום יישמר בפרופיל שלך

## 5. פתרון בעיות

### המפה לא נטענת
- ודא שה-API Key נכון
- בדוק שה-Maps SDK for Android מופעל
- ודא שה-package name תואם

### המיקום לא מתקבל
- בדוק שהרשאות המיקום ניתנו
- ודא שהמיקום מופעל במכשיר
- בדוק שה-Google Play Services מעודכנים

### שגיאות הרשאות
- ודא שהרשאות המיקום נוספו ל-AndroidManifest.xml
- בדוק שהמשתמש נתן הרשאות לאפליקציה
- נסה לפתוח את הגדרות האפליקציה ולבדוק הרשאות

## 6. הערות חשובות

- המיקום נשמר רק כשהמשתמש בוחר "מיקום מותאם אישית"
- סינון המרחק עובד רק אם יש לך מיקום נוכחי
- המיקום הקבוע בפרופיל משמש כמיקום ברירת מחדל
- כל המיקומים נשמרים ב-Firestore עם קואורדינטות מדויקות
