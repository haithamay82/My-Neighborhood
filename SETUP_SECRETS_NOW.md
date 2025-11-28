# הגדרת Secrets עכשיו - שלב אחר שלב

## למה לעדכן עכשיו?

Firebase הודיע ש-`functions.config()` API יושבת במרץ 2026. עדיף לעדכן עכשיו ולא לחכות.

## שלב 1: הגדרת EMAIL_USER Secret

הרץ את הפקודה הבאה:

```bash
firebase functions:secrets:set EMAIL_USER
```

**כשתבקש, הזן:**
- את כתובת ה-Gmail שלך (לדוגמה: `your-email@gmail.com`)
- לחץ Enter

## שלב 2: הגדרת EMAIL_PASS Secret

הרץ את הפקודה הבאה:

```bash
firebase functions:secrets:set EMAIL_PASS
```

**כשתבקש, הזן:**
- את ה-App Password שיצרת (16 תווים, ללא רווחים)
- לחץ Enter

## שלב 3: בדיקה שהכל הוגדר

```bash
firebase functions:secrets:access EMAIL_USER
firebase functions:secrets:access EMAIL_PASS
```

זה יציג את הערכים (מוצפנים).

## שלב 4: פריסה מחדש

```bash
firebase deploy --only functions:sendCustomVerificationEmail
```

## מה השתנה?

✅ הקוד עכשיו משתמש ב-Google Secret Manager (בטוח יותר)  
✅ עדיין תומך ב-`functions.config()` הישן כגיבוי  
✅ לא יושבת במרץ 2026 - זה הפתרון החדש של Firebase

## יתרונות:

- **בטוח יותר** - Secrets מוצפנים ב-Google Secret Manager
- **קל לניהול** - אפשר לעדכן Secrets בלי לפרוס מחדש
- **עובד גם בעתיד** - לא יושבת במרץ 2026

---

## הערה חשובה:

אחרי שתגדיר את ה-Secrets, **תצטרך לפרוס מחדש** את ה-Function כדי שה-Secrets יטענו.

