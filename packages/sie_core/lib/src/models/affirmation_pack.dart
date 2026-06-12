class AffirmationPack {
  final String id;
  final String name;
  final String category; // 'confidence' | 'calm' | 'energy' | 'general'
  final List<String> phrases;
  final bool isCustom;
  final String? userId;

  const AffirmationPack({
    required this.id,
    required this.name,
    this.category = 'general',
    required this.phrases,
    this.isCustom = false,
    this.userId,
  });

  factory AffirmationPack.fromMap(Map<String, dynamic> m) => AffirmationPack(
        id: m['id'] as String,
        name: m['name'] as String,
        category: m['category'] as String? ?? 'general',
        phrases:
            (m['phrases'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isCustom: m['is_custom'] as bool? ?? false,
        userId: m['user_id'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'phrases': phrases,
        'is_custom': isCustom,
        'user_id': userId,
      };
}
