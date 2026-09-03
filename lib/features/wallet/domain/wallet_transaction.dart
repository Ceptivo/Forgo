enum WalletTransactionStatus { pending, completed, failed, cancelled }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.amountCents,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] as String,
      amountCents: (map['amount_cents'] as num).toInt(),
      status: WalletTransactionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => WalletTransactionStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final int amountCents;
  final WalletTransactionStatus status;
  final DateTime createdAt;

  double get amountRand => amountCents / 100;
}
