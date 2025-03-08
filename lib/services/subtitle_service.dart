export 'subtitle_parser.dart' show SubtitleEntry;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'subtitle_parser.dart';

class SubtitleService {
  static final SubtitleService instance = SubtitleService._internal();
  
  SubtitleService._internal();

  Future<List<SubtitleEntry>> loadSubtitles(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final subtitleData = utf8.decode(response.bodyBytes);
        return SubtitleParser.parseSrt(subtitleData);
      }
      throw Exception('Failed to load subtitles');
    } catch (e) {
      print('Error loading subtitles: $e');
      return [];
    }
  }
}
