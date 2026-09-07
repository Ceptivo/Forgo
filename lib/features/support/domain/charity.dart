class Charity {
  const Charity({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl,
    this.websiteUrl,
    this.registrationInfo,
    this.whyWeSupport,
  });

  factory Charity.fromMap(Map<String, dynamic> map) {
    return Charity(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      logoUrl: map['logo_url'] as String?,
      websiteUrl: map['website_url'] as String?,
      registrationInfo: map['registration_info'] as String?,
      whyWeSupport: map['why_we_support'] as String?,
    );
  }

  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String? websiteUrl;
  final String? registrationInfo;
  final String? whyWeSupport;
}
