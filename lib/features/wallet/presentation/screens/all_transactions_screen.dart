import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/filter_choice_chip.dart';
import '../../domain/wallet_transaction.dart';
import '../widgets/transaction_tile.dart';

enum _TransactionCategory { topup, withdraw, goalWon, goalLost }

const _categoryLabels = {
  _TransactionCategory.topup: 'Top up',
  _TransactionCategory.withdraw: 'Withdraw',
  _TransactionCategory.goalWon: 'Goal Won',
  _TransactionCategory.goalLost: 'Goal Lost',
};

bool _matchesCategory(WalletTransaction transaction, _TransactionCategory category) {
  return switch (category) {
    // Withdrawals aren't a feature yet (see the wallet's top-up
    // disclaimer) — this filter is here for when they ship, and shows
    // nothing until then rather than being left out entirely.
    _TransactionCategory.withdraw => false,
    _TransactionCategory.topup => transaction.type == WalletTransactionType.topup,
    _TransactionCategory.goalWon =>
      transaction.type == WalletTransactionType.goalRefund,
    _TransactionCategory.goalLost =>
      transaction.type == WalletTransactionType.goalStake,
  };
}

/// The full transaction history — reached from WalletScreen's "View
/// more", which only shows the latest 3 inline. [transactions] is passed
/// in rather than re-fetched, since WalletScreen already has the full
/// list.
class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key, required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  _TransactionCategory? _category;
  DateTimeRange? _dateRange;

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rangeEnd = _dateRange == null
        ? null
        : DateTime(
            _dateRange!.end.year,
            _dateRange!.end.month,
            _dateRange!.end.day,
          ).add(const Duration(days: 1));

    final filtered = widget.transactions.where((transaction) {
      if (_category != null && !_matchesCategory(transaction, _category!)) {
        return false;
      }
      if (_dateRange != null) {
        if (transaction.createdAt.isBefore(_dateRange!.start)) return false;
        if (!transaction.createdAt.isBefore(rangeEnd!)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChoiceChip(
                  label: 'All',
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                for (final category in _TransactionCategory.values)
                  FilterChoiceChip(
                    label: _categoryLabels[category]!,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dateRange == null
                          ? 'Filter by date'
                          : '${DateFormat.yMMMd().format(_dateRange!.start)} – '
                                '${DateFormat.yMMMd().format(_dateRange!.end)}',
                    ),
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    tooltip: 'Clear date filter',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _dateRange = null),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No transactions match.',
                  style: textTheme.bodyMedium,
                ),
              )
            else
              for (final transaction in filtered)
                TransactionTile(transaction: transaction),
          ],
        ),
      ),
    );
  }
}
