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
import 'package:hive/hive.dart';

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
    }
  }

  /// Current incognito mode state
  bool get isIncognito => _settingsBox.get('incognitoMode', defaultValue: false);

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
  String get downloadPath => _settingsBox.get(
    _downloadPathKey,
    defaultValue: '/storage/emulated/0/Download/MovieDex',
  );

  /// Set download path
  Future<void> setDownloadPath(String path) async {
    await _settingsBox.put(_downloadPathKey, path);
  }

  bool get isAutoPlayEnabled => _settingsBox.get('autoPlayNext', defaultValue: true);
  
  Future<void> setAutoPlayEnabled(bool value) async {
    await _settingsBox.put('autoPlayNext', value);
    _settingsController.add(null);
  }
}
