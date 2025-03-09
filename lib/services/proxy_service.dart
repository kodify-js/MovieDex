/**
 * ProxyService - HTTP Proxy Configuration Manager
 * 
 * Part of MovieDex - Open Source Movie Streaming App
 * Copyright (c) 2024 MovieDex Contributors
 * 
 * Features:
 * - Proxy configuration management
 * - Proxy validation
 * - URL routing through configured proxy
 * - Persistent proxy settings
 */

import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

/// Manages HTTP proxy configuration and validation
class ProxyService {
  static ProxyService? _instance;
  
  /// Returns singleton instance of ProxyService
  static ProxyService get instance {
    _instance ??= ProxyService._();
    return _instance!;
  }

  ProxyService._();

  /// Returns currently active proxy URL if enabled, null otherwise
  String? get activeProxy {
    final settings = Hive.box('settings');
    final useCustomProxy = settings.get('useCustomProxy', defaultValue: false);
    return useCustomProxy ? settings.get('proxyUrl') : null;
  }

  /// Validates proxy URL by attempting a test connection
  Future<bool> validateProxy(String proxyUrl) async {
    try {
      final response = await http.get(
        Uri.parse('${proxyUrl}https://www.google.com'),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Saves proxy URL to persistent storage
  Future<void> setProxy(String proxyUrl) async {
    final settings = await Hive.openBox('settings');
    await settings.put('proxyUrl', proxyUrl);
  }
}
