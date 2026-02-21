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
import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:video_player/video_player.dart';

/// Handles stream extraction from Rive provider
class Rive implements Provider {
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
    try {
      final baseUrl = _buildStreamUrl();
      final response = await http.get(Uri.parse(baseUrl));
      isError = response.statusCode != 200;
      final body = response.body;
      final data = await _parseStreams(body);
      return data;
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

  Future<List<StreamClass>> _parseStreams(String body) async {
    try {
      final List<StreamClass> streams = [];
      final List<SourceClass> sources = [];
      final List<SubtitleClass> subtitles = [];
      final document = jsonDecode(body)['data'];
      print(document);
      if (document == null) {
        throw Exception("No data found in Rive response");
      }
      for (final subtitle in document['captions'] ?? []) {
        subtitles.add(SubtitleClass(
          language: subtitle['label'],
          url: subtitle['file'],
          label: subtitle['label'],
        ));
      }
      for (final source in document['sources']) {
        final url = source['url'];
        int qualityValue;
        try {
          qualityValue = int.parse(source['quality'].toString().replaceAll('p', ''));
        } catch (e) {
          qualityValue = 0;
        }
        final headers = Uri.parse(url).queryParameters['headers'];
        final referer = headers != null
          ? jsonDecode(headers)['Referer']
          : "https://rivestream.net";
        if (qualityValue == 0) {
          streams.add(StreamClass(
            language: source['quality'].toString(),
            url: url,
            sources: await _getSources(url, referer),
            subtitles: subtitles,
            formatHint:VideoFormat.other,
          ));
        }else {
          sources.add(SourceClass(
            quality: source['quality'].toString(),
            url: url,
          ));
        }
      }
      if (sources.isNotEmpty) {
        final uri = Uri.parse(document['sources'][0]['url']);
        final url = uri.queryParameters['url'] ?? document['sources'][0]['url'];
        final referer = uri.queryParameters['headers'] != null
          ? jsonDecode(uri.queryParameters['headers']!)['Referer']
          : "https://rivestream.net";
        streams.add(StreamClass(
          language: 'Original',
          url: url,
          sources: sources,
          baseUrl: referer,
          subtitles: subtitles,
          formatHint: VideoFormat.other, 
        ));
      }

      return streams;
    } catch (e) {
      print("Error parsing Rive streams: $e");
      throw Exception("Failed to parse Rive streams: ${e.toString()}");
    }
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
      print(response.body);
      if (response.statusCode != 200) {
        return [];
      }
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
      List<SourceClass> result = data.where((url) => url.contains(".m3u8")).map((link) {
        return SourceClass(
            quality: link.split("/")[0],
            url: '${url.split('/index.m3u8')[0]}/${link.split('\n')[0]}');
      }).toList();
      print(result);
      print(result.isEmpty);
      if (result.isEmpty){
        result = body.split("RESOLUTION=").where((url) => url.contains("stream/")).map((link) {
          final quality = link.split("\n")[0].split("x")[1];
          final streamUrl = link.split("\n")[1].trim();
          print("${url.split('/index.m3u8')[0]}$streamUrl");
          return SourceClass(
              quality: quality,
              url: '${url.split('/index.m3u8')[0]}$streamUrl');
        }).toList();
      }
      isError = false;
      return result;
    } catch (e) {
      isError = true;
      throw Exception("Failed to load video: ${e.toString()}");
    }
  }
}
