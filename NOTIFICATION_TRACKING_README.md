# מערכת מעקב התראות - מניעת כפילויות

## סקירה כללית
מערכת זו מונעת שליחת התראות כפולות למשתמשים כאשר הם מתחברים מחדש לאפליקציה.

## הבעיה שנפתרה
לפני התיקון, האפליקציה שלחה התראות אוטומטיות מחדש בכל פעם שמשתמש התחבר, גם אם כבר קיבל את ההתראה בעבר.

## הפתרון
יצרנו מערכת מעקב מתקדמת שמזכירה אילו התראות כבר נשלחו לכל משתמש.

## קבצים שנוצרו/עודכנו

### 1. `lib/services/notification_tracking_service.dart` (חדש)
שירות מרכזי למעקב אחר התראות שנשלחו:
- `hasNotificationBeenSent()` - בדיקה אם התראה נשלחה
- `markNotificationAsSent()` - סימון שהתראה נשלחה
- `hasNotificationWithParamsBeenSent()` - בדיקה עם פרמטרים ספציפיים
- `markNotificationWithParamsAsSent()` - סימון עם פרמטרים ספציפיים

### 2. `lib/screens/home_screen.dart` (עודכן)
### 3. `lib/services/location_service.dart` (עודכן)
### 4. `lib/services/app_sharing_service.dart` (עודכן)
### 5. `lib/screens/detailed_rating_screen.dart` (עודכן)
עודכנו את הפונקציות הבאות להשתמש במערכת המעקב החדשה:

#### `_showGuestStatusMessage()`
- **לפני**: השתמש ב-SharedPreferences פשוט
- **אחרי**: משתמש ב-NotificationTrackingService עם סוגי התראות ספציפיים:
  - `guest_welcome_first_week` - ברוכים הבאים לשבוע הראשון
  - `guest_with_categories` - משתמש אורח עם תחומי עיסוק
  - `guest_trial_ended` - שבוע הניסיון הסתיים

#### `_showLocationReminderMessage()`
- **לפני**: השתמש ב-SharedPreferences פשוט
- **אחרי**: משתמש ב-NotificationTrackingService עם סוג `location_reminder`

#### `_checkForNewNotifications()` ו-`_checkForNewNotificationsDelayed()`
- **לפני**: הציגו התראות מקומיות ללא מעקב
- **אחרי**: בודקים אם התראה מקומית כבר הוצגה לפני הצגתה

#### `_sendRadiusIncreaseNotification()` (ב-3 קבצים)
- **לפני**: שלחו התראות כפולות על הגדלת טווח
- **אחרי**: בודקים אם כבר נשלחה התראה עם אותם פרמטרים לפני שליחה

## סוגי התראות שנעקבים

### התראות למשתמשי אורח
1. **ברוכים הבאים לשבוע הראשון** - `guest_welcome_first_week`
2. **מצב אורח עם תחומי עיסוק** - `guest_with_categories`
3. **שבוע הניסיון הסתיים** - `guest_trial_ended`

### התראות כלליות
1. **תזכורת מיקום קבוע** - `location_reminder`

### התראות על הגדלת טווח
1. **הגדלת טווח** - `radius_increase` (עם פרמטרים: recommendationsCount, averageRating, radiusIncrease)

### התראות מקומיות
1. **התראה מקומית רגילה** - `local_notification`
2. **התראה מקומית מושהית** - `local_notification_delayed`

## איך זה עובד

### 1. בדיקה לפני שליחה
```dart
final hasBeenSent = await NotificationTrackingService.hasNotificationBeenSent(
  userId: userProfile.userId,
  notificationType: 'guest_welcome_first_week',
);
```

### 2. שליחת התראה רק אם לא נשלחה
```dart
if (!hasBeenSent) {
  // שליחת ההתראה
  await NotificationService.sendNotification(...);
  
  // סימון שנשלחה
  await NotificationTrackingService.markNotificationAsSent(
    userId: userProfile.userId,
    notificationType: 'guest_welcome_first_week',
  );
}
```

### 3. מעקב עם פרמטרים ספציפיים
```dart
final hasBeenShown = await NotificationTrackingService.hasNotificationWithParamsBeenSent(
  userId: user.uid,
  notificationType: 'local_notification',
  params: {'notificationId': notificationId},
);
```

## יתרונות

1. **מניעת כפילויות** - כל התראה נשלחת פעם אחת בלבד
2. **מעקב מדויק** - כל סוג התראה נעקב בנפרד
3. **גמישות** - תמיכה בפרמטרים ספציפיים
4. **ביצועים** - שימוש ב-SharedPreferences מהיר
5. **ניהול קל** - פונקציות לניקוי ובדיקה

## פונקציות ניהול

### ניקוי כל המעקב
```dart
await NotificationTrackingService.clearAllNotificationTracking();
```

### ניקוי מעקב למשתמש ספציפי
```dart
await NotificationTrackingService.clearUserNotificationTracking(userId);
```

### קבלת רשימת התראות שנשלחו
```dart
final sentNotifications = await NotificationTrackingService.getSentNotificationsForUser(userId);
```

## בדיקת תקינות

המערכת כוללת הודעות debug מפורטות:
- `✅ Guest status notification sent: guest_welcome_first_week for user: [userId]`
- `Guest status notification already sent: guest_welcome_first_week for user: [userId]`
- `Local notification already shown for notification: [notificationId]`

## סיכום

המערכת החדשה מבטיחה שמשתמשים יקבלו כל התראה פעם אחת בלבד, גם אם הם מתחברים מחדש לאפליקציה מספר פעמים. זה משפר את חוויית המשתמש ומונע ספאם של התראות.
