/**
 * Coitus Stream Provider
 * 
 * Handles video stream extraction from Coitus:
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
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/services/proxy_service.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from Coitus provider
class Autoembed {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  final String? name;
  Autoembed(
      {required this.id,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.name = 'Autoembed'});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = await _buildStreamUrl();
      print('Autoembed URL: $baseUrl');
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch stream: ${response.statusCode}');
      }
      print(response.body);
      final data = jsonDecode(response.body);

      // Check if data is a List, if not wrap it in a List
      final contentList = data is List ? data : [data];

      if (contentList.isEmpty) {
        throw Exception('No streams available');
      }

      final streams = await Future.wait(contentList.map((content) async {
        final m3u8Url = content['source']['files'][0]['file'] as String?;
        if (m3u8Url == null || m3u8Url.isEmpty) {
          return null;
        }

        final sources =
            await _getSources(sourcesData: content['source']['files']);

        List<SubtitleClass> subtitles = [];
        for (var subtitle in content['source']['subtitles']) {
          subtitles.add(SubtitleClass(
              url: subtitle['url'] ?? '',
              language: subtitle['lang'] ?? 'unknown',
              label: subtitle['lang'] ?? 'unknown'));
        }
        return sources.isEmpty
            ? null
            : StreamClass(
                language: content['language'] ?? 'original',
                url: m3u8Url,
                sources: sources,
                subtitles: subtitles,
                isError: false);
      }));

      // Filter out null values and return valid streams
      return streams.whereType<StreamClass>().toList();
    } catch (e) {
      print('Stream error: $e');
      isError = true;
      return [
        StreamClass(language: 'original', url: '', sources: [], isError: true)
      ];
    }
  }

  Future<String> _buildStreamUrl() async {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment =
        isMovie ? '' : "/${seasonNumber ?? '1'}/${episodeNumber ?? '1'}";
    final proxyUrl = ProxyService.instance.activeProxy;
    return '${proxyUrl}https://flix.1anime.app/${isMovie ? "movie" : "tv"}/autoembed/${id}$episodeSegment';
  }

  /// Extracts quality options from M3U8 playlist or direct URL
  Future<List<SourceClass>> _getSources({required List sourcesData}) async {
    try {
      if (sourcesData.isEmpty) throw "No valid sources found";
      List<SourceClass> sources = [];
      isError = false;
      for (var source in sourcesData) {
        sources.add(SourceClass(
          quality: source['quality'] ?? 'unknown',
          url: source['file'] ?? '',
        ));
      }
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
