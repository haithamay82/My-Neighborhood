# תיקון קריסת Google Maps

## הבעיה:
```
java.lang.IllegalStateException: The API key can only be specified once
```

## הסיבה:
היו **שני מפתחות Google Maps API** ב-AndroidManifest.xml, מה שגרם לקריסה.

## התיקון שביצעתי:
1. **מחקתי את המפתח הכפול** - השארתי רק `com.google.android.geo.API_KEY`
2. **שיפרתי את הטיפול בשגיאות** - הוספתי בדיקות טובות יותר
3. **הוספתי הודעות ברורות** - המשתמש יראה הוראות פתרון

## מה לעשות עכשיו:

### 1. **בנה מחדש את האפליקציה:**
```bash
flutter clean
flutter pub get
flutter run
```

### 2. **אם עדיין יש בעיות:**

#### בדוק את המפתח Google Maps API:
1. לך ל-[Google Cloud Console](https://console.cloud.google.com/)
2. בדוק שהמפתח `AIzaSyBvOkBw7cTUFjE8hZ9Q2vK8mN3pL7sR4tU` תקין
3. ודא שהוא מוגבל לאפליקציה שלך

#### צור מפתח חדש:
1. לך ל-APIs & Services > Credentials
2. צור מפתח API חדש
3. הגבל אותו ל-Android apps
4. הזן Package name: `com.example.flutter1`
5. החלף את המפתח ב-AndroidManifest.xml

### 3. **אם המפה עדיין לא עובדת:**
- האפליקציה תציג מסך שגיאה עם הוראות
- תוכל ללחוץ על "בחור מיקום ידנית"
- תוכל להזין כתובת ולחפש מיקום

## בדיקה:
1. לך לפרופיל
2. לחץ על "עדכן מיקום"
3. המפה אמורה להיטען כעת ללא קריסה

אם עדיין יש בעיות, שלח לי את הלוגים החדשים!
