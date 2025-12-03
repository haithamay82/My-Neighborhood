# 🔧 תיקון שגיאת Google Maps API: ExpiredKeyMapError

## הבעיה:
השגיאה `ExpiredKeyMapError` אומרת שה-API key של Google Maps פג תוקף או לא פעיל.

## API Key שמוגדר בקוד:

### ב-`web/index.html`:
- **API Key:** `AIzaSyAGALOMmVVNl1f_xYDRXoFrgX_Z0B5HjQQ`
- **שימוש:** Google Maps JavaScript API

## מה לעשות:

### שלב 1: בדוק את ה-API Key ב-Google Cloud Console
1. לך ל-[Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
2. מצא את ה-API Key: `AIzaSyAGALOMmVVNl1f_xYDRXoFrgX_Z0B5HjQQ`
3. לחץ עליו לעריכה

### שלב 2: בדוק את הסטטוס של ה-API Key
בודקים:
- ✅ האם ה-API Key **פעיל** (לא מושבת)
- ✅ האם **Maps JavaScript API** מופעל
- ✅ האם יש **הגבלות** שמונעות שימוש (למשל, רק דומיינים מסוימים)

### שלב 3: בדוק את ה-Restrictions
אם יש Restrictions:
1. **Application restrictions:**
   - אם מוגדר "HTTP referrers", ודא ש-`https://nearme-970f3.web.app/*` ו-`https://nearme-970f3.firebaseapp.com/*` מופיעים ברשימה
   - אם מוגדר "None", זה אמור לעבוד

2. **API restrictions:**
   - ודא ש-**Maps JavaScript API** מופיע ברשימה
   - או בחר "Don't restrict key" (לא מומלץ לייצור)

### שלב 4: אם ה-API Key פג תוקף או לא פעיל
#### אפשרות 1: הפעל את ה-API Key מחדש
1. ב-Google Cloud Console, לחץ על ה-API Key
2. ודא ש-**Key restriction** > **Application restrictions** מוגדר ל-"None" או ל-HTTP referrers עם הדומיינים הנכונים
3. ודא ש-**API restrictions** כולל את **Maps JavaScript API**
4. לחץ **"Save"**

#### אפשרות 2: צור API Key חדש
אם ה-API Key לא ניתן להפעלה:
1. ב-Google Cloud Console, לחץ **"Create Credentials"** > **"API Key"**
2. העתק את ה-API Key החדש
3. עדכן את `web/index.html` עם ה-API Key החדש:
   ```html
   script.src = 'https://maps.googleapis.com/maps/api/js?key=YOUR_NEW_API_KEY&libraries=places&loading=async&callback=initGoogleMaps';
   ```
4. ודא שה-API Key החדש מופעל עבור **Maps JavaScript API**

### שלב 5: ודא ש-Maps JavaScript API מופעל
1. לך ל-[Google Cloud Console - APIs & Services](https://console.cloud.google.com/apis/library?project=nearme-970f3)
2. חפש **"Maps JavaScript API"**
3. ודא שהוא **מופעל** (Enabled)
4. אם לא, לחץ **"Enable"**

### שלב 6: בדוק את ה-Billing
Google Maps API דורש billing account:
1. לך ל-[Google Cloud Console - Billing](https://console.cloud.google.com/billing?project=nearme-970f3)
2. ודא שיש billing account פעיל
3. אם אין, הוסף billing account

## קישורים שימושיים:

- [Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
- [Google Cloud Console - Maps JavaScript API](https://console.cloud.google.com/apis/library/maps-javascript-backend.googleapis.com?project=nearme-970f3)
- [Google Maps Platform - Error Messages](https://developers.google.com/maps/documentation/javascript/error-messages#expired-key-map-error)

## אחרי התיקון:
1. עדכן את `web/index.html` עם ה-API Key החדש (אם יצרת חדש)
2. בנה מחדש: `flutter build web --release`
3. פרס מחדש: `firebase deploy --only hosting`

