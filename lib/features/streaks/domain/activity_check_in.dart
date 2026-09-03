import '../../goals/domain/goal.dart';

class ActivityCheckIn {
  const ActivityCheckIn({
    required this.id,
    required this.activity,
    required this.loggedDate,
  });

  factory ActivityCheckIn.fromMap(Map<String, dynamic> map) {
    return ActivityCheckIn(
      id: map['id'] as String,
      activity: distanceActivityFromString(map['activity'] as String)!,
      loggedDate: DateTime.parse(map['logged_date'] as String),
    );
  }

  final String id;
  final DistanceActivity activity;
  final DateTime loggedDate;
}
