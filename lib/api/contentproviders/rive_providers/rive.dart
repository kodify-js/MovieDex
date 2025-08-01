/**
 * Rive Stream Provider
 * 
 * Handles video stream extraction from Rive:
 * - Stream source detection
 * - Quality options parsing
 * - Direct link extraction
 * - Error handling
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'dart:convert';

import 'package:appwrite/models.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:video_player/video_player.dart';

/// Handles stream extraction from Rive provider
class Rive {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;

  Rive(
      {required this.id,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.name = 'Rive'});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    final List<StreamClass> streams = [];
    try {
      final lang = [];
      final baseUrl = _buildStreamUrl();
      final response = await http.get(Uri.parse(baseUrl));
      isError = response.statusCode != 200;
      final body = response.body;
      final data = await _parseStreams(body);
      streams.add(data);
      return streams;
    } catch (e) {
      isError = true;
      return [];
    }
  }

  String _buildStreamUrl() {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment =
        isMovie ? '' : "&season=${seasonNumber}&episode=${episodeNumber}";
    return "http://scrapper.rivestream.org/api/provider?provider=$name&id=$id$episodeSegment";
  }

  Future<StreamClass> _parseStreams(String body) async {
    try {
      StreamClass streams = StreamClass(
          language: 'original', url: '', sources: [], isError: true);
      final List<SubtitleClass> subtitles = [];
      final document = jsonDecode(body)['data'];
      if (document == null) {
        throw Exception("No data found in Rive response");
      }
      final content = document['sources'][0];
      final contentSubtitle = document['captions'] ?? [];
      for (var subtitle in contentSubtitle) {
        final url = subtitle['file'] ?? '';
        final lang = subtitle['label'] ?? '';
        final lable = subtitle['label'] ?? '';
        if (url.isNotEmpty) {
          subtitles.add(SubtitleClass(url: url, language: lang, label: lable));
        }
      }
      List<SourceClass> sources = [];
      final url =
          Uri.parse(content['url']).queryParameters['url'] ?? content['url'];
      print("Rive Stream URL: $url");
      final headers = Uri.parse(content['url']).queryParameters['headers'];
      final referer = headers != null
          ? jsonDecode(headers)['Referer']
          : "https://rivestream.net";
      print("Rive Referer: $referer");
      if (content['format'] != "hls" && content['format'] != "m3u8") {
        for (final source in document['sources']) {
          sources.add(SourceClass(
            quality: source['quality'].toString(),
            url: url,
          ));
        }
      } else {
        if (_isValidStreamUrl(url)) {
          sources = await _getSources(url, referer);
        }
      }
      streams = StreamClass(
          language: 'original',
          url: url,
          sources: sources,
          subtitles: subtitles,
          baseUrl: referer,
          formatHint: content['format'] != 'hls' && content['format'] != 'm3u8'
              ? VideoFormat.other
              : VideoFormat.hls,
          isError: isError);

      return streams;
    } catch (e) {
      print("Error parsing Rive streams: $e");
      throw Exception("Failed to parse Rive streams: ${e.toString()}");
    }
  }

  bool _isValidStreamUrl(String url) {
    return url.contains('stream') ||
        url.contains('embed') ||
        url.contains('.m3u8') ||
        url.contains('player');
  }

  Future<List<SourceClass>> _getSources(String url, String referer) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
        'origin': referer,
        'Accept': '*/*',
        'referer': referer,
      }).timeout(const Duration(seconds: 5));
      // Extract quality options
      if (response.body.toString().contains(".ts") &&
          !response.body.toString().contains(".m3u8")) {
        return [SourceClass(quality: 'auto', url: url)];
      }
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
