import 'package:flutter/material.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_grid.dart';

/// What Forgo is, what it does, and why — reached from the info icon on
/// the home screen.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About Forgo')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BentoCard(
              gradient: AppColors.accentGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"A goal without a stake is just a wish."',
                    style: textTheme.titleLarge?.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Put money behind the thing you keep meaning to do.',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('What Forgo is', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              "Forgo is a commitment app: you set a goal, stake real money "
              "on it, and either follow through and keep your stake, or "
              "fall short and it goes to charity. No automated tracking — "
              "just you, your word, and money on the line to make sure "
              "that word means something.",
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('What you can do', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            const _FeatureRow(
              icon: Icons.flag_rounded,
              title: 'Stake a goal',
              description:
                  'Distance, time, or weight-loss — set a target, stake '
                  'what it\'s worth to you, and report back when it\'s done.',
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.local_fire_department_rounded,
              title: 'Build a streak',
              description:
                  'Every goal you complete adds to your streak and shows '
                  'up on your heatmap — earn badges the more consistent '
                  'you are.',
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.groups_rounded,
              title: 'Challenge a group',
              description:
                  'Start a group chat, stake a shared goal, and see who '
                  'actually follows through on the leaderboard.',
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.people_alt_rounded,
              title: 'Follow friends',
              description:
                  "Follow people, see what they've accomplished, and keep "
                  "each other honest.",
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.volunteer_activism_rounded,
              title: 'Give back either way',
              description:
                  "A goal that doesn't get done doesn't just disappear — "
                  "its stake goes toward the charities Forgo supports.",
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentDeep),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(description, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
