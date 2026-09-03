import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/wallet_transaction.dart';

class TopUpRequest {
  const TopUpRequest({required this.paymentUrl, required this.transactionId});

  final String paymentUrl;
  final String transactionId;
}

/// How long a single request waits before giving up and surfacing a
/// retryable error, rather than leaving the caller's spinner running
/// indefinitely on a stalled connection.
const _networkTimeout = Duration(seconds: 12);

class WalletRepository {
  WalletRepository(this._client);

  final SupabaseClient _client;

  /// Calls the create-payfast-payment Edge Function to start a top-up. The
  /// Payfast merchant credentials never touch the app — they're Edge
  /// Function secrets — this just gets back a signed payment URL to open
  /// in a WebView.
  Future<TopUpRequest> startTopUp({required int amountCents}) async {
    final response = await _client.functions
        .invoke('create-payfast-payment', body: {'amount_cents': amountCents})
        .timeout(_networkTimeout);

    final data = response.data;
    if (response.status != 200 || data is! Map) {
      final error = (data is Map ? data['error'] : null) ?? 'Unknown error';
      throw WalletException(error.toString());
    }

    return TopUpRequest(
      paymentUrl: data['payment_url'] as String,
      transactionId: data['transaction_id'] as String,
    );
  }

  Future<List<WalletTransaction>> fetchTransactions(String userId) async {
    final rows = await _client
        .from('wallet_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(_networkTimeout);
    return rows.map(WalletTransaction.fromMap).toList();
  }
}

class WalletException implements Exception {
  WalletException(this.message);

  final String message;

  @override
  String toString() => message;
}
