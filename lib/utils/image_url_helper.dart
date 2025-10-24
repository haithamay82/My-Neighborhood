class ImageUrlHelper {
  /// המרת URL של Firebase Storage ל-URL תקין
  static String getProxyUrl(String originalUrl) {
    // בדיקה אם זה URL של Firebase Storage
    if (originalUrl.contains('firebasestorage.googleapis.com')) {
      // תיקון bucket name - השתמש ב-appspot.com במקום firebasestorage.app
      if (originalUrl.contains('firebasestorage.app')) {
        return originalUrl.replaceAll('firebasestorage.app', 'appspot.com');
      }
    }
    
    // אם זה לא URL של Firebase Storage, החזר את ה-URL המקורי
    return originalUrl;
  }
  
  /// בדיקה אם URL הוא של Firebase Storage
  static bool isFirebaseStorageUrl(String url) {
    return url.contains('firebasestorage.googleapis.com');
  }
}
