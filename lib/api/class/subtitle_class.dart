class SubtitleClass {
  final String language;
  final String url;
  final String? label;

  SubtitleClass({
    required this.language,
    required this.url,
    this.label,
  });

  factory SubtitleClass.fromJson(Map<String, dynamic> json) {
    return SubtitleClass(
      language: json['language'] as String,
      url: json['url'] as String,
      label: json['label'] as String?,
    );
  }
}
