import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_tracking_service.dart';

class AppSharingService {
  // קישורים לאפליקציה (יש לעדכן כשהאפליקציה תהיה זמינה בחנויות)
  static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.example.flutter1';
  static const String _appStoreUrl = 'https://apps.apple.com/app/id123456789';
  
  // טקסט שיתוף מוכן
  static const String _shareText = '''
🏠 גיליתי אפליקציה מדהימה שמשנה את השכונה!

"שכונתי" - האפליקציה שמחברת בין שכנים לעזרה הדדית אמיתית

🌟 למה זה מדהים:
• בקשות עזרה מקומיות - תמיד יש מישהו קרוב שיכול לעזור
• עזרה הדדית בשכונה - קהילה תומכת וחמה
• חיבור אמיתי בין שכנים - הכרת האנשים שגרים לידך
• מערכת דירוגים ואמון - רק אנשים אמינים ומוכחים
• צ'אט ישיר עם נותני השירות - תקשורת נוחה ומהירה
• מפה אינטראקטיבית - רואה בדיוק מי יכול לעזור

💡 דוגמאות לעזרה:
🔧 תיקונים קטנים בבית
🚗 הסעות קצרות
🛒 קניות מהסופר
👶 שמירה על ילדים
📚 עזרה בלימודים
🌱 טיפול בגינה

📱 הורד עכשיו וקבל גישה מלאה לאפליקציה בחינם במשך 3 חודשים:
Android: $_playStoreUrl
iOS: $_appStoreUrl

💡 האפליקציה בחינם עם אפשרויות מנוי מתקדמות:
• פרטי חינם - בקשות עזרה בסיסיות
• פרטי מנוי - תכונות מתקדמות ועדיפות
• עסקי מנוי - פרסום שירותים מקצועיים

🤝 בואו נבנה קהילה חזקה יותר יחד!
#שכונתי #עזרה_הדדית #שכנים #קהילה #ישראל
''';

