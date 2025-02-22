import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:moviedex/utils/error_handlers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/models/downloads_manager.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/services/settings_service.dart';

class M3U8DownloaderService {
  static const int _baseNotificationId = 1000;
  static const int _notificationId = _baseNotificationId;
  static const int _completionNotificationId = _baseNotificationId + 1;
  static const int _errorNotificationId = _baseNotificationId + 2;

  static final M3U8DownloaderService _instance = M3U8DownloaderService._internal();
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
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Contentclass? _currentContent;
  String? _currentQuality;
  int? _currentEpisode;
  int? _currentSeason;
  Map<String, int> _lastDownloadedSegment = {};
  Map<String, List<String>> _segmentsList = {};

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
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosSettings = DarwinInitializationSettings();
      
      await _notifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Create notification channels
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
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

  Future<void> _showProgressNotification(String title, double progress, {bool ongoing = true, bool isPaused = false}) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'downloads', 'Downloads',
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
          return _parseM3U8(content, url);
        }
      }
      throw 'Invalid M3U8 response: ${response.statusCode}';
    } catch (e) {
      debugPrint('M3U8 fetch error: $e');
      onError?.call('Failed to fetch M3U8: $e');
      rethrow;
    }
  }

  String? _parseMasterPlaylist(String content, String baseUrl) {
    final lines = content.split('\n');
    String? highestQualityUrl;
    int maxBandwidth = 0;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('#EXT-X-STREAM-INF')) {
        // Parse bandwidth
        final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i]);
        if (bandwidthMatch != null) {
          final bandwidth = int.parse(bandwidthMatch.group(1)!);
          if (bandwidth > maxBandwidth && i + 1 < lines.length) {
            maxBandwidth = bandwidth;
            var streamUrl = lines[i + 1].trim();
            if (!streamUrl.startsWith('http')) {
              // Convert relative URL to absolute
              final uri = Uri.parse(baseUrl);
              final baseUri = uri.replace(path: uri.path.substring(0, uri.path.lastIndexOf('/')));
              streamUrl = baseUri.resolve(streamUrl).toString();
            }
            highestQualityUrl = streamUrl;
          }
        }
      }
    }
    return highestQualityUrl;
  }

  List<String> _parseM3U8(String content, String baseUrl) {
    final lines = content.split('\n');
    final List<String> segments = [];
    final baseUri = Uri.parse(baseUrl);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Handle different segment formats
      if (line.endsWith('.ts') || 
          line.endsWith('.mp4') ||
          line.startsWith('https')||
          line.startsWith('http')|| 
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

  Future<void> _downloadSegment(String url, String savePath, {int retries = 3}) async {
    if (_isCancelled) return;

    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final segmentFile = File(savePath);
        final parent = segmentFile.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
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
        );

        if (response.statusCode == 200 && response.data != null) {
          await segmentFile.writeAsBytes(response.data);
          
          if (await segmentFile.exists() && await segmentFile.length() > 0) {
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
      // Sanitize title to remove special characters
      final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '')
                               .replaceAll(RegExp(r'\s+'), '_');
      
      final basePath = '${SettingsService.instance.downloadPath}/$sanitizedTitle';
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
            ) ?? false;

            if (shouldRequest) {
              hasPermission = await Permission.manageExternalStorage.request().isGranted;
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
    BuildContext context,  // Add context parameter
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
      final baseDir = Directory(SettingsService.instance.downloadPath);
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
      _activeDownloadId = '${content.id}_${DateTime.now().millisecondsSinceEpoch}';

      // Create download paths
      final fileName = '${title.replaceAll(RegExp(r'[^\w\s-]'), '')}_${quality}.mp4';
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
      final downloadId = '${content.id}_${episodeNumber ?? 0}_${seasonNumber ?? 0}';
      
      // Get segments list if not already fetched
      if (!_segmentsList.containsKey(downloadId)) {
        _segmentsList[downloadId] = await _fetchM3U8(m3u8Url);
      }
      final segments = _segmentsList[downloadId]!;

      // Get last downloaded segment index
      final startIndex = _lastDownloadedSegment[downloadId] ?? 0;
      final totalSegments = segments.length;

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

  void _handleDownloadError(Contentclass content, String quality, String title, dynamic error) {
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

  Future<void> _combineSegments(String dirPath, String outputPath, int count) async {
    try {
      final output = File(outputPath);
      if (await output.exists()) {
        await output.delete();
      }
      
      final sink = await output.open(mode: FileMode.writeOnly);
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
          if (await output.exists()) {
            await output.delete();
          }
          return;
        }

        final segment = File('$dirPath/segment_$i.ts');
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
      
      if (combinedCount != count || !await output.exists() || (await output.length()) == 0) {
        throw 'Failed to merge all segments';
      }

      await _cleanupSegments(dirPath);

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
        final files = await dir.list().where((f) => f.path.endsWith('.ts')).toList();
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
        final dir = Directory('${SettingsService.instance.downloadPath}/${_currentContent!.title}');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
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

    // Cancel all related notifications
    _notifications.cancel(_notificationId);
    _notifications.cancel(_completionNotificationId);
    _notifications.cancel(_errorNotificationId);

    // Update provider state
    if (_currentContent != null) {
      _activeDownloadId = null;
      DownloadsProvider.instance.removeDownload(_currentContent!.id);
      _currentContent = null;
    }
  }

  void pauseDownload() {
    if (!_isActive || _isCancelled) return;
    
    _isPaused = true;
    if (_currentContent != null && _activeDownloadId != null) {
      DownloadsProvider.instance.pauseDownload(_currentContent!.id);
      _showProgressNotification(
        _currentContent!.title,
        DownloadsProvider.instance.getDownloadProgress(_currentContent!.id)?.progress ?? 0.0,
        isPaused: true
      );
    }
  }

  Future<void> resumeDownload() async {
    if (!_isActive || _isCancelled || _currentContent == null) return;
    
    _isPaused = false;
    if (_currentContent != null) {
      DownloadsProvider.instance.resumeDownload(_currentContent!.id);
      
      // Restart download from last segment
      try {
        await startDownload(
          _lastContext!,
          _lastUrl!,
          _currentContent!.title,
          _currentContent!,
          _currentQuality ?? 'Auto',
          episodeNumber: _currentEpisode,
          seasonNumber: _currentSeason,
        );
      } catch (e) {
        debugPrint('Resume error: $e');
      }
    }
  }

  void _updateProgress(Contentclass content, double progress) {
    onProgressCallback?.call(progress);
    
    DownloadsProvider.instance.updateProgress(
      content.id,
      progress,
      'downloading',
      content.title,
      content.poster,
      _currentQuality ?? '',
      isPaused: _isPaused,
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
      context, url, title, content, quality,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber,
    );
  }
}
