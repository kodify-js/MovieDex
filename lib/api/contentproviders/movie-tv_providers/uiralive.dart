/**
 * Uiralive Stream Provider
 * 
 * Handles video stream extraction from Uiralive:
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

/// Handles stream extraction from Uiralive provider
class Uiralive {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  final String? name;
  Uiralive({
    required this.id,
    required this.type,
    this.name = 'Uira.live',
    this.episodeNumber,
    this.seasonNumber
  });

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = await _buildStreamUrl();
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
          "sec-fetch-mode": "cors",
          "sec-ch-ua-platform": "Windows",
          "sec-fetch-site": "cross-site", 
          "accept-language": "en-US,en;q=0.9,en-IN;q=0.8",
          "accept": "*/*",
          "accept-encoding": "identity", // Changed to identity to avoid compression
          "Origin": "https://pstream.org"
        }
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to get stream: ${response.statusCode}');
      }

      // Decode with UTF8
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (data == null || data.isEmpty) {
        throw Exception('Empty response from server');
      }

      print('Response data: $data'); // Debug log
      return await getAllStreams(data);
      
    } catch (e) {
      print('Stream error: $e');
      isError = true;
      return [
        StreamClass(
          language: 'original',
          url: '',
          sources: [],
          isError: true
        )
      ];
    }
  }

  Future<List<StreamClass>> getAllStreams(data) async {
    final streams = data.map((content) async {
      final sources = await _getSources(url: content['m3u8_stream']);
      return StreamClass(
        language: content['language'] ?? 'original',
        url: content['m3u8_stream'],
        sources: sources,
        isError: isError
      );
    });
    return Future.wait(streams);
  }

  Future<String> _buildStreamUrl() async {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment = isMovie ? '' : "?s=${seasonNumber ?? '1'}&e=${episodeNumber ?? '1'}";
    return 'https://xj4h5qk3tf7v2mlr9s.uira.live/all/$id$episodeSegment';
  }

  /// Extracts quality options from M3U8 playlist or direct URL
  Future<List<SourceClass>> _getSources({required String url}) async {
    try {
      if (!url.contains(".m3u8")) {
        return [SourceClass(quality: "Auto", url: url)];
      }

      final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
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
          final streamUrl = lines[i + 1].contains("./")?_resolveStreamUrl(lines[i + 1].split('./')[1].trim(), baseUrl):lines[i+1];
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