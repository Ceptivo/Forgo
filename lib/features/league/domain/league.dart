/// "No Turning Back" — a 30-day founder-run competitive league inside the
/// Forgo Community Group. See supabase/migrations/0017_no_turning_back_league.sql
/// for the full mechanics and the reasoning behind each design choice.
class League {
  const League({
    required this.id,
    required this.name,
    required this.entryFeeCents,
    required this.prizeCents,
    required this.startDate,
    required this.createdBy,
    this.winnerUserId,
    this.finalizedAt,
  });

  factory League.fromMap(Map<String, dynamic> map) {
    return League(
      id: map['id'] as String,
      name: map['name'] as String,
      entryFeeCents: (map['entry_fee_cents'] as num).toInt(),
      prizeCents: (map['prize_cents'] as num).toInt(),
      startDate: _parseDateUtc(map['start_date'] as String),
      createdBy: map['created_by'] as String,
      winnerUserId: map['winner_user_id'] as String?,
      finalizedAt: map['finalized_at'] == null
          ? null
          : DateTime.parse(map['finalized_at'] as String),
    );
  }

  final String id;
  final String name;
  final int entryFeeCents;
  final int prizeCents;
  final DateTime startDate;
  final String createdBy;
  final String? winnerUserId;
  final DateTime? finalizedAt;

  double get entryFeeRand => entryFeeCents / 100;
  double get prizeRand => prizeCents / 100;
  bool get isFinalized => finalizedAt != null;

  /// Day 1 releases on [startDate] at 04:00 SAST; every following day
  /// releases 24 hours after the last. South Africa has no daylight
  /// saving, so SAST is always a fixed UTC+2 — 04:00 SAST is 02:00 UTC.
  /// Mirrors public.league_day_release_at in the migration exactly.
  DateTime releaseAt(int dayNumber) =>
      startDate.add(Duration(days: dayNumber - 1, hours: 2));

  bool hasStarted(DateTime now) => !now.isBefore(releaseAt(1));

  bool hasFinished(DateTime now) => !now.isBefore(releaseAt(31));

  static DateTime _parseDateUtc(String isoDate) {
    final parts = isoDate.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

class LeagueDay {
  const LeagueDay({
    required this.dayNumber,
    required this.title,
    required this.description,
  });

  factory LeagueDay.fromMap(Map<String, dynamic> map) {
    return LeagueDay(
      dayNumber: map['day_number'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
    );
  }

  final int dayNumber;
  final String title;
  final String description;
}

class LeagueEntry {
  const LeagueEntry({required this.userId, required this.joinedAt});

  factory LeagueEntry.fromMap(Map<String, dynamic> map) {
    return LeagueEntry(
      userId: map['user_id'] as String,
      joinedAt: DateTime.parse(map['joined_at'] as String),
    );
  }

  final String userId;
  final DateTime joinedAt;
}

class LeagueSubmission {
  const LeagueSubmission({
    required this.userId,
    required this.dayNumber,
    required this.completed,
    required this.submittedAt,
  });

  factory LeagueSubmission.fromMap(Map<String, dynamic> map) {
    return LeagueSubmission(
      userId: map['user_id'] as String,
      dayNumber: map['day_number'] as int,
      completed: map['completed'] as bool,
      submittedAt: DateTime.parse(map['submitted_at'] as String),
    );
  }

  final String userId;
  final int dayNumber;
  final bool completed;
  final DateTime submittedAt;
}

/// A single entrant's derived state in a league — nothing here is stored;
/// it's all computed from [League.releaseAt] plus the raw entries/
/// submissions, the same "fetch raw rows, aggregate client-side" pattern
/// the group-goal leaderboard already uses. This is for display only —
/// the actual prize payout is decided independently, server-side, in
/// finalize_league (see the migration), never trusted from this.
class LeagueStanding {
  const LeagueStanding({
    required this.userId,
    required this.daysCompleted,
    required this.eliminatedOnDay,
    required this.totalElapsed,
  });

  final String userId;
  final int daysCompleted;
  final int? eliminatedOnDay;
  final Duration totalElapsed;

  bool get isEliminated => eliminatedOnDay != null;
  bool get hasFinishedAll30 => !isEliminated && daysCompleted == 30;
}

List<LeagueStanding> computeLeagueStandings({
  required League league,
  required List<LeagueEntry> entries,
  required List<LeagueSubmission> submissions,
  required DateTime now,
}) {
  final byUser = <String, List<LeagueSubmission>>{};
  for (final submission in submissions) {
    (byUser[submission.userId] ??= []).add(submission);
  }

  var lastClosedDay = 0;
  for (var day = 1; day <= 30; day++) {
    if (!now.isBefore(league.releaseAt(day + 1))) {
      lastClosedDay = day;
    }
  }

  final standings = entries.map((entry) {
    final mine = byUser[entry.userId] ?? const <LeagueSubmission>[];
    final byDay = {for (final s in mine) s.dayNumber: s};

    int? eliminatedOnDay;
    for (var day = 1; day <= lastClosedDay; day++) {
      if (byDay[day]?.completed != true) {
        eliminatedOnDay = day;
        break;
      }
    }

    var daysCompleted = 0;
    var totalElapsed = Duration.zero;
    for (final submission in mine) {
      if (!submission.completed) continue;
      daysCompleted++;
      totalElapsed += submission.submittedAt.difference(
        league.releaseAt(submission.dayNumber),
      );
    }

    return LeagueStanding(
      userId: entry.userId,
      daysCompleted: daysCompleted,
      eliminatedOnDay: eliminatedOnDay,
      totalElapsed: totalElapsed,
    );
  }).toList();

  standings.sort((a, b) {
    if (a.isEliminated != b.isEliminated) {
      return a.isEliminated ? 1 : -1;
    }
    if (!a.isEliminated) {
      if (a.hasFinishedAll30 != b.hasFinishedAll30) {
        return a.hasFinishedAll30 ? -1 : 1;
      }
      if (a.hasFinishedAll30) {
        return a.totalElapsed.compareTo(b.totalElapsed);
      }
      if (a.daysCompleted != b.daysCompleted) {
        return b.daysCompleted.compareTo(a.daysCompleted);
      }
      return a.totalElapsed.compareTo(b.totalElapsed);
    }
    if (a.daysCompleted != b.daysCompleted) {
      return b.daysCompleted.compareTo(a.daysCompleted);
    }
    return (b.eliminatedOnDay ?? 0).compareTo(a.eliminatedOnDay ?? 0);
  });

  return standings;
}
