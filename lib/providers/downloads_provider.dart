import 'package:flutter/foundation.dart';

class DownloadProgress {
  final double progress;
  final String status;
  final String title;
  final String poster;
  final String quality;
  final bool isPaused;
  final double? speed;
  final Duration? timeRemaining;

  DownloadProgress({
    required this.progress,
    required this.status,
    required this.title,
    required this.poster,
    required this.quality,
    this.isPaused = false,
    this.speed,
    this.timeRemaining,
  });
}

class DownloadsProvider extends ChangeNotifier implements ValueListenable<Map<int, DownloadProgress>> {
  static final DownloadsProvider instance = DownloadsProvider._internal();
  DownloadsProvider._internal();

  final Map<int, DownloadProgress> _activeDownloads = {};

  @override
  Map<int, DownloadProgress> get value => _activeDownloads;

  Map<int, DownloadProgress> get activeDownloads => _activeDownloads;

  ValueNotifier<DownloadProgress?> getDownloadProgressNotifier(int contentId) {
    return ValueNotifier<DownloadProgress?>(_activeDownloads[contentId]);
  }

  void updateProgress(
    int contentId,
    double progress,
    String status,
    String title,
    String poster,
    String quality, {
    bool isPaused = false,
    double? speed,
    Duration? timeRemaining,
  }) {
    _activeDownloads[contentId] = DownloadProgress(
      progress: progress,
      status: status,
      title: title,
      poster: poster,
      quality: quality,
      isPaused: isPaused,
      speed: speed,
      timeRemaining: timeRemaining,
    );
    notifyListeners();
  }

  void removeDownload(int contentId) {
    _activeDownloads.remove(contentId);
    notifyListeners();
  }

  void pauseDownload(int contentId) {
    final download = _activeDownloads[contentId];
    if (download != null) {
      _activeDownloads[contentId] = DownloadProgress(
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

  DownloadProgress? getDownloadProgress(int contentId) {
    return _activeDownloads[contentId];
  }

  void clear() {
    _activeDownloads.clear();
    notifyListeners();
  }
}
