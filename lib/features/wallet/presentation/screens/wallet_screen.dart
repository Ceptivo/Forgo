import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../goals/domain/goal.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/wallet_providers.dart';
import '../../domain/wallet_transaction.dart';
import '../widgets/topup_amount_sheet.dart';
import 'payfast_webview_screen.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _startingTopUp = false;

  Future<void> _refresh() async {
    ref.invalidate(currentProfileProvider);
    ref.invalidate(walletTransactionsProvider);
    await Future.wait([
      ref.read(currentProfileProvider.future),
      ref.read(walletTransactionsProvider.future),
    ]);
  }

  Future<void> _startTopUp() async {
    final amountCents = await showTopUpAmountSheet(context);
    if (amountCents == null || !mounted) return;

    setState(() => _startingTopUp = true);
    try {
      final request = await ref
          .read(walletRepositoryProvider)
          .startTopUp(amountCents: amountCents);
      if (!mounted) return;

      final outcome = await Navigator.of(context).push<PayfastOutcome>(
        MaterialPageRoute(
          builder: (_) => PayfastWebviewScreen(paymentUrl: request.paymentUrl),
        ),
      );

      if (outcome == PayfastOutcome.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Payment received — your balance will update shortly.",
            ),
          ),
        );
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start top-up: $e')));
      }
    } finally {
      if (mounted) setState(() => _startingTopUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    final textTheme = Theme.of(context).textTheme;
    final walletBalance = profileAsync.value?.walletBalanceRand ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ResponsivePage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BentoCard(
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
                        'R${walletBalance.toStringAsFixed(2)}',
                        style: textTheme.headlineMedium?.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _startingTopUp ? null : _startTopUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: _startingTopUp
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Top up'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Transaction history', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                transactionsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => RetryableError(
                    message: 'Could not load transactions.',
                    onRetry: () => ref.invalidate(walletTransactionsProvider),
                  ),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No transactions yet.',
                          style: textTheme.bodyMedium,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final transaction in transactions)
                          _TransactionTile(transaction: transaction),
                      ],
                    );
                  },
                ),
                const SizedBox(height: DockClearFab.clearance),
              ],
            ),
          ),
        ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    switch (transaction.type) {
      case WalletTransactionType.goalStake:
        return _tile(
          context,
          icon: Icons.flag_rounded,
          color: AppColors.danger,
          title: _stakeDescription(transaction.goal),
          amountText: '-R${transaction.amountRand.toStringAsFixed(2)}',
          amountColor: AppColors.danger,
          subtitle: DateFormat.yMMMd().add_jm().format(transaction.createdAt),
        );
      case WalletTransactionType.goalRefund:
        return _tile(
          context,
          icon: Icons.emoji_events_rounded,
          color: AppColors.success,
          title: _refundDescription(transaction.goal, transaction.createdAt),
          amountText: '+R${transaction.amountRand.toStringAsFixed(2)}',
          amountColor: AppColors.success,
          subtitle: DateFormat.yMMMd().add_jm().format(transaction.createdAt),
        );
      case WalletTransactionType.topup:
        final (icon, color, label) = switch (transaction.status) {
          WalletTransactionStatus.completed => (
            Icons.check_circle_rounded,
            AppColors.success,
            'Completed',
          ),
          WalletTransactionStatus.pending => (
            Icons.schedule_rounded,
            AppColors.warning,
            'Pending',
          ),
          WalletTransactionStatus.failed => (
            Icons.error_rounded,
            AppColors.danger,
            'Failed',
          ),
          WalletTransactionStatus.cancelled => (
            Icons.cancel_rounded,
            AppColors.textMuted,
            'Cancelled',
          ),
        };
        return _tile(
          context,
          icon: icon,
          color: color,
          title: 'Top-up · R${transaction.amountRand.toStringAsFixed(2)}',
          subtitle:
              '$label · ${DateFormat.yMMMd().add_jm().format(transaction.createdAt)}',
        );
    }
  }

  String _stakeDescription(Goal? goal) {
    if (goal == null) return 'Goal | stake';
    final title = goal.title;
    if (goal.deadline != null) {
      return 'Goal | $title by ${DateFormat.yMMMd().format(goal.deadline!)}';
    }
    return 'Goal | $title · Weekly commitment';
  }

  String _refundDescription(Goal? goal, DateTime completedAt) {
    final when = DateFormat.yMMMd().format(completedAt);
    if (goal == null) return 'Goal Achieved | $when';
    return 'Goal Achieved | ${goal.title} on $when';
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? amountText,
    Color? amountColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  Text(subtitle, style: textTheme.bodySmall),
                ],
              ),
            ),
            if (amountText != null) ...[
              const SizedBox(width: 8),
              Text(
                amountText,
                style: textTheme.titleMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
