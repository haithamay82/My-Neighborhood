# Firebase Storage Setup - הוראות הגדרה

## 🚨 בעיה: Permission Denied (403)

השגיאה `Permission denied` מתרחשת כי Firebase Storage לא מוגדר עם כללי אבטחה נכונים.

## 🔧 פתרון:

### 1. עבור ל-Firebase Console
1. פתח [Firebase Console](https://console.firebase.google.com/)
2. בחר את הפרויקט שלך
3. עבור ל-**Storage** בתפריט הצד

### 2. הגדר Storage Rules
1. לחץ על **Rules** בטאב העליון
2. החלף את התוכן ב:

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to read and write their own profile images
    match /profile_images/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to read and write their own request images
    match /request_images/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to read and write their own payment proof images
    match /payment_images/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow authenticated users to read and write chat images
    match /chat_images/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    // Allow authenticated users to read all images (for viewing other users' content)
    match /{allPaths=**} {
      allow read: if request.auth != null;
    }
  }
}
```

### 3. שמור ופרסם
1. לחץ על **Publish** (פרסם)
2. המתן עד שהכללים יתעדכנו

## ✅ בדיקה:
לאחר הפרסום, נסה שוב להעלות תמונת פרופיל - זה אמור לעבוד!

## 📁 מבנה התיקיות ב-Storage:
```
profile_images/
  └── {userId}               # תמונות פרופיל (ללא סיומת)
request_images/
  └── {userId}/
      └── {imageName}        # תמונות בקשות
payment_images/
  └── {userId}/
      └── {imageName}        # תמונות הוכחת תשלום
chat_images/
  └── {imageName}            # תמונות בצ'אט
```

## 🔒 אבטחה:
- כל משתמש יכול להעלות/למחוק רק את התמונות שלו
- כל משתמש יכול לקרוא תמונות של אחרים (לצפייה)
- רק משתמשים מחוברים יכולים לגשת לתמונות
