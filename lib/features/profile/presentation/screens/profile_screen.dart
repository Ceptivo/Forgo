import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
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
import '../../../streaks/application/streak_providers.dart';
import '../../../streaks/domain/streak_badge.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile.dart';
import 'settings_screen.dart';

/// Gap (2) + pencil IconButton width (22) — see the name/pencil Row below.
const _pencilSlotWidth = 24.0;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
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
                    // Invisible spacer matching the trailing gap + pencil
                    // width, so the Row being centered as a whole actually
                    // centers the *name* — without it the pencil's width
                    // pulls the name visibly left of center.
                    const SizedBox(width: _pencilSlotWidth),
                    Flexible(
                      child: Text(
                        profile.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Tight padding/constraints rather than the default
                    // 48x48 tap target — IconButton's usual hit area is
                    // asymmetric relative to the name text next to it and
                    // visibly pushes the name off-center otherwise.
                    IconButton(
                      onPressed: () => showNicknameEditDialog(context, ref, profile),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      tooltip: 'Edit nickname',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
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
                _CharityGivenCard(userId: profile.id),
                const SizedBox(height: 12),
                _BadgesSection(userId: profile.id),
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

Future<void> showNicknameEditDialog(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => _NicknameEditDialog(initialValue: profile.fullName),
  );

  if (result == null || result.isEmpty || result == profile.fullName) return;

  await ref.read(profileRepositoryProvider).updateFullName(profile.id, result);
  ref.invalidate(currentProfileProvider);
}

/// A dedicated StatefulWidget so the [TextEditingController] is created and
/// disposed by the widget that actually owns the [TextField] using it.
/// Creating the controller outside `showDialog` and disposing it right
/// after the awaited Future completes is racy: the dialog route's closing
/// transition can still be running (and the TextField still attached)
/// when that dispose() call fires, which throws
/// `'_dependents.isEmpty': is not true` from the framework.
class _NicknameEditDialog extends StatefulWidget {
  const _NicknameEditDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_NicknameEditDialog> createState() => _NicknameEditDialogState();
}

class _NicknameEditDialogState extends State<_NicknameEditDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit nickname'),
      content: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
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
      // No maxWidth/maxHeight here — the crop step needs the original
      // resolution to crop from; downscaling happens after, on the
      // already-cropped result.
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    final originalBytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => _CropAvatarScreen(imageBytes: originalBytes),
        fullscreenDialog: true,
      ),
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      // The crop step always produces a circle-masked PNG regardless of
      // the source format, so the uploaded extension/content-type need
      // to match that rather than the originally-picked file's.
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(
            userId: widget.profile.id,
            bytes: cropped,
            fileExtension: 'png',
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

/// Full-screen circular crop step shown between picking a gallery photo
/// and uploading it — pops with the cropped PNG bytes, or null if the
/// user backs out.
class _CropAvatarScreen extends StatefulWidget {
  const _CropAvatarScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_CropAvatarScreen> createState() => _CropAvatarScreenState();
}

class _CropAvatarScreenState extends State<_CropAvatarScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not crop that photo — try again.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop photo'),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.cropCircle();
                  },
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Crop(
            image: widget.imageBytes,
            controller: _controller,
            withCircleUi: true,
            baseColor: Colors.black,
            maskColor: Colors.black.withValues(alpha: 0.75),
            onCropped: _onCropped,
          ),
          if (_cropping)
            const ColoredBox(
              color: Colors.black38,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
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

class _CharityGivenCard extends ConsumerWidget {
  const _CharityGivenCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final statsAsync = ref.watch(publicProfileStatsProvider(userId));
    final givenRand = statsAsync.value?.charityGivenRand;

    return BentoCard(
      child: Row(
        children: [
          const Icon(Icons.volunteer_activism_rounded, color: AppColors.accentDeep),
          const SizedBox(width: 12),
          Text(
            givenRand == null ? '—' : 'R${givenRand.toStringAsFixed(2)}',
            style: textTheme.titleLarge,
          ),
          const SizedBox(width: 8),
          Text('Given to charity', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BadgesSection extends ConsumerWidget {
  const _BadgesSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(streakSummaryProvider(userId));
    final earned = earnedStreakBadges(summaryAsync.value?.longestWeeklyStreak ?? 0);
    final textTheme = Theme.of(context).textTheme;

    if (summaryAsync.isLoading) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Badges', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          if (earned.isEmpty)
            Text(
              'Keep a weekly streak going to earn your first badge.',
              style: textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final badge in earned) _BadgeChip(badge: badge),
              ],
            ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final StreakBadge badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.accent,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            badge.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
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
