import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Add this import
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  static UpdateService get instance => _instance;
  
  final String _githubApiUrl = 'https://api.github.com/repos/kodify-js/MovieDex/releases/latest';
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  UpdateService._internal();
  
  Future<void> initialize() async {
    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
        if (details.payload != null) {
          final result = await OpenFilex.open(details.payload!);
          if (result.type != ResultType.done) {
            debugPrint('Could not open APK file');
          }
        }
      },
    );
  }
  
  Future<Map<String, dynamic>?> checkForUpdates() async {
    print("object");
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('Current version: $currentVersion');
      
      final response = await http.get(Uri.parse(_githubApiUrl));
      debugPrint('GitHub API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'].toString().replaceAll('v', '').split("-")[0];
        debugPrint('Latest version: $latestVersion');
        
        if (_isNewerVersion(currentVersion, latestVersion)) {
          debugPrint('Update available!');
          return {
            'version': latestVersion,
            'description': data['body'],
            'downloadUrl': data['assets'][0]['browser_download_url'],
          };
        }else{
        return null;
      }
      }else{
        return null;
      }
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    print(currentParts);
    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<void> downloadAndInstallUpdate(String downloadUrl, String version) async {
    try {
      // Download update
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download update');
      }

      // Get temporary directory to save the update
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/update.apk');
      await file.writeAsBytes(response.bodyBytes);

      // Install the update
      if (Platform.isAndroid) {
        await _installAndroidUpdate(file.path);
      } else if (Platform.isIOS) {
        await _installIOSUpdate(file.path);
      }
    } catch (e) {
      debugPrint('Update installation failed: $e');
      rethrow;
    }
  }

  Future<void> _installAndroidUpdate(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
        uti: 'public.android-package-archive',
      );
      
      if (result.type != ResultType.done) {
        throw Exception('Failed to open installation file');
      }
    } catch (e) {
      debugPrint('Android installation failed: $e');
      throw Exception('Installation failed: $e');
    }
  }

  Future<void> _installIOSUpdate(String filePath) async {
    // iOS updates are handled through the App Store
    throw UnimplementedError('iOS updates are handled through the App Store');
  }

  Future<void> _showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'updates',
      'App Updates',
      channelDescription: 'Notifications for app updates',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const details = NotificationDetails(android: androidDetails);
    
    await _notifications.show(
      0,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
