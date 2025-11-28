import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class TermsAndPrivacyScreen extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool readOnly;

  const TermsAndPrivacyScreen({
    super.key,
    required this.onAccept,
    required this.onDecline,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termsAndPrivacyTitle),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // כותרת
            Center(
              child: Text(
                l10n.welcomeToTermsScreen,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // תנאי שימוש
            _buildSection(
              context,
              l10n.termsOfService,
              [
                l10n.termsSection1,
                l10n.termsSection2,
                l10n.termsSection3,
                l10n.termsSection4,
                l10n.termsSection5,
                l10n.termsSection6,
                l10n.termsSection7,
                l10n.termsSection8,
                l10n.termsSection10,
                l10n.termsSection11,
                l10n.termsSection12,
              ],
            ),

            const SizedBox(height: 24),

            // עזרה הדדית ובטיחות
            _buildSection(
              context,
              l10n.mutualHelpAndSafety,
              [
                l10n.mutualHelpSection1,
                l10n.mutualHelpSection2,
                l10n.mutualHelpSection3,
                l10n.mutualHelpSection4,
                l10n.mutualHelpSection5,
                l10n.mutualHelpSection6,
                l10n.mutualHelpSection8,
              ],
            ),

            const SizedBox(height: 24),

            // מדיניות פרטיות
            _buildSection(
              context,
              l10n.privacyPolicy,
              [
                l10n.privacySection1,
                l10n.privacySection2,
                l10n.privacySection3,
                l10n.privacySection4,
                l10n.privacySection5,
                l10n.privacySection6,
                l10n.privacySection7,
                l10n.privacySection8,
                l10n.privacySection9,
                l10n.privacySection10,
                l10n.privacySection11,
                l10n.privacySection12,
                l10n.privacySection13,
                l10n.privacySection14,
                l10n.privacySection15,
              ],
            ),

            // הצג את החלק הזה רק אם זה לא readOnly (כלומר, במהלך הרשמה)
            if (!readOnly) ...[
              const SizedBox(height: 32),

              // אזהרה חשובה
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.importantNote,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onTertiaryContainer,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.byContinuingYouConfirm,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onTertiaryContainer,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // כפתורי פעולה
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onDecline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.doNotAgree,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.agreeAndContinue,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // הודעה על עדכונים
              Center(
                child: Text(
                  l10n.termsMayBeUpdated,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        ...points.asMap().entries.map((entry) {
          final point = entry.value;
          // נסה לחלץ את המספר מהתחלה של הטקסט
          final numberMatch = RegExp(r'^(\d+)\.\s*').firstMatch(point);
          if (numberMatch != null) {
            final number = numberMatch.group(1);
            final text = point.substring(numberMatch.end);
            return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                    '$number. ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Text(
                      text,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
            );
          } else {
            // אם אין מספר, פשוט הצג את הטקסט
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                point,
                style: const TextStyle(height: 1.4),
              ),
            );
          }
        }),
      ],
    );
  }
}
