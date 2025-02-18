/**
 * MovieDex Watch History Service
 * 
 * Manages user watch history with features:
 * - Local history storage
 * - Cloud sync support
 * - Continue watching tracking
 * - Watch progress management
 * - Incognito mode support
 * 
 * Data is stored locally using Hive and optionally synced to Firebase
 * when user is authenticated and sync is enabled.
 */

import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/models/watch_history_model.dart';

/// Service for managing user watch history and progress
class WatchHistoryService {
  // Storage box names
  static const String _historyBoxName = 'watch_history';
  static const String _continueBoxName = 'continue_watching';
  static const String _settingsBoxName = 'settings';
  
  late Box<WatchHistoryItem> _historyBox;
  late Box<WatchHistoryItem> _continueBox;
  late Box _settingsBox;
  static WatchHistoryService? _instance;
  bool _isInitialized = false;

  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  static WatchHistoryService get instance {
    _instance ??= WatchHistoryService._();
    return _instance!;
  }

  WatchHistoryService._();

  Future<void> init() async {
    if (!_isInitialized) {
      await Hive.initFlutter();
      
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(WatchHistoryItemAdapter());
      }

      _historyBox = await Hive.openBox<WatchHistoryItem>(_historyBoxName);
      _continueBox = await Hive.openBox<WatchHistoryItem>(_continueBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);
      
      _isInitialized = true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// Adds content to watch history
  /// @param content The content to add to history
  Future<void> addToHistory(Contentclass content) async {
    await _ensureInitialized();
    
    // Check incognito and sync settings
    final settingsBox = await Hive.openBox('settings');
    final isIncognito = settingsBox.get('incognitoMode', defaultValue: false);
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    
    if (isIncognito) return;

    final item = WatchHistoryItem(
      contentId: content.id,
      title: content.title,
      poster: content.poster,
      type: content.type,
      watchedAt: DateTime.now(),
    );

    // Save to local storage
    await _historyBox.put(content.id.toString(), item);

    // Sync with Firebase if enabled and user is logged in
    if (syncEnabled && _auth.currentUser != null) {
      try {
        await _database
            .child('users')
            .child(_auth.currentUser!.uid)
            .child('watchHistory')
            .child(content.id.toString())
            .set(item.toJson());
      } catch (e) {
        print('Error syncing watch history: $e');
      }
    }
  }

  Future<void> updateContinueWatching(
    Contentclass content,
    Duration position,
    Duration total,
    {int? episodeNumber, String? episodeTitle}
  ) async {
    await _ensureInitialized();

    // Don't save if in incognito mode
    final settingsBox = await Hive.openBox('settings');
    final isIncognito = settingsBox.get('incognitoMode', defaultValue: false);
    if (isIncognito) return;

    // Only save if watched more than 1% and less than 95%
    final progress = position.inSeconds / total.inSeconds;
    if (progress < 0.01 || progress > 0.95) {
      await removeFromContinueWatching(content.id);
      return;
    }

    final item = WatchHistoryItem(
      contentId: content.id,
      title: content.title,
      poster: content.poster,
      type: content.type,
      watchedAt: DateTime.now(),
      progress: position,
      totalDuration: total,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
    );

    await _continueBox.put(content.id.toString(), item);
  }

  Future<void> syncWithFirebase() async {
    if (!_isInitialized) return;
    
    final user = _auth.currentUser;
    if (user == null) return;

    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    final isIncognito = settingsBox.get('incognitoMode', defaultValue: false);

    if (!syncEnabled || isIncognito) return;

    try {
      // Get server data
      final snapshot = await _database
          .child('users')
          .child(user.uid)
          .child('watchHistory')
          .get();

      if (snapshot.exists) {
        final serverData = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Merge with local data
        for (var entry in serverData.entries) {
          final serverItem = WatchHistoryItem.fromJson(
            Map<String, dynamic>.from(entry.value as Map)
          );
          
          // Get local item if exists
          final localItem = _historyBox.get(entry.key);
          
          // Keep most recent version
          if (localItem == null || 
              serverItem.watchedAt.isAfter(localItem.watchedAt)) {
            await _historyBox.put(entry.key, serverItem);
          }
        }
      }

      // Upload local data
      final localItems = _historyBox.values;
      for (var item in localItems) {
        await _database
            .child('users')
            .child(user.uid)
            .child('watchHistory')
            .child(item.contentId.toString())
            .set(item.toJson());
      }
    } catch (e) {
      print('Error during watch history sync: $e');
    }
  }

  List<WatchHistoryItem> getWatchHistory() {
    if (!_isInitialized) return [];
    return _historyBox.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt)); // Sort by newest first
  }

  List<WatchHistoryItem> getContinueWatching({String? type}) {
    if (!_isInitialized) return [];
    
    var list = _continueBox.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

    if (type != null) {
      list = list.where((item) => item.type == type).toList();
    }

    return list;
  }

  Future<void> removeFromHistory(dynamic contentId) async {
    await _ensureInitialized();
    
    // Convert contentId to string if it's an int
    final id = contentId.toString();
    
    // Remove from local storage
    await _historyBox.delete(id);

    // Remove from Firebase if sync is enabled and user is logged in
    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    final user = _auth.currentUser;
    
    if (syncEnabled && user != null) {
      try {
        await _database
            .child('users')
            .child(user.uid)
            .child('watchHistory')
            .child(id)
            .remove();
      } catch (e) {
        print('Error removing from synced watch history: $e');
      }
    }
  }

  Future<void> removeFromContinueWatching(int contentId) async {
    await _ensureInitialized();
    await _continueBox.delete(contentId.toString());
  }

  Future<void> clearHistory() async {
    await _ensureInitialized();
    await _historyBox.clear();
  }

  Future<void> clearContinueWatching() async {
    await _ensureInitialized();
    await _continueBox.clear();
  }

  Future<void> clearAllHistory() async {
    await _ensureInitialized();
    
    // Clear local history
    await _historyBox.clear();
    
    // Clear Firebase history if user is logged in and sync is enabled
    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    final user = _auth.currentUser;
    
    if (syncEnabled && user != null) {
      try {
        await _database
            .child('users')
            .child(user.uid)
            .child('watchHistory')
            .remove();
      } catch (e) {
      }
    }
  }
}
