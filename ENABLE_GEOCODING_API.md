# 🔧 הפעלת Geocoding API ב-Google Cloud Console

## הבעיה:
השגיאה `REQUEST_DENIED: This API key is not authorized to use this service or API` אומרת שה-API key לא מופעל עבור Geocoding API.

## API Key:
- **API Key:** `AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`

## מה לעשות:

### שלב 1: הפעל את Geocoding API
1. לך ל-[Google Cloud Console - APIs & Services](https://console.cloud.google.com/apis/library?project=nearme-970f3)
2. חפש **"Geocoding API"**
3. לחץ על **"Geocoding API"**
4. לחץ **"Enable"** (הפעל)

### שלב 2: בדוק את ה-API Key
1. לך ל-[Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)
2. מצא את ה-API Key: `AIzaSyBzZH8y4mlSIXX_IsXe3I5ghLziRJp84TA`
3. לחץ עליו לעריכה

### שלב 3: ודא ש-Geocoding API מופיע ברשימת ה-APIs
ב-API Key settings, תחת **"API restrictions"**:
- ודא ש-**Geocoding API** מופיע ברשימה
- או בחר **"Don't restrict key"** (לא מומלץ לייצור)

### שלב 4: שמור את השינויים
לחץ **"Save"** כדי לשמור את ההגדרות

## קישורים שימושיים:

- [Google Cloud Console - Geocoding API](https://console.cloud.google.com/apis/library/geocoding-backend.googleapis.com?project=nearme-970f3)
- [Google Cloud Console - API Keys](https://console.cloud.google.com/apis/credentials?project=nearme-970f3)

## אחרי ההפעלה:
1. המתן 1-2 דקות עד שההגדרות ייכנסו לתוקף
2. רענן את האתר: https://nearme-970f3.web.app
3. נסה שוב לבחור מיקום במפה
4. הכתובת אמורה להופיע במקום "מיקום לא ידוע"

