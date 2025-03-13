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

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/services/proxy_service.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from AutoEmbed provider
class AutoEmbed {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;

  AutoEmbed(
      {required this.id,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.name = 'AutoEmbed (Multi Language <Use Vpn>)'});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = _buildStreamUrl();
      print(baseUrl);
      final response = await http
          .get(Uri.parse(baseUrl))
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
    final episodeSegment =
        isMovie ? '' : "/${seasonNumber ?? '1'}/${episodeNumber ?? '1'}";
    final proxyUrl = ProxyService.instance.activeProxy;
    return '${proxyUrl}https://hin.autoembed.cc/${isMovie ? "movie" : "tv"}/$id$episodeSegment';
  }

  Future<List<StreamClass>> _parseStreams(String body) async {
    final List<StreamClass> streams = [];
    final script = body.split("sources:")[1];
    final List source = jsonDecode('${script.split("],")[0]}]');
    for (var data in source) {
      final url = data['file'];
      if (_isValidStreamUrl(url)) {
        final sources = await _getSources(url);
        if (sources.isNotEmpty) {
          streams.add(StreamClass(
              language: data['label'],
              url: url,
              sources: sources,
              isError: isError));
        }
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

  Future<List<SourceClass>> _getSources(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      // Extract quality options
      final qualities = _parseQualities(response.body, url);
      if (qualities.isEmpty) {
        return [];
      }
      return qualities;
    } catch (e) {
      return [];
    }
  }

  List<SourceClass> _parseQualities(String body, String url) {
    try {
      final data = body.split("./");
      final result = data.where((url) => url.contains(".m3u8")).map((link) {
        return SourceClass(
            quality: link.split("/")[0],
            url: '${url.split('/index.m3u8')[0]}/${link.split('\n')[0]}');
      }).toList();
      isError = false;
      return result;
    } catch (e) {
      isError = true;
      throw Exception("Failed to load video: ${e.toString()}");
    }
  }
}
