import 'package:flutter_test/flutter_test.dart';
import 'package:forgo/features/auth/presentation/widgets/date_of_birth_field.dart';

void main() {
  final referenceNow = DateTime(2026, 9, 2);

  group('DateOfBirthField.isEligible', () {
    test('rejects someone who turns 18 tomorrow', () {
      final dob = DateTime(2008, 9, 3);
      expect(DateOfBirthField.isEligible(dob, referenceNow), isFalse);
    });

    test('accepts someone who turns 18 today', () {
      final dob = DateTime(2008, 9, 2);
      expect(DateOfBirthField.isEligible(dob, referenceNow), isTrue);
    });

    test('accepts someone who turned 18 yesterday', () {
      final dob = DateTime(2008, 9, 1);
      expect(DateOfBirthField.isEligible(dob, referenceNow), isTrue);
    });

    test('rejects a 10 year old', () {
      final dob = DateTime(2016, 1, 1);
      expect(DateOfBirthField.isEligible(dob, referenceNow), isFalse);
    });
  });
}
