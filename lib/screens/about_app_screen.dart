import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import 'terms_and_privacy_screen.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  String _appVersion = 'Loading...';
  String _appBuildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _appBuildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  Future<void> _openSupportEmail() async {
    final l10n = AppLocalizations.of(context);
    final email = l10n.aboutSupportEmail.isNotEmpty 
        ? l10n.aboutSupportEmail 
        : 'support@shchunati.com';
    final uri = Uri.parse('mailto:$email?subject=${Uri.encodeComponent(l10n.aboutSupportSubject)}');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open email: $email')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo or Icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.home,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // App Name
            Center(
              child: Text(
                l10n.aboutAppName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              l10n.aboutDescription,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 32),
            
            // Version Info
            _buildInfoCard(
              context,
              icon: Icons.info_outline,
              title: l10n.aboutVersion,
              content: '$_appVersion (Build: $_appBuildNumber)',
            ),
            const SizedBox(height: 16),
            
            // Support
            _buildInfoCard(
              context,
              icon: Icons.support_agent,
              title: l10n.aboutSupport,
              content: l10n.aboutSupportDescription,
              onTap: _openSupportEmail,
              isClickable: true,
            ),
            const SizedBox(height: 16),
            
            // Legal Links
            _buildLegalLinks(context, l10n),
            
            const SizedBox(height: 32),
            
            // Footer
            Center(
              child: Text(
                l10n.aboutFooter,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    VoidCallback? onTap,
    bool isClickable = false,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isClickable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    if (isClickable) ...[
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).aboutClickToContact,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isClickable)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalLinks(BuildContext context, AppLocalizations l10n) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aboutLegalTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildLegalLink(context, l10n.termsAndPrivacyButton, Icons.description, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TermsAndPrivacyScreen(
                    onAccept: () {},
                    onDecline: () {},
                    readOnly: true, // קריאה בלבד - לא להציג לחצנים
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalLink(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

