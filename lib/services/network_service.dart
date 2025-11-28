import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static bool _isConnected = true;
  static final List<VoidCallback> _listeners = [];

  /// אתחול השירות
  static void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        debugPrint('Network connectivity error: $error');
        _isConnected = false;
        _notifyListeners();
      },
    );
    
    // בדיקה ראשונית
    _checkInitialConnection();
  }

  /// בדיקה ראשונית של החיבור
  static Future<void> _checkInitialConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking initial connectivity: $e');
      _isConnected = false;
      _notifyListeners();
    }
  }

  /// עדכון סטטוס החיבור
  static void _updateConnectionStatus(List<ConnectivityResult> result) {
    _isConnected = result.any((connectivity) => 
      connectivity != ConnectivityResult.none);
    
    debugPrint('Network status changed: $_isConnected');
    _notifyListeners();
  }

  /// הוספת מאזין לשינויים בחיבור
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// הסרת מאזין
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// הודעה לכל המאזינים
  static void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error notifying network listener: $e');
      }
    }
  }

  /// בדיקה אם יש חיבור לאינטרנט
  static bool get isConnected => _isConnected;

  /// בדיקה אסינכרונית של החיבור
  static Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.any((connectivity) => connectivity != ConnectivityResult.none);
    } catch (e) {
      debugPrint('Error checking connection: $e');
      return false;
    }
  }

  /// קבלת סוג החיבור הנוכחי
  static Future<List<ConnectivityResult>> getConnectionType() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('Error getting connection type: $e');
      return [ConnectivityResult.none];
    }
  }

  /// הודעה על חיבור לאינטרנט
  static String getConnectionMessage() {
    if (_isConnected) {
      return 'יש חיבור לאינטרנט';
    } else {
      return 'אין חיבור לאינטרנט';
    }
  }

  /// ביצוע פעולה עם retry אוטומטי
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    String? operationName,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < maxRetries) {
      try {
        // בדיקת חיבור לפני הפעולה
        if (!_isConnected) {
          await Future.delayed(delay);
          final connected = await checkConnection();
          if (!connected) {
            throw Exception('אין חיבור לאינטרנט');
          }
        }

        // ביצוע הפעולה
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempts++;
        
        debugPrint('${operationName ?? 'Operation'} failed (attempt $attempts/$maxRetries): $e');
        
        if (attempts < maxRetries) {
          // המתנה לפני ניסיון נוסף
          await Future.delayed(delay * attempts);
        }
      }
    }

    throw lastException ?? Exception('הפעולה נכשלה לאחר $maxRetries ניסיונות');
  }

  /// בדיקה אם שגיאה היא שגיאת רשת
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
           errorString.contains('timeout') ||
           errorString.contains('connection') ||
           errorString.contains('unreachable') ||
           errorString.contains('socket') ||
           errorString.contains('dns') ||
           errorString.contains('firebase') && errorString.contains('unavailable');
  }

  /// קבלת הודעת שגיאה מותאמת
  static String getErrorMessage(dynamic error) {
    if (isNetworkError(error)) {
      return 'שגיאת רשת - בדוק את החיבור לאינטרנט';
    }
    
    // טיפול בשגיאות Firebase Auth
    if (error.toString().contains('user-not-found') || 
        error.toString().contains('USER_NOT_FOUND')) {
      return 'אימייל זה אינו רשום במערכת';
    }
    
    if (error.toString().contains('wrong-password') || 
        error.toString().contains('WRONG_PASSWORD') ||
        error.toString().contains('invalid-credential') ||
        error.toString().contains('INVALID_CREDENTIAL')) {
      return 'הסיסמה שגויה';
    }
    
    if (error.toString().contains('timeout')) {
      return 'פסק זמן - החיבור איטי מדי';
    }
    
    if (error.toString().contains('permission')) {
      return 'שגיאה בהרשאות - בדוק את ההגדרות';
    }
    
    return 'שגיאה לא צפויה - נסה שוב';
  }

  /// הודעה מפורטת על סוג החיבור
  static Future<String> getDetailedConnectionMessage() async {
    if (!_isConnected) {
      return 'אין חיבור לאינטרנט - בדוק את החיבור שלך';
    }

    try {
      final connectionTypes = await getConnectionType();
      
      if (connectionTypes.contains(ConnectivityResult.wifi)) {
        return 'מחובר ל-WiFi';
      } else if (connectionTypes.contains(ConnectivityResult.mobile)) {
        return 'מחובר לנתונים ניידים';
      } else if (connectionTypes.contains(ConnectivityResult.ethernet)) {
        return 'מחובר לאינטרנט קווי';
      } else if (connectionTypes.contains(ConnectivityResult.bluetooth)) {
        return 'מחובר דרך Bluetooth';
      } else {
        return 'מחובר לאינטרנט';
      }
    } catch (e) {
      return 'מחובר לאינטרנט';
    }
  }

  /// סגירת השירות
  static void dispose() {
    _connectivitySubscription?.cancel();
    _listeners.clear();
  }
}

/// מיקסין לבדיקת חיבור לאינטרנט
mixin NetworkMixin<T extends StatefulWidget> on State<T> {
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  @override
  void initState() {
    super.initState();
    _isConnected = NetworkService.isConnected;
    NetworkService.addListener(_onNetworkChanged);
  }

  @override
  void dispose() {
    NetworkService.removeListener(_onNetworkChanged);
    super.dispose();
  }

  void _onNetworkChanged() {
    if (mounted) {
      setState(() {
        _isConnected = NetworkService.isConnected;
      });
    }
  }

  /// הצגת הודעת חיבור לאינטרנט
  void showNetworkMessage(BuildContext context) {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white),
              const SizedBox(width: 8),
              const Text('אין חיבור לאינטרנט'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'נסה שוב',
            textColor: Colors.white,
            onPressed: () async {
              final connected = await NetworkService.checkConnection();
              // Guard context usage after async gap
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(connected ? 'החיבור שוחזר!' : 'עדיין אין חיבור'),
                  backgroundColor: connected ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  /// הצגת הודעת שגיאת רשת
  void showNetworkError(BuildContext context, {String? customMessage, VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(customMessage ?? 'שגיאת רשת - בדוק את החיבור שלך'),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'נסה שוב',
          textColor: Colors.white,
          onPressed: () async {
            if (onRetry != null) {
              onRetry();
            } else {
              final connected = await NetworkService.checkConnection();
              // Guard context usage after async gap
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(connected ? 'החיבור שוחזר!' : 'עדיין אין חיבור'),
                  backgroundColor: connected ? Colors.green : Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  /// הצגת הודעת שגיאה מותאמת
  void showError(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    final errorMessage = NetworkService.getErrorMessage(error);
    final isNetworkErr = NetworkService.isNetworkError(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isNetworkErr ? Icons.wifi_off : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(errorMessage),
            ),
          ],
        ),
        backgroundColor: isNetworkErr ? Colors.orange : Colors.red,
        duration: const Duration(seconds: 4),
        action: onRetry != null ? SnackBarAction(
          label: 'נסה שוב',
          textColor: Colors.white,
          onPressed: onRetry,
        ) : null,
      ),
    );
  }

  /// הצגת הודעת הצלחה
  void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
