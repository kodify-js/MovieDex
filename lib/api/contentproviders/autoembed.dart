/**
 * AutoEmbed Stream Provider
 * 
 * Handles video stream extraction from AutoEmbed:
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

/// Handles stream extraction from AutoEmbed provider
class AutoEmbed {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;

  AutoEmbed({
    required this.id,
    required this.type,
    this.episodeNumber,
    this.seasonNumber
  });

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = _buildStreamUrl();
      final response = await http.get(Uri.parse(baseUrl));
      return await _parseStreams(response.body);
    } catch (e) {
      return [];
    }
  }

  String _buildStreamUrl() {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment = isMovie ? '' : "/${seasonNumber ?? '1'}-${episodeNumber ?? '1'}";
    return 'https://autoembed.to/${isMovie ? "movie" : "tv"}/tmdb/$id$episodeSegment';
  }

  Future<List<StreamClass>> _parseStreams(String body) async {
    // Extract stream URLs using regex
    final urlPattern = RegExp(r'https?:\/\/[^\s<>"]+|www\.[^\s<>"]+');
    final matches = urlPattern.allMatches(body);

    if (matches.isEmpty) return [];

    // Convert matches to StreamClass objects
    final List<StreamClass> streams = [];
    for (var match in matches) {
      final url = body.substring(match.start, match.end);
      if (_isValidStreamUrl(url)) {
        final sources = await _getSources(url);
        if (sources.isNotEmpty) {
          streams.add(StreamClass(
            language: "Stream ${streams.length + 1}",
            url: url,
            sources: sources,
            isError: false
          ));
        }
      }
    }

    return streams;
  }

  bool _isValidStreamUrl(String url) {
    return url.contains('stream') || 
           url.contains('embed') || 
           url.contains('player');
  }

  Future<List<SourceClass>> _getSources(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      // Extract quality options
      final qualities = _parseQualities(response.body);
      if (qualities.isEmpty) {
        return [SourceClass(quality: "Auto", url: url)];
      }
      
      return qualities;
    } catch (e) {
      return [];
    }
  }

  List<SourceClass> _parseQualities(String body) {
    final qualities = <SourceClass>[];
    // Add quality parsing logic here based on provider response format
    return qualities;
  }
}