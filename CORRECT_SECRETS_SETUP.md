# תיקון הגדרת Secrets

## הבעיה:

אם הזנת את כתובת האימייל כמפתח (במקום כערך), צריך לתקן.

## הפתרון:

### שלב 1: מחיקת Secret שגוי (אם נוצר)

```bash
firebase functions:secrets:destroy HAITHAM_AY82@GMAIL_COM
```

או אם נוצר עם שם אחר, בדוק את כל ה-Secrets:

```bash
firebase functions:secrets:list
```

### שלב 2: הגדרה נכונה של EMAIL_USER

הרץ:

```bash
firebase functions:secrets:set EMAIL_USER
```

**כשתבקש:**
- **"Enter a value for EMAIL_USER"** → הזן את כתובת ה-Gmail שלך (לדוגמה: `haitham.ay82@gmail.com`)
- לחץ Enter

### שלב 3: הגדרה נכונה של EMAIL_PASS

הרץ:

```bash
firebase functions:secrets:set EMAIL_PASS
```

**כשתבקש:**
- **"Enter a value for EMAIL_PASS"** → הזן את ה-App Password (16 תווים, ללא רווחים)
- לחץ Enter

### שלב 4: בדיקה

```bash
firebase functions:secrets:list
```

אתה אמור לראות:
- `EMAIL_USER`
- `EMAIL_PASS`

### שלב 5: פריסה מחדש

```bash
firebase deploy --only functions:sendCustomVerificationEmail
```

---

## הערה חשובה:

- **המפתח** (Key) = `EMAIL_USER` או `EMAIL_PASS` (קבוע)
- **הערך** (Value) = כתובת האימייל או הסיסמה (המידע הסודי)

