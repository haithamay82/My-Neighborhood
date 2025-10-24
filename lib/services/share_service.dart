import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/request.dart';

class ShareService {
  /// שיתוף בקשה ב-WhatsApp
  static Future<void> shareViaWhatsApp(Request request) async {
    try {
      final message = _buildShareMessage(request);
      final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(message)}';
      
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Could not launch WhatsApp');
      }
    } catch (e) {
      debugPrint('Error sharing via WhatsApp: $e');
    }
  }

  /// שיתוף בקשה ב-SMS
  static Future<void> shareViaSMS(Request request) async {
    try {
      final message = _buildShareMessage(request);
      final smsUrl = 'sms:?body=${Uri.encodeComponent(message)}';
      
      final uri = Uri.parse(smsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Could not launch SMS');
      }
    } catch (e) {
      debugPrint('Error sharing via SMS: $e');
    }
  }

  /// שיתוף כללי (מערכת)
  static Future<void> shareGeneral(Request request) async {
    try {
      final message = _buildShareMessage(request);
      await Share.share(message, subject: 'בקשה מעניינת - NearMe');
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  /// בניית הודעת השיתוף
  static String _buildShareMessage(Request request) {
    final appUrl = 'https://nearme-970f3.web.app';
    final deepLink = '$appUrl/request/${request.requestId}';
    
    return '''
🎯 בקשה מעניינת ב-NearMe!

📝 ${request.title}
📍 ${request.location?.name ?? 'מיקום לא צוין'}
📅 ${_formatDate(request.createdAt)}

${request.description}

🔗 הורד את האפליקציה: $appUrl
📱 או לחץ כאן: $deepLink

#NearMe #בקשות #עזרה
''';
  }

  /// עיצוב תאריך
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return 'לפני ${difference.inDays} ימים';
    } else if (difference.inHours > 0) {
      return 'לפני ${difference.inHours} שעות';
    } else if (difference.inMinutes > 0) {
      return 'לפני ${difference.inMinutes} דקות';
    } else {
      return 'עכשיו';
    }
  }
}
