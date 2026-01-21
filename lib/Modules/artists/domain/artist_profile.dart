class ArtistProfile {
  final String key;
  final String displayName;
  final String? thumbnail;
  final String? thumbnailLocalPath;

  const ArtistProfile({
    required this.key,
    required this.displayName,
    this.thumbnail,
    this.thumbnailLocalPath,
  });

  ArtistProfile copyWith({
    String? key,
    String? displayName,
    String? thumbnail,
    String? thumbnailLocalPath,
  }) {
    return ArtistProfile(
      key: key ?? this.key,
      displayName: displayName ?? this.displayName,
      thumbnail: thumbnail ?? this.thumbnail,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'displayName': displayName,
    'thumbnail': thumbnail,
    'thumbnailLocalPath': thumbnailLocalPath,
  };

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    return ArtistProfile(
      key: (json['key'] as String?)?.trim() ?? '',
      displayName: (json['displayName'] as String?)?.trim() ?? '',
      thumbnail: (json['thumbnail'] as String?)?.trim(),
      thumbnailLocalPath: (json['thumbnailLocalPath'] as String?)?.trim(),
    );
  }

  static String normalizeKey(String raw) {
    final s = raw.trim().toLowerCase();
    return s.isEmpty ? 'unknown' : s;
  }
}
