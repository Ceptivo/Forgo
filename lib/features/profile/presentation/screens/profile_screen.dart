import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../social/application/social_providers.dart';
import '../../../social/presentation/screens/friends_screen.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

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
                _AvatarPicker(profile: profile),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        profile.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showNicknameEditor(context, ref, profile),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit nickname',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (profile.username.isNotEmpty)
                  Center(
                    child: Text(
                      '@${profile.username}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 20),
                _FollowStatsRow(userId: profile.id),
                const SizedBox(height: 12),
                _CompletedGoalsCard(userId: profile.id),
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
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
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

Future<void> _showNicknameEditor(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final controller = TextEditingController(text: profile.fullName);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit nickname'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nickname'),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (result == null || result.isEmpty || result == profile.fullName) return;

  await ref.read(profileRepositoryProvider).updateFullName(profile.id, result);
  ref.invalidate(currentProfileProvider);
}

class _AvatarPicker extends ConsumerStatefulWidget {
  const _AvatarPicker({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  bool _uploading = false;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.contains('.')
          ? picked.path.split('.').last.toLowerCase()
          : 'jpg';
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(
            userId: widget.profile.id,
            bytes: bytes,
            fileExtension: ext,
          );
      ref.invalidate(currentProfileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update your photo — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = widget.profile.avatarUrl;
    return Center(
      child: GestureDetector(
        onTap: _uploading ? null : _pick,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.accentGradient,
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: _uploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      widget.profile.fullName.isNotEmpty
                          ? widget.profile.fullName[0].toUpperCase()
                          : '?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.ink),
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
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
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          Text(completed?.toString() ?? '—', style: textTheme.titleLarge),
          const SizedBox(width: 8),
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
            child: _FollowStat(label: 'Followers', value: stats?.followerCount),
          ),
          Container(width: 1, height: 32, color: AppColors.surfaceBorder),
          Expanded(
            child: _FollowStat(label: 'Following', value: stats?.followingCount),
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
