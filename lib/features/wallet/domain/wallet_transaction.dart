import '../../goals/domain/goal.dart';

enum WalletTransactionStatus { pending, completed, failed, cancelled }

enum WalletTransactionType { topup, goalStake, goalRefund, leagueEntry, leaguePrize }

WalletTransactionType _typeFromString(String value) => switch (value) {
  'goal_stake' => WalletTransactionType.goalStake,
  'goal_refund' => WalletTransactionType.goalRefund,
  'league_entry' => WalletTransactionType.leagueEntry,
  'league_prize' => WalletTransactionType.leaguePrize,
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
    this.leagueName,
  });

  /// [goal] and [leagueName] are looked up separately (see
  /// WalletRepository.fetchTransactions) since a transaction only stores
  /// a goal_id/league_id — this keeps the "Goal | Run 5km by ..." /
  /// "League | No Turning Back" wording built from the same data the
  /// rest of the app already uses, rather than duplicating it in SQL.
  factory WalletTransaction.fromMap(
    Map<String, dynamic> map, {
    Goal? goal,
    String? leagueName,
  }) {
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
      leagueName: leagueName,
    );
  }

  final String id;
  final WalletTransactionType type;
  final int amountCents;
  final WalletTransactionStatus status;
  final DateTime createdAt;
  final Goal? goal;
  final String? leagueName;

  double get amountRand => amountCents / 100;
}
