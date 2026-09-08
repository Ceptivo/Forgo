import 'package:flutter_test/flutter_test.dart';
import 'package:forgo/core/xp/level.dart';

void main() {
  group('xpForLevel', () {
    test('matches the spec table', () {
      expect(xpForLevel(1), 0);
      expect(xpForLevel(2), 12);
      expect(xpForLevel(3), 36);
      expect(xpForLevel(10), 540);
      expect(xpForLevel(52), 15912);
      expect(xpForLevel(100), 59400);
    });
  });

  group('levelForXp', () {
    test('matches the spec table at exact thresholds', () {
      expect(levelForXp(0), 1);
      expect(levelForXp(12), 2);
      expect(levelForXp(540), 10);
      expect(levelForXp(59400), 100);
    });

    test('stays at the lower level just below a threshold', () {
      expect(levelForXp(11), 1);
      expect(levelForXp(539), 9);
      expect(levelForXp(59399), 99);
    });

    test('extends past level 100 using the same formula', () {
      expect(levelForXp(xpForLevel(150)), 150);
    });
  });

  group('levelProgressForXp', () {
    test('reports progress within the current level', () {
      // Level 10 starts at 540, level 11 at 660 — 120 XP needed.
      final progress = levelProgressForXp(570);
      expect(progress.level, 10);
      expect(progress.xpIntoLevel, 30);
      expect(progress.xpForNextLevel, 120);
      expect(progress.fraction, closeTo(0.25, 1e-9));
    });

    test('starts a fresh level at zero progress', () {
      final progress = levelProgressForXp(540);
      expect(progress.level, 10);
      expect(progress.xpIntoLevel, 0);
      expect(progress.fraction, 0);
    });
  });
}
