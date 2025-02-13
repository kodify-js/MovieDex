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

  Vidsrc({
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
    final episodeSegment = isMovie ? '' : "/${episodeNumber ?? '1'}/${seasonNumber ?? '1'}";
    return 'https://proxy.wafflehacker.io/?destination=https://vidsrc.su/embed/${isMovie ? "movie" : "tv"}/$id$episodeSegment';
  }

  Future<List<StreamClass>> _parseStreams(String body) async {
    final script = body.split("fixedServers = [")[1];
    final sourceString = script.split("];")[0];
    
    // Extract valid URLs
    final urlPattern = RegExp(r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?");
    final matches = urlPattern.allMatches(sourceString).toList().reversed;

    // Convert matches to StreamClass objects
    final streams = matches.map((match) async {
      final url = sourceString.substring(match.start, match.end);
      final sources = await _getSources(url: url);
      return StreamClass(
        language: "Stream ${matches.length - matches.toList().indexOf(match)}",
        url: url,
        sources: sources,
        isError: isError
      );
    }).toList();

    return Future.wait(streams);
  }

  /// Extracts quality options from M3U8 playlist or direct URL
  Future<List<SourceClass>> _getSources({required String url}) async {
    try {
      if (!url.contains(".m3u8")) {
        return [SourceClass(quality: "Auto", url: url)];
      }

      final response = await http.get(Uri.parse(url));
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
          final streamUrl = _resolveStreamUrl(lines[i + 1].trim(), baseUrl);
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
    final baseUri = Uri.parse(baseUrl);
    final resolvedUri = baseUri.resolve(streamUrl);
    return resolvedUri.toString();
  }
}