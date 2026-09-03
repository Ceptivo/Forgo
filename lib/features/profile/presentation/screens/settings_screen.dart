import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../support/presentation/screens/charities_screen.dart';
import '../../../support/presentation/screens/feedback_form_screen.dart';
import 'account_screen.dart';

/// Settings landing screen — a list of categories so more can be added
/// the same way later.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsCategoryTile(
            icon: Icons.person_outline,
            label: 'Account',
            subtitle: 'Username, date of birth, email',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCategoryTile(
            icon: Icons.bug_report_outlined,
            label: 'Report a Bug',
            subtitle: 'Tell us what went wrong',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FeedbackFormScreen(
                  kind: 'bug',
                  appBarTitle: 'Report a Bug',
                  heading: "What's not working?",
                  body:
                      'The more detail, the faster we can track it down — '
                      'what you were doing, and what happened instead.',
                  titleLabel: 'Summary',
                  descriptionLabel: 'What happened',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCategoryTile(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Suggest a Feature',
            subtitle: 'Tell us what you want to see',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FeedbackFormScreen(
                  kind: 'feature',
                  appBarTitle: 'Suggest a Feature',
                  heading: 'What should Forgo do next?',
                  body:
                      'Every suggestion gets read — the most popular ones '
                      'make it onto the shortlist people can vote on.',
                  titleLabel: 'Feature',
                  descriptionLabel: 'Why you want it',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCategoryTile(
            icon: Icons.volunteer_activism_outlined,
            label: 'Charities we support',
            subtitle: "Where a forfeited goal's stake goes",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CharitiesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  const _SettingsCategoryTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.titleMedium),
                    Text(subtitle, style: textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
