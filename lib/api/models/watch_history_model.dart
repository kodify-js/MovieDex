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

  WatchHistoryItem({
    required this.contentId,
    required this.title,
    required this.poster,
    required this.type,
    required this.watchedAt,
    this.progress,
    this.totalDuration,
  });
}
