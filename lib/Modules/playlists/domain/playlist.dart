class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.itemIds,
    required this.createdAt,
    required this.updatedAt,
    this.coverUrl,
    this.coverLocalPath,
  });

  final String id;
  final String name;
  final List<String> itemIds;
  final int createdAt;
  final int updatedAt;
  final String? coverUrl;
  final String? coverLocalPath;

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? itemIds,
    int? createdAt,
    int? updatedAt,
    String? coverUrl,
    String? coverLocalPath,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverUrl: coverUrl ?? this.coverUrl,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
    );
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['itemIds'] as List?) ?? const [];
    return Playlist(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? 'Lista sin nombre',
      itemIds: rawItems.whereType<String>().toList(),
      createdAt: (json['createdAt'] as int?) ?? 0,
      updatedAt: (json['updatedAt'] as int?) ?? 0,
      coverUrl: (json['coverUrl'] as String?)?.trim(),
      coverLocalPath: (json['coverLocalPath'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'itemIds': itemIds,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'coverUrl': coverUrl,
        'coverLocalPath': coverLocalPath,
      };
}
