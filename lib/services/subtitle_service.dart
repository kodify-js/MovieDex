export 'subtitle_parser.dart' show SubtitleEntry;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SubtitleEntry {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleEntry({
    required this.start,
    required this.end,
    required this.text,
  });
}

class SubtitleService {
  SubtitleService._privateConstructor();
  static final SubtitleService _instance =
      SubtitleService._privateConstructor();
  static SubtitleService get instance => _instance;

  Future<List<SubtitleEntry>> loadSubtitles(String url) async {
    try {
      String subtitleContent;

      // Handle base64 data URLs
      if (url.startsWith('data:')) {
        if (url.startsWith('data:text/vtt;base64,')) {
          final base64Content = url.substring('data:text/vtt;base64,'.length);
          subtitleContent = _decodeBase64Content(base64Content);
        } else if (url.startsWith('data:text/plain;base64,')) {
          final base64Content = url.substring('data:text/plain;base64,'.length);
          subtitleContent = _decodeBase64Content(base64Content);
        } else {
          // Try to extract the base64 content from any data URL
          final parts = url.split(';base64,');
          if (parts.length > 1) {
            subtitleContent = _decodeBase64Content(parts[1]);
          } else {
            throw Exception("Unsupported data URL format");
          }
        }
      } else {
        // Regular HTTP fetch for normal URLs
        subtitleContent = await _fetchSubtitleContent(url);
      }

      // Improved format detection
      if (_isVttFormat(subtitleContent)) {
        return _parseVTT(subtitleContent);
      } else {
        return _parseSRT(subtitleContent);
      }
    } catch (e) {
      debugPrint('Error loading subtitles: $e');
      return [];
    }
  }

  // Helper to decode base64 content with fallback options
  String _decodeBase64Content(String base64Content) {
    try {
      return utf8.decode(base64Decode(base64Content), allowMalformed: true);
    } catch (e) {
      try {
        return latin1.decode(base64Decode(base64Content));
      } catch (e2) {
        // Last resort
        var bytes = base64Decode(base64Content);
        return String.fromCharCodes(bytes);
      }
    }
  }

