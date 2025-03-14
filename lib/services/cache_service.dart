import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/api/models/cache_model.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _boxName = 'api_cache';
  Box<CacheModel>? _cacheBox;
  Box? _settingsBox;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  static CacheService get instance => _instance;

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
    try {
      final cacheDir = await getTemporaryDirectory();
      return await _calculateDirSize(cacheDir);
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }

  Future<int> _calculateDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (dir.existsSync()) {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      print('Error calculating cache size: $e');
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
    await clearCache();
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        await for (var entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }
}
