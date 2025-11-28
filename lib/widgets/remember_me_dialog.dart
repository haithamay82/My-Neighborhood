import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class RememberMeDialog extends StatefulWidget {
  final String loginMethod;
  final VoidCallback onRemember;
  final VoidCallback onDontRemember;

  const RememberMeDialog({
    super.key,
    required this.loginMethod,
    required this.onRemember,
    required this.onDontRemember,
  });

  @override
  State<RememberMeDialog> createState() => _RememberMeDialogState();
}

class _RememberMeDialogState extends State<RememberMeDialog> {
  bool _rememberMe = false;

  String _methodDisplayName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (widget.loginMethod) {
      case 'email':
        return l10n.emailAndPassword;
      case 'google':
        return 'גוגל'; // Google - שם מותג, לא מתורגם
      case 'facebook':
        return 'פייסבוק'; // Facebook - שם מותג, לא מתורגם
      case 'instagram':
        return 'אינסטגרם'; // Instagram - שם מותג, לא מתורגם
      case 'tiktok':
        return 'טיקטוק'; // TikTok - שם מותג, לא מתורגם
      default:
        return l10n.yourAccount; // נצטרך להוסיף תרגום זה
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.fingerprint,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            l10n.rememberMe,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : null,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.saveCredentialsQuestion,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.loginMethod(_methodDisplayName(context)),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.blue.shade900.withValues(alpha: 0.3) 
                  : Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.blue[700]! 
                    : Colors.blue[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.saveCredentialsInfo,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            title: Text(
              l10n.saveCredentialsText,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : null,
              ),
            ),
            subtitle: Text(
              l10n.autoLoginText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white70 
                    : null,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
      actions: [
        // כפתור "לא תודה" - תמיד מוחק את כל הפרטים השמורים, גם אם הצ'קבוקס מסומן
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onDontRemember(); // זה תמיד ימחק את כל הפרטים השמורים
          },
          child: Text(
            l10n.noThanks,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
        // כפתור "שמור" - פעיל רק אם הצ'קבוקס מסומן, ושומר את הפרטים
        ElevatedButton(
          onPressed: _rememberMe ? () {
            Navigator.of(context).pop();
            widget.onRemember(); // זה ישמור את הפרטים רק אם הצ'קבוקס מסומן
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _rememberMe 
                ? Theme.of(context).primaryColor 
                : Colors.grey[400],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            l10n.save,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// פונקציה עזר להצגת הדיאלוג
Future<void> showRememberMeDialog({
  required BuildContext context,
  required String loginMethod,
  required VoidCallback onRemember,
  required VoidCallback onDontRemember,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => RememberMeDialog(
      loginMethod: loginMethod,
      onRemember: onRemember,
      onDontRemember: onDontRemember,
    ),
  );
}