  /// עדכון מספר המלצות המשתמש
  static Future<void> _incrementRecommendationsCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'recommendationsCount': FieldValue.increment(1),
        'lastRecommendationAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Recommendations count incremented for user: ${user.uid}');
      
      // בדיקת הגדלת טווח אחרי עדכון המלצות
      await _checkRadiusIncrease();
    } catch (e) {
      debugPrint('❌ Error incrementing recommendations count: $e');
    }
  }

  /// עדכון מספר השיתופים להארכת תקופת ניסיון
  static Future<void> _incrementTrialExtensionSharingCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // נשתמש באותה פונקציה כמו המלצות רגילות
      await _incrementRecommendationsCount();
      
      debugPrint('✅ Trial extension sharing count incremented for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error incrementing trial extension sharing count: $e');
    }
  }

  /// בדיקת הגדלת טווח אחרי המלצה
  static Future<void> _checkRadiusIncrease() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userType = userData['userType'] as String? ?? 'personal';
      final isSubscriptionActive = userData['isSubscriptionActive'] as bool? ?? false;
      final recommendationsCount = userData['recommendationsCount'] as int? ?? 0;
      final averageRating = userData['averageRating'] as double? ?? 0.0;
      final isAdmin = userData['isAdmin'] as bool? ?? false;

      // חישוב הטווח הנוכחי
      final currentRadius = _calculateMaxRadiusForUser(
        userType: userType,
        isSubscriptionActive: isSubscriptionActive,
        recommendationsCount: recommendationsCount,
        averageRating: averageRating,
        isAdmin: isAdmin,
      );

      // חישוב הטווח הקודם (ללא הבונוסים הנוכחיים)
      final baseRadius = _calculateMaxRadiusForUser(
        userType: userType,
        isSubscriptionActive: isSubscriptionActive,
        recommendationsCount: 0,
        averageRating: 0.0,
        isAdmin: isAdmin,
      );

      // בדיקה אם יש שינוי משמעותי בטווח
      final radiusIncrease = currentRadius - baseRadius;
      if (radiusIncrease > 0) {
        await _sendRadiusIncreaseNotification(radiusIncrease, recommendationsCount, averageRating);
      }
    } catch (e) {
      debugPrint('❌ Error checking radius increase after recommendation: $e');
    }
  }

  /// חישוב טווח מקסימלי למשתמש (העתקה מ-LocationService)
  static double _calculateMaxRadiusForUser({
    required String userType,
    required bool isSubscriptionActive,
    required int recommendationsCount,
    required double averageRating,
    required bool isAdmin,
  }) {
    double baseRadius = 1000.0; // טווח בסיסי במטרים (1 ק"מ)

    // טווח לפי סוג משתמש (במטרים)
    switch (userType) {
      case 'personal':
        baseRadius = isSubscriptionActive ? 2000.0 : 1000.0; // 2 ק"מ או 1 ק"מ
        break;
      case 'business':
        baseRadius = isSubscriptionActive ? 3000.0 : 1000.0; // 3 ק"מ או 1 ק"מ
        break;
      case 'admin':
        baseRadius = 50000.0; // 50 ק"מ
        break;
    }

    // בונוס המלצות (200 מטר לכל המלצה)
    final recommendationsBonus = recommendationsCount * 200.0;

    // בונוס דירוג (במטרים)
    double ratingBonus = 0.0;
    if (averageRating >= 4.5) {
      ratingBonus = 1500.0; // 1.5 ק"מ
    } else if (averageRating >= 4.0) {
      ratingBonus = 1000.0; // 1 ק"מ
    } else if (averageRating >= 3.5) {
      ratingBonus = 500.0; // 500 מטר
    }

    return baseRadius + recommendationsBonus + ratingBonus;
  }

  /// שליחת התראה על הגדלת טווח (העתקה מ-LocationService)
  static Future<void> _sendRadiusIncreaseNotification(
    double radiusIncrease,
    int recommendationsCount,
    double averageRating,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // בדיקה אם כבר נשלחה התראה על הגדלת טווח עם אותם פרמטרים
      final hasBeenSent = await NotificationTrackingService.hasNotificationWithParamsBeenSent(
        userId: user.uid,
        notificationType: 'radius_increase',
        params: {
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating.toStringAsFixed(1),
          'radiusIncrease': radiusIncrease.toStringAsFixed(1),
        },
      );

      if (hasBeenSent) {
        debugPrint('Radius increase notification already sent for user: ${user.uid} with same parameters');
        return;
      }

      String message = '';
      String details = '';
      
      if (recommendationsCount > 0) {
        final recommendationsBonus = recommendationsCount * 200.0;
        message += '🎉 תודה על $recommendationsCount המלצות שלך! ';
        details += 'המלצות: +${(recommendationsBonus / 1000).toStringAsFixed(1)} ק"מ ';
      }
      
      if (averageRating >= 3.5) {
        double ratingBonus = 0.0;
        if (averageRating >= 4.5) {
          ratingBonus = 1500.0;
        } else if (averageRating >= 4.0) {
          ratingBonus = 1000.0;
        } else if (averageRating >= 3.5) {
          ratingBonus = 500.0;
        }
        message += '⭐ דירוג מעולה של ${averageRating.toStringAsFixed(1)}! ';
        details += 'דירוג גבוה: +${(ratingBonus / 1000).toStringAsFixed(1)} ק"מ ';
      }
      
      message += '🚀 הטווח שלך גדל ב-${(radiusIncrease / 1000).toStringAsFixed(1)} ק"מ!';

      // יצירת התראה
      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'toUserId': user.uid,
        'title': 'הטווח שלך גדל!',
        'message': message,
        'type': 'radius_increase',
        'data': {
          'radiusIncrease': radiusIncrease,
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating,
          'details': details.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      };

      // שמירת ההתראה ב-Firestore
      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notification);

      // סימון שההתראה נשלחה
      await NotificationTrackingService.markNotificationWithParamsAsSent(
        userId: user.uid,
        notificationType: 'radius_increase',
        params: {
          'recommendationsCount': recommendationsCount,
          'averageRating': averageRating.toStringAsFixed(1),
          'radiusIncrease': radiusIncrease.toStringAsFixed(1),
        },
      );

      debugPrint('✅ Radius increase notification sent: $message');
    } catch (e) {
      debugPrint('❌ Error sending radius increase notification: $e');
    }
  }

  /// שיתוף האפליקציה עם מעקב להארכת תקופת ניסיון
  static Future<void> shareAppForTrialExtension(BuildContext context) async {
    try {
      // הצגת דיאלוג שיתוף עם אפשרויות
      await showDialog(
        context: context,
        builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.share,
                color: Colors.blue[400],
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'שתף אפליקציה להארכת תקופת ניסיון',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'בחר איך תרצה לשתף את האפליקציה:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // אפשרויות שיתוף
              _buildShareOption(
                context,
                icon: Icons.chat,
                title: 'WhatsApp',
                subtitle: 'שלח לחברים ב-WhatsApp',
                color: Colors.green,
                onTap: () => _shareToWhatsAppForTrialExtension(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.message,
                title: 'SMS',
                subtitle: 'שלח הודעה',
                color: Colors.blue,
                onTap: () => _shareToSMSForTrialExtension(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.email,
                title: 'Email',
                subtitle: 'שלח במייל',
                color: Colors.orange,
                onTap: () => _shareToEmailForTrialExtension(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.share,
                title: 'שיתוף כללי',
                subtitle: 'פתח אפשרויות שיתוף',
                color: Colors.blue,
                onTap: () => _shareGeneralForTrialExtension(context),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ביטול'),
            ),
          ],
        );
      },
      );
    } catch (e) {
      debugPrint('Error in shareAppForTrialExtension: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בפתיחת שיתוף: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// שיתוף האפליקציה
  static Future<void> shareApp(BuildContext context) async {
    try {
      // הצגת דיאלוג שיתוף עם אפשרויות
      await showDialog(
        context: context,
        builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.share,
                color: Colors.blue[400],
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'שתף אפליקציה',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'בחר איך תרצה לשתף את האפליקציה:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // אפשרויות שיתוף
              _buildShareOption(
                context,
                icon: Icons.chat,
                title: 'WhatsApp',
                subtitle: 'שלח לחברים ב-WhatsApp',
                color: Colors.green,
                onTap: () => _shareToWhatsApp(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.message,
                title: 'SMS',
                subtitle: 'שלח הודעה',
                color: Colors.blue,
                onTap: () => _shareToSMS(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.email,
                title: 'Email',
                subtitle: 'שלח במייל',
                color: Colors.orange,
                onTap: () => _shareToEmail(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.message,
                title: 'Facebook Messenger',
                subtitle: 'שלח ב-Messenger',
                color: Colors.indigo,
                onTap: () => _shareToFacebook(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.camera_alt,
                title: 'Instagram',
                subtitle: 'שתף ב-Instagram',
                color: Colors.pink,
                onTap: () => _shareToInstagram(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.share,
                title: 'שיתוף כללי',
                subtitle: 'פתח אפשרויות שיתוף',
                color: Colors.blue,
                onTap: () => _shareGeneral(context),
              ),
              const SizedBox(height: 8),
              _buildShareOption(
                context,
                icon: Icons.copy,
                title: 'העתק ללוח',
                subtitle: 'העתק טקסט לשיתוף',
                color: Colors.grey,
                onTap: () => _copyToClipboard(context),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ביטול'),
            ),
          ],
        );
      },
    );
    } catch (e) {
      debugPrint('Share app dialog failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה בפתיחת דיאלוג השיתוף'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// בניית אפשרות שיתוף
  static Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withOpacity(0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// שיתוף ל-WhatsApp
  static Future<void> _shareToWhatsApp(BuildContext context) async {
    try {
      // נסיון ראשון - WhatsApp ישיר
      try {
        final Uri whatsappUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(_shareText)}');
        final bool launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        
        if (launched) {
          // עדכון מספר המלצות
          await _incrementRecommendationsCount();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('פותח WhatsApp...'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('WhatsApp direct failed: $e');
      }
      
      // נסיון שני - WhatsApp עם intent
      try {
        final Uri whatsappIntentUri = Uri.parse('intent://send?text=${Uri.encodeComponent(_shareText)}#Intent;scheme=whatsapp;package=com.whatsapp;end');
        final bool launched = await launchUrl(whatsappIntentUri, mode: LaunchMode.externalApplication);
        
        if (launched) {
          // עדכון מספר המלצות
          await _incrementRecommendationsCount();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('פותח WhatsApp...'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('WhatsApp intent failed: $e');
      }
      
      // נסיון שלישי - WhatsApp Web
      try {
        final Uri whatsappWebUri = Uri.parse('https://web.whatsapp.com/send?text=${Uri.encodeComponent(_shareText)}');
        await launchUrl(whatsappWebUri, mode: LaunchMode.externalApplication);
        
        // עדכון מספר המלצות
        await _incrementRecommendationsCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח WhatsApp Web...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      } catch (e) {
        debugPrint('WhatsApp Web failed: $e');
      }
      
      // אם כל הנסיונות נכשלו, העתק ללוח
      await _copyToClipboard(context);
      
    } catch (e) {
      debugPrint('WhatsApp sharing failed completely: $e');
      await _copyToClipboard(context);
    }
  }

  /// שיתוף ל-SMS
  static Future<void> _shareToSMS(BuildContext context) async {
    try {
      final Uri smsUri = Uri.parse('sms:?body=${Uri.encodeComponent(_shareText)}');
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        
        // עדכון מספר המלצות
        await _incrementRecommendationsCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח אפליקציית הודעות...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // אם SMS לא זמין, העתק ללוח
        await _copyToClipboard(context);
      }
    } catch (e) {
      // אם יש שגיאה, העתק ללוח
      await _copyToClipboard(context);
    }
  }

  /// שיתוף ל-Email
  static Future<void> _shareToEmail(BuildContext context) async {
    try {
      final Uri emailUri = Uri.parse(
        'mailto:?subject=${Uri.encodeComponent('🏠 גיליתי אפליקציה מדהימה - שכונתי!')}&body=${Uri.encodeComponent(_shareText)}'
      );
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        
        // עדכון מספר המלצות
        await _incrementRecommendationsCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח אפליקציית מייל...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // אם Email לא זמין, העתק ללוח
        await _copyToClipboard(context);
      }
    } catch (e) {
      // אם יש שגיאה, העתק ללוח
      await _copyToClipboard(context);
    }
  }

  /// שיתוף ל-Instagram
  static Future<void> _shareToInstagram(BuildContext context) async {
    try {
      // נסיון לפתוח את Instagram עם האפליקציה
      final Uri instagramAppUri = Uri.parse('instagram://story-camera');
      
      try {
        await launchUrl(instagramAppUri, mode: LaunchMode.externalApplication);
        
        // עדכון מספר המלצות
        await _incrementRecommendationsCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח Instagram... העתק את הטקסט מהלוח'),
              backgroundColor: Colors.pink,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // העתק את הטקסט ללוח כדי שהמשתמש יוכל להדביק
        await Clipboard.setData(ClipboardData(text: _shareText));
        return;
      } catch (e) {
        debugPrint('Instagram app launch failed: $e');
      }
      
      // נסיון שני - עם Instagram Web
      try {
        final Uri instagramWebUri = Uri.parse('https://www.instagram.com/');
        await launchUrl(instagramWebUri, mode: LaunchMode.externalApplication);
        
        // עדכון מספר המלצות
        await _incrementRecommendationsCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח Instagram Web... העתק את הטקסט מהלוח'),
              backgroundColor: Colors.pink,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // העתק את הטקסט ללוח
        await Clipboard.setData(ClipboardData(text: _shareText));
        return;
      } catch (e) {
        debugPrint('Instagram Web launch failed: $e');
      }
      
      // אם כל הנסיונות נכשלו, העתק ללוח
      await _copyToClipboard(context);
      
    } catch (e) {
      // אם יש שגיאה כללית, העתק ללוח
      debugPrint('Instagram sharing failed completely: $e');
      await _copyToClipboard(context);
    }
  }

  /// שיתוף ל-Facebook Messenger
  static Future<void> _shareToFacebook(BuildContext context) async {
    try {
      // נסיון ראשון - Facebook Messenger ישיר
      final Uri messengerUri = Uri.parse('fb-messenger://share?text=${Uri.encodeComponent(_shareText)}');
      final bool launched = await launchUrl(messengerUri, mode: LaunchMode.externalApplication);
      
      if (launched) {
        // עדכון מספר המלצות
        await _incrementRecommendationsCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח Facebook Messenger...'),
              backgroundColor: Colors.indigo,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // אם Messenger לא זמין, השתמש בשיתוף כללי
        await _shareGeneral(context);
      }
    } catch (e) {
      debugPrint('Facebook Messenger failed: $e');
      // אם Messenger נכשל, השתמש בשיתוף כללי
      await _shareGeneral(context);
    }
  }


  /// שיתוף כללי עם share_plus
  static Future<void> _shareGeneral(BuildContext context) async {
    try {
      await Share.share(
        _shareText,
        subject: '🏠 גיליתי אפליקציה מדהימה - שכונתי!',
      );
      
      // עדכון מספר המלצות
      await _incrementRecommendationsCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('פותח אפשרויות שיתוף...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('General sharing failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שגיאה בפתיחת אפשרויות השיתוף'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// העתקה ללוח
  static Future<void> _copyToClipboard(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: _shareText));
      
      // עדכון מספר המלצות
      await _incrementRecommendationsCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הטקסט הועתק ללוח! שתף אותו עם חברים'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהעתקה: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// דירוג האפליקציה
  static Future<void> rateApp(BuildContext context) async {
    try {
      // עדכון מספר המלצות
      await _incrementRecommendationsCount();
      
      // פתיחת חנות האפליקציות
      await _openAppStore(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בפתיחת החנות: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// פתיחת חנות האפליקציות
  static Future<void> _openAppStore(BuildContext context) async {
    try {
      // נסיון לפתוח את Google Play Store
      final Uri playStoreUri = Uri.parse(_playStoreUrl);
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        return;
      }
      
      // נסיון לפתוח את App Store
      final Uri appStoreUri = Uri.parse(_appStoreUrl);
      if (await canLaunchUrl(appStoreUri)) {
        await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
        return;
      }
      
      // אם לא הצליח, הצגת הודעה
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא ניתן לפתוח את חנות האפליקציות'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בפתיחת החנות: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// הצגת דיאלוג המלצה
  static Future<void> showRecommendationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.favorite,
                color: Colors.red[400],
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'המלץ לחברים',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'אהבת את האפליקציה? עזור לנו לצמוח!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '🎯 שתף עם חברים\n⭐ דרג אותנו\n💬 ספר על החוויה שלך',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Text(
                  'כל המלצה עוזרת לנו להגיע לעוד שכנים שמחפשים עזרה הדדית!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('אולי מאוחר יותר'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                shareApp(context);
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('שתף עכשיו'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// הצגת דיאלוג דירוג
  static Future<void> showRatingDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.amber[600],
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'דרג את האפליקציה',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'איך הייתה החוויה שלך?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'הדירוג שלך עוזר לנו לשפר את האפליקציה ולהגיע לעוד משתמשים.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: const Text(
                  '⭐ דירוג גבוה = יותר שכנים = יותר עזרה הדדית!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('אולי מאוחר יותר'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                rateApp(context);
              },
              icon: const Icon(Icons.star, size: 18),
              label: const Text('דרג עכשיו'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[600],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// הצגת דיאלוג תגמולים
  static Future<void> showRewardsDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.card_giftcard,
                color: Colors.purple[400],
                size: 28,
              ),
              const SizedBox(width: 8),
              const Text(
                'תגמולים לממליצים',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'המלץ על האפליקציה וקבל תגמולים!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '🎁 10 נקודות - כל המלצה\n⭐ 5 נקודות - דירוג 5 כוכבים\n💬 3 נקודות - ביקורת חיובית',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: const Text(
                  'נקודות = עדיפות בבקשות + תכונות מיוחדות!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('אולי מאוחר יותר'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                shareApp(context);
              },
              icon: const Icon(Icons.card_giftcard, size: 18),
              label: const Text('התחל להרוויח'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// שיתוף ב-WhatsApp עם מעקב להארכת תקופת ניסיון
  static Future<void> _shareToWhatsAppForTrialExtension(BuildContext context) async {
    try {
      final Uri whatsappUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(_shareText)}');
      final bool launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      
      if (launched) {
        await _incrementTrialExtensionSharingCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח WhatsApp...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _copyToClipboardForTrialExtension(context);
      }
    } catch (e) {
      debugPrint('WhatsApp sharing failed: $e');
      await _copyToClipboardForTrialExtension(context);
    }
  }

  /// שיתוף ב-SMS עם מעקב להארכת תקופת ניסיון
  static Future<void> _shareToSMSForTrialExtension(BuildContext context) async {
    try {
      final Uri smsUri = Uri.parse('sms:?body=${Uri.encodeComponent(_shareText)}');
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        await _incrementTrialExtensionSharingCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח אפליקציית הודעות...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _copyToClipboardForTrialExtension(context);
      }
    } catch (e) {
      debugPrint('SMS sharing failed: $e');
      await _copyToClipboardForTrialExtension(context);
    }
  }

  /// שיתוף במייל עם מעקב להארכת תקופת ניסיון
  static Future<void> _shareToEmailForTrialExtension(BuildContext context) async {
    try {
      final Uri emailUri = Uri.parse(
        'mailto:?subject=${Uri.encodeComponent('🏠 גיליתי אפליקציה מדהימה - שכונתי!')}&body=${Uri.encodeComponent(_shareText)}'
      );
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        await _incrementTrialExtensionSharingCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('פותח אפליקציית מייל...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _copyToClipboardForTrialExtension(context);
      }
    } catch (e) {
      debugPrint('Email sharing failed: $e');
      await _copyToClipboardForTrialExtension(context);
    }
  }

  /// שיתוף כללי עם מעקב להארכת תקופת ניסיון
  static Future<void> _shareGeneralForTrialExtension(BuildContext context) async {
    try {
      await Share.share(_shareText);
      await _incrementTrialExtensionSharingCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('פותח אפשרויות שיתוף...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('General sharing failed: $e');
      await _copyToClipboardForTrialExtension(context);
    }
  }

  /// העתקה ללוח עם מעקב להארכת תקופת ניסיון
  static Future<void> _copyToClipboardForTrialExtension(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: _shareText));
      await _incrementTrialExtensionSharingCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('הטקסט הועתק ללוח! שתף אותו עם חברים'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהעתקה: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
