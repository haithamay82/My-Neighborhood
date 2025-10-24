import 'package:flutter/material.dart';
import '../services/network_service.dart';

/// Widget שמטפל בקישוריות חלשה ומציג הודעות מתאימות
class NetworkAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget? offlineWidget;
  final bool showOfflineIndicator;
  final VoidCallback? onConnectionRestored;

  const NetworkAwareWidget({
    super.key,
    required this.child,
    this.offlineWidget,
    this.showOfflineIndicator = true,
    this.onConnectionRestored,
  });

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> with NetworkMixin {
  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!isConnected && widget.showOfflineIndicator)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange,
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'אין חיבור לאינטרנט',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final connected = await NetworkService.checkConnection();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(connected ? 'החיבור שוחזר!' : 'עדיין אין חיבור'),
                            backgroundColor: connected ? Colors.green : Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('נסה שוב', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Mixin שמספק פונקציות עזר לטיפול בקישוריות
mixin NetworkAwareMixin<T extends StatefulWidget> on State<T> {
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

  /// ביצוע פעולה עם טיפול בשגיאות רשת
  Future<T?> executeWithNetworkHandling<T>(
    Future<T> Function() operation, {
    String? operationName,
    VoidCallback? onRetry,
    bool showLoading = true,
  }) async {
    if (!isConnected) {
      showNetworkMessage(context);
      return null;
    }

    if (showLoading) {
      _showLoadingDialog();
    }

    try {
      final result = await NetworkService.executeWithRetry(
        operation,
        operationName: operationName,
      );
      
      if (showLoading && mounted) {
        Navigator.pop(context);
      }
      
      return result;
    } catch (e) {
      if (showLoading && mounted) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        showError(context, e, onRetry: onRetry);
      }
      return null;
    }
  }

  /// הצגת דיאלוג טעינה
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('מעבד...'),
              ],
            ),
          ),
        ),
      ),
    );
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
              if (mounted) {
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
