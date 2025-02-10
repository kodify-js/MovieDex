import 'package:moviedex/api/class/source_class.dart';

class StreamClass {
  final String language;
  final List<SourceClass> sources;
  final String url;
  final bool isError;
  const StreamClass({
    required this.language,
    required this.url,
    this.isError=false,
    required this.sources
  });
}