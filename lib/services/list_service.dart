/**
 * List Management Service
 * 
 * Handles user's personal content lists with features:
 * - Local storage with Hive
 * - Firebase sync support
 * - Cached list operations
 * - Offline support
 * - Sort and filter capabilities
 * 
 * Part of MovieDex - MIT Licensed
 */
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/models/list_item_model.dart';
import 'package:moviedex/services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';
/// Manages user's content lists with sync capabilities
class ListService {
  static const String _listBoxName = 'my_list';
  Box<ListItem>? _listBox; // Change to nullable
  static ListService? _instance;
  bool _isInitialized = false;

  // Add cache for list items
  List<ListItem>? _cachedList;

  static ListService get instance {
    _instance ??= ListService._();
    return _instance!;
  }

  ListService._();

  Future<void> init() async {
    if (!_isInitialized) {
      try {
        await Hive.initFlutter();
        _listBox = await Hive.openBox<ListItem>(_listBoxName);
        _isInitialized = true;
      } catch (e) {
        print('Error initializing ListService: $e');
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
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
        collectionId: AppwriteService.userListCollection,
        queries: [Query.equal('user_id', user.$id)],
      );

      // Merge with local data
      for (var doc in serverDocs.rows) {
        final serverItem = ListItem.fromJson(doc.data);
        final localItem = _listBox?.get(serverItem.contentId.toString());

        if (localItem == null) {
          await _listBox?.put(serverItem.contentId.toString(), serverItem);
        }
      }

      // Upload local data
      for (var item in _listBox!.values) {
        try {
          await appwrite.createDocument(
            collectionId: AppwriteService.userListCollection,
            documentId: item.contentId.toString(),
            data: {
              ...item.toJson(),
              'user_id': user.$id,
            },
          );
        } catch (e) {
          print('Error uploading list item: $e');
        }
      }
    } catch (e) {
      print('Error during watch list sync: $e');
    }
  }

  /// Adds content to user's list and syncs if enabled
  Future<void> addToList(Contentclass content) async {
    await _ensureInitialized();
    if (_listBox == null) return;
    
    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);

    final item = ListItem(
      contentId: content.id,
      title: content.title,
      poster: content.poster,
      type: content.type,
      addedAt: DateTime.now(),
    );

    // Save to local storage
    await _listBox!.put(content.id.toString(), item);

    // Sync with Appwrite if enabled
    if (syncEnabled && await AppwriteService.instance.isLoggedIn()) {
      try {
        final user = await AppwriteService.instance.getCurrentUser();
        await AppwriteService.instance.createDocument(
          collectionId: AppwriteService.userListCollection,
          documentId: content.id.toString(),
          data: {
            ...item.toJson(),
            'user_id': user.$id,
          },
        );
      } catch (e) {
        print('Error syncing list item: $e');
      }
    }

    _cachedList = _listBox?.values.toList();
  }

  /// Removes content from user's list and syncs if enabled
  Future<void> removeFromList(int contentId) async {
    await _ensureInitialized();
    if (_listBox == null) return;
    
    // Check if sync is enabled
    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);

    // Remove from local storage
    await _listBox!.delete(contentId.toString());

    // Remove from Appwrite if enabled and user is logged in
    if (syncEnabled && await AppwriteService.instance.isLoggedIn()) {
      try {
        await AppwriteService.instance.deleteDocument(
          collectionId: AppwriteService.userListCollection,
          documentId: contentId.toString(),
        );
      } catch (e) {
        print('Error removing from synced list: $e');
      }
    }

    // Update cache
    _cachedList = _listBox?.values.toList();
  }

  List<ListItem> getList() {
    if (!_isInitialized) return [];
    
    // Use cached list if available
    _cachedList ??= _listBox?.values.toList() ?? [];
    return List.from(_cachedList!)
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  bool isInList(int contentId) {
    if (!_isInitialized || _listBox == null) return false;
    return _listBox!.containsKey(contentId.toString());
  }
}
