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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/models/list_item_model.dart';

/// Manages user's content lists with sync capabilities
class ListService {
  static const String _listBoxName = 'my_list';
  Box<ListItem>? _listBox; // Change to nullable
  static ListService? _instance;
  bool _isInitialized = false;
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

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
        if (!Hive.isAdapterRegistered(5)) {
          Hive.registerAdapter(ListItemAdapter());
        }
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

  /// Adds content to user's list and syncs if enabled
  Future<void> addToList(Contentclass content) async {
    await _ensureInitialized();
    if (_listBox == null) return;
    
    // Check if sync is enabled
    final settingsBox = await Hive.openBox('settings');
    final syncEnabled = settingsBox.get('syncEnabled', defaultValue: true);

    final item = ListItem(
      contentId: content.id,
      title: content.title,
      poster: content.poster,
      type: content.type,
      addedAt: DateTime.now(),
      content: content.toJson(),
    );

    // Save to local storage
    await _listBox!.put(content.id.toString(), item);

    // Sync with Firebase if enabled and user is logged in
    if (syncEnabled && _auth.currentUser != null) {
      await _database
          .child('users')
          .child(_auth.currentUser!.uid)
          .child('myList')
          .child(content.id.toString())
          .set(item.content);
    }

    // Update cache
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

    // Remove from Firebase if enabled and user is logged in
    if (syncEnabled && _auth.currentUser != null) {
      await _database
          .child('users')
          .child(_auth.currentUser!.uid)
          .child('myList')
          .child(contentId.toString())
          .remove();
    }

    // Update cache
    _cachedList = _listBox?.values.toList();

    // Show success feedback
    print('Successfully removed from My List');
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
