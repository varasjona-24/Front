import 'source_origin.dart';

// ============================
// 🧩 MODELO: PILL
// ============================
class SourceThemePill {
  const SourceThemePill({
    required this.id,
    required this.themeId,
    required this.title,
    required this.origins,
    required this.createdAt,
  });

  // ============================
  // 📌 PROPIEDADES
  // ============================
  final String id;
  final String themeId;
  final String title;
  final List<SourceOrigin> origins;
  final int createdAt;

  // ============================
  // 🧬 COPY
  // ============================
  SourceThemePill copyWith({
    String? id,
    String? themeId,
    String? title,
    List<SourceOrigin>? origins,
    int? createdAt,
  }) {
    return SourceThemePill(
      id: id ?? this.id,
      themeId: themeId ?? this.themeId,
      title: title ?? this.title,
      origins: origins ?? this.origins,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ============================
  // 🔁 SERIALIZACION
  // ============================
  factory SourceThemePill.fromJson(Map<String, dynamic> json) {
    final rawOrigins = (json['origins'] as List?) ?? const [];
    return SourceThemePill(
      id: (json['id'] as String?)?.trim() ?? '',
      themeId: (json['themeId'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      origins: rawOrigins
          .whereType<String>()
          .map(SourceOriginX.fromKey)
          .toList(),
      createdAt: (json['createdAt'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'themeId': themeId,
        'title': title,
        'origins': origins.map((e) => e.key).toList(),
        'createdAt': createdAt,
      };
}
