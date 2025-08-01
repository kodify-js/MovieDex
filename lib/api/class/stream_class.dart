import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:video_player/video_player.dart';

class StreamClass {
  String language;
  final List<SourceClass> sources;
  final String url;
  final bool isError;
  final List<SubtitleClass>? subtitles;
  final List? animeEpisodes;
  final String? baseUrl;
  final VideoFormat? formatHint;
  StreamClass(
      {required this.language,
      required this.url,
      this.isError = false,
      required this.sources,
      this.subtitles,
      this.animeEpisodes,
      this.baseUrl,
      this.formatHint});
}
