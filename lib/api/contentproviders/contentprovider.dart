import 'package:moviedex/api/contentproviders/autoembed.dart';

class ContentProvider {
  final int id;
  late Map<String, dynamic> params;
  ContentProvider({required this.id});
  Autoembed get autoembed => Autoembed(id: id);
}