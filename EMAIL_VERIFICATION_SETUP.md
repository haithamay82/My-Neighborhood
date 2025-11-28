# הגדרת אימייל אימות מותאם אישית

## הגדרת תבנית אימייל ב-Firebase Console

1. היכנס ל-[Firebase Console](https://console.firebase.google.com/)
2. בחר את הפרויקט שלך: `nearme-970f3`
3. עבור ל-**Authentication** > **Templates**
4. בחר **Email address verification**
5. עדכן את התבנית:

### כותרת האימייל (Subject):
```
Verify your email for MyNeighborhood App
```

### גוף ההודעה (Message body):
```
שלום,

אנא לחץ על הקישור הבא כדי לאמת את כתובת האימייל שלך:

{{link}}

אם לא ביקשת לאמת כתובת זו, תוכל להתעלם מהאימייל הזה.

תודה,
צוות MyNeighborhood

---

Hello,

Please click the following link to verify your email address:

{{link}}

If you didn't ask to verify this address, you can ignore this email.

Thanks,
MyNeighborhood team
```

### הגדרות נוספות למניעת ספאם:

1. **SPF Record**: ודא שיש לך SPF record ב-DNS
2. **DKIM**: הפעל DKIM ב-Firebase Console > Authentication > Settings > Authorized domains
3. **Sender Name**: הגדר שם שולח ברור: "MyNeighborhood"
4. **Reply-to Address**: הגדר כתובת תשובה תקפה

## הגדרת Domain Authentication (מומלץ)

1. ב-Firebase Console > Authentication > Settings > Authorized domains
2. הוסף את הדומיין שלך
3. הוסף את ה-DNS records הנדרשים (SPF, DKIM)

## בדיקת אימייל אימות

לאחר ההגדרה, בדוק:
- האימייל מגיע לתיבת הדואר הנכנס (לא לספאם)
- הכותרת נכונה: "Verify your email for MyNeighborhood App"
- החתימה נכונה: "Thanks, MyNeighborhood team"
- ההודעה בעברית ובאנגלית

