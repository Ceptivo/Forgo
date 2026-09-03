import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/goal_group_providers.dart';
import '../../data/goal_group_repository.dart';
import '../../domain/goal_group.dart';
import '../../domain/goal_group_leaderboard_entry.dart';
import '../../domain/goal_group_message.dart';
import '../../domain/goal_group_round.dart';
import '../../domain/goal_group_stake.dart';
import '../widgets/invite_friend_sheet.dart';
import 'start_group_round_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.group});

  final GoalGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          bottom: const TabBar(
            tabs: [Tab(text: 'Chat'), Tab(text: 'Leaderboard')],
          ),
          actions: [
            IconButton(
              tooltip: 'Invite a friend',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => showInviteFriendSheet(context, group.id),
            ),
            IconButton(
              tooltip: 'Invite code: ${group.inviteCode}',
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: group.inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invite code ${group.inviteCode} copied'),
                  ),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ChatTab(group: group),
            _LeaderboardTab(groupId: group.id),
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
        _RoundStatusBanner(group: widget.group),
        const Divider(height: 1),
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
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

class _RoundStatusBanner extends ConsumerWidget {
  const _RoundStatusBanner({required this.group});

  final GoalGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoundAsync = ref.watch(goalGroupActiveRoundProvider(group.id));
    final textTheme = Theme.of(context).textTheme;

    return activeRoundAsync.when(
      loading: () => const SizedBox(
        height: 4,
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (round) {
        if (round == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'No goal running right now.',
                    style: textTheme.bodyMedium,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StartGroupRoundScreen(groupId: group.id),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Start goal'),
                ),
              ],
            ),
          );
        }
        return _ActiveRoundCard(group: group, round: round);
      },
    );
  }
}

class _ActiveRoundCard extends ConsumerWidget {
  const _ActiveRoundCard({required this.group, required this.round});

  final GoalGroup group;
  final GoalGroupRound round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final stakesAsync = ref.watch(goalGroupRoundStakesProvider(round.id));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppColors.accentDim,
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
              Text(
                round.title,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'R${round.stakeRand.toStringAsFixed(2)} each · ${stakes.length} staked',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              _RoundAction(roundId: round.id, myStake: myStake),
            ],
          );
        },
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
        onPressed: () =>
            _run(() => repo.joinRound(widget.roundId)),
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
        child: const Text('Join this goal'),
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

class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(goalGroupLeaderboardProvider(groupId));
    final textTheme = Theme.of(context).textTheme;

    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: RetryableError(
          message: 'Could not load the leaderboard.',
          onRetry: () => ref.invalidate(goalGroupLeaderboardProvider(groupId)),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No goals resolved yet — the leaderboard fills in once '
                'someone reports an outcome.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _LeaderboardRow(rank: index + 1, entry: entries[index]),
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.entry});

  final int rank;
  final GoalGroupLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: textTheme.titleMedium?.copyWith(
                color: rank == 1 ? AppColors.accentDeep : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fullName, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${entry.completions} hit · ${entry.fails} missed',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+R${entry.wonRand.toStringAsFixed(0)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '-R${entry.lostRand.toStringAsFixed(0)}',
                style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
