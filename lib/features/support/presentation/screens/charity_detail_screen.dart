import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/charity.dart';
import '../widgets/charity_logo.dart';

/// Overview of a single charity — who they are, a link to their own page,
/// their registration details, and Forgo's own note on why they're one of
/// the charities behind forfeited stakes.
class CharityDetailScreen extends StatelessWidget {
  const CharityDetailScreen({super.key, required this.charity});

  final Charity charity;

  Future<void> _openWebsite(BuildContext context) async {
    final url = charity.websiteUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Couldn't open that link.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(charity.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: CharityLogo(logoUrl: charity.logoUrl, size: 88)),
            const SizedBox(height: 16),
            Text(
              charity.name,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              charity.description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (charity.websiteUrl != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openWebsite(context),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Visit their website'),
                ),
              ),
            if (charity.registrationInfo != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registration',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(charity.registrationInfo!, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
            if (charity.whyWeSupport != null) ...[
              const SizedBox(height: 28),
              Text('Why we support ${charity.name}', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(charity.whyWeSupport!, style: textTheme.bodyMedium),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
