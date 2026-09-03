import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_grid.dart';
import '../../../core/widgets/glow_background.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/screens/new_goal_screen.dart';
import '../../profile/application/profile_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final textTheme = Theme.of(context).textTheme;
    final firstName = profileAsync.value?.fullName.split(' ').first;
    final walletBalance = profileAsync.value?.walletBalanceRand ?? 0;
    final activeGoalsCount =
        goalsAsync.value
            ?.where((g) => g.status == GoalStatus.active)
            .length ??
        0;

    void openNewGoal() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewGoalScreen()),
    );

    return Scaffold(
      body: GlowBackground(
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                firstName == null ? 'Welcome to Forgo' : 'Hey, $firstName',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Stake money, prove it with a photo, keep it.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              BentoGrid(
                items: [
                  BentoGridItem(
                    size: BentoSize.wide,
                    child: _ActiveGoalsCard(
                      activeCount: activeGoalsCount,
                      onTap: activeGoalsCount == 0
                          ? openNewGoal
                          : () => context.go('/goals'),
                    ),
                  ),
                  BentoGridItem(
                    size: BentoSize.half,
                    child: _StatCard(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Wallet',
                      value: 'R${walletBalance.toStringAsFixed(0)}',
                      onTap: () => context.go('/wallet'),
                    ),
                  ),
                  BentoGridItem(
                    size: BentoSize.half,
                    child: const _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Streak',
                      value: '0 wks',
                      iconColor: AppColors.warning,
                    ),
                  ),
                  BentoGridItem(
                    size: BentoSize.wide,
                    child: _NewGoalCard(onTap: openNewGoal),
                  ),
                  BentoGridItem(
                    size: BentoSize.tall,
                    child: const _TipCard(),
                  ),
                  BentoGridItem(
                    size: BentoSize.tall,
                    child: const _CharityImpactCard(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor ?? AppColors.accentBright, size: 22),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActiveGoalsCard extends StatelessWidget {
  const _ActiveGoalsCard({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasGoals = activeCount > 0;

    return BentoCard(
      onTap: onTap,
      gradient: AppColors.accentGradient,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillBadge(
                  label: hasGoals
                      ? '$activeCount ACTIVE ${activeCount == 1 ? 'GOAL' : 'GOALS'}'
                      : 'NO ACTIVE GOALS',
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  hasGoals
                      ? 'Keep your streak alive'
                      : 'Start your first commitment',
                  style: textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  hasGoals
                      ? 'Tap to see your active goals and log progress.'
                      : 'Pick a goal, set your stake, and put your money '
                            'where your goals are.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_circle_right_rounded,
            color: Colors.white,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _NewGoalCard extends StatelessWidget {
  const _NewGoalCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BentoCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.accentBright),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New goal', style: textTheme.titleMedium),
                Text(
                  'Run or weight-loss — choose your stake',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.warning),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick tip', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'A screenshot of your fitness app is all the proof you '
                'need — captured live, no gallery uploads.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharityImpactCard extends StatelessWidget {
  const _CharityImpactCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.volunteer_activism_rounded, color: AppColors.success),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Given to charity', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('R0.00 so far', style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
