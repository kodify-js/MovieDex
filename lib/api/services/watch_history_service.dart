import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/models/watch_history_model.dart';


class WatchHistoryService {
  static const String _historyBoxName = 'watch_history';
  static const String _continueBoxName = 'continue_watching';
  static const String _settingsBoxName = 'settings';
  
  late Box<WatchHistoryItem> _historyBox;
  late Box<WatchHistoryItem> _continueBox;
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

  Future<void> addToHistory(Contentclass content) async {
    await _ensureInitialized();
    final item = WatchHistoryItem(
      contentId: content.id,
      title: content.title,
      poster: content.poster,
      type: content.type,
      watchedAt: DateTime.now(),
    );
    await _historyBox.put(content.id.toString(), item);
  }

  Future<void> updateContinueWatching(
    Contentclass content,
    Duration progress,
    Duration total,
  ) async {
    final item = WatchHistoryItem(
      contentId: content.id,
      title: content.title,
      poster: content.poster,
      type: content.type,
      watchedAt: DateTime.now(),
      progress: progress,
      totalDuration: total,
    );

    await _continueBox.put(content.id.toString(), item);
  }

  List<WatchHistoryItem> getWatchHistory() {
    if (!_isInitialized) return [];
    return _historyBox.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  }

  List<WatchHistoryItem> getContinueWatching() {
    if (!_isInitialized) return [];
    return _continueBox.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  }

  Future<void> removeFromHistory(int contentId) async {
    await _ensureInitialized();
    await _historyBox.delete(contentId.toString());
  }

  Future<void> removeFromContinueWatching(int contentId) async {
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
}
