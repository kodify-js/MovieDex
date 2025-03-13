import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  static UpdateService get instance => _instance;
  bool _isInitialized = false;
  
  UpdateService._();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if settings exist and create if needed
      final settingsBox = await Hive.openBox('settings');
      if (!settingsBox.containsKey('showUpdateDialog')) {
        await settingsBox.put('showUpdateDialog', true);
      }
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing update service: $e');
    }
  }

  final String _owner = 'kodify-js';
  final String _repo = 'MovieDex';
  
  Future<Map<String, dynamic>?> getLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching latest release: $e');
    }
    return null;
  }

  Future<bool> checkForUpdate() async {
    try {
      final currentVersion = (await PackageInfo.fromPlatform()).version;
      final latestRelease = await getLatestRelease();
      
      if (latestRelease == null) return false;
      
      final latestVersion = latestRelease['tag_name'].toString().replaceAll('v', '').split('-').first;
      // Compare versions
      final current = currentVersion.split('.').map(int.parse).toList();
      final latest = latestVersion.split('.').map(int.parse).toList();
      
      for (var i = 0; i < 3; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      
      return false;
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }

  Future<void> launchUpdate() async {
    final latestRelease = await getLatestRelease();
    if (latestRelease == null) return;

    final url = latestRelease['html_url'];
    if (url == null) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> downloadAndInstallUpdate(String downloadUrl, String version) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/MovieDex_$version.apk');

      // Download the file
      final response = await http.get(Uri.parse(downloadUrl));
      await file.writeAsBytes(response.bodyBytes);

      // Open the APK file
      await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
        uti: 'public.apk-archive',
      );
    } catch (e) {
      debugPrint('Error downloading update: $e');
      rethrow;
    }
  }
}