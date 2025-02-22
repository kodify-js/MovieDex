import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';

class BackgroundDownloadService {
  static final BackgroundDownloadService _instance = BackgroundDownloadService._internal();
  static BackgroundDownloadService get instance => _instance;
  
  static const int notificationId = 888;
  static const String channelId = 'downloads';
  static const String channelName = 'Downloads';
  
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  BackgroundDownloadService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize notifications first
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidSettings);
      
      bool? success = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      if (success != true) {
        debugPrint('Notification initialization failed');
        return;
      }

      // Create notification channel
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
          
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            importance: Importance.low,
            enableVibration: false,
            playSound: false,
          ),
        );
      }

      // Configure background service
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: channelId,
          initialNotificationTitle: 'Downloads Service',
          initialNotificationContent: 'Preparing download...',
          foregroundServiceNotificationId: notificationId,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Background service init error: $e');
      _isInitialized = false;
    }
  }

  Future<bool> start() async {
    if (!_isInitialized) {
      await init();
    }
    return await _service.startService();
  }

  Future<void> stop() async {
    if (!await isRunning()) return;
    
    // Call invoke without awaiting since it returns void
    _service.invoke("stopService");
    
    // Wait for service to actually stop
    final maxWaitTime = Duration(seconds: 5);
    final startTime = DateTime.now();
    
    while (await _service.isRunning()) {
      if (DateTime.now().difference(startTime) > maxWaitTime) {
        debugPrint('Service stop timeout');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  Future<void> _downloadSegment(String url, String savePath) async {
    if (!await isRunning()) {
      await start();
    }
    // ...rest of method...
  }

  Future<void> _combineSegments(String dirPath, String outputPath, int count) async {
    if (!await isRunning()) {
      await start();
    }
    // ...rest of method...
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  final dio = Dio();
  final notifications = FlutterLocalNotificationsPlugin();

  service.on('downloadSegment').listen((event) async {
    if (event == null) return;
    
    try {
      final url = event['url'] as String;
      final savePath = event['savePath'] as String;
      final retries = event['retries'] as int;

      // Download logic
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.data);
      }
    } catch (e) {
      service.invoke('downloadError', {'error': e.toString()});
    }
  });

  service.on('combineSegments').listen((event) async {
    if (event == null) return;
    
    try {
      final dirPath = event['dirPath'] as String;
      final outputPath = event['outputPath'] as String;
      final count = event['count'] as int;

      final output = await File(outputPath).open(mode: FileMode.writeOnly);
      
      for (var i = 0; i < count; i++) {
        final segment = File('$dirPath/segment_$i.ts');
        if (await segment.exists()) {
          final bytes = await segment.readAsBytes();
          await output.writeFrom(bytes);
          await segment.delete();
        }
      }
      
      await output.close();
    } catch (e) {
      service.invoke('combineError', {'error': e.toString()});
    }
  });

  service.on('stopService').listen((event) async {
    await service.stopSelf();
  });
}
