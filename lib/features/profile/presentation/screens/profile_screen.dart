import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../social/application/social_providers.dart';
import '../../../social/presentation/screens/friends_screen.dart';
import '../../application/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsivePage(
        child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: RetryableError(
                message: 'Could not load profile.',
                onRetry: () => ref.invalidate(currentProfileProvider),
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Not signed in.'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.accentGradient,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        profile.fullName.isNotEmpty
                            ? profile.fullName[0].toUpperCase()
                            : '?',
                        style: textTheme.headlineMedium?.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(profile.fullName, style: textTheme.titleLarge),
                  ),
                  Center(
                    child: Text(profile.email, style: textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 24),
                  BentoGrid(
                    items: [
                      BentoGridItem(
                        size: BentoSize.wide,
                        child: BentoCard(
                          gradient: AppColors.accentGradient,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallet balance',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'R${profile.walletBalanceRand.toStringAsFixed(2)}',
                                style: textTheme.headlineMedium?.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      BentoGridItem(
                        size: BentoSize.half,
                        child: BentoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.cake_rounded,
                                color: AppColors.accentDeep,
                              ),
                              const Spacer(),
                              Text(
                                DateFormat.yMMMd().format(profile.dateOfBirth),
                                style: textTheme.titleMedium,
                              ),
                              Text('Date of birth', style: textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      BentoGridItem(
                        size: BentoSize.half,
                        child: _CompletedGoalsCard(userId: profile.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FollowStatsRow(userId: profile.id),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Find friends'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authRepositoryProvider).signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }
}

class _CompletedGoalsCard extends ConsumerWidget {
  const _CompletedGoalsCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final completed = statsAsync.value?.completedGoalsCount;

    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_rounded, color: AppColors.accentDeep),
          const Spacer(),
          Text(completed?.toString() ?? '—', style: textTheme.titleMedium),
          Text('Goals completed', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FollowStatsRow extends ConsumerWidget {
  const _FollowStatsRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final stats = statsAsync.value;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FollowStat(
              label: 'Followers',
              value: stats?.followerCount,
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.surfaceBorder),
          Expanded(
            child: _FollowStat(
              label: 'Following',
              value: stats?.followingCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowStat extends StatelessWidget {
  const _FollowStat({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value?.toString() ?? '—', style: textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}
