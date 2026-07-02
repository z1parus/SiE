class Tip {
  final String id;

  /// Russian (canonical) copy. Always present.
  final String title;
  final String description;

  /// English copy. May be empty for legacy rows created before localization;
  /// the localized getters fall back to the Russian text in that case.
  final String titleEn;
  final String descriptionEn;

  final bool isActive;

  const Tip({
    required this.id,
    required this.title,
    required this.description,
    this.titleEn = '',
    this.descriptionEn = '',
    this.isActive = true,
  });

  /// Title for the given language code ('en' → English when available, else
  /// the Russian fallback).
  String localizedTitle(String langCode) =>
      langCode == 'en' && titleEn.trim().isNotEmpty ? titleEn : title;

  /// Description for the given language code (English when available, else the
  /// Russian fallback).
  String localizedDescription(String langCode) =>
      langCode == 'en' && descriptionEn.trim().isNotEmpty
          ? descriptionEn
          : description;

  Tip copyWith({
    String? title,
    String? description,
    String? titleEn,
    String? descriptionEn,
    bool? isActive,
  }) =>
      Tip(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        titleEn: titleEn ?? this.titleEn,
        descriptionEn: descriptionEn ?? this.descriptionEn,
        isActive: isActive ?? this.isActive,
      );

  factory Tip.fromJson(Map<String, dynamic> json) => Tip(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        titleEn: json['title_en'] as String? ?? '',
        descriptionEn: json['description_en'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'title_en': titleEn,
        'description_en': descriptionEn,
        'is_active': isActive,
      };
}
