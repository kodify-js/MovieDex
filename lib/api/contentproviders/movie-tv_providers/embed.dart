/**
 * Embed Stream Provider
 * 
 * Handles video stream extraction from Embed:
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
import 'package:moviedex/services/proxy_service.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from Embed provider
class Embed {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  String baseUrl = 'https://embed.su';
  String? name;
  Embed(
      {required this.id,
      required this.type,
      this.name = 'Embed.su',
      this.episodeNumber,
      this.seasonNumber});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final url = await _buildStreamUrl();
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch stream: ${response.statusCode}');
      }

      final data = response.body;
      RegExp regExp = RegExp(r"atob\(`([^`]+)`\)");
      final match = regExp.firstMatch(data)!.group(1);
      final decoded = jsonDecode(await stringAtob(match!));
      final mhash = decoded['hash'].toString();
      String firstDecoded = await stringAtob(mhash);
      List<String> firstDecodeParts = firstDecoded.split(".");
      firstDecodeParts = firstDecodeParts
          .map((item) => item.split("").reversed.join(""))
          .toList();
      String secondDecodedString = await stringAtob(
          firstDecodeParts.join("").split("").reversed.join(""));
      return await getAllStreams(jsonDecode(secondDecodedString));
    } catch (e) {
      print('Stream error: $e');
      isError = true;
      return [
        StreamClass(language: 'original', url: '', sources: [], isError: true)
      ];
    }
  }

  Future<String> stringAtob(String base64Str) async {
    base64Str = base64Str.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');

    // Add padding if necessary to make the base64 string a multiple of 4
    int paddingLength = (4 - base64Str.length % 4) % 4;
    base64Str = base64Str + '=' * paddingLength;
    return utf8.decode(base64Decode(base64Str));
  }

  Future<List<StreamClass>> getAllStreams(data) async {
    final streams = (data as List)
        .where((item) => item['name'] == 'viper')
        .map((item) async {
      final url = '$baseUrl/api/e/${item['hash']}';
      final response = await http.get(Uri.parse(url), headers: {
        "Referer": baseUrl,
        "User-Agent":
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        "Accept": "*/*"
      }).timeout(const Duration(seconds: 5));
      final data = jsonDecode(response.body);
<<<<<<< HEAD
<<<<<<< Updated upstream
      final sourceUrl =
          data['source'].toString().replaceAll("embed.su/api/proxy/viper/", "");
=======
      final sourceUrl = data['source'].toString();
>>>>>>> Stashed changes
=======
      print(data);
      final sourceUrl = data['source'].toString();
>>>>>>> a26ee08b469fc3026312200224f337f30c8c7341
      final sources = await _getSources(url: sourceUrl);
      return StreamClass(
          language: 'original',
          url: sourceUrl,
          sources: sources,
          baseUrl: baseUrl,
          isError: isError);
    });
    return Future.wait(streams);
  }

  Future<String> _buildStreamUrl() async {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment =
        isMovie ? '' : "/${seasonNumber ?? '1'}/${episodeNumber ?? '1'}";
    return '$baseUrl/embed/${isMovie ? 'movie' : 'tv'}/$id$episodeSegment';
  }

  /// Extracts quality options from M3U8 playlist or direct URL
  Future<List<SourceClass>> _getSources({required String url}) async {
    try {
      if (!url.contains(".m3u8")) {
        return [SourceClass(quality: "Auto", url: url)];
      }

<<<<<<< HEAD
<<<<<<< Updated upstream
      final response = await http.get(Uri.parse(url));
=======
=======
>>>>>>> a26ee08b469fc3026312200224f337f30c8c7341
      final response = await http.get(Uri.parse(url), headers: {
        "Referer": baseUrl,
        "User-Agent":
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        "Accept": "*/*"
      });
<<<<<<< HEAD
>>>>>>> Stashed changes
=======
      print(response.body);
>>>>>>> a26ee08b469fc3026312200224f337f30c8c7341
      final sources = _parseM3U8Playlist(response.body, url);
      if (sources.isEmpty) throw "No valid sources found";
      isError = false;
      return sources;
    } catch (e) {
      isError = true;
      print("Error: $e");
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
          final streamUrl = _resolveStreamUrl(lines[i + 1]);
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

  String _resolveStreamUrl(String streamUrl) {
    final resolvedUri =
        Uri.parse(baseUrl).resolve(streamUrl.replaceAll('.png', '.m3u8'));
    return resolvedUri.toString();
  }
}
