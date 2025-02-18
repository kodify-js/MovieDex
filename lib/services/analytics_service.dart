import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  late final FirebaseAnalytics _analytics;

  AnalyticsService._internal() {
    _analytics = FirebaseAnalytics.instance;
  }

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logUpdateEvent({
    required String version,
    required bool success,
    String? error,
  }) async {
    final Map<String, Object> parameters = {
      'version': version,
      'success': success,
    };
    
    if (error != null) {
      parameters['error'] = error;
    }

    await _analytics.logEvent(
      name: 'app_update',
      parameters: parameters,
    );
  }

  Future<void> logSearch(String query) async {
    await _analytics.logSearch(searchTerm: query);
  }

  Future<void> logMovieView(String movieId, String title) async {
    await _analytics.logEvent(
      name: 'movie_view',
      parameters: {
        'movie_id': movieId,
        'title': title,
      },
    );
  }
}
