import 'package:moviedex/api/class/source_class.dart';

class StreamClass {
  final String language;
  final List<SourceClass> sources;
  final String url;
  const StreamClass({
    required this.language,
    required this.url,
    required this.sources
  });
}