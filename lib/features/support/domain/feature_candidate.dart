/// One developer-picked feature idea users can vote for — the one with
/// the most votes is what actually gets built next.
class FeatureCandidate {
  const FeatureCandidate({
    required this.id,
    required this.title,
    required this.description,
    required this.voteCount,
    required this.myVote,
  });

  factory FeatureCandidate.fromMap(Map<String, dynamic> map) {
    return FeatureCandidate(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      voteCount: (map['vote_count'] as num).toInt(),
      myVote: map['my_vote'] as bool,
    );
  }

  final String id;
  final String title;
  final String description;
  final int voteCount;
  final bool myVote;
}
