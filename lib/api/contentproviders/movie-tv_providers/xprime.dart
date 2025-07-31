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
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/services/proxy_service.dart';
import 'package:moviedex/utils/utils.dart';

/// Handles stream extraction from AutoEmbed provider
class Xprime {
  final int id;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;

  Xprime(
      {required this.id,
      required this.type,
      this.episodeNumber,
      this.seasonNumber,
      this.name = 'Xprime'});

  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      final baseUrl = await _buildStreamUrl();
      print('Xprime URL: $baseUrl');
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      print('Xprime Response: ${response.statusCode}');
      print('Xprime Response Body: ${response.body}');
      isError = response.statusCode != 200;
      return await _parseStreams(response.body);
    } catch (e) {
      isError = true;
      return [];
    }
  }

  Future<String> _buildStreamUrl() async {
    final isMovie = type == ContentType.movie.value;
    final episodeSegment =
        isMovie ? '' : "&season=${seasonNumber}&episode=${episodeNumber}";
    final proxyUrl = ProxyService.instance.activeProxy ?? "";
    final api = Api();
    Contentclass info = await api.getDetails(id: id, type: type);
    final title = info.title.replaceAll(' ', '%20');
    String year = '2024'; // Default year if not found
    if (type == ContentType.movie.value) {
      year = info.releaseDate.toString().split('-')[0];
    } else {
      for (Season season in info.seasons!) {
        if (season.season == seasonNumber) {
          year = season.airDate.toString().split('-')[0];
        }
      }
    }
    return '${proxyUrl}https://backend.xprime.tv/primebox?name=${title}&year=${year}&fallback_year=${year}${episodeSegment}';
  }

  Future<List<StreamClass>> _parseStreams(String body) async {
    final List<StreamClass> streams = [];
    final List<SourceClass> sources = [];
    final List<SubtitleClass> subtitles = [];
    final data = jsonDecode(body);
    final List available_qualities = data['available_qualities'];
    for (var qualitie in available_qualities) {
      sources.add(SourceClass(
          quality: qualitie.toString().replaceAll("p", ""),
          url: data['streams'][qualitie]));
    }
    for (var subtitle in data['subtitles']) {
      final url = subtitle['file'] ?? '';
      final lang = subtitle['label'] ?? '';
      final label = subtitle['label'] ?? '';
      if (url.isNotEmpty) {
        subtitles.add(SubtitleClass(url: url, language: lang, label: label));
      }
    }
    final url = data['streams'][available_qualities[0]];
    streams.add(StreamClass(
        language: 'original',
        url: url,
        sources: sources,
        subtitles: [],
        isError: isError));

    return streams;
  }
}
