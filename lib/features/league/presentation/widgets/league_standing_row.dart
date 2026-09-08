import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/league.dart';

/// One entrant's row in a standings list — reused by both the full league
/// screen and the home screen's top-3 preview card.
class LeagueStandingRow extends StatelessWidget {
  const LeagueStandingRow({
    super.key,
    required this.rank,
    required this.name,
    required this.standing,
  });

  final int rank;
  final String name;
  final LeagueStanding standing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = standing.isEliminated
        ? 'Out on day ${standing.eliminatedOnDay}'
        : standing.hasFinishedAll30
        ? 'Finished all 30 days'
        : '${standing.daysCompleted} day${standing.daysCompleted == 1 ? '' : 's'} survived';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: textTheme.titleMedium?.copyWith(
                color: standing.isEliminated
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: standing.isEliminated
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (!standing.isEliminated && standing.hasFinishedAll30)
            const Icon(Icons.emoji_events_rounded, color: AppColors.accentDeep),
        ],
      ),
    );
  }
}
