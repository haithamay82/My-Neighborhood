# הגדרת Google Maps API לאחר שינוי Package Name

## הבעיה:
לאחר שינוי ה-package name ל-`com.myneighborhood.app`, המפה מציגה מסך לבן.

## הפתרון:

### שלב 1: בדוק ב-Google Cloud Console

1. **לך ל-[Google Cloud Console](https://console.cloud.google.com/)**
2. **בחר את הפרויקט:** `nearme-970f3`
3. **לך ל-APIs & Services > Credentials**
4. **מצא את המפתח:** `AIzaSyBhAEQ7wNaBH1nmtRs51WqZPGHfPoRtFQs`
5. **לחץ על המפתח לעריכה**

### שלב 2: עדכן את ההגבלות של המפתח

**תחת "Application restrictions":**
1. בחר **"Android apps"**
2. לחץ **"Add an item"**
3. הזן:
   - **Package name:** `com.myneighborhood.app`
   - **SHA-1 certificate fingerprint:** (ראה למטה)

**תחת "API restrictions":**
1. בחר **"Restrict key"**
2. סמן:
   - ✅ **Maps SDK for Android**
   - ✅ **Geocoding API**
   - ✅ **Places API** (אם נדרש)

### שלב 3: קבל את SHA-1 Fingerprint

**פתח PowerShell/Terminal והרץ:**

```bash
cd "C:\Users\haith\vscode flutter\flutter1"
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**העתק את SHA-1 fingerprint** (השורה שמתחילה ב-`SHA1:`)

### שלב 4: הוסף את SHA-1 ב-Google Cloud Console

1. חזור למפתח API ב-Google Cloud Console
2. תחת "Android apps" > "Add an item"
3. הזן את ה-SHA-1 שהעתקת
4. לחץ **"Save"**

### שלב 5: וודא שה-APIs מופעלים

1. לך ל-**APIs & Services > Library**
2. ודא שהפעלת:
   - ✅ **Maps SDK for Android**
   - ✅ **Geocoding API**
   - ✅ **Places API** (אופציונלי)

### שלב 6: נקה ובנה מחדש

```bash
flutter clean
flutter pub get
flutter run
```

## אם עדיין לא עובד:

### בדוק את הלוגים:
```bash
adb logcat | grep -i "maps\|google\|api"
```

### בדוק שהמפתח נכון:
- המפתח ב-AndroidManifest.xml: `AIzaSyBhAEQ7wNaBH1nmtRs51WqZPGHfPoRtFQs`
- המפתח ב-google-services.json: `AIzaSyBhAEQ7wNaBH1nmtRs51WqZPGHfPoRtFQs`

### אם צריך ליצור מפתח חדש:

1. לך ל-APIs & Services > Credentials
2. לחץ "Create Credentials" > "API Key"
3. העתק את המפתח החדש
4. עדכן את ה-AndroidManifest.xml
5. הגבל את המפתח ל-`com.myneighborhood.app` + SHA-1

## הערות חשובות:

- ⚠️ **אל תשתמש במפתחות לא מוגבלים** - זה יכול לעלות כסף!
- ✅ **תמיד הגבל מפתחות** ל-package name + SHA-1
- ✅ **ודא שה-APIs מופעלים** לפני השימוש
- ✅ **חכה 5-10 דקות** לאחר עדכון ההגבלות

