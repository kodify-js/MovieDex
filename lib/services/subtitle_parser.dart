import 'dart:convert';

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

class SubtitleParser {
  static Duration _parseTimecode(String timecode) {
    final parts = timecode.split(':');
    final seconds = parts[2].split(',');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(seconds[0]),
      milliseconds: int.parse(seconds[1]),
    );
  }

  static List<SubtitleEntry> parseSrt(String data) {
    final entries = <SubtitleEntry>[];
    final lines = LineSplitter.split(data).toList();
    var i = 0;

    while (i < lines.length) {
      // Skip empty lines and index numbers
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      if (i >= lines.length) break;

      // Skip subtitle number
      i++;
      if (i >= lines.length) break;

      // Parse timecode
      final timeLine = lines[i].split(' --> ');
      if (timeLine.length != 2) {
        i++;
        continue;
      }

      final start = _parseTimecode(timeLine[0]);
      final end = _parseTimecode(timeLine[1]);
      i++;

      // Parse text
      var text = StringBuffer();
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        text.write(lines[i]);
        text.write('\n');
        i++;
      }

      if (text.isNotEmpty) {
        entries.add(SubtitleEntry(
          start: start,
          end: end,
          text: text.toString().trim(),
        ));
      }
    }
    return entries;
  }

  static List<SubtitleEntry> parseVtt(String data) {
    // Remove WEBVTT header
    final content = data.replaceFirst(RegExp(r'^WEBVTT\n'), '');
    print(content);
    return parseSrt(content);
  }
}
