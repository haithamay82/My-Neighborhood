import 'package:flutter/material.dart';

class RememberMeDialog extends StatefulWidget {
  final String loginMethod;
  final VoidCallback onRemember;
  final VoidCallback onDontRemember;

  const RememberMeDialog({
    Key? key,
    required this.loginMethod,
    required this.onRemember,
    required this.onDontRemember,
  }) : super(key: key);

  @override
  State<RememberMeDialog> createState() => _RememberMeDialogState();
}

class _RememberMeDialogState extends State<RememberMeDialog> {
  bool _rememberMe = false;

  String get _methodDisplayName {
    switch (widget.loginMethod) {
      case 'email':
        return 'אימייל וסיסמה';
      case 'google':
        return 'גוגל';
      case 'facebook':
        return 'פייסבוק';
      case 'instagram':
        return 'אינסטגרם';
      case 'tiktok':
        return 'טיקטוק';
      default:
        return 'החשבון שלך';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.fingerprint,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'זכור אותי',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'האם תרצה לשמור את פרטי הכניסה שלך?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'שיטת כניסה: $_methodDisplayName',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'אם תבחר כן, תוכל להיכנס אוטומטית בפעם הבאה',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
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
            title: const Text(
              'שמור את פרטי הכניסה שלי',
              style: TextStyle(fontSize: 16),
            ),
            subtitle: const Text(
              'אני רוצה להיכנס אוטומטית בפעם הבאה',
              style: TextStyle(fontSize: 12),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onDontRemember();
          },
          child: Text(
            'לא, תודה',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _rememberMe ? () {
            Navigator.of(context).pop();
            widget.onRemember();
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
          child: const Text(
            'שמור',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
