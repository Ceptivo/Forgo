import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/league_providers.dart';
import '../screens/league_screen.dart';

/// Links into the current "No Turning Back" league — nothing shows if
/// one's never been created (see the League feature's own founder-only
/// Create League flow). Rendered at the same height as a GoalCard
/// (~88dp) rather than the banner's own aspect ratio, so it sits
/// consistently among the goal cards below it. Shared between the Goals
/// screen and the Community screen's Goals tab.
class CashPrizeChallengeBanner extends ConsumerWidget {
  const CashPrizeChallengeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(currentLeagueProvider).value;
    if (league == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cash Prize Challenges', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Material(
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LeagueScreen(leagueId: league.id)),
              ),
              child: SizedBox(
                height: 88,
                child: Image.asset(
                  'assets/images/no_turning_back_banner.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
