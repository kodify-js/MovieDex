/**
 * Vidzee Stream Provider
 * 
 * Handles video stream extraction from Vidzee:
 * - Stream source detection
 * - Quality options parsing
 * - Direct link extraction
 * - Error handling
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'dart:convert';

import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from Vidzee provider
class Vidzee {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;

  Vidzee(
      {required this.id,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.name = 'Vidzee (Multi Language)'});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = _buildStreamUrl();
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
    final episodeSegment = isMovie
        ? ''
        : "&season=${seasonNumber ?? '1'}&episode=${episodeNumber ?? '1'}";
    return 'https://hilarious-rugelach-6767a8.netlify.app/?destination=https://vidzee.wtf/${isMovie ? "movie" : "tv"}/player.php?id=$id$episodeSegment';
  }

  Future<List<StreamClass>> _parseStreams(String body) async {
    final List<StreamClass> streams = [];
    final List<SubtitleClass> subtitles = [];
    final document = parse(body);
    final content = document
            .querySelector('div.player-container')
            ?.attributes['data-stream-sources'] ??
        '[]';
    final contentSubtitle = document
            .querySelector('div.player-container')
            ?.attributes['data-initial-subtitles'] ??
        '[]';
    for (var subtitle in jsonDecode(contentSubtitle)) {
      final url = subtitle['url'] ?? '';
      final lang = subtitle['srclang'] ?? '';
      final lable = subtitle['label'] ?? '';
      if (url.isNotEmpty) {
        subtitles.add(SubtitleClass(url: url, language: lang, label: lable));
      }
    }
    final source = jsonDecode(content);
    for (var data in source) {
      final url = Uri.parse(data['url']).queryParameters['url'] ?? '';
      if (_isValidStreamUrl(url)) {
        final sources = await _getSources(url);
        if (sources.isNotEmpty) {
          streams.add(StreamClass(
              language: data['label'],
              url: url,
              sources: sources,
              subtitles: subtitles,
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
