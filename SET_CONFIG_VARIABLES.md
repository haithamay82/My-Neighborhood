# הגדרת משתנים דרך Terminal

## שלב 1: הגדרת המשתנים

הרץ את הפקודות הבאות ב-Terminal (החלף את הערכים):

```bash
firebase functions:config:set email.user="YOUR_EMAIL@gmail.com" email.pass="YOUR_APP_PASSWORD"
```

**דוגמה:**
```bash
firebase functions:config:set email.user="haitham.ay82@gmail.com" email.pass="abcd efgh ijkl mnop"
```

⚠️ **חשוב**: 
- הסיסמה צריכה להיות **ללא רווחים** (אם יש רווחים, הסר אותם)
- השתמש במירכאות כפולות סביב הערכים

## שלב 2: בדיקה שהמשתנים הוגדרו

```bash
firebase functions:config:get
```

זה יציג את כל המשתנים שהוגדרו.

## שלב 3: פריסת ה-Function

```bash
cd functions
firebase deploy --only functions:sendCustomVerificationEmail
```

---

## אם יש שגיאה:

אם אתה מקבל שגיאה, נסה:
1. ודא שאתה בתיקיית הפרויקט הראשית
2. ודא ש-Firebase CLI מותקן: `firebase --version`
3. ודא שאתה מחובר: `firebase login`

