import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_grid.dart';
import '../../../../core/widgets/dock_clear_fab.dart';
import '../../../../core/widgets/retryable_error.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/wallet_providers.dart';
import '../widgets/topup_amount_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'all_transactions_screen.dart';
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final transaction in transactions.take(3))
                          TransactionTile(transaction: transaction),
                        if (transactions.length > 3)
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AllTransactionsScreen(
                                  transactions: transactions,
                                ),
                              ),
                            ),
                            child: const Text('View more'),
                          ),
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
