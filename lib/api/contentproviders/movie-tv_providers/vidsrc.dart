/**
 * VidSrc Stream Provider
 * 
 * Handles video stream extraction from VidSrc:
 * - Stream URL extraction
 * - Quality parsing
 * - M3U8 playlist handling
 * - Error management
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from VidSrc provider
class Vidsrc {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  String? name;
  Vidsrc(
      {required this.id,
      required this.type,
      this.name = 'VidSrc.vip (Multi Language)',
      this.episodeNumber,
      this.seasonNumber});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = await _buildStreamUrl();
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch stream: ${response.statusCode}');
      }
      List<StreamClass> streams = [];
      List languages = [];
      String lang;
      final data = jsonDecode(response.body);
      for (var value in data.values) {
        if (value == null ||
            value['url'] == "" ||
            value['url']
                .toString()
                .contains("https://proxy.vid1.site/proxy?url=")) continue;
        if (languages.contains(value['language'])) {
          final count = languages
              .where((e) => e.toString().contains(value['language']))
              .length;
          lang = '${value['language']} $count';
          languages.add(lang);
        } else {
          languages.add(value['language'] ?? 'original');
          lang = value['language'];
        }
        final stream = await getAllStreams(value, lang);
        if (!stream.isError) {
          streams.add(stream);
        }
      }
      if (streams.isEmpty) {
        throw Exception('No streams found');
      }
      return streams;
    } catch (e) {
      print('Stream error: $e');
      isError = true;
      return [
        StreamClass(
            language: 'original', url: '', sources: [], isError: isError)
      ];
    }
  }

  Future<StreamClass> getAllStreams(data, language) async {
    final sources = await _getSources(url: data['url']);
    return StreamClass(
        language: language,
        url: data['url'],
        sources: sources,
        isError: isError);
  }

  Future<String> _buildStreamUrl() async {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment =
        isMovie ? '' : "&s=${seasonNumber ?? '1'}&e=${episodeNumber ?? '1'}";
    if (isMovie) {
      final C = id.toString().split("").map((e) {
        final encoding = "abcdefghij";
        return encoding[int.parse(e)];
      }).join("");
      String B = C.split('').reversed.join('');
      String A = base64Encode(utf8.encode(B));
      String D = base64Encode(utf8.encode(A));
      return 'https://api.vid3c.site/allmvse2.php?id=$D';
    } else {
      final formattedString = '${id}-${seasonNumber}-${episodeNumber}';
      final reversedString = formattedString.split('').reversed.join('');
      final firstBase64 = base64Encode(utf8.encode(reversedString));
      final secondBase64 = base64Encode(utf8.encode(firstBase64));
      return 'https://api.vid3c.site/alltvse2.php?id=${secondBase64}';
    }
  }

  /// Extracts quality options from M3U8 playlist or direct URL
  Future<List<SourceClass>> _getSources({required String url}) async {
    try {
      if (!url.contains(".m3u8")) {
        return [SourceClass(quality: "Auto", url: url)];
      }

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      final sources = _parseM3U8Playlist(response.body, url);
      if (sources.isEmpty) throw "No valid sources found";
      isError = false;
      return sources;
    } catch (e) {
      isError = true;
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
          final streamUrl = lines[i + 1].contains("./")
              ? _resolveStreamUrl(lines[i + 1].split('./')[1].trim(), baseUrl)
              : lines[i + 1];
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
    final resolvedUri = '${baseUrl.split('index')[0]}$streamUrl';
    return resolvedUri.toString();
  }
}
