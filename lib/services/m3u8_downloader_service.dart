import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/models/downloads_manager.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/services/settings_service.dart';
import 'dart:math' as Math;

class _DownloadSnapshot {
  final DateTime time;
  final int bytesDownloaded;
  final double speed;
  final Duration timeRemaining;

  _DownloadSnapshot({
    required this.time,
    required this.bytesDownloaded,
    required this.speed,
    required this.timeRemaining,
  });
}

class M3U8DownloaderService {
  static const int _baseNotificationId = 1000;
  static const int _notificationId = _baseNotificationId;
  static const int _completionNotificationId = _baseNotificationId + 1;
  static const int _errorNotificationId = _baseNotificationId + 2;

  static final M3U8DownloaderService _instance =
      M3U8DownloaderService._internal();
  factory M3U8DownloaderService() => _instance;

  // Private constructor with initialization
  M3U8DownloaderService._internal() {
    _initNotifications();
  }

  // Class properties
  final Dio _dio = Dio();
  bool _isCancelled = false;
  bool _isPaused = false;
  bool _isActive = false;
  String? _activeDownloadId;
  Map<String, List<int>> _downloadProgress = {};
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Contentclass? _currentContent;
  String? _currentQuality;
  int? _currentEpisode;
  int? _currentSeason;
  Map<String, int> _lastDownloadedSegment = {};
  Map<String, List<String>> _segmentsList = {};

  // Add these properties for speed calculation
  DateTime? _lastUpdateTime;
  int _lastDownloadedBytes = 0;
  double _downloadSpeed = 0;
  int _totalBytes = 0;

  // Add these properties for overall progress
  int _totalSegments = 0;
  int _currentSegment = 0;
  int _totalDownloadedBytes = 0;
  int _estimatedTotalBytes = 0;

  // Add these properties for smoother speed/time calculations
  final Queue<double> _speedSamples = Queue();
  static const int _maxSpeedSamples = 5;
  DateTime? _lastSpeedUpdate;
  Duration? _lastTimeRemaining;

  // Add these properties for better speed tracking
  int _totalBytesDownloaded = 0;
  DateTime? _downloadStartTime;

  // Add these properties for smoother time remaining updates
  static const int _minTimeUpdateInterval = 1000; // milliseconds
  DateTime? _lastTimeUpdate;
  Queue<Duration> _timeRemainingSamples = Queue();
  static const int _maxTimeRemainingSamples = 5;

  // Add these properties for smoother time tracking
  static const int _updateIntervalMs = 500;
  final Queue<_DownloadSnapshot> _snapshots = Queue();
  static const int _maxSnapshots = 10;
  DateTime? _lastProgressUpdate;

  // Add these properties for better speed calculation
  Queue<double> _recentSpeeds = Queue();
  DateTime? _lastSpeedCalculation;
  int _lastBytesDownloaded = 0;
  double _currentSpeed = 0.0;
  Duration _currentTimeRemaining = Duration.zero;

  // Add these new properties for accurate speed/time tracking
  final Queue<int> _bytesPerSecondQueue = Queue();
  static const int _speedSampleSize = 5;
  int _totalExpectedBytes = 0;
  int _previousTotalBytes = 0;

  // Remove duplicate constructor
  // M3U8DownloaderService({
  //   void Function(double)? onProgress,
  //   this.onError,
  // }) : onProgressCallback = onProgress {
  //   _initNotifications();
  // }

  // Add callback setters
  void Function(double)? onProgressCallback;
  void Function(String)? onError;

  void setCallbacks({
    void Function(double)? onProgress,
    void Function(String)? onError,
  }) {
    onProgressCallback = onProgress;
    this.onError = onError;
  }

