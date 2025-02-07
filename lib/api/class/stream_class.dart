import 'package:moviedex/api/class/source_class.dart';

class StreamClass {
  final String language;
  final List<SourceClass> sources;
  const StreamClass({
    required this.language,
    required this.sources
  });
}