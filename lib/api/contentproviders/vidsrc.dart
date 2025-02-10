import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/utils.dart';

class Vidsrc {
  final int id;
  final String type;
  final int? episodeNumber,seasonNumber;
  const Vidsrc({required this.id,required this.type,this.episodeNumber,this.seasonNumber});

  Future<List<StreamClass>> getStream() async {
    try {
      final response = await http.get(Uri.parse('https://proxy.wafflehacker.io/?destination=https://vidsrc.su/embed/${ContentType.movie.value==type?"movie":"tv"}/$id${ContentType.movie.value==type?"":"/${episodeNumber??"1"}/${seasonNumber??"1"}"}'));
      final script = (response.body.toString()).split("fixedServers = [")[1];
      // Clean the string from comments and extra spaces
      final sourceString = script.split("];")[0];
      // Extract array of objects
      RegExp exp = new RegExp(r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?");
      Iterable<RegExpMatch> matches = exp.allMatches(sourceString);
      var i=0;
      final result = matches.map((match) async {
         final url = sourceString.substring(match.start, match.end);
        List<SourceClass> sources = await _getSources(url: url);
        i++;
        return StreamClass(
          language: "original ${i}",
          url: url,
          sources: sources
        );
      }).toList();

      if(result.isEmpty) throw "No valid sources found";
      return Future.wait(result);
    } catch (e) {
      throw Exception("Failed to load video: ${e.toString()}");
    }
  }

  Future<List<SourceClass>> _getSources({required String url}) async {
    try {
      if(url.contains(".m3u8")){
        final response = await http.get(Uri.parse(url));
        final data = response.body.split("\n");
        final result = data.where((url) => url.contains(".m3u8")).map((link) {
        return SourceClass(quality: link.split("/")[0], url: '${url.split('/index.m3u8')[0]}/${link.split('\n')[0]}');
      }).toList();
      }
      return [SourceClass(quality: "Auto", url: url)];
    } catch (e) {
      throw Exception("Failed to load video: ${e.toString()}");
    }
  }
}