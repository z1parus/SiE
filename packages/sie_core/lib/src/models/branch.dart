class Branch {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? iconUrl;

  const Branch({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.iconUrl,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        iconUrl: json['icon_url'] as String?,
      );
}
