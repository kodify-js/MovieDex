import 'dart:convert';

import 'package:moviedex/api/contentproviders/autoembed.dart';
import 'package:http/http.dart' as http;

class ContentProvider {
  final int id;
  late Map<String, dynamic> params;
  ContentProvider({required this.id});
  Autoembed get autoembed => Autoembed(id: id);
}