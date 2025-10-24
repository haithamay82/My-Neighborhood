# 🔧 פתרון בעיות Google Sign-In

## השגיאה הנוכחית:
```
PlatformException(channel-error, Unable to establish connection on channel: "dev.flutter.pigeon.google_sign_in_android.GoogleSignInApi.init"., null, null)
```

## 🔍 בדיקות נדרשות:

### 1. ✅ בדוק SHA-1 ב-Firebase Console:
1. **לך ל-[Firebase Console](https://console.firebase.google.com/)**
2. **בחר את הפרויקט:** `nearme-970f3`
3. **לחץ על ⚙️ (Settings) > Project settings**
4. **גלול למטה ל-"Your apps"**
5. **בחר את האפליקציה Android:** `com.example.flutter1`
6. **ודא שה-SHA-1 מופיע:**
   ```
   11:35:E3:E1:8D:1D:E4:52:76:DC:AB:61:07:35:9E:BA:23:07:49:1C
   ```

### 2. ✅ בדוק Google Sign-In מופעל:
1. **לך ל-Authentication > Sign-in method**
2. **לחץ על Google**
3. **ודא ש-"Enable" מופעל**
4. **לחץ "Save"**

### 3. ✅ בדוק google-services.json:
- **מיקום:** `android/app/google-services.json`
- **ודא שהקובץ קיים ולא ריק**
- **ודא שה-package_name נכון:** `com.example.flutter1`

### 4. 🔄 נסה פתרונות נוספים:

#### פתרון 1: הוסף SHA-1 נוסף
אם יש לך keystore נוסף (release keystore), הוסף גם אותו:
```bash
keytool -list -v -keystore "path\to\your\release\keystore" -alias your_alias
```

#### פתרון 2: בדוק את ה-Application ID
ב-`android/app/build.gradle.kts`:
```kotlin
defaultConfig {
    applicationId = "com.example.flutter1"  // ודא שזה זהה ל-Firebase
}
```

#### פתרון 3: נסה להריץ על מכשיר אחר
אולי הבעיה ספציפית למכשיר הנוכחי.

### 5. 🚨 אם עדיין לא עובד:

#### בדוק את הלוגים המפורטים:
```bash
flutter logs --verbose
```

#### נסה להריץ באמולטור:
```bash
flutter run -d emulator-5554
```

#### בדוק את Firebase Console:
- לך ל-Authentication > Users
- בדוק אם יש שגיאות שם

## 📞 אם כל זה לא עוזר:

### אפשרויות נוספות:
1. **צור פרויקט Firebase חדש** ונסה שם
2. **בדוק אם יש בעיות רשת** (firewall, proxy)
3. **נסה גרסה אחרת** של google_sign_in
4. **בדוק אם יש שגיאות** ב-Firebase Console

### שגיאות נפוצות:
- **"SHA-1 not found"** - הוסף את ה-SHA-1
- **"Google Sign-In disabled"** - הפעל את Google Sign-In
- **"Invalid package name"** - בדוק את ה-applicationId
- **"Network error"** - בדוק את החיבור לאינטרנט

## 🎯 הצעד הבא:
1. **בדוק את כל השלבים למעלה**
2. **נסה להריץ מחדש**
3. **דווח על התוצאה**
