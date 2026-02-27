class SubtitleTrack {
  final String language;
  final String url;

  const SubtitleTrack({required this.language, required this.url});

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      language: (json['language'] as String?)?.trim() ?? '',
      url: (json['url'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'language': language, 'url': url};

  bool get isValid => language.isNotEmpty && url.isNotEmpty;
}
