import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';
import '../../domain/goal_group.dart';
import '../../domain/goal_group_message.dart';
import '../../domain/goal_group_round.dart';
import '../../domain/goal_group_stake.dart';
import '../widgets/invite_friend_sheet.dart';
import '../widgets/leaderboard_list.dart';
import 'group_settings_screen.dart';
import 'start_group_round_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.group});

  final GoalGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls back to the (possibly stale) constructor value while the live
    // row loads, rather than a loading flash on the app bar title — but
    // reflects a rename from GroupSettingsScreen once it lands.
    final liveName =
        ref.watch(goalGroupByIdProvider(group.id)).value?.name ?? group.name;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(liveName),
          bottom: const TabBar(
            tabs: [Tab(text: 'Chat'), Tab(text: 'Leaderboard')],
          ),
          actions: [
            IconButton(
              tooltip: 'Add a friend',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => showInviteFriendSheet(context, group.id),
            ),
            IconButton(
              tooltip: 'Group settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupSettingsScreen(groupId: group.id),
                ),
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ChatTab(group: group),
            LeaderboardList(groupId: group.id),
          ],
        ),
      ),
    );
  }
}

class _ChatTab extends ConsumerStatefulWidget {
  const _ChatTab({required this.group});

  final GoalGroup group;

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(goalGroupRepositoryProvider)
          .sendMessage(widget.group.id, body);
      _messageController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(goalGroupMessagesProvider(widget.group.id));
    final namesAsync = ref.watch(goalGroupMemberNamesProvider(widget.group.id));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => RetryableError(
              message: 'Could not load chat.',
              onRetry: () => ref.invalidate(
                goalGroupMessagesProvider(widget.group.id),
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No messages yet — say hi.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              final names = namesAsync.value ?? const {};
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  final senderName = message.senderId == null
                      ? null
                      : (names[message.senderId] ?? 'Member');
                  return _MessageRow(
                    message: message,
                    senderName: senderName,
                    isMine: message.senderId == currentUserId,
                  );
                },
              );
            },
          ),
        ),
        _ActiveRoundNotification(group: widget.group),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Challenge the group with a goal',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StartGroupRoundScreen(groupId: widget.group.id),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_rounded, size: 28),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Message the group'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: AppColors.ink),
                  icon: _sending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.senderName,
    required this.isMine,
  });

  final GoalGroupMessage message;
  final String? senderName;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (message.kind != GoalGroupMessageKind.text) {
      final (icon, color) = switch (message.kind) {
        GoalGroupMessageKind.systemWin => (
          Icons.check_circle_rounded,
          AppColors.success,
        ),
        GoalGroupMessageKind.systemLoss => (
          Icons.cancel_rounded,
          AppColors.danger,
        ),
        _ => (Icons.groups_rounded, AppColors.textMuted),
      };
      final amount = message.amountRand;
      final suffix = amount == null
          ? ''
          : (message.kind == GoalGroupMessageKind.systemWin
                ? ' · +R${amount.toStringAsFixed(2)} back'
                : ' · -R${amount.toStringAsFixed(2)} forfeited');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${senderName ?? 'Someone'} ${message.body}$suffix',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.ink : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName ?? 'Member',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDeep,
                  ),
                ),
              ),
            Text(
              message.body,
              style: textTheme.bodyMedium?.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown only while there's an active round to join or report on — this
/// used to be a green bar pinned above the chat permanently; now it's a
/// full-width card that pops in with a small appear animation and goes
/// away on its own after 10s (or the X), same as a notification. It
/// isn't gone for good, though: it's keyed by round id, so it comes back
/// the next time this screen is opened while that round is still
/// unresolved for the caller — nobody's permanently locked out of
/// joining just because they weren't looking at the right moment.
class _ActiveRoundNotification extends ConsumerWidget {
  const _ActiveRoundNotification({required this.group});

  final GoalGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoundAsync = ref.watch(goalGroupActiveRoundProvider(group.id));

    return activeRoundAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (round) {
        if (round == null) return const SizedBox.shrink();
        return _RoundNotificationCard(
          key: ValueKey(round.id),
          round: round,
        );
      },
    );
  }
}

class _RoundNotificationCard extends ConsumerStatefulWidget {
  const _RoundNotificationCard({super.key, required this.round});

  final GoalGroupRound round;

  @override
  ConsumerState<_RoundNotificationCard> createState() =>
      _RoundNotificationCardState();
}

class _RoundNotificationCardState
    extends ConsumerState<_RoundNotificationCard> {
  bool _dismissed = false;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _autoDismiss = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _dismissed = true);
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final stakesAsync = ref.watch(goalGroupRoundStakesProvider(widget.round.id));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accentDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent),
        ),
        child: stakesAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, _) => Text(
            'Could not load this goal\'s status.',
            style: textTheme.bodySmall,
          ),
          data: (stakes) {
            final mine = stakes.where((s) => s.userId == currentUserId).toList();
            final myStake = mine.isEmpty ? null : mine.first;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      color: AppColors.accentDeep,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'New group goal',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDeep,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _dismissed = true),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(widget.round.title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'R${widget.round.stakeRand.toStringAsFixed(2)} each · '
                  '${stakes.length} staked',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _RoundAction(roundId: widget.round.id, myStake: myStake),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoundAction extends ConsumerStatefulWidget {
  const _RoundAction({required this.roundId, required this.myStake});

  final String roundId;
  final GoalGroupStake? myStake;

  @override
  ConsumerState<_RoundAction> createState() => _RoundActionState();
}

class _RoundActionState extends ConsumerState<_RoundAction> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(goalGroupRoundStakesProvider(widget.roundId));
      ref.invalidate(goalGroupActiveRoundProvider);
    } on GoalGroupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndJoin(GoalGroupRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this goal?'),
        content: const Text(
          "Your stake will be taken from your wallet the moment you accept.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed == true) _run(() => repo.joinRound(widget.roundId));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(goalGroupRepositoryProvider);

    if (_busy) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (widget.myStake == null) {
      return ElevatedButton(
        onPressed: () => _confirmAndJoin(repo),
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
        child: const Text('Accept Goal'),
      );
    }

    if (widget.myStake!.outcome != GoalGroupStakeOutcome.pending) {
      final done = widget.myStake!.outcome == GoalGroupStakeOutcome.completed;
      return Text(
        done ? 'You reported: hit it' : 'You reported: missed it',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: done ? AppColors.success : AppColors.danger,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton(
          onPressed: () => _run(
            () => repo.reportOutcome(roundId: widget.roundId, completed: true),
          ),
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          child: const Text('I hit it'),
        ),
        OutlinedButton(
          onPressed: () => _run(
            () => repo.reportOutcome(roundId: widget.roundId, completed: false),
          ),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          child: const Text('I missed it'),
        ),
      ],
    );
  }
}

