import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../../core/widgets/image_crop_picker.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../social/presentation/screens/friends_screen.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile.dart';
import '../widgets/profile_stat_cards.dart';
import 'settings_screen.dart';

/// Gap (4) + pencil tap target (4 padding + 15 icon + 4 padding = 23) — see
/// the name/pencil Row below.
const _pencilSlotWidth = 27.0;

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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // A bare tap target rather than IconButton — IconButton's
                    // minimum 48x48 hit area (even constrained down) still
                    // pads the pencil further from the name than wanted.
                    GestureDetector(
                      onTap: () => showNicknameEditDialog(context, ref, profile),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit_rounded, size: 15),
                      ),
                    ),
                  ],
                ),
                if (profile.username.isNotEmpty)
                  Center(
                    child: Text(
                      '@${profile.username}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FollowStatsRow(userId: profile.id),
                const SizedBox(height: 12),
                CompletedGoalsCard(userId: profile.id),
                const SizedBox(height: 12),
                CharityGivenCard(userId: profile.id),
                const SizedBox(height: 12),
                BadgesSection(userId: profile.id),
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
                // Clears the floating bottom nav dock (HomeShell uses
                // extendBody: true), which otherwise overlaps and hides
                // whatever's last in a scrollable tab body.
                const SizedBox(height: DockClearFab.clearance),
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
    final cropped = await pickAndCropCircularImage(context);
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

