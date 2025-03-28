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
import 'package:moviedex/api/api.dart';

/// Handles stream extraction from VidSrc provider
class Vidsrc {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  String? name;
  Vidsrc({
    required this.id,
    required this.type,
    this.name = 'VidSrc.vip (Multi Language <Use Vpn>)',
    this.episodeNumber,
    this.seasonNumber
  });

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = await _buildStreamUrl();
      final response = await http.get(Uri.parse(baseUrl))
        .timeout(const Duration(seconds: 5));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch stream: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      
      // Check if data is a List, if not wrap it in a List
      final contentList = data is List ? data : [data];
      
      if (contentList.isEmpty) {
        throw Exception('No streams available');
      }

      final streams = await Future.wait(
        contentList.map((content) async {
          final m3u8Url = content['m3u8_stream'];
          if (m3u8Url == null || m3u8Url.isEmpty) {
            return null;
          }

          final sources = await _getSources(url: m3u8Url);
          return sources.isEmpty ? null : StreamClass(
            language: content['language'] ?? 'original',
            url: m3u8Url,
            sources: sources,
            isError: false
          );
        })
      );

      // Filter out null values and return valid streams
      return streams.whereType<StreamClass>().toList();
      
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
    final episodeSegment = isMovie ? '' : "&s=${seasonNumber ?? '1'}&e=${episodeNumber ?? '1'}";
    
    final api = Api();
    final imdbId = await api.getExternalIds(id: id, type: type);
    
    if (imdbId.isEmpty) {
        throw Exception("No IMDB ID found for this content");
    }
    
    return 'https://vidsrc.vip/hnd.php?id=$imdbId$episodeSegment';
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