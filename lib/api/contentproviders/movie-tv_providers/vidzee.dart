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

import 'package:appwrite/models.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from Vidzee provider
class Vidzee implements Provider {
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
    final List<StreamClass> streams = [];
    try {
      final lang = [];
      for (int i = 1; i <= 3; i++) {
        final baseUrl = _buildStreamUrl(i);
        final response = await http.get(Uri.parse(baseUrl), headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
          'origin': 'https://player.vidzee.wtf',
          'Accept': '*/*',
        }).timeout(const Duration(seconds: 5));
        isError = response.statusCode != 200;
        if (isError) {
          continue; // Skip to next server if error
        }
        final body = response.body;
        final stream = await _parseStreams(body);
        if (stream.isError) {
          continue; // Skip to next server if error
        }
        if (lang.contains(stream.language)) {
          stream.language = "${stream.language}-$i";
        }
        lang.add(stream.language);
        streams.add(stream);
      }
      return streams;
    } catch (e) {
      isError = true;
      return [];
    }
  }

  String _buildStreamUrl(server) {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment =
        isMovie ? '' : "&ss=${seasonNumber}&ep=${episodeNumber}";
    return 'https://player.vidzee.wtf/api/server?id=${id}&sr=${server}$episodeSegment';
  }

  Future<StreamClass> _parseStreams(String body) async {
    StreamClass streams =
        StreamClass(language: 'original', url: '', sources: [], isError: true);
    final List<SubtitleClass> subtitles = [];
    final document = jsonDecode(body);
    final content = document['url'][0];
    final contentSubtitle = document['tracks'];
    for (var subtitle in contentSubtitle) {
      final url = subtitle['url'] ?? '';
      final lang = subtitle['lang'] ?? '';
      final lable = subtitle['lang'] ?? '';
      if (url.isNotEmpty) {
        subtitles.add(SubtitleClass(url: url, language: lang, label: lable));
      }
    }
    final url =
        Uri.parse(content['link']).queryParameters['url'] ?? content['link'];
    if (_isValidStreamUrl(url)) {
      final sources = await _getSources(url, document['headers']['Referer']);
      streams = StreamClass(
          language: content['lang'],
          url: url,
          sources: sources,
          subtitles: subtitles,
          baseUrl: "https://player.vidzee.wtf",
          isError: isError);
    }

    return streams;
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
        'origin': 'https://player.vidzee.wtf',
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
