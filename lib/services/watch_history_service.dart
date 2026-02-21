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
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/models/list_item_model.dart';
import 'package:moviedex/services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';
/// Service for managing user watch history and progress
class WatchHistoryService {
  // Storage box names
  static const String _historyBoxName = 'watch_history';
  static const String _continueBoxName = 'continue_watching';
  static const String _settingsBoxName = 'settings';
  
  late Box<ListItem> _historyBox;
  late Box<ListItem> _continueBox;
  late Box _settingsBox;
  static WatchHistoryService? _instance;
  bool _isInitialized = false;

  static WatchHistoryService get instance {
    _instance ??= WatchHistoryService._();
    return _instance!;
  }

  WatchHistoryService._();

  Future<void> init() async {
    if (!_isInitialized) {
      await Hive.initFlutter();

      _historyBox = await Hive.openBox<ListItem>(_historyBoxName);
      _continueBox = await Hive.openBox<ListItem>(_continueBoxName);
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

    final item = ListItem(
      contentId: content.id,
      title: content.title,
      poster: content.poster,
      type: content.type,
      addedAt: DateTime.now(),
    );

    // Save to local storage
    await _historyBox.put(content.id.toString(), item);

    // Sync with Appwrite if enabled and user is logged in
    if (syncEnabled && await AppwriteService.instance.isLoggedIn()) {
      try {
        final user = await AppwriteService.instance.getCurrentUser();
        await AppwriteService.instance.createDocument(
          collectionId: AppwriteService.watchHistoryCollection,
          documentId: '${content.id.toString()}-${content.type}',
          data: {
            ...item.toJson(),
            'user_id': user.$id,
          },
        );
      } catch (e) {
        print('Error syncing watch history: $e');
      }
    }
  }

  Future<void> syncWithAppwrite() async {
    if (!_isInitialized) return;
    
    final appwrite = AppwriteService.instance;
    if (!await appwrite.isLoggedIn()) return;

    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    final isIncognito = settingsBox.get('incognitoMode', defaultValue: false);

    if (!syncEnabled || isIncognito) return;

    try {
      // Get server data
      final user = await appwrite.getCurrentUser();
      final serverDocs = await appwrite.listDocuments(
        collectionId: AppwriteService.watchHistoryCollection,
        queries: [Query.equal('user_id', user.$id)],
      );

      // Merge with local data
      for (var doc in serverDocs.rows) {
        final serverItem = ListItem.fromJson(doc.data);
        final localItem = _historyBox.get(serverItem.contentId.toString());

        if (localItem == null || 
            serverItem.addedAt.isAfter(localItem.addedAt)) {
          await _historyBox.put(serverItem.contentId.toString(), serverItem);
        }
      }

      // Upload local data
      for (var item in _historyBox.values) {
        try {
          await appwrite.createDocument(
            collectionId: AppwriteService.watchHistoryCollection,
            documentId: item.contentId.toString(),
            data: {
              ...item.toJson(),
              'user_id': user.$id,
            },
          );
        } catch (e) {
          print('Error uploading history item: $e');
        }
      }
    } catch (e) {
      print('Error during watch history sync: $e');
    }
  }

  List<ListItem> getWatchHistory() {
    if (!_isInitialized) {};
    return _historyBox.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt)); // Sort by newest first
  }

  List<ListItem> getContinueWatching({String? type}) {
    if (!_isInitialized) return [];
    
    var list = _continueBox.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    if (type != null) {
      list = list.where((item) => item.type == type).toList();
    }

    return list;
  }

  Future<void> removeFromHistory(dynamic contentId) async {
    await _ensureInitialized();
    
    final id = contentId.toString();
    await _historyBox.delete(id);

    // Remove from Appwrite if sync is enabled
    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    
    if (syncEnabled && await AppwriteService.instance.isLoggedIn()) {
      try {
        await AppwriteService.instance.deleteDocument(
          collectionId: AppwriteService.watchHistoryCollection,
          documentId: id,
        );
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
    
    // Clear Appwrite history if user is logged in and sync is enabled
    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);
    
    if (syncEnabled && await AppwriteService.instance.isLoggedIn()) {
      try {
        final user = await AppwriteService.instance.getCurrentUser();
        final docs = await AppwriteService.instance.listDocuments(
          collectionId: AppwriteService.watchHistoryCollection,
          queries: ['user_id = "${user.$id}"'],
        );
        for (var doc in docs.rows) {
          await AppwriteService.instance.deleteDocument(
            collectionId: AppwriteService.watchHistoryCollection,
            documentId: doc.$id,
          );
        }
      } catch (e) {
        print('Error clearing Appwrite watch history: $e');
      }
    }
  }
}
