import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/models/download_state_model.dart';

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

  late Box<DownloadState> _downloadStatesBox;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _downloadsBox = await Hive.openBox('downloads');
      _isInitialized = true;
      _downloadStatesBox = await Hive.openBox<DownloadState>('download_states');
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
    
    // Create the download item with proper typing
    final downloadItem = {
      'contentId': content.id,
      'title': content.title,
      'poster': content.poster,
      'type': content.type,
      'filePath': filePath,
      'quality': quality,
      'episodeNumber': episodeNumber,
      'seasonNumber': seasonNumber,
      'downloadDate': DateTime.now().toIso8601String(),
    };

    try {
      await _downloadsBox?.put(content.id.toString(), downloadItem);
    } catch (e) {
      debugPrint('Error adding download: $e');
      rethrow;
    }
  }

  List<DownloadItem> getDownloads() {
    if (_downloadsBox == null) return [];
    
    try {
      return _downloadsBox!.values
          .map((item) {
            if (item == null) return null;
            
            final Map<String, dynamic> downloadData = Map<String, dynamic>.from(item);
            
            // Add null checks and safe type casting
            final contentId = downloadData['contentId'];
            if (contentId == null) return null;
            
            return DownloadItem(
              contentId: contentId is String ? int.parse(contentId) : contentId as int,
              title: downloadData['title'] as String? ?? '',
              poster: downloadData['poster'] as String? ?? '',
              type: downloadData['type'] as String? ?? '',
              filePath: downloadData['filePath'] as String? ?? '',
              quality: downloadData['quality'] as String? ?? '',
              downloadDate: DateTime.parse(downloadData['downloadDate'] as String? ?? DateTime.now().toIso8601String()),
              episodeNumber: downloadData['episodeNumber'] is String 
                  ? int.tryParse(downloadData['episodeNumber'])
                  : downloadData['episodeNumber'] as int?,
              seasonNumber: downloadData['seasonNumber'] is String 
                  ? int.tryParse(downloadData['seasonNumber'])
                  : downloadData['seasonNumber'] as int?,
            );
          })
          .where((item) => item != null) // Filter out null items
          .cast<DownloadItem>() // Cast to List<DownloadItem>
          .toList()
        ..sort((a, b) => b.downloadDate.compareTo(a.downloadDate));
    } catch (e) {
      debugPrint('Error getting downloads: $e');
      return [];
    }
  }

  Future<void> removeDownload(int contentId) async {
    try {
      // Get the box
      final box = await Hive.openBox<Map>('downloads');
      
      // Get all downloads for this content
      final downloads = getAllDownloadsForContent(contentId);
      
      // Delete each download's file
      for (var download in downloads) {
        final filePath = download['path'] as String;
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Remove from Hive box
      await box.delete(contentId.toString());

      // Remove any episode-specific downloads
      final episodeKeys = box.keys.where((key) => key.toString().startsWith('${contentId}_'));
      for (var key in episodeKeys) {
        await box.delete(key);
      }

      await box.compact();
      
    } catch (e) {
      debugPrint('Error removing download: $e');
    }
  }

  bool hasDownload(int contentId) {
    return _downloadsBox?.containsKey(contentId.toString()) ?? false;
  }

  bool hasEpisodeDownload(int contentId, {required int episodeNumber, required int seasonNumber}) {
    if (_downloadsBox == null) return false;
    
    try {
      final downloads = getDownloads();
      return downloads.any((download) => 
        download.contentId == contentId &&
        download.episodeNumber == episodeNumber &&
        download.seasonNumber == seasonNumber
      );
    } catch (e) {
      debugPrint('Error checking episode download: $e');
      return false;
    }
  }

  DownloadItem? getDownload(int contentId, {int? episodeNumber, int? seasonNumber}) {
    if (_downloadsBox == null) return null;

    try {
      final downloads = getDownloads();
      return downloads.firstWhere(
        (download) => 
          download.contentId == contentId &&
          (episodeNumber == null || download.episodeNumber == episodeNumber) &&
          (seasonNumber == null || download.seasonNumber == seasonNumber),
        orElse: () => throw 'Download not found',
      );
    } catch (e) {
      debugPrint('Error getting download: $e');
      return null;
    }
  }

  String getEpisodeText(DownloadItem download) {
    if (download.seasonNumber != null && download.episodeNumber != null) {
      return 'S${download.seasonNumber.toString().padLeft(2, '0')}E${download.episodeNumber.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Future<void> saveDownloadState({
    required int contentId,
    required String status,
    required double progress,
    required String url,
    required String quality,
    int? lastSegmentIndex,
    int? episodeNumber,
    int? seasonNumber,
  }) async {
    await _downloadStatesBox.put(
      contentId.toString(),
      DownloadState(
        contentId: contentId,
        status: status,
        progress: progress,
        url: url,
        quality: quality,
        lastSegmentIndex: lastSegmentIndex,
        episodeNumber: episodeNumber,
        seasonNumber: seasonNumber,
      ),
    );
  }

  DownloadState? getDownloadState(int contentId) {
    return _downloadStatesBox.get(contentId.toString());
  }

  Future<void> clearDownloadState(int contentId) async {
    await _downloadStatesBox.delete(contentId.toString());
  }

  List<DownloadState> getPendingDownloads() {
    return _downloadStatesBox.values
        .where((state) => state.status != 'completed')
        .toList();
  }

  List<Map<String, dynamic>> getAllDownloadsForContent(int contentId) {
    if (_downloadsBox == null) return [];

    try {
      // Get all download entries that match the content ID
      final List<Map<String, dynamic>> downloads = [];
      
      // Check main content download
      final mainDownload = _downloadsBox?.get(contentId.toString());
      if (mainDownload != null) {
        downloads.add(Map<String, dynamic>.from(mainDownload));
      }

      // Check episode-specific downloads
      final episodeKeys = _downloadsBox?.keys
          .where((key) => key.toString().startsWith('${contentId}_'));
      
      for (final key in episodeKeys ?? []) {
        final download = _downloadsBox?.get(key);
        if (download != null) {
          downloads.add(Map<String, dynamic>.from(download));
        }
      }

      return downloads;
    } catch (e) {
      debugPrint('Error getting downloads for content: $e');
      return [];
    }
  }

  List<DownloadItem> getDownloadsForSeason(int contentId, {required int seasonNumber}) {
    if (_downloadsBox == null) return [];
    
    try {
      final downloads = getDownloads();
      return downloads.where((download) => 
        download.contentId == contentId &&
        download.seasonNumber == seasonNumber
      ).toList();
    } catch (e) {
      debugPrint('Error getting season downloads: $e');
      return [];
    }
  }
}
