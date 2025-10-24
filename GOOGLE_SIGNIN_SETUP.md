# הגדרת Google Sign-In

## שלבים להגדרת Google Sign-In באפליקציה

### 1. הגדרת Firebase Console

1. **פתח את [Firebase Console](https://console.firebase.google.com/)**
2. **בחר את הפרויקט שלך**
3. **עבור ל-Authentication > Sign-in method**
4. **הפעל את Google Sign-In**

### 2. הגדרת Android

#### א. קבלת SHA-1 Fingerprint

הרץ את הפקודה הבאה בטרמינל:

```bash
# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### ב. הוספת SHA-1 ל-Firebase

1. **עבור ל-Project Settings > General**
2. **בחר את האפליקציה Android**
3. **הוסף את ה-SHA-1 fingerprint שקיבלת**

#### ג. הורדת google-services.json

1. **הורד את הקובץ google-services.json החדש**
2. **החלף את הקובץ הקיים ב-`android/app/google-services.json`**

### 3. הגדרת iOS (אופציונלי)

#### א. הוספת Bundle ID

1. **עבור ל-Project Settings > General**
2. **הוסף iOS app עם Bundle ID: `com.example.flutter1`**

#### ב. הורדת GoogleService-Info.plist

1. **הורד את הקובץ GoogleService-Info.plist**
2. **הכנס אותו ל-`ios/Runner/GoogleService-Info.plist`**

### 4. הרצת האפליקציה

```bash
flutter clean
flutter pub get
flutter run
```

### 5. בדיקה

1. **פתח את מסך ההתחברות**
2. **לחץ על "התחבר עם Google"**
3. **בחר חשבון Google**
4. **ודא שהכניסה עובדת**

## פתרון בעיות נפוצות

### שגיאת SHA-1
- ודא שהוספת את ה-SHA-1 הנכון ל-Firebase
- ודא שהורדת את google-services.json החדש

### שגיאת רשת
- בדוק את החיבור לאינטרנט
- ודא שה-Google Sign-In מופעל ב-Firebase

### שגיאת הרשאות
- ודא שהוספת את כל ההרשאות הנדרשות
- ודא שה-google-services.json נמצא במקום הנכון

## הערות חשובות

- **לפרודקשן**: תצטרך ליצור keystore חדש ולקבל SHA-1 עבורו
- **בדיקה**: תמיד בדוק על מכשיר פיזי ולא רק באמולטור
- **אבטחה**: אל תשתף את ה-google-services.json בפומבי
