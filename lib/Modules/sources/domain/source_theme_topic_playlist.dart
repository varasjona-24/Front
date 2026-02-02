// ============================
// 🧩 MODELO: PLAYLIST
// ============================
class SourceThemeTopicPlaylist {
  const SourceThemeTopicPlaylist({
    required this.id,
    required this.topicId,
    required this.name,
    required this.itemIds,
    required this.createdAt,
    this.parentId,
    this.depth = 1,
    this.coverUrl,
    this.coverLocalPath,
    this.colorValue,
  });

  // ============================
  // 📌 PROPIEDADES
  // ============================
  final String id;
  final String topicId;
  final String name;
  final List<String> itemIds;
  final int createdAt;
  final String? parentId;
  final int depth;
  final String? coverUrl;
  final String? coverLocalPath;
  final int? colorValue;

  // ============================
  // 🧬 COPY
  // ============================
  SourceThemeTopicPlaylist copyWith({
    String? id,
    String? topicId,
    String? name,
    List<String>? itemIds,
    int? createdAt,
    String? parentId,
    int? depth,
    String? coverUrl,
    String? coverLocalPath,
    int? colorValue,
  }) {
    return SourceThemeTopicPlaylist(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
      depth: depth ?? this.depth,
      coverUrl: coverUrl ?? this.coverUrl,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  // ============================
  // 🔁 SERIALIZACION
  // ============================
  Map<String, dynamic> toJson() => {
        'id': id,
        'topicId': topicId,
        'name': name,
        'itemIds': itemIds,
        'createdAt': createdAt,
        'parentId': parentId,
        'depth': depth,
        'coverUrl': coverUrl,
        'coverLocalPath': coverLocalPath,
        'colorValue': colorValue,
      };

  factory SourceThemeTopicPlaylist.fromJson(Map<String, dynamic> json) {
    return SourceThemeTopicPlaylist(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      name: json['name'] as String,
      itemIds: (json['itemIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      createdAt: json['createdAt'] as int,
      parentId: json['parentId'] as String?,
      depth: (json['depth'] as int?) ?? 1,
      coverUrl: (json['coverUrl'] as String?)?.trim(),
      coverLocalPath: (json['coverLocalPath'] as String?)?.trim(),
      colorValue: json['colorValue'] as int?,
    );
  }
}
