/**
 * Aniwave Stream Provider
 * 
 * Handles video stream extraction from Aniwave:
 * - Stream source detection
 * - Quality options parsing
 * - Direct link extraction
 * - Error handling
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:html/parser.dart';
import 'package:moviedex/api/class/subtitle_class.dart';

/// Handles stream extraction from Aniwave provider
class Gogo {
  final String title;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;
  final List? animeEpisodes;
  final String? airDate;
  Gogo(
      {required this.title,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.airDate,
      this.name = 'GOGO Anime',
      this.animeEpisodes});

  /// Calculates string similarity percentage between two strings
  double _calculateSimilarity(String str1, String str2) {
    // Convert strings to lowercase for case-insensitive comparison
    str1 = str1.toLowerCase();
    str2 = str2.toLowerCase();

    if (str1 == str2) return 100.0; // Exact match
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    // Check if one string contains the other
    if (str1.contains(str2)) return 90.0;
    if (str2.contains(str1)) return 85.0;

    // Calculate Levenshtein distance
    final int len1 = str1.length;
    final int len2 = str2.length;
    List<List<int>> d =
        List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) d[i][0] = i;
    for (int j = 0; j <= len2; j++) d[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        int cost = str1[i - 1] == str2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce((curr, next) => curr < next ? curr : next);
      }
    }

    // Calculate similarity percentage based on edit distance
    double maxLen = len1 > len2 ? len1.toDouble() : len2.toDouble();
    return maxLen > 0
        ? ((maxLen - d[len1][len2].toDouble()) / maxLen) * 100
        : 100.0;
  }

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final List<StreamClass> streams = [];
      final response = await http.get(
          Uri.parse(
              'https://backend.animetsu.to/api/anime/search?query=$title&page=1&perPage=20'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
            'origin': 'https://animetsu.to/',
            'referer': 'https://animetsu.to/',
            'Accept': 'application/json, text/plain, */*',
          });
      final animes = jsonDecode(response.body)['results'];
      final search = animes.map((e) {
        final searchTitle = e['title']['english'] ??
            e['title']['romaji'] ??
            e['title']['native'];
        final matchPercentage = _calculateSimilarity(searchTitle, title);
        final data = {
          "title": searchTitle,
          "id": e['id'],
          "matchPercentage": matchPercentage
        };

        return data;
      }).toList();
      // Sort the search results by match percentage in descending order
      search.sort((a, b) => (b["matchPercentage"] as double)
          .compareTo(a["matchPercentage"] as double));
      // Continue with the highest match
      final id = search.isNotEmpty ? search[0]["id"] : null;
      if (id == null) throw Exception('Failed to fetch stream: No data found');

      final servers = await http.get(
          Uri.parse(
              'https://backend.animetsu.to/api/anime/servers?id=$id&num=$episodeNumber'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
            'origin': 'https://animetsu.to/',
            'referer': 'https://animetsu.to/',
            'Accept': 'application/json, text/plain, */*',
          });
      for (var server in jsonDecode(servers.body)) {
        if (server['id'] == 'pahe') continue; // Skip GogoAnime server
        if (server['hasDub']) {
          final stream =
              await getSource(id, server['id'], 'dub', episodeNumber);
          if (stream != null) streams.add(stream);
        }
        final stream = await getSource(id, server['id'], null, episodeNumber);
        if (stream != null) streams.add(stream);
      }
      if (streams.isEmpty) {
        throw Exception('No streams available');
      }
      return streams;
    } catch (e) {
      print('Stream error: $e');
      isError = true;
      return [];
    }
  }

  Future getSource(id, server, lang, episodes) async {
    try {
      final watchData = await http.get(
          Uri.parse(
              'https://backend.animetsu.to/api/anime/tiddies?server=$server&id=$id&num=$episodes${lang != null ? '&lang=$lang' : ''}'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
            'origin': 'https://animetsu.to/',
            'referer': 'https://animetsu.to/',
            'Accept': 'application/json, text/plain, */*',
          });
      final watchDocument = jsonDecode(watchData.body);
      final sources = watchDocument['sources'];
      List<SourceClass> source = [];
      for (var sourceData in sources) {
        if (sourceData['url'] != null && sourceData['quality'] != null) {
          source.add(SourceClass(
              quality: sourceData['quality'].toString().replaceAll("p", ""),
              url:
                  "https://sl4ytr9k.vlop.fun/m3u8-proxy?url=${sourceData['url'].toString()}&headers=%7B%22referer%22%3A%22https%3A%2F%2Fanimetsu.to%2F%22%2C%22origin%22%3A%22https%3A%2F%2Fanimetsu.to%22%7D"));
        }
      }
      final stream = new StreamClass(
        language: lang == null ? server : "$server-$lang",
        url:
            "https://sl4ytr9k.vlop.fun/m3u8-proxy?url=${sources[0]['url']}&headers=%7B%22referer%22%3A%22https%3A%2F%2Fanimetsu.to%2F%22%2C%22origin%22%3A%22https%3A%2F%2Fanimetsu.to%22%7D",
        sources: source,
        isError: isError,
      );
      return stream;
    } catch (e) {
      print("errpr $e in ${lang}");
      return;
    }
  }
}
