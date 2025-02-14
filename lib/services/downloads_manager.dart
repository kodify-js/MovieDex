import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:moviedex/api/class/content_class.dart';

part 'downloads_manager.g.dart';

@HiveType(typeId: 6)
class DownloadItem {
  @HiveField(0)
  final int contentId;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String poster;
  
  @HiveField(3)
  final String type;
  
  @HiveField(4)
  final String filePath;
  
  @HiveField(5)
  final DateTime downloadDate;
  
  @HiveField(6)
  final int? episodeNumber;
  
  @HiveField(7)
  final int? seasonNumber;
  
  @HiveField(8)
  final String quality;
  
  DownloadItem({
    required this.contentId,
    required this.title,
    required this.poster,
    required this.type,
    required this.filePath,
    required this.downloadDate,
    this.episodeNumber,
    this.seasonNumber,
    required this.quality,
  });

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'title': title,
    'poster': poster,
    'type': type,
    'filePath': filePath,
    'downloadDate': downloadDate.toIso8601String(),
    'episodeNumber': episodeNumber,
    'seasonNumber': seasonNumber,
    'quality': quality,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    contentId: json['contentId'],
    title: json['title'],
    poster: json['poster'],
    type: json['type'],
    filePath: json['filePath'],
    downloadDate: DateTime.parse(json['downloadDate']),
    episodeNumber: json['episodeNumber'],
    seasonNumber: json['seasonNumber'],
    quality: json['quality'],
  );
}

class DownloadsManager {
  static final DownloadsManager _instance = DownloadsManager._();
  static DownloadsManager get instance => _instance;
  Box? _downloadsBox;
  bool _isInitialized = false;

  DownloadsManager._();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _downloadsBox = await Hive.openBox('downloads');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing downloads box: $e');
      // Try to delete and recreate the box if corrupted
      await _handleCorruptedBox();
    }
  }

  Future<void> _handleCorruptedBox() async {
    try {
      await Hive.deleteBoxFromDisk('downloads');
      _downloadsBox = await Hive.openBox('downloads');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to recover downloads box: $e');
    }
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized || _downloadsBox == null || !_downloadsBox!.isOpen) {
      await init();
    }
  }

  Future<void> addDownload(
    Contentclass content,
    String filePath,
    String quality, {
    int? episodeNumber,
    int? seasonNumber,
  }) async {
    await ensureInitialized();
    try {
      await _downloadsBox?.put(content.id.toString(), {
        'id': content.id,
        'title': content.title,
        'poster': content.poster,
        'type': content.type,
        'filePath': filePath,
        'quality': quality,
        'episodeNumber': episodeNumber,
        'seasonNumber': seasonNumber,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error adding download: $e');
      rethrow;
    }
  }

  List<DownloadItem> getDownloads() {
    return _downloadsBox!.values
        .map((item) => DownloadItem.fromJson(Map<String, dynamic>.from(item)))
        .toList()
        ..sort((a, b) => b.downloadDate.compareTo(a.downloadDate));
  }

  Future<void> removeDownload(int contentId) async {
    await _downloadsBox?.delete(contentId.toString());
  }

  bool hasDownload(int contentId) {
    return _downloadsBox?.containsKey(contentId.toString()) ?? false;
  }
}
