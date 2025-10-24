# 🔧 תיקון Google Sign-In

## הבעיה:
```
PlatformException(channel-error, Unable to establish connection on channel: "dev.flutter.pigeon.google_sign_in_android.GoogleSignInApi.init"., null, null)
```

## הסיבה:
ה-SHA-1 fingerprint לא מוגדר ב-Firebase Console.

## הפתרון:

### 1. 📋 SHA-1 Fingerprint שלך:
```
11:35:E3:E1:8D:1D:E4:52:76:DC:AB:61:07:35:9E:BA:23:07:49:1C
```

### 2. 🔧 הוראות תיקון:

#### שלב 1: פתח Firebase Console
1. **לך ל-[Firebase Console](https://console.firebase.google.com/)**
2. **בחר את הפרויקט שלך**

#### שלב 2: הוסף SHA-1
1. **לחץ על ⚙️ (Settings) > Project settings**
2. **גלול למטה ל-"Your apps"**
3. **בחר את האפליקציה Android שלך**
4. **לחץ על "Add fingerprint"**
5. **הדבק את ה-SHA-1:**
   ```
   11:35:E3:E1:8D:1D:E4:52:76:DC:AB:61:07:35:9E:BA:23:07:49:1C
   ```
6. **לחץ "Save"**

#### שלב 3: הורד google-services.json חדש
1. **לחץ על "Download google-services.json"**
2. **החלף את הקובץ הקיים ב-`android/app/google-services.json`**

#### שלב 4: הפעל Google Sign-In
1. **לך ל-Authentication > Sign-in method**
2. **לחץ על Google**
3. **הפעל את "Enable"**
4. **לחץ "Save"**

### 3. 🚀 הרצה מחדש:
```bash
flutter clean
flutter pub get
flutter run
```

### 4. ✅ בדיקה:
1. **פתח את האפליקציה**
2. **לחץ על "התחבר עם Google"**
3. **בחר חשבון Google**
4. **ודא שהכניסה עובדת**

## אם עדיין לא עובד:

### בדוק את הלוגים:
```bash
flutter logs
```

### שגיאות נפוצות:
- **"SHA-1 not found"** - ודא שהוספת את ה-SHA-1 הנכון
- **"Google Sign-In disabled"** - ודא שהפעלת את Google Sign-In
- **"Invalid google-services.json"** - ודא שהורדת את הקובץ החדש

## 📞 אם יש בעיות:
1. **בדוק שהקובץ google-services.json נטען נכון**
2. **ודא שה-SHA-1 זהה בדיוק**
3. **נסה להריץ `flutter clean` לפני `flutter run`**
