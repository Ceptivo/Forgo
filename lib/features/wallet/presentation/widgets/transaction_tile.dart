import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../goals/domain/goal.dart';
import '../../domain/wallet_transaction.dart';

/// One row in a transaction list — shared between the wallet screen's
/// last-3 preview and the full, filterable transaction list, so both
/// always render identically.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

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
          title: _refundDescription(transaction.goal),
          amountText: '+R${transaction.amountRand.toStringAsFixed(2)}',
          amountColor: AppColors.success,
          subtitle: DateFormat.yMMMd().add_jm().format(transaction.createdAt),
        );
      case WalletTransactionType.leagueEntry:
        return _tile(
          context,
          icon: Icons.bolt_rounded,
          color: AppColors.danger,
          title: 'League | ${transaction.leagueName ?? 'Entry fee'}',
          amountText: '-R${transaction.amountRand.toStringAsFixed(2)}',
          amountColor: AppColors.danger,
          subtitle: DateFormat.yMMMd().add_jm().format(transaction.createdAt),
        );
      case WalletTransactionType.leaguePrize:
        return _tile(
          context,
          icon: Icons.emoji_events_rounded,
          color: AppColors.success,
          title: 'League Won | ${transaction.leagueName ?? 'Prize'}',
          amountText: '+R${transaction.amountRand.toStringAsFixed(2)}',
          amountColor: AppColors.success,
          subtitle: DateFormat.yMMMd().add_jm().format(transaction.createdAt),
        );
      case WalletTransactionType.topup:
        // Only a completed top-up has actually added money to the
        // wallet — a pending/failed/cancelled one gets its status
        // called out instead of a green "+", which would otherwise
        // claim money arrived that didn't.
        final completed = transaction.status == WalletTransactionStatus.completed;
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
          title: 'Top-up',
          amountText:
              '${completed ? '+' : ''}R${transaction.amountRand.toStringAsFixed(2)}',
          amountColor: completed ? AppColors.success : AppColors.textMuted,
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

  // No date here — the row's own subtitle already carries the
  // transaction's timestamp, so repeating it in the title would just be
  // redundant.
  String _refundDescription(Goal? goal) {
    if (goal == null) return 'Goal Achieved';
    return 'Goal Achieved | ${goal.title}';
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
                style: textTheme.titleMedium?.copyWith(color: amountColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
