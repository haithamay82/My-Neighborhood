import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/request.dart';
import '../models/ad.dart';

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
      // TODO: Replace with SharePlus.instance.share() when ShareParams API is stable
      // ignore: deprecated_member_use
      await Share.share(message);
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  /// בניית הודעת השיתוף
  static String _buildShareMessage(Request request) {
    final appUrl = 'https://nearme-970f3.web.app';
    final deepLink = '$appUrl/request/${request.requestId}';
    
    // בניית פרטי הבקשה
    final categoryName = _getCategoryName(request.category);
    final urgencyText = _getUrgencyText(request);
    final typeText = request.type == RequestType.paid ? '💰 בתשלום' : '🆓 חינם';
    final deadlineText = request.deadline != null 
        ? '⏰ תאריך יעד: ${_formatDate(request.deadline!)}'
        : '';
    
    return '''
🎯 בקשה מעניינת ב-"שכונתי"!

📝 ${request.title}
📍 ${request.location?.name ?? 'מיקום לא צוין'}
🏷️ קטגוריה: $categoryName
$typeText $urgencyText
📅 פורסם: ${_formatDate(request.createdAt)}
$deadlineText

📄 תיאור:
${request.description}

💡 רוצה לעזור? הורד את האפליקציה "שכונתי" וצור קשר ישיר!

📱 הורד עכשיו:
$appUrl

🔗 או לחץ כאן לפתיחת הבקשה:
$deepLink

🤝 בואו נבנה קהילה חזקה יותר יחד!
#שכונתי #עזרה_הדדית #בקשות #קהילה #ישראל
''';
  }
  
  /// קבלת שם הקטגוריה בעברית
  static String _getCategoryName(RequestCategory category) {
    return category.categoryDisplayName;
  }
  
  /// קבלת טקסט דחיפות
  static String _getUrgencyText(Request request) {
    if (request.isUrgent || request.urgencyLevel == UrgencyLevel.emergency) {
      return '🚨 דחוף מאוד!';
    } else if (request.urgencyLevel == UrgencyLevel.urgent24h) {
      return '⏰ דחוף - תוך 24 שעות';
    } else {
      return '';
    }
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

  // ========== פונקציות שיתוף למודעות ==========
  
  /// שיתוף מודעה ב-WhatsApp
  static Future<void> shareAdViaWhatsApp(Ad ad) async {
    try {
      final message = _buildAdShareMessage(ad);
      final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(message)}';
      
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Could not launch WhatsApp');
      }
    } catch (e) {
      debugPrint('Error sharing ad via WhatsApp: $e');
    }
  }

  /// שיתוף מודעה ב-SMS
  static Future<void> shareAdViaSMS(Ad ad) async {
    try {
      final message = _buildAdShareMessage(ad);
      final smsUrl = 'sms:?body=${Uri.encodeComponent(message)}';
      
      final uri = Uri.parse(smsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Could not launch SMS');
      }
    } catch (e) {
      debugPrint('Error sharing ad via SMS: $e');
    }
  }

  /// שיתוף כללי של מודעה (מערכת)
  static Future<void> shareAdGeneral(Ad ad) async {
    try {
      final message = _buildAdShareMessage(ad);
      // TODO: Replace with SharePlus.instance.share() when ShareParams API is stable
      // ignore: deprecated_member_use
      await Share.share(message);
    } catch (e) {
      debugPrint('Error sharing ad: $e');
    }
  }

  /// בניית הודעת השיתוף למודעה
  static String _buildAdShareMessage(Ad ad) {
    final appUrl = 'https://nearme-970f3.web.app';
    final deepLink = '$appUrl/ad/${ad.adId}';
    
    // בניית פרטי המודעה
    final categoryName = ad.category.categoryDisplayName;
    final priceText = ad.price != null ? '💰 מחיר: ${ad.price!.toStringAsFixed(0)} ₪' : '🆓 חינם';
    final appointmentText = ad.requiresAppointment ? '📅 דורש תור' : '';
    final deliveryText = ad.requiresDelivery ? '🚚 אפשר לקבל במשלוח' : '';
    
    return '''
📢 מודעה מעניינת ב-"שכונתי"!

📝 ${ad.title}
📍 ${ad.address ?? ad.location?.name ?? 'מיקום לא צוין'}
🏷️ קטגוריה: $categoryName
$priceText $appointmentText $deliveryText
📅 פורסם: ${_formatDate(ad.createdAt)}

📄 תיאור:
${ad.description}

💡 רוצה לראות עוד? הורד את האפליקציה "שכונתי"!

📱 הורד עכשיו:
$appUrl

🔗 או לחץ כאן לפתיחת המודעה:
$deepLink

🤝 בואו נבנה קהילה חזקה יותר יחד!
#שכונתי #מודעות #קהילה #ישראל
''';
  }
}
