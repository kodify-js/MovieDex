import 'package:hive/hive.dart';

part 'download_state_model.g.dart';

@HiveType(typeId: 7)
class DownloadState {
  @HiveField(0)
  final int contentId;

  @HiveField(1)
  final String status; // 'downloading', 'paused', 'error', 'completed'

  @HiveField(2)
  final double progress;

  @HiveField(3)
  final String url;

  @HiveField(4)
  final String quality;

  @HiveField(5)
  final int? lastSegmentIndex;

  @HiveField(6)
  final int? episodeNumber;

  @HiveField(7)
  final int? seasonNumber;

  @HiveField(8)
  final double speed;

  @HiveField(9)
  final double timeLeft;

  DownloadState({
    required this.contentId,
    required this.status,
    required this.progress,
    required this.url,
    required this.quality,
    this.lastSegmentIndex,
    this.episodeNumber,
    this.seasonNumber,
    this.speed = 0,
    this.timeLeft = 0,
  });
}
