/**
 * MovieDex Settings Service
 * 
 * Centralized settings management for MovieDex application.
 * Handles user preferences and application configuration:
 * - Incognito mode management
 * - Data sync preferences
 * - Local storage persistence
 * - Settings state broadcasting
 * - Cross-component settings sync
 * 
 * Copyright (c) 2024 MovieDex Contributors
 * Licensed under MIT License
 */

import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'dart:io' show Directory, Platform;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:flutter/foundation.dart';

/// Manages application-wide settings and preferences
class SettingsService {
  static SettingsService? _instance;
  late Box _settingsBox;
  bool _isInitialized = false;
  static const String _downloadPathKey = 'downloadPath';

  /// Broadcasts incognito mode state changes
  final _incognitoController = StreamController<bool>.broadcast();

  /// Stream of incognito mode state changes
  Stream<bool> get incognitoStream => _incognitoController.stream;

  /// Broadcasts settings changes
  final _settingsController = StreamController<void>.broadcast();

  /// Stream of settings changes
  Stream<void> get settingsStream => _settingsController.stream;

  /// Singleton instance accessor
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  SettingsService._();

  /// Initialize settings storage and broadcast initial state
  Future<void> init() async {
    if (!_isInitialized) {
      _settingsBox = await Hive.openBox('settings');
      _isInitialized = true;
      _incognitoController.add(isIncognito);

      // Initialize default values if not set
      if (!_settingsBox.containsKey('showUpdateDialog')) {
        await _settingsBox.put('showUpdateDialog', false);
      }

      // Set default download path if not already set
      if (!_settingsBox.containsKey(_downloadPathKey)) {
        final defaultPath = await _getDefaultDownloadPath();
        await _settingsBox.put(_downloadPathKey, defaultPath);
      }
    }
  }

  /// Get default download path based on platform
  Future<String> _getDefaultDownloadPath() async {
    try {
      if (Platform.isAndroid) {
        return '/storage/emulated/0/Download/MovieDex';
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        return '${directory.path}/Downloads';
      } else if (Platform.isWindows) {
        final directory = await getDownloadsDirectory();
        return '${directory?.path ?? ''}/MovieDex';
      } else if (Platform.isMacOS) {
        final directory = await getDownloadsDirectory();
        return '${directory?.path ?? ''}/MovieDex';
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        return '$home/Downloads/MovieDex';
      } else {
        // Fallback for other platforms
        final directory = await getApplicationDocumentsDirectory();
        return '${directory.path}/MovieDex';
      }
    } catch (e) {
      debugPrint('Error getting default download path: $e');
      return '/Downloads/MovieDex';
    }
  }

  /// Current incognito mode state
  bool get isIncognito =>
      _settingsBox.get('incognitoMode', defaultValue: false);

  /// Current sync enabled state
  bool get isSyncEnabled => _settingsBox.get('syncEnabled', defaultValue: true);

  /// Last sync state before incognito mode
  bool? get lastSyncState => _settingsBox.get('lastSyncState');

  /// Set incognito mode and handle related settings
  Future<void> setIncognitoMode(bool value) async {
    await _ensureInitialized();

    if (value) {
      await _settingsBox.put('lastSyncState', isSyncEnabled);
      await _settingsBox.put('syncEnabled', false);
    } else {
      final previousState = lastSyncState ?? true;
      await _settingsBox.put('syncEnabled', previousState);
    }

    await _settingsBox.put('incognitoMode', value);
    _incognitoController.add(value);
  }

  /// Enable/disable data synchronization
  Future<void> setSyncEnabled(bool value) async {
    if (!isIncognito) {
      await _settingsBox.put('syncEnabled', value);
      await _settingsBox.put('lastSyncState', value);
    }
  }

  /// Force refresh settings across all listeners
  Future<void> syncSettings() async {
    await _ensureInitialized();
    _incognitoController.add(isIncognito);
  }

  /// Ensure service is initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// Clean up resources
  void dispose() {
    _incognitoController.close();
    _settingsController.close();
  }

  /// Current download path
  Future<String> get downloadPath async {
    await _ensureInitialized();
    final savedPath = _settingsBox.get(_downloadPathKey);
    if (savedPath == null) {
      final defaultPath = await _getDefaultDownloadPath();
      await _settingsBox.put(_downloadPathKey, defaultPath);
      return defaultPath;
    }
    return savedPath;
  }

  /// Set download path
  Future<void> setDownloadPath(String path) async {
    await _ensureInitialized();
    await _settingsBox.put(_downloadPathKey, path);
    _settingsController.add(null); // Notify listeners
  }

  /// Get auto-play next episode setting
  bool get isAutoPlayNext =>
      _settingsBox.get('autoPlayNext', defaultValue: true);

  /// Set auto-play next episode setting
  Future<void> setAutoPlayNext(bool value) async {
    await _ensureInitialized();
    await _settingsBox.put('autoPlayNext', value);
    _settingsController.add(null); // Notify listeners
  }

  bool get isAutoPlayEnabled =>
      _settingsBox.get('autoPlayNext', defaultValue: true);

  Future<void> setAutoPlayEnabled(bool value) async {
    await _settingsBox.put('autoPlayNext', value);
    _settingsController.add(null);
  }

  /// Current show update dialog state
  bool get showUpdateDialog =>
      _settingsBox.get('showUpdateDialog', defaultValue: true);

  /// Set show update dialog state
  Future<void> setShowUpdateDialog(bool value) async {
    await _ensureInitialized();
    await _settingsBox.put('showUpdateDialog', value);
    _settingsController.add(null); // Notify listeners
  }

  /// Gets the appropriate server preference key based on content type
  String getServerPreferenceKey(Contentclass content) {
    return content.genres.contains("Animation")
        ? 'preferredAnimeServer'
        : 'preferredServer';
  }

  /// Saves the preferred server based on content type
  Future<void> savePreferredServer(
      Contentclass content, String serverName) async {
    try {
      await init();
      final preferenceKey = getServerPreferenceKey(content);
      await _settingsBox.put(preferenceKey, serverName);

      debugPrint(
          'Saved preferred ${preferenceKey == 'preferredAnimeServer' ? "anime" : "regular"} server: $serverName');
    } catch (e) {
      debugPrint('Error saving preferred server: $e');
    }
  }

  /// Gets the preferred server based on content type
  Future<String?> getPreferredServer(Contentclass content) async {
    await init();
    final preferenceKey = getServerPreferenceKey(content);
    return _settingsBox.get(preferenceKey);
  }

  /// Gets any setting with default value
  Future<T> getSetting<T>(String key, {T? defaultValue}) async {
    await init();
    return _settingsBox.get(key, defaultValue: defaultValue) as T;
  }

  /// Saves any setting
  Future<void> saveSetting(String key, dynamic value) async {
    await init();
    await _settingsBox.put(key, value);
    _settingsController.add(null); // Notify listeners
  }
}