  // Helper to fetch subtitle content with encoding fallbacks
  Future<String> _fetchSubtitleContent(String url) async {
    final response = await http.get(Uri.parse(url));
    try {
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (e) {
      try {
        return latin1.decode(response.bodyBytes);
      } catch (e2) {
        // Last resort
        return response.body;
      }
    }
  }

  // Better detection of VTT format
  bool _isVttFormat(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('WEBVTT') || trimmed.contains('\nWEBVTT');
  }

  // Enhance the clean subtitle method to better handle Arabic text
  String _cleanSubtitleText(String text) {
    // Remove common HTML tags
    String cleanedText = text
        .replaceAll(RegExp(r'<\/?i>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?b>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?u>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?font[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?span[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?div[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\/?p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s?\/?>', caseSensitive: false), '\n');

    // Replace HTML entities
    cleanedText = cleanedText
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    // Fix common issues with Arabic text direction markers
    cleanedText = cleanedText
        .replaceAll('\u200E', '') // Remove LTR mark
        .replaceAll('\u200F', ''); // Remove RTL mark

    // Handle all remaining HTML tags
    cleanedText = cleanedText.replaceAll(RegExp(r'<[^>]*>'), '');

    return cleanedText;
  }

  List<SubtitleEntry> _parseVTT(String vttContent) {
    final List<SubtitleEntry> entries = [];
    final lines = vttContent.split('\n');

    int lineIndex = 0;

    // Skip WEBVTT header and any metadata
    while (lineIndex < lines.length && !lines[lineIndex].contains('-->')) {
      lineIndex++;
    }

    while (lineIndex < lines.length) {
      // Find timestamp line
      if (lineIndex < lines.length && lines[lineIndex].contains('-->')) {
        final timecodeLine = lines[lineIndex];
        final timecodes = _parseTimeCodes(timecodeLine);
        lineIndex++;

        // Get subtitle text
        String subtitleText = '';
        while (lineIndex < lines.length && lines[lineIndex].trim().isNotEmpty) {
          if (subtitleText.isNotEmpty) subtitleText += '\n';
          subtitleText += lines[lineIndex];
          lineIndex++;
        }

        if (timecodes != null && subtitleText.isNotEmpty) {
          entries.add(SubtitleEntry(
            start: timecodes[0],
            end: timecodes[1],
            text: _cleanSubtitleText(subtitleText),
          ));
        }
      } else {
        lineIndex++;
      }
    }

    return entries;
  }

  List<SubtitleEntry> _parseSRT(String srtContent) {
    final List<SubtitleEntry> entries = [];
    final List<String> lines = srtContent.split('\n');

    int lineIndex = 0;

    while (lineIndex < lines.length) {
      // Skip empty lines
      while (lineIndex < lines.length && lines[lineIndex].trim().isEmpty) {
        lineIndex++;
      }

      if (lineIndex >= lines.length) break;

      // Skip sequence number (may or may not be a number)
      lineIndex++;

      // Parse timestamp if available
      if (lineIndex < lines.length && lines[lineIndex].contains('-->')) {
        final timecodes = _parseTimeCodes(lines[lineIndex]);
        lineIndex++;

        // Get subtitle text
        String subtitleText = '';
        while (lineIndex < lines.length && lines[lineIndex].trim().isNotEmpty) {
          if (subtitleText.isNotEmpty) subtitleText += '\n';
          subtitleText += lines[lineIndex];
          lineIndex++;
        }

        if (timecodes != null && subtitleText.isNotEmpty) {
          entries.add(SubtitleEntry(
            start: timecodes[0],
            end: timecodes[1],
            text: _cleanSubtitleText(subtitleText),
          ));
        }
      } else {
        // If no timestamp found, skip to next line
        lineIndex++;
      }
    }

    return entries;
  }

  List<Duration>? _parseTimeCodes(String line) {
    // First try HH:MM:SS.mmm format (VTT and SRT both use this)
    final regex = RegExp(
        r'(\d{1,2}):(\d{2}):(\d{2})[\.,](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[\.,](\d{1,3})');
    final match = regex.firstMatch(line);

    if (match != null) {
      final startHours = int.parse(match.group(1)!);
      final startMinutes = int.parse(match.group(2)!);
      final startSeconds = int.parse(match.group(3)!);
      String startMillisStr = match.group(4)!;
      while (startMillisStr.length < 3)
        startMillisStr += '0'; // Pad to 3 digits
      final startMillis = int.parse(startMillisStr);

      final endHours = int.parse(match.group(5)!);
      final endMinutes = int.parse(match.group(6)!);
      final endSeconds = int.parse(match.group(7)!);
      String endMillisStr = match.group(8)!;
      while (endMillisStr.length < 3) endMillisStr += '0'; // Pad to 3 digits
      final endMillis = int.parse(endMillisStr);

      final start = Duration(
        hours: startHours,
        minutes: startMinutes,
        seconds: startSeconds,
        milliseconds: startMillis,
      );

      final end = Duration(
        hours: endHours,
        minutes: endMinutes,
        seconds: endSeconds,
        milliseconds: endMillis,
      );

      return [start, end];
    }

    // Then try MM:SS.mmm format (some VTT uses this shorter format)
    final altRegex = RegExp(
        r'(\d{1,2}):(\d{2})[\.,](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2})[\.,](\d{1,3})');
    final altMatch = altRegex.firstMatch(line);

    if (altMatch != null) {
      final startMinutes = int.parse(altMatch.group(1)!);
      final startSeconds = int.parse(altMatch.group(2)!);
      String startMillisStr = altMatch.group(3)!;
      while (startMillisStr.length < 3) startMillisStr += '0';
      final startMillis = int.parse(startMillisStr);

      final endMinutes = int.parse(altMatch.group(4)!);
      final endSeconds = int.parse(altMatch.group(5)!);
      String endMillisStr = altMatch.group(6)!;
      while (endMillisStr.length < 3) endMillisStr += '0';
      final endMillis = int.parse(endMillisStr);

      final start = Duration(
        minutes: startMinutes,
        seconds: startSeconds,
        milliseconds: startMillis,
      );

      final end = Duration(
        minutes: endMinutes,
        seconds: endSeconds,
        milliseconds: endMillis,
      );

      return [start, end];
    }

    return null;
  }
}
