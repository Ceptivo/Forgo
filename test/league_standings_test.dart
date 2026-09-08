import 'package:flutter_test/flutter_test.dart';
import 'package:forgo/features/league/domain/league.dart';

void main() {
  final league = League(
    id: 'league-1',
    name: 'No Turning Back',
    entryFeeCents: 5000,
    prizeCents: 100000,
    startDate: DateTime.utc(2026, 1, 1),
    createdBy: 'founder',
  );

  LeagueSubmission submitted({
    required String userId,
    required int dayNumber,
    required bool completed,
    Duration delay = Duration.zero,
  }) {
    return LeagueSubmission(
      userId: userId,
      dayNumber: dayNumber,
      completed: completed,
      submittedAt: league.releaseAt(dayNumber).add(delay),
    );
  }

  group('League.releaseAt', () {
    test('day 1 releases at 04:00 SAST (02:00 UTC) on the start date', () {
      expect(league.releaseAt(1), DateTime.utc(2026, 1, 1, 2));
    });

    test('each following day releases 24 hours later', () {
      expect(league.releaseAt(2), DateTime.utc(2026, 1, 2, 2));
      expect(league.releaseAt(30), DateTime.utc(2026, 1, 30, 2));
    });
  });

  group('computeLeagueStandings', () {
    final entries = [
      LeagueEntry(userId: 'alice', joinedAt: league.startDate),
      LeagueEntry(userId: 'bob', joinedAt: league.startDate),
      LeagueEntry(userId: 'carol', joinedAt: league.startDate),
    ];

    test('a user who misses a closed day is eliminated on that day', () {
      final now = league.releaseAt(3); // day 2's window has fully closed
      final submissions = [
        submitted(userId: 'alice', dayNumber: 1, completed: true),
        submitted(userId: 'alice', dayNumber: 2, completed: true),
        // bob never submits day 1 at all
        submitted(userId: 'carol', dayNumber: 1, completed: true),
        submitted(userId: 'carol', dayNumber: 2, completed: false),
      ];

      final standings = computeLeagueStandings(
        league: league,
        entries: entries,
        submissions: submissions,
        now: now,
      );

      final byId = {for (final s in standings) s.userId: s};
      expect(byId['alice']!.isEliminated, isFalse);
      expect(byId['bob']!.eliminatedOnDay, 1);
      expect(byId['carol']!.eliminatedOnDay, 2);
    });

    test('survivors rank above eliminated entrants', () {
      final now = league.releaseAt(2); // only day 1's window has closed
      final submissions = [
        submitted(userId: 'alice', dayNumber: 1, completed: true),
        submitted(userId: 'bob', dayNumber: 1, completed: false),
      ];

      final standings = computeLeagueStandings(
        league: league,
        entries: entries,
        submissions: submissions,
        now: now,
      );

      expect(standings.first.userId, 'alice');
      expect(standings.first.isEliminated, isFalse);
    });

    test('among finishers of all 30 days, the fastest total time ranks first', () {
      final now = league.releaseAt(31);
      final submissions = [
        for (var day = 1; day <= 30; day++) ...[
          submitted(
            userId: 'alice',
            dayNumber: day,
            completed: true,
            delay: const Duration(minutes: 5),
          ),
          submitted(
            userId: 'bob',
            dayNumber: day,
            completed: true,
            delay: const Duration(minutes: 30),
          ),
        ],
      ];

      final standings = computeLeagueStandings(
        league: league,
        entries: entries.where((e) => e.userId != 'carol').toList(),
        submissions: submissions,
        now: now,
      );

      expect(standings.first.userId, 'alice');
      expect(standings.first.hasFinishedAll30, isTrue);
      expect(standings[1].userId, 'bob');
    });

    test('nobody eliminated yet on day 1 before its window closes', () {
      final now = league.releaseAt(1).add(const Duration(hours: 1));
      final standings = computeLeagueStandings(
        league: league,
        entries: entries,
        submissions: const [],
        now: now,
      );

      expect(standings.every((s) => !s.isEliminated), isTrue);
    });
  });
}
