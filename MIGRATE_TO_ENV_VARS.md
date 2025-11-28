# העברת משתנים מ-functions.config() ל-Environment Variables

## למה לעדכן?

Firebase הודיע ש-`functions.config()` API יושבת במרץ 2026. צריך לעבור ל-Environment Variables או Google Secret Manager.

## שיטה 1: Google Secret Manager (מומלץ - בטוח יותר)

### שלב 1: הגדרת Secrets

```bash
# הגדרת EMAIL_USER
firebase functions:secrets:set EMAIL_USER

# כשתבקש, הזן את כתובת ה-Gmail שלך
# לדוגמה: your-email@gmail.com

# הגדרת EMAIL_PASS
firebase functions:secrets:set EMAIL_PASS

# כשתבקש, הזן את ה-App Password (16 תווים)
```

### שלב 2: עדכון הקוד

הקוד כבר מעודכן להשתמש ב-`process.env.EMAIL_USER` ו-`process.env.EMAIL_PASS`.

### שלב 3: עדכון ה-Function להכריז על Secrets

צריך להוסיף את ה-Secrets להגדרת ה-Function. נעדכן את הקוד.

---

## שיטה 2: Environment Variables (פשוט יותר)

אם אתה מעדיף לא להשתמש ב-Secret Manager, אפשר להגדיר Environment Variables דרך Firebase Console:

1. היכנס ל-Firebase Console > Functions > Configuration
2. לחץ על "Environment variables" (אם זמין)
3. הוסף:
   - `EMAIL_USER` = כתובת ה-Gmail שלך
   - `EMAIL_PASS` = ה-App Password

---

## הערה

הקוד כבר תומך בשתי השיטות:
- קודם מנסה `process.env.EMAIL_USER` / `process.env.EMAIL_PASS`
- אם לא נמצא, נופל חזרה ל-`functions.config().email.user` / `functions.config().email.pass`

זה מאפשר מעבר הדרגתי.

