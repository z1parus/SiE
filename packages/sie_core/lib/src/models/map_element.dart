import 'dart:ui' show Offset;

/// Kind discriminator for a [MapElement] — the polymorphic, "map-native"
/// content that lives only on the Tactical Map (never in list mode).
///
/// Stage 1 ships `note` and `label`. Later stages reuse the same table:
/// `image` (Stage 3 — image cards), `group`/`connector` (Stage 4).
enum MapElementKind {
  note,
  label,
  image,
  group,
  connector;

  static MapElementKind fromString(String? s) {
    switch (s) {
      case 'label':
        return MapElementKind.label;
      case 'image':
        return MapElementKind.image;
      case 'group':
        return MapElementKind.group;
      case 'connector':
        return MapElementKind.connector;
      case 'note':
      default:
        return MapElementKind.note;
    }
  }

  String get wire => name;
}

/// A free-floating element placed directly on the Tactical Map canvas.
///
/// Positions use the same logical canvas coordinates as plan nodes (an [Offset]
/// relative to the goal centre at `(0,0)`; on screen it is `_cx + pos`). Unlike
/// node positions (stored in `LocalMapPositions`), an element carries its own
/// `x`/`y` because it is self-contained.
class MapElement {
  const MapElement({
    required this.id,
    required this.goalId,
    required this.kind,
    required this.x,
    required this.y,
    required this.createdBy,
    required this.createdAt,
    this.w,
    this.h,
    this.zIndex = 0,
    this.content,
    this.colorHex,
    this.mediaUrl,
    this.fromRef,
    this.toRef,
    this.styleJson,
    this.updatedAt,
  });

  final String id;
  final String goalId;
  final MapElementKind kind;
  final double x;
  final double y;
  final double? w;
  final double? h;
  final int zIndex;
  final String? content;
  final String? colorHex;
  final String? mediaUrl; // Stage 3 (image)
  final String? fromRef; // Stage 4 (connector)
  final String? toRef; // Stage 4 (connector)
  final Map<String, dynamic>? styleJson; // Stage 4 (connector style)
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Offset get position => Offset(x, y);

  MapElement copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
    int? zIndex,
    String? content,
    String? colorHex,
    String? mediaUrl,
    String? fromRef,
    String? toRef,
    Map<String, dynamic>? styleJson,
    DateTime? updatedAt,
  }) =>
      MapElement(
        id: id,
        goalId: goalId,
        kind: kind,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        zIndex: zIndex ?? this.zIndex,
        content: content ?? this.content,
        colorHex: colorHex ?? this.colorHex,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        fromRef: fromRef ?? this.fromRef,
        toRef: toRef ?? this.toRef,
        styleJson: styleJson ?? this.styleJson,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory MapElement.fromJson(Map<String, dynamic> j) => MapElement(
        id: j['id'] as String,
        goalId: j['goal_id'] as String,
        kind: MapElementKind.fromString(j['kind'] as String?),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num?)?.toDouble(),
        h: (j['h'] as num?)?.toDouble(),
        zIndex: (j['z_index'] as num?)?.toInt() ?? 0,
        content: j['content'] as String?,
        colorHex: j['color_hex'] as String?,
        mediaUrl: j['media_url'] as String?,
        fromRef: j['from_ref'] as String?,
        toRef: j['to_ref'] as String?,
        styleJson: j['style_json'] as Map<String, dynamic>?,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: j['updated_at'] != null
            ? DateTime.parse(j['updated_at'] as String)
            : null,
      );

  /// Payload for Supabase upsert (server fills defaults for null columns).
  Map<String, dynamic> toUpsertJson() => {
        'id': id,
        'goal_id': goalId,
        'kind': kind.wire,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'z_index': zIndex,
        'content': content,
        'color_hex': colorHex,
        'media_url': mediaUrl,
        'from_ref': fromRef,
        'to_ref': toRef,
        'style_json': styleJson,
        'created_by': createdBy,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}
