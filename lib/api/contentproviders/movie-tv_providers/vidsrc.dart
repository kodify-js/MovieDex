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

import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:video_player/video_player.dart';

/// Handles stream extraction from VidSrc provider
class Vidsrc implements Provider {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  String? name;
  Vidsrc(
      {required this.id,
      required this.type,
      this.name = 'MovieDex',
      this.episodeNumber,
      this.seasonNumber});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = await _buildStreamUrl();
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch stream: ${response.statusCode}');
      }
      print(response.body);
      List<StreamClass> streams = [];
      List languages = [];
      String lang;
      final data = parse(response.body);
      final frame = data.querySelector('div #player_iframe');
      final src = "https:${frame?.attributes['src'] ?? ''}";
      final streamData =
          await http.get(Uri.parse(src)).timeout(const Duration(seconds: 10));
      final text = streamData.body.toString();
      final iframeData =
          "https://cloudnestra.com/prorcp/${text.split("'/prorcp/")[1].split("'")[0]}";
      final iframeResponse = await http
          .get(Uri.parse(iframeData))
          .timeout(const Duration(seconds: 10));
      final site = iframeResponse.body.toString();
      final link = site.split("file: '")[1].split("'")[0];
      print(link);
      final sources = await _getSources(url: link);
      streams.add(StreamClass(
          language: 'original',
          url: link,
          sources: sources,
          isError: isError,
          formatHint: VideoFormat.hls,
          baseUrl: "https://cloudnestra.com"));
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

  Future<String> _buildStreamUrl() async {
    final isMovie = type == ContentType.movie.value;
    final tmdbId = await Api().getExternalIds(id: id, type: type);
    if (tmdbId == null) {
      return '';
    }
    if (isMovie) {
      return 'https://vsembed.ru/embed/$tmdbId';
    } else {
      return 'https://vsembed.ru/embed/$tmdbId%26season%3D$seasonNumber%26episode%3D$episodeNumber';
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
          sources.add(SourceClass(
              quality: quality,
              url: "https://tmstr3.shadowlandschronicles.com$streamUrl"));
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
