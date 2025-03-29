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

import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:html/parser.dart';
import 'package:moviedex/api/class/subtitle_class.dart';

/// Handles stream extraction from Aniwave provider
class Aniwave {
  final String title;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;
  final List? animeEpisodes;
  final String? airDate;
  Aniwave(
      {required this.title,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.airDate,
      this.name = 'Aniwave',
      this.animeEpisodes});

  bool isNumeric(String? str) {
    if (str == null) return false;
    return num.tryParse(str) != null;
  }

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
      print(
          'https://aniwave.at/catalog?keyword=$title${airDate != null ? ("&year=${airDate?.split("-").first}") : ""}');
      if (episode.isEmpty) {
        final data = await http.get(Uri.parse(
            'https://aniwave.at/catalog?keyword=$title${airDate != null ? ("&year=${airDate?.split("-").first}") : ""}'));
        final document = parse(data.body);
        final results = document.querySelectorAll("div.mt-6 div.grid a");
        if (results.isEmpty)
          throw Exception('Failed to fetch stream: No data found');
        final search = results.map((e) {
          final searchTitle = e.querySelector("img")?.attributes['alt'] ?? "";
          final matchPercentage = _calculateSimilarity(searchTitle, title);

          final data = {
            "title": searchTitle,
            "url": e.attributes['href'],
            "matchPercentage": matchPercentage
          };
          return data;
        }).toList();

        // Sort the search results by match percentage in descending order
        search.sort((a, b) => (b["matchPercentage"] as double)
            .compareTo(a["matchPercentage"] as double));
        // Continue with the highest match
        final infoUrl = search.isNotEmpty ? search[0]["url"] : null;
        if (infoUrl == null)
          throw Exception('Failed to fetch stream: No data found');
        final infoData =
            await http.get(Uri.parse('https://aniwave.at$infoUrl'));
        final infoDocument = parse(infoData.body);
        final watchUrl = infoDocument
            .querySelector("a.bg-white")
            ?.attributes['href']
            ?.split("/watch")[1];
        if (watchUrl == null)
          throw Exception('Failed to fetch stream: No data found');
        List episodeList = [];
        final watchData =
            await http.get(Uri.parse('https://aniwave.at/watch$watchUrl'));
        final body = watchData.body;
        String previousEpisode =
            "0"; // Default to 0 to avoid parsing an empty string
        final animeId = body.split("animeID")[1].split(":")[1].split(",")[0];
        final container = body
            .split('ep_id')
            .where((e) => e.startsWith('\\"'))
            .map((e) => e.split("//")[0])
            .where((e) => e.contains("ep_no"))
            .where((e) => !episodeList.contains(_safelyGetEpisodeNumber(e)))
            .map((e) {
          String currentEpisode = _safelyGetEpisodeNumber(e);
          // If couldn't parse episode number, decrement previous episode
          if (currentEpisode.isEmpty) {
            try {
              currentEpisode = (int.parse(previousEpisode) - 1).toString();
            } catch (_) {
              currentEpisode = "0"; // Fallback if parsing fails
            }
          }

          String episodeId = _safelyGetEpisodeId(e);
          final data = {
            "episodeId": episodeId,
            "episodeNumber": currentEpisode,
            "watchUrl":
                watchUrl.split("episode-").first + "$animeId-ep-$episodeId"
          };

          if (currentEpisode.isNotEmpty) {
            previousEpisode = currentEpisode;
          }

          episodeList.add(currentEpisode);
          return data;
        }).toList();
        episode = container;
      }

      if (episode.isNotEmpty) {
        for (int i = 0; i < episode.length; i++) {
          if (episode[i]["episodeNumber"] == episodeNumber.toString()) {
            final url = episode[i]["watchUrl"];
            final stream = await getSource(url, 'sub', episode);
            if (stream != null) {
              streams.add(stream);
            }
            final dubStream = await getSource(url, 'dub', episode);
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

  /// Safely extracts episode number avoiding index errors
  String _safelyGetEpisodeNumber(String input) {
    try {
      final parts = input.split("ep_no");
      if (parts.length < 2) return "";

      final numParts = parts[1].split(",");
      if (numParts.isEmpty) return "";

      final valueParts = numParts[0].split(":");
      if (valueParts.length < 2) return "";

      return valueParts[1];
    } catch (e) {
      print("Episode number parsing error: $e");
      return "";
    }
  }

  /// Safely extracts episode ID avoiding index errors
  String _safelyGetEpisodeId(String input) {
    try {
      final parts = input.split("ep_no");
      if (parts.isEmpty) return "";

      final idParts = parts[0].split(":");
      if (idParts.length < 2) return "";

      final valueParts = idParts[1].split(",");
      if (valueParts.isEmpty) return "";

      return valueParts[0];
    } catch (e) {
      print("Episode ID parsing error: $e");
      return "";
    }
  }

  Future getSource(watchUrl, lang, episodes) async {
    try {
      final watchData = await http.get(
          Uri.parse('https://aniwave.at/api/jwplayer$watchUrl/hd-2/${lang}'),
          headers: {"Referer": "https://aniwave.at/watch$watchUrl"});
      final watchDocument = parse(watchData.body);
      final videoUrl = watchDocument
          .querySelector("media-provider source")
          ?.attributes['src']
          ?.replaceAll("https://cors.hi-anime.site/", "")
          .replaceAll("https://cdn.aniwave.lat/", "");
      ;
      final subtitles = watchDocument.querySelectorAll("track").map((e) {
        return SubtitleClass(
            language: e.attributes['srclang'] ?? "",
            url: e.attributes['src'] ?? "",
            label: e.attributes['label']);
      }).toList();
      if (videoUrl == null)
        throw Exception('Failed to fetch stream: No data found');
      final uri = Uri.parse(videoUrl);
      final url = uri.queryParameters['url'] != null
          ? uri.queryParameters['url']!
          : videoUrl;
      final source = await _getSources(url);
      final stream = new StreamClass(
          language: lang,
          url: url,
          sources: source,
          isError: isError,
          subtitles: subtitles,
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
