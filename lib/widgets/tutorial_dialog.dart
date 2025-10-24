import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

class TutorialDialog extends StatelessWidget {
  final String tutorialKey;
  final String title;
  final String message;
  final List<String> features;
  final String? actionText;
  final VoidCallback? onAction;
  final bool showDontShowAgain;

  const TutorialDialog({
    super.key,
    required this.tutorialKey,
    required this.title,
    required this.message,
    required this.features,
    this.actionText,
    this.onAction,
    this.showDontShowAgain = true,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.amber[600],
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
            if (features.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'מה תוכל לעשות:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        if (showDontShowAgain)
          TextButton(
            onPressed: () async {
              await TutorialService.markTutorialAsSeen(tutorialKey);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('לא להציג שוב'),
          ),
        if (actionText != null && onAction != null)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAction!();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text(actionText!),
          ),
        TextButton(
          onPressed: () async {
            if (showDontShowAgain) {
              await TutorialService.markTutorialAsSeen(tutorialKey);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('הבנתי'),
        ),
      ],
    );
  }
}
