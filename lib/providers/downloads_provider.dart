import 'package:flutter/foundation.dart';

class DownloadProgress {
  final int contentId;
  final double progress;
  final String status;  // 'downloading', 'paused', 'completed', 'error'
  final String title;
  final String poster;
  final String quality;
  final bool isPaused;  // Add this field

  DownloadProgress({
    required this.contentId,
    required this.progress,
    required this.status,
    required this.title,
    required this.poster,
    required this.quality,
    this.isPaused = false,  // Default to false
  });
}

class DownloadsProvider extends ChangeNotifier {
  static final DownloadsProvider instance = DownloadsProvider._();
  DownloadsProvider._();

  final Map<int, DownloadProgress> _activeDownloads = {};

  Map<int, DownloadProgress> get activeDownloads => Map.unmodifiable(_activeDownloads);

  void updateProgress(
    int contentId, 
    double progress,
    String status,
    String title,
    String poster,
    String quality, {
    bool isPaused = false,  // Add isPaused parameter
  }) {
    _activeDownloads[contentId] = DownloadProgress(
      contentId: contentId,
      progress: progress,
      status: status,
      title: title,
      poster: poster,
      quality: quality,
      isPaused: isPaused,
    );
    notifyListeners();
  }

  void removeDownload(int contentId) {
    _activeDownloads.remove(contentId);
    notifyListeners();
  }

  DownloadProgress? getDownloadProgress(int contentId) {
    return _activeDownloads[contentId];
  }

  bool isDownloading(int contentId) {
    return _activeDownloads.containsKey(contentId);
  }

  // Add methods to handle pause/resume
  void pauseDownload(int contentId) {
    final download = _activeDownloads[contentId];
    if (download != null) {
      _activeDownloads[contentId] = DownloadProgress(
        contentId: contentId,
        progress: download.progress,
        status: 'paused',
        title: download.title,
        poster: download.poster,
        quality: download.quality,
        isPaused: true,
      );
      notifyListeners();
    }
  }

  void resumeDownload(int contentId) {
    final download = _activeDownloads[contentId];
    if (download != null) {
      _activeDownloads[contentId] = DownloadProgress(
        contentId: contentId,
        progress: download.progress,
        status: 'downloading',
        title: download.title,
        poster: download.poster,
        quality: download.quality,
        isPaused: false,
      );
      notifyListeners();
    }
  }
}
