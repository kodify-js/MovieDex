import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/utils.dart';

class Vidsrc {
  final int id;
  final String type;
  final int? episodeNumber,seasonNumber;
  Vidsrc({required this.id,required this.type,this.episodeNumber,this.seasonNumber});
  bool isError = false;

  Future<List<StreamClass>> getStream() async {
    try {
      final response = await http.get(Uri.parse('https://proxy.wafflehacker.io/?destination=https://vidsrc.su/embed/${ContentType.movie.value==type?"movie":"tv"}/$id${ContentType.movie.value==type?"":"/${episodeNumber??"1"}/${seasonNumber??"1"}"}'));
      final script = (response.body.toString()).split("fixedServers = [")[1];
      // Clean the string from comments and extra spaces
      final sourceString = script.split("];")[0];
      // Extract array of objects
      RegExp exp = new RegExp(r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?");
      Iterable<RegExpMatch> matches = exp.allMatches(sourceString).toList().reversed;
      int i = 0;
      final result = matches.map((match) async {
      final url = sourceString.substring(match.start, match.end);
        List<SourceClass> sources = await _getSources(url: url);
        i++;
        return StreamClass(
          language: "original $i",
          url: url,
          sources: sources,
          isError: isError
        );
      }).toList();

      if(result.isEmpty) throw "No valid sources found";
      return Future.wait(result);
    } catch (e) {
      return [];
    }
  }

  Future<List<SourceClass>> _getSources({required String url}) async {
    try {
      if(url.contains(".m3u8")) {
        final response = await http.get(Uri.parse(url));
        final List<String> lines = response.body.split('\n');
        List<SourceClass> sources = [];
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('#EXT-X-STREAM-INF')) {
            // Extract resolution from the info line
            final RegExp resolutionRegex = RegExp(r'RESOLUTION=\d+x(\d+)');
            final match = resolutionRegex.firstMatch(lines[i]);
            
            if (match != null && i + 1 < lines.length) {
              final quality = "${match.group(1)}";
              final streamUrl = lines[i + 1].trim();
              
              // Handle relative URLs
              final Uri baseUri = Uri.parse(url);
              final Uri resolvedUri = baseUri.resolve(streamUrl);
              
              sources.add(SourceClass(
                quality: quality,
                url: resolvedUri.toString(),
              ));
            }
          }
        }
        isError = false;
        if (sources.isEmpty) throw "No valid sources found";
        return sources;
      }
      return [SourceClass(quality: "Auto", url: url)];
    } catch (e) {
      isError = true;
      throw Exception("Failed to load video: ${e.toString()}");
    }
  }
}