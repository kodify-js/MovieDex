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
class Hianime {
  final String title;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;
  final List? animeEpisodes;
  final String? airDate;
  Hianime(
      {required this.title,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.airDate,
      this.name = 'Hianime',
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
      List episode = animeEpisodes ?? [];
      final List<StreamClass> streams = [];
      if (episode.isEmpty) {
        final response = await http.get(
            Uri.parse(
                'https://hianime.pstream.org/api/v2/hianime/search?q=${title}'),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
              'origin': 'https://hianime.pstream.org/',
              'Accept': '*/*',
            });
        final animes = jsonDecode(response.body)['data']['animes'];
        final search = animes.map((e) {
          final searchTitle = e['name'] ?? "";
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
        if (id == null)
          throw Exception('Failed to fetch stream: No data found');
        List episodeList = [];
        final episodes = await http.get(
            Uri.parse(
                'https://hianime.pstream.org/api/v2/hianime/anime/${id}/episodes'),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
              'origin': 'https://hianime.pstream.org/',
              'Accept': '*/*',
            });
        final body = jsonDecode(episodes.body);
        for (var e in body['data']['episodes']) {
          episodeList.add({
            "episodeNumber": e['number'].toString(),
            "id": e['episodeId'],
          });
        }
        episode = episodeList;
      }
      if (episode.isNotEmpty) {
        for (int i = 0; i < episode.length; i++) {
          if (episode[i]["episodeNumber"].toString() ==
              episodeNumber.toString()) {
            final id = episode[i]["id"];
            final stream = await getSource(id, 'sub', episode);
            if (stream != null) {
              streams.add(stream);
            }
            final dubStream = await getSource(id, 'dub', episode);
            if (dubStream != null) {
              streams.add(dubStream);
            }
          }
        }
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

  Future getSource(id, lang, episodes) async {
    try {
      final watchData = await http.get(
          Uri.parse(
              'https://hianime.pstream.org/api/v2/hianime/episode/sources?animeEpisodeId=${id}&server=hd-2&category=${lang}'),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
            'origin': 'https://hianime.pstream.org/',
            'Accept': '*/*',
          });
      final watchDocument = jsonDecode(watchData.body);
      final videoUrl = watchDocument['data']['sources'][0]['url'];
      if (videoUrl == null)
        throw Exception('Failed to fetch stream: No data found');
      final uri = Uri.parse(videoUrl);
      final url = uri.queryParameters['url'] != null
          ? uri.queryParameters['url']!
          : videoUrl;
      final source = await _getSources(url);
      List<SubtitleClass> subtitleClass = [];
      for (var subtitle in watchDocument['data']['tracks']) {
        if (subtitle['kind'] == "captions") {
          subtitleClass.add(SubtitleClass(
            language: subtitle['label'] ?? 'Unknown',
            label: subtitle['label'] ?? 'Unknown',
            url: subtitle['file'] ?? '',
          ));
        }
      }
      final stream = new StreamClass(
          language: lang,
          url: url,
          sources: source,
          isError: isError,
          subtitles: subtitleClass,
          animeEpisodes: episodes);
      return stream;
    } catch (e) {
      print("errpr $e in ${lang}");
      return;
    }
  }

  Future<List<SourceClass>> _getSources(String url) async {
    try {
      final newUrl = Uri.parse(url);
      final response = await http
          .get(newUrl.queryParameters['url'] != null
              ? Uri.parse(newUrl.queryParameters['url']!)
              : newUrl)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return [];
      }
      // Extract quality options
      final qualities = _parseM3U8Playlist(
          response.body,
          newUrl.queryParameters['url'] != null
              ? newUrl.queryParameters['url']!
              : url);
      if (qualities.isEmpty) {
        return [];
      }
      return qualities;
    } catch (e) {
      return [];
    }
  }

  List<SourceClass> _parseM3U8Playlist(String playlist, String baseUrl) {
    final sources = <SourceClass>[];
    final lines = playlist.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('#EXT-X-STREAM-INF')) {
        final quality = _extractQuality(lines[i]);
        if (quality != null && i + 1 < lines.length) {
          final streamUrl = lines[i + 1].contains("https://")
              ? lines[i + 1]
              : _resolveStreamUrl(lines[i + 1], baseUrl);
          sources.add(SourceClass(quality: quality, url: streamUrl));
        }
      }
    }
    return sources;
  }

  String? _extractQuality(String infoLine) {
    final resolutionRegex = RegExp(r'RESOLUTION=\d+x(\d+)');
    final match = resolutionRegex.firstMatch(infoLine);
    return match?.group(1);
  }

  String _resolveStreamUrl(String streamUrl, String baseUrl) {
    final resolvedUri = '${baseUrl.split('master')[0]}$streamUrl';
    return resolvedUri.toString();
  }
}
