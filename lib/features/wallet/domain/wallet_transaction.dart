import '../../goals/domain/goal.dart';

enum WalletTransactionStatus { pending, completed, failed, cancelled }

enum WalletTransactionType { topup, goalStake, goalRefund }

WalletTransactionType _typeFromString(String value) => switch (value) {
  'goal_stake' => WalletTransactionType.goalStake,
  'goal_refund' => WalletTransactionType.goalRefund,
  _ => WalletTransactionType.topup,
};

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    this.goal,
  });

  /// [goal] is looked up separately (see WalletRepository.fetchTransactions)
  /// since a transaction only stores a goal_id — this keeps the "Goal |
  /// Run 5km by ..." wording built from the same Goal.title/deadline the
  /// rest of the app already uses, rather than duplicating that
  /// formatting logic in SQL.
  factory WalletTransaction.fromMap(Map<String, dynamic> map, {Goal? goal}) {
    return WalletTransaction(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String),
      amountCents: (map['amount_cents'] as num).toInt(),
      status: WalletTransactionStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => WalletTransactionStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      goal: goal,
    );
  }

  final String id;
  final WalletTransactionType type;
  final int amountCents;
  final WalletTransactionStatus status;
  final DateTime createdAt;
  final Goal? goal;

  double get amountRand => amountCents / 100;
}