  Future<void> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        throw 'Notification permission denied';
      }
    }
  }

  Future<void> _initNotifications() async {
    try {
      // Request permission using permission_handler
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        if (!status.isGranted) {
          debugPrint('Notification permission denied');
          return;
        }
      }

      // Initialize notifications with basic settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosSettings = DarwinInitializationSettings();

      await _notifications.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Create notification channels
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'downloads',
            'Downloads',
            description: 'Shows download progress',
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
            showBadge: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'downloads_complete',
            'Completed Downloads',
            description: 'Shows completed downloads',
            importance: Importance.high,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  Future<void> _showProgressNotification(String title, double progress,
      {bool ongoing = true, bool isPaused = false}) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'downloads',
        'Downloads',
        channelDescription: 'Shows download progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: (progress * 100).toInt(),
        ongoing: ongoing && !isPaused,
        autoCancel: !ongoing,
        icon: '@mipmap/launcher_icon',
        enableVibration: false,
        playSound: false,
      );

      await _notifications.show(
        _notificationId,
        'Downloading $title',
        '${(progress * 100).toInt()}% complete',
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
      // Continue without notifications
    }
  }

  Future<void> _showCompleteNotification(String title, String filePath) async {
    // Update progress notification to show completion
    await _showProgressNotification(
      title,
      1.0,
      ongoing: false,
    );

    final androidDetails = AndroidNotificationDetails(
      'downloads_complete',
      'Completed Downloads',
      channelDescription: 'Show download completions',
      importance: Importance.high,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
    );

    await _notifications.show(
      _completionNotificationId, // Use completion ID
      'Download Complete',
      title,
      NotificationDetails(android: androidDetails),
      payload: filePath,
    );
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;

        if (deviceInfo.version.sdkInt >= 30) {
          // Android 11 (API 30) and above
          final status = await Permission.manageExternalStorage.request();
          return status.isGranted;
        } else {
          // Below Android 11
          final status = await Permission.storage.request();
          return status.isGranted;
        }
      } else if (Platform.isIOS) {
        // iOS doesn't require explicit storage permission
        return true;
      }
      return true;
    } catch (e) {
      onError?.call('Permission error: $e');
      return false;
    }
  }

  Future<List<String>> _fetchM3U8(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Connection': 'keep-alive',
          },
          followRedirects: true,
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        if (url.toLowerCase().endsWith('.mp4')) {
          return [url];
        }

        final content = response.data as String;
        if (content.contains('#EXTM3U')) {
          final segments = _parseM3U8(content, url);

          // Better total size estimation
          if (segments.isNotEmpty) {
            try {
              // Sample first few segments for better size estimation
              final sampleSize = segments.length > 3 ? 3 : segments.length;
              int totalSampleSize = 0;

              for (var i = 0; i < sampleSize; i++) {
                final response = await _dio.head(segments[i]);
                totalSampleSize +=
                    int.parse(response.headers.value('content-length') ?? '0');
              }

              // Calculate average segment size and estimate total
              final averageSegmentSize = totalSampleSize / sampleSize;
              _totalExpectedBytes =
                  (averageSegmentSize * segments.length).round();
              _estimatedTotalBytes = _totalExpectedBytes;
              _totalSegments = segments.length;
            } catch (e) {
              debugPrint('Error estimating total size: $e');
            }
          }
          return segments;
        }
      }
      throw 'Invalid M3U8 response: ${response.statusCode}';
    } catch (e) {
      debugPrint('M3U8 fetch error: $e');
      onError?.call('Failed to fetch M3U8: $e');
      rethrow;
    }
  }

  List<String> _parseM3U8(String content, String baseUrl) {
    final lines = content.split('\n');
    final List<String> segments = [];
    final baseUri = Uri.parse(baseUrl);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Handle different segment formats
      if (line.endsWith('.ts') ||
          line.endsWith('.html') ||
          line.endsWith('.jpg') ||
          line.endsWith('.png') ||
          line.endsWith('.js') ||
          line.endsWith('.css') ||
          line.endsWith('.webp') ||
          line.endsWith("ico") ||
          line.endsWith('.mp4') ||
          line.startsWith('https') ||
          line.startsWith('http') ||
          line.contains('.ts?') ||
          line.contains('.mp4?')) {
        if (line.startsWith('http') || line.startsWith('https')) {
          segments.add(line);
        } else {
          // Handle relative URLs
          final uri = Uri.parse(line);
          final absoluteUrl = baseUri.resolve(uri.path).toString();
          segments.add(absoluteUrl);
        }
      }
    }
    return segments;
  }

  // Add new method to get temp directory path
  Future<String> _getTempPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory('${appDir.path}/temp_downloads');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir.path;
  }

  Future<void> _downloadSegment(String url, String savePath,
      {int retries = 3}) async {
    if (_isCancelled) return;

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final tempPath = await _getTempPath();
        final segmentFile = File('$tempPath/${savePath.split('/').last}');

        final parent = segmentFile.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }

        int receivedBytes = 0;
        final startTime = DateTime.now();

        // Initialize download start time if first segment
        if (_currentSegment == 0) {
          _downloadStartTime = DateTime.now();
          _totalBytesDownloaded = 0;
        }

        // Initialize download tracking on first segment
        if (_currentSegment == 0) {
          _downloadStartTime = DateTime.now();
          _previousTotalBytes = 0;
          _bytesPerSecondQueue.clear();
        }

        final response = await _dio.get(
          url,
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0',
              'Connection': 'keep-alive',
            },
            followRedirects: true,
            validateStatus: (status) => status! < 500,
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
          onReceiveProgress: (received, total) {
            if (_isCancelled || _isPaused) return;

            final now = DateTime.now();

            // Initialize if first update
            if (_lastSpeedUpdate == null) {
              _lastSpeedUpdate = now;
              _previousTotalBytes = _totalBytesDownloaded;
              _downloadStartTime ??= now;
            }

            // Update total bytes downloaded
            final newBytes = received - (_lastBytesDownloaded ?? 0);
            if (newBytes >= 0) {
              // Only update if we have positive progress
              _totalBytesDownloaded += newBytes;
            }
            _lastBytesDownloaded = received;

            // Calculate overall progress
            final overallProgress = _totalSegments > 0
                ? ((_currentSegment + (received / total)) / _totalSegments)
                : 0.0;

            // Update speed and time every 500ms
            if (now.difference(_lastSpeedUpdate!).inMilliseconds >= 500) {
              final duration = now.difference(_lastSpeedUpdate!).inSeconds;

              if (duration > 0) {
                // Calculate speed in MB/s
                final bytesPerSecond =
                    (_totalBytesDownloaded - _previousTotalBytes) / duration;
                _currentSpeed = Math.max(
                    0, bytesPerSecond / (1024 * 1024)); // Ensure positive speed

                // Calculate time remaining based on total expected size
                if (_totalExpectedBytes > 0 && _currentSpeed > 0) {
                  final remainingBytes =
                      _totalExpectedBytes - _totalBytesDownloaded;
                  if (remainingBytes > 0) {
                    final timeRemainingSeconds =
                        remainingBytes / (bytesPerSecond);
                    _currentTimeRemaining =
                        Duration(seconds: timeRemainingSeconds.round());
                  }
                }

                _previousTotalBytes = _totalBytesDownloaded;
                _lastSpeedUpdate = now;
              }

              // Update progress in UI
              if (_currentContent != null) {
                DownloadsProvider.instance.updateProgress(
                  _currentContent!.id,
                  overallProgress.clamp(
                      0.0, 1.0), // Ensure progress is between 0 and 1
                  'downloading',
                  _currentContent!.title,
                  _currentContent!.poster,
                  _currentQuality ?? '',
                  isPaused: false,
                  speed: _currentSpeed,
                  timeRemaining: _currentTimeRemaining,
                );

                _showProgressNotification(
                  _currentContent!.title,
                  overallProgress.clamp(0.0, 1.0),
                  isPaused: false,
                );
              }
            }
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          await segmentFile.writeAsBytes(response.data);

          if (await segmentFile.exists() && await segmentFile.length() > 0) {
            _currentSegment++;
            return;
          }
          throw 'Invalid segment file';
        }
        throw 'Invalid response: ${response.statusCode}';
      } catch (e) {
        debugPrint('Download attempt ${attempt + 1} failed: $e');
        if (attempt == retries - 1) {
          throw 'Failed to download segment after $retries attempts: $e';
        }
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
  }

  Future<String> getDownloadPath(String filename, String title) async {
    try {
      // Using await here to resolve the future before continuing
      final basePath = await SettingsService.instance.downloadPath;
      final directory = Directory(basePath);

      // Create directories recursively with proper permissions
      if (!await directory.exists()) {
        await directory.create(recursive: true);

        // Set directory permissions
        if (Platform.isAndroid) {
          try {
            await Process.run('chmod', ['777', directory.path]);
          } catch (e) {
            debugPrint('Error setting directory permissions: $e');
          }
        }
      }

      // Ensure the path exists and is writable
      if (!await directory.exists()) {
        throw 'Failed to create download directory';
      }

      final filePath = '${directory.path}/$filename';
      return filePath;
    } catch (e) {
      throw 'Failed to create download path: $e';
    }
  }

  Future<bool> _checkAndRequestPermissions(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        bool hasPermission = false;

        if (deviceInfo.version.sdkInt >= 30) {
          // Android 11+ needs MANAGE_EXTERNAL_STORAGE
          hasPermission = await Permission.manageExternalStorage.isGranted;
          if (!hasPermission) {
            // Show explanation dialog
            final shouldRequest = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Storage Permission Required'),
                    content: const Text(
                      'MovieDex needs storage access to download and save videos. '
                      'Please grant storage permission in the next screen.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (shouldRequest) {
              hasPermission =
                  await Permission.manageExternalStorage.request().isGranted;
            }
          }
        } else {
          // Below Android 11 needs WRITE_EXTERNAL_STORAGE
          hasPermission = await Permission.storage.isGranted;
          if (!hasPermission) {
            final status = await Permission.storage.request();
            hasPermission = status.isGranted;
          }
        }

        // Check notification permission
        final notificationStatus = await Permission.notification.status;
        if (!notificationStatus.isGranted) {
          await Permission.notification.request();
        }

        return hasPermission;
      }
      return true; // iOS or other platforms
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  Future<String> startDownload(
    BuildContext context, // Add context parameter
    String m3u8Url,
    String title,
    Contentclass content,
    String quality, {
    int? episodeNumber,
    int? seasonNumber,
  }) async {
    debugPrint('Starting download: $title, URL: $m3u8Url');

    if (_isActive) {
      debugPrint('Download already in progress');
      throw 'A download is already in progress';
    }

    try {
      // Check if download path exists and is writable
      final basePath = await SettingsService.instance.downloadPath;
      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      // Verify content data
      if (content.title.isEmpty) {
        throw 'Invalid content data';
      }

      // Initialize managers
      await DownloadsManager.instance.ensureInitialized();
      await SettingsService.instance.init();

      // Check permissions first
      final hasPermissions = await _checkAndRequestPermissions(context);
      if (!hasPermissions) {
        throw 'Storage permission required to download content';
      }

      _isActive = true;
      _isCancelled = false;
      _isPaused = false;
      _currentContent = content;
      _currentQuality = quality;
      _currentEpisode = episodeNumber;
      _currentSeason = seasonNumber;
      _activeDownloadId =
          '${content.id}_${DateTime.now().millisecondsSinceEpoch}';

      // Create download paths
      final fileName =
          '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}_${quality}.mp4';
      final downloadPath = await getDownloadPath(fileName, title);
      final downloadDir = Directory(downloadPath).parent;

      debugPrint('Download path: $downloadPath');

      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Update initial state
      DownloadsProvider.instance.updateProgress(
        content.id,
        0.0,
        'downloading',
        content.title,
        content.poster,
        quality,
        isPaused: false,
      );

      // Show initial notification
      await _showProgressNotification(title, 0.0);

      // Fetch M3U8 segments
      debugPrint('Fetching M3U8 playlist');
      final downloadId =
          '${content.id}_${episodeNumber ?? 0}_${seasonNumber ?? 0}';

      // Get segments list if not already fetched
      if (!_segmentsList.containsKey(downloadId)) {
        _segmentsList[downloadId] = await _fetchM3U8(m3u8Url);
      }
      final segments = _segmentsList[downloadId]!;

      // Get last downloaded segment index
      final startIndex = _lastDownloadedSegment[downloadId] ?? 0;
      final totalSegments = segments.length;

      // Reset counters
      _currentSegment = 0;
      _totalDownloadedBytes = 0;
      _estimatedTotalBytes = 0;
      _totalSegments = segments.length;

      // Reset download tracking
      _downloadStartTime = null;
      _totalBytesDownloaded = 0;
      _downloadSpeed = 0;
      _speedSamples.clear();
      _timeRemainingSamples.clear();
      _lastTimeUpdate = null;

      // Initialize _downloadStartTime at the start of download
      _downloadStartTime = DateTime.now();

      for (var i = startIndex; i < totalSegments; i++) {
        if (_isCancelled) {
          // Save last downloaded segment index
          _lastDownloadedSegment[downloadId] = i;
          DownloadsProvider.instance.pauseDownload(content.id);
          throw 'Download paused';
        }

        while (_isPaused) {
          _lastDownloadedSegment[downloadId] = i;
          await Future.delayed(const Duration(milliseconds: 500));
          if (_isCancelled) throw 'Download cancelled';
        }

        final segment = segments[i];
        final segmentPath = '${downloadDir.path}/segment_$i.ts';

        try {
          await _downloadSegment(segment, segmentPath);
          _lastDownloadedSegment[downloadId] = i + 1;
        } catch (e) {
          // On error, save progress and rethrow
          _lastDownloadedSegment[downloadId] = i;
          DownloadsProvider.instance.pauseDownload(content.id);
          rethrow;
        }

        // Update progress
        final progress = (i + 1) / totalSegments;
        _updateProgress(content, progress);
      }

      // Combine segments
      debugPrint('Combining segments');
      final outputPath = '${downloadDir.path}/$fileName';
      await _combineSegments(downloadDir.path, outputPath, totalSegments);

      if (!await File(outputPath).exists()) {
        debugPrint('Failed to create output file');
        throw 'Failed to create output file';
      }

      // Add to downloads
      await DownloadsManager.instance.addDownload(
        content,
        outputPath,
        quality,
        episodeNumber: episodeNumber,
        seasonNumber: seasonNumber,
      );

      // Show completion
      await _showCompleteNotification(title, outputPath);

      DownloadsProvider.instance.updateProgress(
        content.id,
        1.0,
        'completed',
        content.title,
        content.poster,
        quality,
      );

      DownloadsProvider.instance.removeDownload(content.id);

      debugPrint('Download completed successfully');

      _isActive = false;
      _activeDownloadId = null;
      return outputPath;
    } catch (e, stack) {
      debugPrint('Download error: $e');
      debugPrint('Stack trace: $stack');

      _isActive = false;
      _activeDownloadId = null;
      _handleDownloadError(_currentContent!, quality, title, e);

      rethrow;
    } finally {
      if (_isCancelled) {
        await _notifications.cancel(_notificationId);
      }
      // Cleanup temp files
      _cleanupOnError();
    }
  }

  void _handleDownloadError(
      Contentclass content, String quality, String title, dynamic error) {
    try {
      // Show error notification
      _notifications.show(
        _errorNotificationId,
        'Download Failed',
        'Error downloading $title: $error',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'downloads_error',
            'Download Errors',
            channelDescription: 'Show download errors',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );

      // Update provider state
      DownloadsProvider.instance.updateProgress(
        content.id,
        0.0,
        'error',
        content.title,
        content.poster,
        quality,
      );
      DownloadsProvider.instance.removeDownload(content.id);

      // Notify error callback
      onError?.call('Download failed: $error');
    } catch (e) {
      debugPrint('Error handling download error: $e');
    }
  }

  Future<void> _combineSegments(
      String dirPath, String outputPath, int count) async {
    try {
      final tempPath = await _getTempPath();
      final tempOutput = File('$tempPath/temp_output.mp4');

      if (await tempOutput.exists()) {
        await tempOutput.delete();
      }

      final sink = await tempOutput.open(mode: FileMode.writeOnly);
      var combinedCount = 0;

      if (_currentContent != null) {
        DownloadsProvider.instance.updateProgress(
          _currentContent!.id,
          0.99,
          'merging',
          _currentContent!.title,
          _currentContent!.poster,
          _currentQuality ?? '',
        );
      }

      for (var i = 0; i < count; i++) {
        if (_isCancelled) {
          await sink.close();
          await tempOutput.delete();
          return;
        }

        final segment = File('$tempPath/segment_$i.ts');
        if (await segment.exists()) {
          try {
            final bytes = await segment.readAsBytes();
            await sink.writeFrom(bytes);
            await sink.flush();
            await segment.delete();
            combinedCount++;
          } catch (e) {
            debugPrint('Error processing segment $i: $e');
          }
        }
      }

      await sink.flush();
      await sink.close();

      if (combinedCount != count ||
          !await tempOutput.exists() ||
          (await tempOutput.length()) == 0) {
        throw 'Failed to merge all segments';
      }

      // Move final file to download path
      final finalOutput = File(outputPath);
      if (await finalOutput.exists()) {
        await finalOutput.delete();
      }

      final downloadDir = finalOutput.parent;
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      await tempOutput.copy(outputPath);
      await tempOutput.delete();

      // Clean up temp directory
      await _cleanupTempDir();
    } catch (e) {
      debugPrint('Merge error: $e');
      onError?.call('Failed to merge segments: $e');
      rethrow;
    }
  }

  Future<void> _cleanupSegments(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final files =
            await dir.list().where((f) => f.path.endsWith('.ts')).toList();
        for (var file in files) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  Future<void> _cleanupOnError() async {
    try {
      if (_currentContent != null) {
        // Get the download path asynchronously
        final basePath = await SettingsService.instance.downloadPath;
        final dir = Directory('$basePath/${_currentContent!.title}');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  Future<void> _cleanupTempDir() async {
    try {
      final tempPath = await _getTempPath();
      final tempDir = Directory(tempPath);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  Future<void> _cleanupDownload() async {
    try {
      // Clean temp directory
      final tempPath = await _getTempPath();
      final tempDir = Directory(tempPath);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }

      // Clean partial downloads if any
      if (_currentContent != null) {
        // Get the download path correctly with await
        final basePath = await SettingsService.instance.downloadPath;
        final downloadPath =
            '$basePath/${_currentContent!.title}_${_currentQuality ?? ""}';
        final downloadDir = Directory(downloadPath).parent;
        if (await downloadDir.exists()) {
          await downloadDir.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  void cancelDownload() {
    if (!_isActive) return;

    _isCancelled = true;
    _isPaused = false;
    _isActive = false;

    // Cancel all ongoing operations
    _recentSpeeds.clear();
    _currentSpeed = 0;
    _currentTimeRemaining = Duration.zero;

    // Cancel notifications
    _notifications.cancel(_notificationId);
    _notifications.cancel(_completionNotificationId);
    _notifications.cancel(_errorNotificationId);

    // Clean up downloaded segments and files
    _cleanupDownload();

    // Update provider state and remove from active downloads
    if (_currentContent != null) {
      final contentId = _currentContent!.id;

      // Remove from active downloads
      DownloadsProvider.instance.removeDownload(contentId);

      // Remove from Hive storage if exists
      DownloadsManager.instance.removeDownload(contentId);

      // Reset content reference
      _currentContent = null;
    }

    // Reset all trackers
    _lastDownloadedSegment.clear();
    _segmentsList.clear();
    _currentEpisode = null;
    _currentSeason = null;
    _currentQuality = null;
    _speedSamples.clear();
    _lastUpdateTime = null;
    _lastSpeedUpdate = null;
    _lastTimeRemaining = null;
    _activeDownloadId = null;

    // Clean temp files
    _cleanupTempDir();
  }

  void pauseDownload() {
    if (!_isActive || _isCancelled) return;

    _isPaused = true;

    // Save current download state
    if (_currentContent != null) {
      final progress = _totalSegments > 0
          ? (_currentSegment / _totalSegments).clamp(0.0, 1.0)
          : 0.0;

      DownloadsProvider.instance.updateProgress(
        _currentContent!.id,
        progress,
        'paused',
        _currentContent!.title,
        _currentContent!.poster,
        _currentQuality ?? '',
        isPaused: true,
        speed: 0,
        timeRemaining: _currentTimeRemaining,
      );
    }

    // Save download state for resume
    if (_currentContent != null) {
      final downloadId =
          '${_currentContent!.id}_${_currentEpisode ?? 0}_${_currentSeason ?? 0}';
      _lastDownloadedSegment[downloadId] = _currentSegment;
    }
  }

  Future<void> resumeDownload() async {
    if (!_isActive || _isCancelled || _currentContent == null) return;

    _isPaused = false;

    // Notify provider about resume
    DownloadsProvider.instance.resumeDownload(_currentContent!.id);

    try {
      // Restart download from last saved segment
      if (_lastContext != null && _lastUrl != null) {
        await startDownload(
          _lastContext!,
          _lastUrl!,
          _currentContent!.title,
          _currentContent!,
          _currentQuality ?? 'Auto',
          episodeNumber: _currentEpisode,
          seasonNumber: _currentSeason,
        );
      }
    } catch (e) {
      debugPrint('Resume error: $e');
      // Handle resume error by canceling the download
      cancelDownload();
    }
  }

  void _updateProgress(Contentclass content, double progress) {
    onProgressCallback?.call(progress);

    // Keep existing speed and time when updating progress
    final currentProgress =
        DownloadsProvider.instance.getDownloadProgress(content.id);

    DownloadsProvider.instance.updateProgress(
      content.id,
      progress,
      'downloading',
      content.title,
      content.poster,
      _currentQuality ?? '',
      isPaused: _isPaused,
      speed: currentProgress?.speed ?? _downloadSpeed,
      timeRemaining: currentProgress?.timeRemaining,
    );

    _showProgressNotification(
      content.title,
      progress,
      isPaused: _isPaused,
    );
  }

  // Add these properties to store last download state
  BuildContext? _lastContext;
  String? _lastUrl;

  // Change return type to match startDownload
  Future<String> initialDownload(
    BuildContext context,
    String url,
    String title,
    Contentclass content,
    String quality, {
    int? episodeNumber,
    int? seasonNumber,
  }) async {
    _lastContext = context;
    _lastUrl = url;
    return startDownload(
      context,
      url,
      title,
      content,
      quality,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber,
    );
  }

  void dispose() {
    _cleanupTempDir();
  }

  void _updateDownloadProgress() {
    if (_currentContent == null || _isPaused || _isCancelled) return;

    // Ensure _downloadStartTime is initialized
    _downloadStartTime ??= DateTime.now();

    final now = DateTime.now();

    // Calculate speed using non-null _downloadStartTime
    if (now.difference(_downloadStartTime!).inMilliseconds >= 500) {
      // ...existing speed calculation code...
    }

    // Calculate progress
    final progress = _totalSegments > 0
        ? (_currentSegment / _totalSegments).clamp(0.0, 1.0)
        : 0.0;

    // Ensure we have valid values
    final speed =
        _currentSpeed.isNaN || _currentSpeed < 0 ? 0.01 : _currentSpeed;
    final timeRemaining = _currentTimeRemaining.inSeconds < 0
        ? Duration.zero
        : _currentTimeRemaining;

    DownloadsProvider.instance.updateProgress(
      _currentContent!.id,
      progress,
      'downloading',
      _currentContent!.title,
      _currentContent!.poster,
      _currentQuality ?? '',
      isPaused: false,
      speed: speed,
      timeRemaining: timeRemaining,
    );

    _showProgressNotification(
      _currentContent!.title,
      progress,
      isPaused: false,
    );
  }
}
