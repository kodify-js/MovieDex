/**
 * VietAutoEmbed Stream Provider
 * 
 * Handles video stream extraction from VietAutoEmbed:
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
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from VietAutoEmbed provider
class VietAutoEmbed {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  String? name;
  VietAutoEmbed({
    required this.id,
    required this.type,
    this.name = 'VietAutoEmbed',
    this.episodeNumber,
    this.seasonNumber
  });

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = _buildStreamUrl();
      final response = await http.get(Uri.parse(baseUrl))
      .timeout(const Duration(seconds: 5));
      isError = response.statusCode != 200;
      return await _parseStreams(response.body);
    } catch (e) {
      isError = true;
      return [];
    }
  }

  String _buildStreamUrl() {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment = isMovie ? '' : "/${seasonNumber ?? '1'}/${episodeNumber ?? '1'}";
    return 'https://simple-proxy.metalewis21.workers.dev/?destination=https://viet.autoembed.cc/${isMovie ? "movie" : "tv"}/$id$episodeSegment';
  }

  Future<List<StreamClass>> _parseStreams(String body) async {
    final List<StreamClass> streams = [];
    final url = body.split("file:")[1].split(",")[0].trim().replaceAll('"', '');
    if (_isValidStreamUrl(url)) {
      final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
        final sources = _parseM3U8Playlist(response.body, url);
        if (sources.isNotEmpty) {
          streams.add(StreamClass(
            language: 'original',
            url: url,
            sources: sources,
            isError: isError
          ));
        }
      }

    return streams;
  }

  bool _isValidStreamUrl(String url) {
    return url.contains('stream') || 
           url.contains('embed') || 
           url.contains('.m3u8') || 
           url.contains('player');
  }

  List<SourceClass> _parseM3U8Playlist(String playlist, String baseUrl) {
    final sources = <SourceClass>[];
    final lines = playlist.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('#EXT-X-STREAM-INF')) {
        final quality = _extractQuality(lines[i]);
        if (quality != null && i + 1 < lines.length) {
          final streamUrl = _resolveStreamUrl(lines[i + 1], baseUrl);
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