import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:moviedex/api/secrets.dart';
import 'dart:io';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  late final Mixpanel _mixpanel;
  bool _initialized = false;

  AnalyticsService._internal();

  Future<void> init() async {
    if (_initialized) return;
    
    try {
      _mixpanel = await Mixpanel.init(
        mixpanelToken,
        optOutTrackingDefault: true,
        trackAutomaticEvents: true
      );
      _initialized = true;
      
      // Track app open as user session start
      trackSession(true);
    } catch (e) {
      print('Error initializing Mixpanel: $e');
    }
  }

  void track(String eventName, {Map<String, dynamic>? properties}) {
    if (!_initialized) return;
    _mixpanel.track(eventName, properties: properties);
  }

  void trackSession(bool isStart) {
    if (!_initialized) return;
    
    final eventName = isStart ? 'Session Start' : 'Session End';
    track(eventName, properties: {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
    });

    // Update user last seen time
    if (isStart) {
      _mixpanel.getPeople().set('last_seen', DateTime.now().toIso8601String());
      _mixpanel.getPeople().increment('session_count', 1);
    }
  }

}