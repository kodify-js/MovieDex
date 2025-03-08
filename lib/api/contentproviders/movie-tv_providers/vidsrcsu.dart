/**
 * VidSrcSu Stream Provider
 * 
 * Handles video stream extraction from VidSrcSu:
 * - Stream URL extraction
 * - Quality parsing
 * - M3U8 playlist handling
 * - Error management
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from VidSrcSu provider
class VidSrcSu {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  bool isError = false;
  String baseUrl = 'https://VidSrc.su';
  VidSrcSu({
    required this.id,
    required this.type,
    this.episodeNumber,
    this.seasonNumber
  });

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = await _buildStreamUrl();
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {"User-Agent": "Mozilla/5.0",  
    "Accept": "text/html"}      
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch stream: ${response.statusCode}');
      }
      final data = response.body;
      // get all the links from the page
      final links = RegExp(r"url: '([^']+)'").allMatches(data).map((e) => e.group(1)).where((item)=>item!.contains(".m3u8")).toList();
      if (links.isEmpty) throw "No valid stream found";
      List<StreamClass> streams = [];
      int i = 0;
      for (var link in links){
        if(!link!.contains(".m3u8")) continue;
        i++;
        final sources = await _getSources(url: link);
        streams.add(
          StreamClass(
            language: 'original $i',
            url: link,
            sources: sources,
            isError: isError
          )
        );

      }
      return streams;
      
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

  Future<String> _buildStreamUrl() async {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment = isMovie ? '' : "/${seasonNumber ?? '1'}/${episodeNumber ?? '1'}";

    return '$baseUrl/embed/${isMovie ? 'movie' : 'tv'}/$id$episodeSegment';
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