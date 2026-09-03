class Charity {
  const Charity({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Charity.fromMap(Map<String, dynamic> map) {
    return Charity(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
    );
  }

  final String id;
  final String name;
  final String description;
}
