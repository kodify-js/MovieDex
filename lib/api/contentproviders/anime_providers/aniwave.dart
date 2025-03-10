/**
 * Aniwave Stream Provider
 * 
 * Handles video stream extraction from Aniwave:
 * - Stream source detection
 * - Quality options parsing
 * - Direct link extraction
 * - Error handling
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'package:http/http.dart' as http;
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:html/parser.dart';
import 'package:moviedex/api/class/subtitle_class.dart';

/// Handles stream extraction from Aniwave provider
class Aniwave {
  final String title;
  final String type;
  final int? episodeNumber;
  final int? seasonNumber;
  final String? name;
  bool isError = false;
  final List? animeEpisodes;
  Aniwave({
    required this.title,
    required this.type,
    this.episodeNumber,
    this.seasonNumber,
    this.name = 'Aniwave',
    this.animeEpisodes
  });

  bool isNumeric(String? str) {
  if (str == null) return false;
  return num.tryParse(str) != null;
}
  /// Fetches available streams for content
  Future<List<StreamClass>> getStream() async {
    try {
      List episode = animeEpisodes ?? [];
      final List<StreamClass> streams = [];
      if(episode.isEmpty) {
        final data = await http.get(Uri.parse('https://aniwave.at/catalog?keyword=$title'));
        final document = parse(data.body);
        final infoUrl = document.querySelector("div.group div.relative a")?.attributes['href'];
        if (infoUrl == null) throw Exception('Failed to fetch stream: No data found');
        final infoData = await http.get(Uri.parse('https://aniwave.at$infoUrl'));
        final infoDocument = parse(infoData.body);
        final watchUrl = infoDocument.querySelector("a.bg-white")?.attributes['href']?.split("/watch")[1];
        if (watchUrl == null) throw Exception('Failed to fetch stream: No data found');
        List episodeList = [];
        final watchData = await http.get(Uri.parse('https://aniwave.at/watch$watchUrl'));
        final body = watchData.body;
        String previousEpisode = "";
        final container = body.split('ep_id').where((e)=>e.startsWith('\\"')).map((e)=>e.split("//")[0]).where((e)=>e.contains("ep_no")).where((e)=>!episodeList.contains(e.split("ep_no")[1].split(",")[0].split(":")[1])).map((e){
          String currentEpisode = isNumeric(e.split("ep_no").last.split(",").first.split(":").last)?e.split("ep_no")[1].split(",")[0].split(":")[1]:(double.parse(previousEpisode)-1).toString();
          final data = {
            "episodeId": e.split("ep_no")[0].split(":")[1].split(",")[0],
            "episodeNumber": currentEpisode,
            "watchUrl": watchUrl.split("ep-")[0]+"ep-${e.split("ep_no")[0].split(":")[1].split(",")[0]}"
          };
          previousEpisode = currentEpisode;
          print(data);
          episodeList.add(e.split("ep_no")[1].split(",")[0].split(":")[1]);
          return data;
        }).toList();
        episode = container;
      }
      
      if (episode.isNotEmpty) {
        for(int i = 0; i < episode.length; i++) {
          if(episode[i]["episodeNumber"] == episodeNumber.toString()) {
            final url = episode[i]["watchUrl"];
            final stream = await getSource(url,'sub',episode);
            if(stream != null) {
              streams.add(stream);
            }
            final dubStream = await getSource(url,'dub',episode);
            if(dubStream != null) {
              streams.add(dubStream);
            }
          }
        }
      }

      if (streams.isEmpty) {
        throw Exception('No streams available');
      }
      return streams;
    } catch (e) {
      print('Stream error: $e');
      isError = true;
      return [];
    }
  }

  Future getSource(watchUrl,lang,episodes) async{
    try {
      final watchData = await http.get(Uri.parse('https://aniwave.at/api/jwplayer$watchUrl/hd-1/${lang}'),headers: {
        "Referer": "https://aniwave.at/watch$watchUrl"
      });
      final watchDocument = parse(watchData.body);
      final subUrl = watchDocument.querySelector("media-provider source")?.attributes['src']?.replaceAll("https://cors.hi-anime.site/","");
      final subtitles = watchDocument.querySelectorAll("track").map((e){
        print(e.attributes['src']);
        return SubtitleClass(language: e.attributes['srclang']??"", url: e.attributes['src']??"",label: e.attributes['label']);
        }).toList();
      if (subUrl == null) throw Exception('Failed to fetch stream: No data found');
      final source = await _getSources(subUrl);
      final stream = new StreamClass(
        language: lang,
        url: subUrl,
        sources: source,
        isError: isError,
        subtitles: subtitles,
        animeEpisodes: episodes
      );
      return stream;
    } catch (e) {
      print("errpr $e in ${lang}");
      return;
    }
  }

  Future<List<SourceClass>> _getSources(String url) async {
    try {
      final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 5));
      
      // Extract quality options
      final qualities = _parseM3U8Playlist(response.body,url);
      if (qualities.isEmpty) {
        return [];
      }
      return qualities;
    } catch (e) {
      return [];
    }
  }

  List<SourceClass> _parseM3U8Playlist(String playlist, String baseUrl) {
    final sources = <SourceClass>[];
    final lines = playlist.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('#EXT-X-STREAM-INF')) {
        final quality = _extractQuality(lines[i]);
        if (quality != null && i + 1 < lines.length) {
          final streamUrl = lines[i + 1].contains("https://")?lines[i+1]:_resolveStreamUrl(lines[i + 1], baseUrl);
          sources.add(SourceClass(quality: quality, url: streamUrl));
        }
      }
    }
    return sources;
  }

  String? _extractQuality(String infoLine) {
    final resolutionRegex = RegExp(r'RESOLUTION=\d+x(\d+)');
    final match = resolutionRegex.firstMatch(infoLine);
    return match?.group(1);
  }

  String _resolveStreamUrl(String streamUrl, String baseUrl) {
    final resolvedUri = '${baseUrl.split('master')[0]}$streamUrl';
    return resolvedUri.toString();
  }
}