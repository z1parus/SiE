class Tip {
  final String id;
  final String title;
  final String description;
  final bool isActive;

  const Tip({
    required this.id,
    required this.title,
    required this.description,
    this.isActive = true,
  });

  Tip copyWith({
    String? title,
    String? description,
    bool? isActive,
  }) =>
      Tip(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
      );

  factory Tip.fromJson(Map<String, dynamic> json) => Tip(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'is_active': isActive,
      };
}