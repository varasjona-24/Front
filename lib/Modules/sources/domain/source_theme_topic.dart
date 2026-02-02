// ============================
// 🧩 MODELO: TOPIC
// ============================
class SourceThemeTopic {
  const SourceThemeTopic({
    required this.id,
    required this.themeId,
    required this.title,
    required this.createdAt,
    required this.itemIds,
    required this.playlistIds,
    this.coverUrl,
    this.coverLocalPath,
    this.colorValue,
  });

  // ============================
  // 📌 PROPIEDADES
  // ============================
  final String id;
  final String themeId;
  final String title;
  final int createdAt;
  final List<String> itemIds;
  final List<String> playlistIds;
  final String? coverUrl;
  final String? coverLocalPath;
  final int? colorValue;

  // ============================
  // 🧬 COPY
  // ============================
  SourceThemeTopic copyWith({
    String? id,
    String? themeId,
    String? title,
    int? createdAt,
    List<String>? itemIds,
    List<String>? playlistIds,
    String? coverUrl,
    String? coverLocalPath,
    int? colorValue,
  }) {
    return SourceThemeTopic(
      id: id ?? this.id,
      themeId: themeId ?? this.themeId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      itemIds: itemIds ?? this.itemIds,
      playlistIds: playlistIds ?? this.playlistIds,
      coverUrl: coverUrl ?? this.coverUrl,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  // ============================
  // 🔁 SERIALIZACION
  // ============================
  factory SourceThemeTopic.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['itemIds'] as List?) ?? const [];
    final rawPlaylists = (json['playlistIds'] as List?) ?? const [];
    return SourceThemeTopic(
      id: (json['id'] as String?)?.trim() ?? '',
      themeId: (json['themeId'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      createdAt: (json['createdAt'] as int?) ?? 0,
      itemIds: rawItems.whereType<String>().toList(),
      playlistIds: rawPlaylists.whereType<String>().toList(),
      coverUrl: (json['coverUrl'] as String?)?.trim(),
      coverLocalPath: (json['coverLocalPath'] as String?)?.trim(),
      colorValue: json['colorValue'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'themeId': themeId,
        'title': title,
        'createdAt': createdAt,
        'itemIds': itemIds,
        'playlistIds': playlistIds,
        'coverUrl': coverUrl,
        'coverLocalPath': coverLocalPath,
        'colorValue': colorValue,
      };
}
