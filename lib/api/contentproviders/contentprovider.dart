import 'package:moviedex/api/contentproviders/autoembed.dart';
import 'package:moviedex/api/contentproviders/vidsrc.dart';

class ContentProvider {
  final int id;
  final String type;
  final int? episodeNumber,seasonNumber;
  late Map<String, dynamic> params;
  ContentProvider({required this.id,required this.type,this.episodeNumber,this.seasonNumber});
  Autoembed get autoembed => Autoembed(id: id,type: type,episodeNumber: episodeNumber,seasonNumber: seasonNumber);
  Vidsrc get vidsrc => Vidsrc(id: id,type: type,episodeNumber: episodeNumber,seasonNumber: seasonNumber);
}