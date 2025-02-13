import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/api/models/cache_model.dart';

class CacheService {
  static const String _boxName = 'api_cache';
  static CacheService? _instance;
  Box<CacheModel>? _cacheBox;
  Box? _settingsBox;
  bool _isInitialized = false;

  // Private constructor
  CacheService._();

  // Factory constructor for singleton
  factory CacheService() {
    _instance ??= CacheService._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (!_isInitialized) {
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CacheModelAdapter());
      }
      
      _cacheBox = await Hive.openBox<CacheModel>(_boxName);
      _settingsBox = await Hive.openBox('settings');
      _isInitialized = true;
    }
  }

  Future<int> getCacheSize() async {
    await _ensureInitialized();
    int totalSize = 0;
    if (_cacheBox != null) {
      for (var item in _cacheBox!.values) {
        totalSize += item.data.toString().length;
      }
    }
    return totalSize;
  }

  Duration get cacheValidity => Duration(
    minutes: _settingsBox?.get(
      'cacheValidity',
      defaultValue: const Duration(days: 1).inMinutes,
    ) ?? const Duration(days: 1).inMinutes,
  );

  Future<dynamic> get(String key) async {
    await _ensureInitialized();
    if (_cacheBox == null) return null;
    
    final cache = _cacheBox!.get(key);
    if (cache != null) {
      final age = DateTime.now().difference(cache.timestamp);
      if (age < cacheValidity) {
        return cache.data;
      } else {
        await _cacheBox!.delete(key);
      }
    }
    return null;
  }

  Future<void> set(String key, dynamic data) async {
    await _ensureInitialized();
    if (_cacheBox != null) {
      final cache = CacheModel(
        key: key,
        data: data,
        timestamp: DateTime.now(),
      );
      await _cacheBox!.put(key, cache);
    }
  }

  Future<void> clear() async {
    await _ensureInitialized();
    await _cacheBox?.clear();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }
}
