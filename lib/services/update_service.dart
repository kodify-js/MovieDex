import 'dart:io';
import 'package:flutter/material.dart';
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
    await _notifications.initialize(initSettings);
  }

  Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      final response = await http.get(Uri.parse(_githubApiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'].toString().replaceAll('v', '').split("-")[0];
        
        if (_isNewerVersion(currentVersion, latestVersion)) {
          return {
            'version': latestVersion,
            'description': data['body'],
            'downloadUrl': data['assets'][0]['browser_download_url'],
          };
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    
    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<void> downloadAndInstallUpdate(String url, String version) async {
    try {
      // Show download starting notification
      await _showNotification(
        'Downloading Update',
        'MovieDex v$version is being downloaded...',
      );

      // Download the APK
      final response = await http.get(Uri.parse(url));
      final appDir = await getExternalStorageDirectory();
      final file = File('${appDir!.path}/MovieDex_$version.apk');
      await file.writeAsBytes(response.bodyBytes);

      // Show installation notification
      await _showNotification(
        'Update Ready',
        'Tap to install MovieDex v$version',
        payload: file.path,
      );

      // Open the APK file using url_launcher
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $uri';
      }
    } catch (e) {
      debugPrint('Error downloading update: $e');
      await _showNotification(
        'Update Failed',
        'Failed to download the update. Please try again.',
      );
    }
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
