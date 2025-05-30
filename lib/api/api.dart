/**
 * MovieDex API Client
 * Part of MovieDex - Open Source Movie Streaming App
 * 
 * Copyright (c) 2024 MovieDex Contributors
 * Licensed under MIT License
 * 
 * This module provides a client for interacting with movie APIs:
 * - Cached responses for better performance
 * - Proxy support for network requests
 * - Rate limiting and error handling
 * - Content filtering and validation
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/api/secrets.dart';
import 'package:moviedex/services/cache_service.dart';
import 'package:moviedex/services/proxy_service.dart';
import 'package:moviedex/services/connectivity_service.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:flutter/foundation.dart';

/// Main API client for MovieDex
class Api {
  final String? baseUrl;
  final CacheService _cacheService;

  /// Creates new API client instance with optional custom base URL
  Api({this.baseUrl = "https://api.tmdb.org"})
      : _cacheService = CacheService() {
    _initCache();
  }

  Future<void> _initCache() async {
    await _cacheService.init();
  }

  // Generate default headers
  Map<String, String> _getDefaultHeaders() {
    return {
      'Accept': 'application/json',
    };
  }

  /// Makes HTTP GET request with proxy support if configured
  Future<http.Response> _get(String url, {Map<String, String>? headers}) async {
    // Check connectivity before making request
    if (!await ConnectivityService.instance.checkConnection()) {
      throw 'No internet connection. Please check your network settings and try again.';
    }

    // Ensure URL has API key
    final String urlWithApiKey =
        url.contains('?') ? '$url&api_key=$apiKey' : '$url?api_key=$apiKey';

    // Merge provided headers with default headers
    final mergedHeaders = {..._getDefaultHeaders(), ...(headers ?? {})};
    final proxy = ProxyService.instance.activeProxy;

    return proxy != null && proxy.isNotEmpty
        ? _makeProxiedRequest(urlWithApiKey, mergedHeaders)
        : _makeDirectRequest(urlWithApiKey, mergedHeaders);
  }

  /// Makes request through configured proxy
  Future<http.Response> _makeProxiedRequest(
      String url, Map<String, String> headers) async {
    final client = http.Client();
    try {
      return await client
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw _handleRequestError(e);
    } finally {
      client.close();
    }
  }

  /// Makes direct request without proxy
  Future<http.Response> _makeDirectRequest(
      String url, Map<String, String> headers) async {
    try {
      return await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw _handleRequestError(e);
    }
  }

  /// Provides a user-friendly error message for network issues
  String _handleRequestError(dynamic error) {
    debugPrint('API Error: $error');

    if (error.toString().contains('SocketException')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    } else if (error.toString().contains('timeout')) {
      return 'The connection timed out. Please try again later.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<T> _fetchWithCache<T>(
      String endpoint, Future<T> Function() fetchData) async {
    final cacheKey = endpoint;

    final cachedData = await _cacheService.get(cacheKey);
    if (cachedData != null) {
      if (T == List<Contentclass>) {
        final List<dynamic> rawList = cachedData as List<dynamic>;
        return rawList
            .map((item) => Contentclass(
                  id: item['id'],
                  backdrop: item['backdrop'],
                  title: item['title'],
                  language: item['language'],
                  genres: List<String>.from(item['genres'] ?? []),
                  type: item['type'],
                  description: item['description'],
                  poster: item['poster'],
                  logoPath: item['logoPath'],
                  rating: item['rating']?.toDouble(),
                  seasons: item['seasons'] != null
                      ? List<Season>.from(
                          (item['seasons'] as List).map((s) => Season(
                                id: s['id'],
                                season: s['season'],
                              )))
                      : null,
                ))
            .toList() as T;
      } else if (T == Contentclass) {
        return Contentclass(
          id: cachedData['id'],
          backdrop: cachedData['backdrop'],
          title: cachedData['title'],
          language: cachedData['language'],
          genres: List<String>.from(cachedData['genres'] ?? []),
          type: cachedData['type'],
          description: cachedData['description'],
          poster: cachedData['poster'],
          logoPath: cachedData['logoPath'],
          rating: cachedData['rating']?.toDouble(),
          seasons: cachedData['seasons'] != null
              ? List<Season>.from(
                  (cachedData['seasons'] as List).map((s) => Season(
                        id: s['id'],
                        season: s['season'],
                      )))
              : null,
        ) as T;
      }
      return cachedData as T;
    }

    try {
      final freshData = await fetchData();
      await _cacheService.set(
          cacheKey,
          freshData is List<Contentclass>
              ? (freshData as List<Contentclass>)
                  .map((c) => c.toJson())
                  .toList()
              : freshData is Contentclass
                  ? (freshData as Contentclass).toJson()
                  : freshData);
      return freshData;
    } catch (e) {
      // If we have cached data and get a network error, return cached data as fallback
      if (cachedData != null && e.toString().contains('internet')) {
        if (T == List<Contentclass>) {
          final List<dynamic> rawList = cachedData as List<dynamic>;
          return rawList
              .map((item) => Contentclass(
                    id: item['id'],
                    backdrop: item['backdrop'],
                    title: item['title'],
                    language: item['language'],
                    genres: List<String>.from(item['genres'] ?? []),
                    type: item['type'],
                    description: item['description'],
                    poster: item['poster'],
                    logoPath: item['logoPath'],
                    rating: item['rating']?.toDouble(),
                    seasons: item['seasons'] != null
                        ? List<Season>.from(
                            (item['seasons'] as List).map((s) => Season(
                                  id: s['id'],
                                  season: s['season'],
                                )))
                        : null,
                  ))
              .toList() as T;
        } else if (T == Contentclass) {
          return Contentclass(
            id: cachedData['id'],
            backdrop: cachedData['backdrop'],
            title: cachedData['title'],
            language: cachedData['language'],
            genres: List<String>.from(cachedData['genres'] ?? []),
            type: cachedData['type'],
            description: cachedData['description'],
            poster: cachedData['poster'],
            logoPath: cachedData['logoPath'],
            rating: cachedData['rating']?.toDouble(),
            seasons: cachedData['seasons'] != null
                ? List<Season>.from(
                    (cachedData['seasons'] as List).map((s) => Season(
                          id: s['id'],
                          season: s['season'],
                        )))
                : null,
          ) as T;
        }
        return cachedData as T;
      }
      rethrow;
    }
  }

  bool _isReleased(Map<String, dynamic> content, String type) {
    final today = DateTime.now();
    final dateString = type == ContentType.movie.value
        ? content['release_date']
        : content['first_air_date'];

    if (dateString == null || dateString.isEmpty) return false;

    final releaseDate = DateTime.parse(dateString);
    return releaseDate.isBefore(today) || releaseDate.isAtSameMomentAs(today);
  }

  Future<List<Contentclass>> getPopular(
      {required type, ImageSize? imageSize, language}) async {
    final endpoint = '/popular/$type/${language ?? "en"}';

    return _fetchWithCache<List<Contentclass>>(endpoint, () async {
      try {
        final data = await _get(
            '$baseUrl/3/discover/${type}?include_video=true&language=en-US&page=1&sort_by=popularity.desc&with_original_language=${language ?? "en"}');
        final response = jsonDecode(data.body);
        if (response['success'] != null) throw "An unexpected error occurred";

        final List<Contentclass> result = (response['results'] as List)
            .where(
                (movie) => _isReleased(movie, type)) // Add release date filter
            .map((movie) {
          return Contentclass(
              id: movie['id'],
              backdrop:
                  'https://wsrv.nl/?url=https://image.tmdb.org/t/p/${imageSize ?? ImageSize.original.value}${movie['backdrop_path']}',
              title: movie['title'] ?? movie['name'],
              language: movie['original_language'] ?? "en",
              genres: [],
              type: type,
              description: movie['overview'] ?? "",
              poster:
                  'https://wsrv.nl/?url=https://image.tmdb.org/t/p/w342${movie["poster_path"]}&output=webp');
        }).toList();

        // Fetch logos for first 5 items
        for (int i = 0; i < 5 && i < result.length; i++) {
          result[i].logoPath = await getLogo(result[i].id, type);
        }
        return result;
      } catch (e) {
        throw e.toString();
      }
    });
  }

  Future<List<Contentclass>> getTrending(
      {required type, required language}) async {
    final endpoint = '/trending/$type/$language';

    return _fetchWithCache<List<Contentclass>>(endpoint, () async {
      try {
        final data = await _get('$baseUrl/3/trending/$type/day?language=en-US');
        final response = jsonDecode(data.body);
        if (response['success'] != null) throw "An unexpected error occured";
        final List<Contentclass> result = (response['results'] as List)
            .where(
                (movie) => _isReleased(movie, type)) // Add release date filter
            .map((movie) {
          Contentclass data = Contentclass(
              id: movie['id'],
              backdrop: imagePath(
                  size: ImageSize.original, path: movie['backdrop_path']),
              title: movie['title'] ?? movie['name'],
              language: movie['original_language'],
              genres: [],
              type: type,
              description: movie['overview'],
              poster:
                  'https://wsrv.nl/?url=https://image.tmdb.org/t/p/w342${movie["poster_path"]}&output=webp');
          return data;
        }).toList();
        return result;
      } catch (e) {
        throw e.toString();
      }
    });
  }

  Future<List<Contentclass>> getGenresContent(
      {required String type, required int id}) async {
    final endpoint = '/genres/$type/$id';

    return _fetchWithCache<List<Contentclass>>(endpoint, () async {
      try {
        final data = await _get(
            '$baseUrl/3/discover/$type?with_genres=$id&language=en-US&page=1&sort_by=popularity.desc');
        final response = jsonDecode(data.body);
        if (response['success'] != null)
          throw "Something went wrong while fetching content";

        // Filter out items without required images
        final List<Contentclass> result = (response['results'] as List)
            .where((movie) =>
                movie['backdrop_path'] != null &&
                movie['poster_path'] != null &&
                _isReleased(movie, type)) // Add release date filter
            .map((movie) => Contentclass(
                id: movie['id'],
                backdrop: imagePath(
                    size: ImageSize.original, path: movie['backdrop_path']),
                title: movie['title'] ?? movie['name'] ?? 'Unknown',
                language: movie['original_language'],
                genres: [],
                type: type,
                description: movie['overview'] ?? '',
                poster:
                    'https://wsrv.nl/?url=https://image.tmdb.org/t/p/w342${movie["poster_path"]}&output=webp'))
            .toList();

        if (result.isEmpty) {
          throw "No content available for this genre";
        }

        // Only fetch logos if we have results
        for (int i = 0; i < 5 && i < result.length; i++) {
          result[i].logoPath = await getLogo(result[i].id, type);
        }

        return result;
      } catch (e) {
        if (e is String) {
          throw e;
        } else {
          throw "Failed to load content. Please try again.";
        }
      }
    });
  }

  Future<Contentclass> getDetails(
      {required int id, required String type}) async {
    final endpoint = '/details/$type/$id';

    return _fetchWithCache<Contentclass>(endpoint, () async {
      try {
        final data = await _get('$baseUrl/3/$type/$id?language=en-US');
        final response = jsonDecode(data.body);
        if (response['status_code'] != null)
          throw "Unable to fetch content details";

        final Contentclass content = Contentclass(
            id: response['id'],
            backdrop: imagePath(
                size: ImageSize.original, path: response['backdrop_path']),
            title: response['title'] ?? response['name'] ?? 'Unknown',
            language: response['original_language'],
            genres: response['genres'].map((genre) => genre['name']).toList(),
            type: response['media_type'] ?? type,
            description: response['overview'] ?? '',
            releaseDate: response['release_date'] ?? '',
            poster: imagePath(
                size: ImageSize.original, path: response['poster_path']),
            rating: response['vote_average'],
            seasons: []);
        if (type == ContentType.tv.value) {
          for (var data in (response['seasons'] as List)) {
            Season season = Season(
                id: data['id'],
                season: data['season_number'],
                airDate: data['air_date']);
            content.seasons?.add(season);
          }
        }
        content.logoPath = await getLogo(id, type);
        return content;
      } catch (e) {
        throw "Failed to load details. Please try again.";
      }
    });
  }

  Future getLogo(id, type) async {
    try {
      final data = await _get('$baseUrl/3/$type/$id/images');
      final response = jsonDecode(data.body);
      var index = 0;
      for (int i = 0; i < response["logos"].length; i++) {
        if (response["logos"][i]["iso_639_1"] == "en") {
          index = i;
          i = response["logos"].length;
        }
      }
      final result = imagePath(
          size: ImageSize.w342, path: response["logos"][index]["file_path"]);
      return result;
    } catch (error) {
      return null;
    }
  }

  Future getEpisodes({required int id, required int season}) async {
    try {
      final data = await _get('$baseUrl/3/tv/$id/season/$season');
      final response = jsonDecode(data.body);
      if (response['status_code'] != null)
        throw Exception("Failed to fetch data");
      final List<Episode> episodes = (response['episodes'] as List)
          .where((episode) => episode['still_path'] != null)
          .map((episode) => Episode(
              id: episode['id'],
              name: episode['name'] ?? 'Unknown',
              episode: episode['episode_number'],
              season: episode['season_number'] ?? 1,
              description: episode['overview'] ?? '',
              airDate: episode['air_date'] ?? "",
              image:
                  'https://wsrv.nl/?url=https://image.tmdb.org/t/p/${ImageSize.w342.value}${episode['still_path']}&output=webp'))
          .toList();
      return episodes;
    } catch (e) {
      throw Exception("Failed to load episodes: ${e.toString()}");
    }
  }

  Future<List<Contentclass>> getRecommendations(
      {required int id, required String type}) async {
    final endpoint = '/recommendations/$type/$id';

    return _fetchWithCache<List<Contentclass>>(endpoint, () async {
      try {
        final data = await _get(
            '$baseUrl/3/$type/$id/recommendations?language=en-US&page=1');
        final response = jsonDecode(data.body);
        if (response['status_code'] != null)
          throw Exception("Failed to fetch data");

        final List<Contentclass> recommendations = (response['results'] as List)
            .where((movie) =>
                movie['backdrop_path'] != null &&
                movie['poster_path'] != null &&
                _isReleased(movie, type))
            .map((movie) => Contentclass(
                id: movie['id'],
                backdrop: imagePath(
                    size: ImageSize.original, path: movie['backdrop_path']),
                title: movie['title'] ?? movie['name'] ?? 'Unknown',
                language: movie['original_language'],
                genres: [],
                type: type,
                description: movie['overview'] ?? '',
                poster: imagePath(
                    size: ImageSize.w342, path: movie['poster_path'])))
            .toList();
        return recommendations;
      } catch (e) {
        throw Exception("Failed to load recommendations: ${e.toString()}");
      }
    });
  }

  Future search({required String query}) async {
    try {
      if (query.isEmpty) throw Exception("Please enter a search query");

      final data = await _get(
          '$baseUrl/3/search/multi?language=en-US&query=$query&page=1&include_adult=false');
      final response = jsonDecode(data.body);
      if (response['status_code'] != null)
        throw Exception("Failed to fetch data");

      final List<Contentclass> searchResults = (response['results'] as List)
          .where((movie) =>
              movie['backdrop_path'] != null &&
              movie['poster_path'] != null &&
              _isReleased(
                  movie, movie['media_type'])) // Add release date filter
          .map((movie) => Contentclass(
              id: movie['id'],
              backdrop: imagePath(
                  size: ImageSize.original, path: movie['backdrop_path']),
              title: movie['title'] ?? movie['name'] ?? 'Unknown',
              language: movie['original_language'],
              genres: [],
              type: movie['media_type'],
              description: movie['overview'] ?? '',
              poster:
                  imagePath(size: ImageSize.w342, path: movie['poster_path'])))
          .toList();
      return searchResults;
    } catch (e) {
      throw Exception("Failed to search: ${e.toString()}");
    }
  }

  Future<String> getExternalIds({required int id, required String type}) async {
    try {
      final data =
          await _get('$baseUrl/3/$type/$id?append_to_response=external_ids');
      final response = jsonDecode(data.body);
      if (response['status_code'] != null) {
        throw Exception("Failed to fetch external IDs");
      }
      return response['external_ids']['imdb_id'] ?? '';
    } catch (e) {
      throw Exception("Failed to load external IDs: ${e.toString()}");
    }
  }
}
