# הוראות הגדרת אימייל אימות מותאם אישית

## שלב 1: יצירת App Password ב-Gmail

1. היכנס ל-[Google Account](https://myaccount.google.com/)
2. עבור ל-**Security** (אבטחה)
3. ודא ש-**2-Step Verification** מופעל (אם לא, הפעל אותו קודם)
4. גלול למטה ולחץ על **App passwords** (סיסמאות אפליקציות)
5. בחר **Mail** ו-**Other (Custom name)**
6. הזן שם: `Firebase Functions`
7. לחץ **Generate** (יצירה)
8. **העתק את הסיסמה** (16 תווים) - תצטרך אותה בשלב הבא

## שלב 2: הגדרת משתני סביבה ב-Firebase Functions

### דרך Firebase Console:

1. היכנס ל-[Firebase Console](https://console.firebase.google.com/)
2. בחר את הפרויקט: `nearme-970f3`
3. עבור ל-**Functions** > **Configuration**
4. לחץ על **Add variable** (הוסף משתנה)
5. הוסף את המשתנים הבאים:

**משתנה 1:**
- **Name**: `email.user`
- **Value**: כתובת ה-Gmail שלך (לדוגמה: `your-email@gmail.com`)

**משתנה 2:**
- **Name**: `email.pass`
- **Value**: ה-App Password שיצרת בשלב 1 (16 תווים)

### דרך Terminal (אופציונלי):

```bash
cd functions
firebase functions:config:set email.user="your-email@gmail.com" email.pass="your-app-password"
```

## שלב 3: התקנת חבילות Node.js

```bash
cd functions
npm install
```

## שלב 4: פריסת Cloud Functions

```bash
cd functions
firebase deploy --only functions:sendCustomVerificationEmail
```

## שלב 5: בדיקה

1. נסה לרשום משתמש חדש
2. בדוק את תיבת הדואר הנכנס
3. האימייל צריך להגיע עם:
   - **כותרת**: "Verify your email for MyNeighborhood App"
   - **תוכן בעברית ובאנגלית**
   - **חתימה**: "תודה, צוות אפליקציית 'שכונתי'" / "Thanks, MyNeighborhood team"

## פתרון בעיות

### האימייל לא נשלח:
1. ודא שה-App Password נכון
2. ודא ש-2-Step Verification מופעל
3. בדוק את ה-logs: `firebase functions:log`

### האימייל מגיע לספאם:
1. ודא שהכותרת והתוכן נכונים
2. הוסף את כתובת השולח לרשימת אנשי קשר
3. בדוק את ה-SPF ו-DKIM records (אם יש דומיין מותאם)

## הערות חשובות:

- **אל תשתף את ה-App Password** - זה סוד!
- **השתמש ב-App Password ולא בסיסמה הרגילה** של Gmail
- **אם תשנה את הסיסמה של Gmail**, תצטרך ליצור App Password חדש

