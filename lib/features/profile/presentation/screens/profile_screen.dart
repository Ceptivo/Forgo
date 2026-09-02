import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/glow_background.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: GlowBackground(
        child: ResponsivePage(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Could not load profile.\n$error',
                textAlign: TextAlign.center,
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
                          color: Colors.white,
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
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'R${profile.walletBalanceRand.toStringAsFixed(2)}',
                                style: textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
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
                                color: AppColors.accentBright,
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
                        child: BentoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.flag_rounded,
                                color: AppColors.accentBright,
                              ),
                              const Spacer(),
                              Text('0', style: textTheme.titleMedium),
                              Text('Goals completed', style: textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
      ),
    );
  }
}
