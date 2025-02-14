import 'package:hive/hive.dart';

part 'watch_history_model.g.dart';

@HiveType(typeId: 4)
class WatchHistoryItem extends HiveObject {
  @HiveField(0)
  final int contentId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String poster;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final DateTime watchedAt;

  @HiveField(5)
  final Duration? progress;

  @HiveField(6)
  final Duration? totalDuration;

  @HiveField(7)
  final int? episodeNumber;

  @HiveField(8)
  final String? episodeTitle;

  @HiveField(9)
  final Map<String, dynamic>? content;

  @HiveField(10)
  final int? seasonNumber; // Add this field

  WatchHistoryItem({
    required this.contentId,
    required this.title,
    required this.poster,
    required this.type,
    required this.watchedAt,
    this.progress,
    this.totalDuration,
    this.episodeNumber,
    this.episodeTitle,
    this.content,
    this.seasonNumber, // Add to constructor
  });

  // Add toJson method for Firebase
  Map<String, dynamic> toJson() {
    return {
      'contentId': contentId,
      'title': title,
      'poster': poster,
      'type': type,
      'watchedAt': watchedAt.toIso8601String(),
      'progress': progress?.inSeconds,
      'totalDuration': totalDuration?.inSeconds,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'content': content,
      'seasonNumber': seasonNumber, // Add to JSON
    };
  }

  // Add fromJson factory for Firebase
  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return WatchHistoryItem(
      contentId: json['contentId'] as int,
      title: json['title'] as String,
      poster: json['poster'] as String,
      type: json['type'] as String,
      watchedAt: DateTime.parse(json['watchedAt'] as String),
      progress: json['progress'] != null 
          ? Duration(seconds: json['progress'] as int) 
          : null,
      totalDuration: json['totalDuration'] != null 
          ? Duration(seconds: json['totalDuration'] as int) 
          : null,
      episodeNumber: json['episodeNumber'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      content: json['content'] as Map<String, dynamic>?,
      seasonNumber: json['seasonNumber'] as int?, // Add from JSON
    );
  }
}
