import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

class SettingsService {
  static SettingsService? _instance;
  late Box _settingsBox;
  bool _isInitialized = false;

  // Add stream controller for incognito mode changes
  final _incognitoController = StreamController<bool>.broadcast();
  Stream<bool> get incognitoStream => _incognitoController.stream;

  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  SettingsService._();

  Future<void> init() async {
    if (!_isInitialized) {
      _settingsBox = await Hive.openBox('settings');
      _isInitialized = true;
    }
  }

  bool get isIncognito => _settingsBox.get('incognitoMode', defaultValue: false);
  bool get isSyncEnabled => _settingsBox.get('syncEnabled', defaultValue: true);
  bool? get lastSyncState => _settingsBox.get('lastSyncState');

  Future<void> setIncognitoMode(bool value) async {
    if (value) {
      // Store current sync state before enabling incognito
      await _settingsBox.put('lastSyncState', isSyncEnabled);
      // Disable sync when entering incognito
      await _settingsBox.put('syncEnabled', false);
    } else {
      // Restore previous sync state when exiting incognito
      final previousState = lastSyncState ?? true;
      await _settingsBox.put('syncEnabled', previousState);
    }
    await _settingsBox.put('incognitoMode', value);
    _incognitoController.add(value); // Notify listeners
  }

  Future<void> setSyncEnabled(bool value) async {
    if (!isIncognito) {
      await _settingsBox.put('syncEnabled', value);
      await _settingsBox.put('lastSyncState', value);
    }
  }

  // Add this method to clean up resources
  void dispose() {
    _incognitoController.close();
  }
}
