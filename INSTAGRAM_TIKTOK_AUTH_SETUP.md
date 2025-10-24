# הגדרת אימות אינסטגרם וטיקטוק

## שלב 1: קבלת מפתחות API

### אינסטגרם:
1. לך ל: https://developers.facebook.com/
2. צור אפליקציה חדשה
3. הוסף את "Instagram Basic Display" product
4. קבל את:
   - **App ID**
   - **App Secret**

### טיקטוק:
1. לך ל: https://developers.tiktok.com/
2. צור אפליקציה חדשה
3. קבל את:
   - **Client Key**
   - **Client Secret**

## שלב 2: עדכון הקוד

עדכן את `lib/services/social_auth_service.dart`:

```dart
static const String _instagramClientId = 'YOUR_ACTUAL_INSTAGRAM_APP_ID';
static const String _instagramClientSecret = 'YOUR_ACTUAL_INSTAGRAM_APP_SECRET';
static const String _tiktokClientId = 'YOUR_ACTUAL_TIKTOK_CLIENT_KEY';
static const String _tiktokClientSecret = 'YOUR_ACTUAL_TIKTOK_CLIENT_SECRET';
```

## שלב 3: הגדרת Redirect URI

### אינסטגרם:
1. ב-Facebook App Settings > Basic
2. הוסף ל-Valid OAuth Redirect URIs:
   ```
   https://your-domain.com/auth/instagram/callback
   ```

### טיקטוק:
1. ב-TikTok Developer Console
2. הוסף ל-Redirect URI:
   ```
   https://your-domain.com/auth/tiktok/callback
   ```

## שלב 4: יצירת Cloud Function

צור Cloud Function לטיפול ב-callback:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.handleInstagramCallback = functions.https.onRequest(async (req, res) => {
  const { code } = req.query;
  
  // החלפת code ב-access token
  const tokenResponse = await fetch('https://api.instagram.com/oauth/access_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: 'YOUR_INSTAGRAM_APP_ID',
      client_secret: 'YOUR_INSTAGRAM_APP_SECRET',
      grant_type: 'authorization_code',
      redirect_uri: 'https://your-domain.com/auth/instagram/callback',
      code: code,
    }),
  });
  
  const tokenData = await tokenResponse.json();
  
  // קבלת פרטי משתמש
  const userResponse = await fetch(`https://graph.instagram.com/me?fields=id,username&access_token=${tokenData.access_token}`);
  const userData = await userResponse.json();
  
  // יצירת Firebase user
  const customToken = await admin.auth().createCustomToken(userData.id, {
    provider: 'instagram',
    username: userData.username,
  });
  
  res.redirect(`yourapp://auth?token=${customToken}`);
});

exports.handleTikTokCallback = functions.https.onRequest(async (req, res) => {
  const { code } = req.query;
  
  // החלפת code ב-access token
  const tokenResponse = await fetch('https://open.tiktokapis.com/v2/oauth/token/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_key: 'YOUR_TIKTOK_CLIENT_KEY',
      client_secret: 'YOUR_TIKTOK_CLIENT_SECRET',
      grant_type: 'authorization_code',
      redirect_uri: 'https://your-domain.com/auth/tiktok/callback',
      code: code,
    }),
  });
  
  const tokenData = await tokenResponse.json();
  
  // קבלת פרטי משתמש
  const userResponse = await fetch('https://open.tiktokapis.com/v2/user/info/?fields=open_id,display_name', {
    headers: { 'Authorization': `Bearer ${tokenData.access_token}` },
  });
  const userData = await userResponse.json();
  
  // יצירת Firebase user
  const customToken = await admin.auth().createCustomToken(userData.data.open_id, {
    provider: 'tiktok',
    display_name: userData.data.display_name,
  });
  
  res.redirect(`yourapp://auth?token=${customToken}`);
});
```

## שלב 5: עדכון AndroidManifest.xml

הוסף intent filters לטיפול ב-callback:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop">
    <!-- ... existing intent filters ... -->
    
    <!-- Instagram callback -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="yourapp" android:host="auth" />
    </intent-filter>
</activity>
```

## שלב 6: עדכון הקוד לטיפול ב-callback

```dart
// ב-main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // טיפול ב-deep link
  FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
    final uri = dynamicLinkData.link;
    if (uri.toString().contains('yourapp://auth?token=')) {
      final token = uri.queryParameters['token'];
      if (token != null) {
        // התחברות עם custom token
        FirebaseAuth.instance.signInWithCustomToken(token);
      }
    }
  });
  
  runApp(MyApp());
}
```

## הערות חשובות:

1. **אבטחה**: לעולם אל תשים את ה-App Secret בקוד הלקוח
2. **HTTPS**: Redirect URIs חייבים להיות HTTPS
3. **Domain**: תצטרך domain אמיתי לטיפול ב-callback
4. **Testing**: בדוק עם אפליקציות בדיקה לפני production

## אלטרנטיבה פשוטה יותר:

אם זה מורכב מדי, אפשר להשתמש ב:
- **Firebase Auth** עם email/password
- **Google Sign-In** (כבר מוגדר)
- **Facebook Login** (כבר מוגדר)

אלה עובדים מיד ללא הגדרה נוספת!
