import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class GoalTypeCard extends StatelessWidget {
  const GoalTypeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
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
            color: selected ? AppColors.accentDim : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.surfaceBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.accentDeep : AppColors.textSecondary,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(title, style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
