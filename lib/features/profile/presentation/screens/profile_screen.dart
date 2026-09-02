import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
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
      body: ResponsivePage(
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
                  child: CircleAvatar(
                    radius: 40,
                    child: Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName[0].toUpperCase()
                          : '?',
                      style: textTheme.headlineMedium,
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wallet balance', style: textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          'R${profile.walletBalanceRand.toStringAsFixed(2)}',
                          style: textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cake_outlined),
                    title: const Text('Date of birth'),
                    subtitle: Text(
                      DateFormat.yMMMMd().format(profile.dateOfBirth),
                    ),
                  ),
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
    );
  }
}
