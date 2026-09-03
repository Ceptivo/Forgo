import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_transaction.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(supabaseClientProvider));
});

final walletTransactionsProvider =
    FutureProvider.autoDispose<List<WalletTransaction>>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return const [];
      return ref.watch(walletRepositoryProvider).fetchTransactions(user.id);
    });
