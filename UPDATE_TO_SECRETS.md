# עדכון ל-Google Secret Manager (מומלץ)

## למה לעדכן עכשיו?

Firebase הודיע ש-`functions.config()` API יושבת במרץ 2026. עדיף לעדכן עכשיו ולא לחכות.

## שלב 1: הגדרת Secrets ב-Google Secret Manager

הרץ את הפקודות הבאות (תתבקש להזין את הערכים):

```bash
# הגדרת EMAIL_USER
firebase functions:secrets:set EMAIL_USER

# כשתבקש, הזן את כתובת ה-Gmail שלך
# לדוגמה: your-email@gmail.com

# הגדרת EMAIL_PASS  
firebase functions:secrets:set EMAIL_PASS

# כשתבקש, הזן את ה-App Password (16 תווים, ללא רווחים)
```

## שלב 2: פריסה מחדש של ה-Function

```bash
cd functions
firebase deploy --only functions:sendCustomVerificationEmail
```

## מה השתנה?

- הקוד עכשיו משתמש ב-`process.env.EMAIL_USER` ו-`process.env.EMAIL_PASS`
- ה-Function מוגדר להשתמש ב-Secrets: `functions.runWith({ secrets: ['EMAIL_USER', 'EMAIL_PASS'] })`
- עדיין תומך ב-`functions.config()` הישן כגיבוי (אם Secrets לא מוגדרים)

## יתרונות:

✅ **בטוח יותר** - Secrets מוצפנים ב-Google Secret Manager  
✅ **לא יושבת במרץ 2026** - זה הפתרון החדש של Firebase  
✅ **קל לניהול** - אפשר לעדכן Secrets בלי לפרוס מחדש את כל ה-Functions

## בדיקה:

לאחר הפריסה, נסה לרשום משתמש חדש ובדוק שהאימייל נשלח.

