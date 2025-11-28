# מדריך שלב אחר שלב - הגדרת אימייל אימות

## שלב 1: יצירת App Password ב-Gmail

### 1.1. היכנס ל-Google Account
- פתח דפדפן וגש ל: https://myaccount.google.com/
- התחבר עם חשבון ה-Gmail שבו תרצה לשלוח את האימיילים

### 1.2. עבור ל-Security (אבטחה)
- בתפריט השמאלי, לחץ על **"Security"** (אבטחה)

### 1.3. הפעל 2-Step Verification (אם לא מופעל)
- גלול למטה למצוא **"2-Step Verification"**
- אם לא מופעל, לחץ עליו והפעל אותו
- תצטרך לאמת עם הטלפון שלך

### 1.4. צור App Password
- אחרי ש-2-Step Verification מופעל, גלול למטה
- חפש **"App passwords"** (סיסמאות אפליקציות)
- לחץ עליו
- ייתכן שתצטרך להזין את הסיסמה של Google שוב

### 1.5. בחר סוג אפליקציה
- בחר **"Mail"** מהרשימה
- בחר **"Other (Custom name)"** מהרשימה השנייה
- הזן: `Firebase Functions`
- לחץ **"Generate"** (יצירה)

### 1.6. העתק את הסיסמה
- תראה סיסמה של 16 תווים (לדוגמה: `abcd efgh ijkl mnop`)
- **העתק את הסיסמה** - תצטרך אותה בשלב הבא
- ⚠️ **חשוב**: זה הסיסמה היחידה שתראה - שמור אותה!

---

## שלב 2: הגדרת משתנים ב-Firebase Console

### 2.1. היכנס ל-Firebase Console
- פתח דפדפן וגש ל: https://console.firebase.google.com/
- התחבר עם אותו חשבון Google
- בחר את הפרויקט: **"nearme-970f3"**

### 2.2. עבור ל-Functions Configuration
- בתפריט השמאלי, לחץ על **"Functions"**
- לחץ על **"Configuration"** (הגדרות) או על הכרטיסייה **"Config"**

### 2.3. הוסף משתנה ראשון
- לחץ על **"Add variable"** (הוסף משתנה) או על הכפתור **"+"**
- בשדה **"Variable name"** הזן: `email.user`
- בשדה **"Value"** הזן: את כתובת ה-Gmail שלך (לדוגמה: `your-email@gmail.com`)
- לחץ **"Save"** או **"Add"**

### 2.4. הוסף משתנה שני
- לחץ שוב על **"Add variable"**
- בשדה **"Variable name"** הזן: `email.pass`
- בשדה **"Value"** הזן: את ה-App Password שיצרת בשלב 1 (16 תווים, ללא רווחים)
- לחץ **"Save"** או **"Add"**

### 2.5. ודא שהמשתנים נשמרו
- אתה אמור לראות שני משתנים:
  - `email.user` = כתובת ה-Gmail שלך
  - `email.pass` = ה-App Password

---

## שלב 3: פריסת Cloud Function

### 3.1. פתח Terminal/PowerShell
- פתח את Terminal או PowerShell
- עבור לתיקיית הפרויקט

### 3.2. עבור לתיקיית functions
```bash
cd functions
```

### 3.3. התקן חבילות (אם עוד לא התקנת)
```bash
npm install
```

### 3.4. פרוס את ה-Function
```bash
firebase deploy --only functions:sendCustomVerificationEmail
```

### 3.5. המתן לסיום הפריסה
- הפריסה יכולה לקחת 2-5 דקות
- בסיום תראה הודעה: `✔ Deploy complete!`

---

## שלב 4: בדיקה

### 4.1. בדוק שהכל עובד
1. פתח את האפליקציה
2. נסה לרשום משתמש חדש
3. בדוק את תיבת הדואר הנכנס של האימייל שרשמת
4. האימייל צריך להגיע עם:
   - **כותרת**: "Verify your email for MyNeighborhood App"
   - **תוכן בעברית ובאנגלית**
   - **חתימה**: "תודה, צוות אפליקציית 'שכונתי'" / "Thanks, MyNeighborhood team"

### 4.2. אם האימייל לא הגיע
- בדוק את תיקיית הספאם
- בדוק את ה-logs: `firebase functions:log`
- ודא שהמשתנים הוגדרו נכון ב-Firebase Console

---

## פתרון בעיות

### בעיה: "Email transporter not configured"
**פתרון**: ודא שהגדרת את `email.user` ו-`email.pass` ב-Firebase Console

### בעיה: "Invalid login"
**פתרון**: ודא שהשתמשת ב-App Password ולא בסיסמה הרגילה של Gmail

### בעיה: האימייל לא נשלח
**פתרון**: 
1. בדוק את ה-logs: `firebase functions:log`
2. ודא ש-2-Step Verification מופעל
3. ודא שה-App Password נכון

### בעיה: האימייל מגיע לספאם
**פתרון**:
1. הוסף את כתובת השולח לרשימת אנשי קשר
2. סמן את האימייל כ-"לא ספאם"
3. בדוק את תיקיית הספאם באופן קבוע

---

## הערות חשובות

- ⚠️ **אל תשתף את ה-App Password** - זה סוד!
- ⚠️ **השתמש ב-App Password ולא בסיסמה הרגילה** של Gmail
- ⚠️ **אם תשנה את הסיסמה של Gmail**, תצטרך ליצור App Password חדש
- ✅ **האימייל יישלח אוטומטית** בכל פעם שמשתמש נרשם

---

## סיכום

לאחר שתסיים את כל השלבים:
1. ✅ App Password נוצר ב-Gmail
2. ✅ משתנים הוגדרו ב-Firebase Console
3. ✅ Cloud Function נפרס
4. ✅ האימייל נשלח עם התוכן המותאם

**הכל מוכן!** 🎉

