import 'package:hive/hive.dart';

part 'content_class.g.dart';

@HiveType(typeId: 2)
class Contentclass {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String backdrop;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String language;

  @HiveField(4)
  final List<dynamic> genres;

  @HiveField(5)
  final String type;

  @HiveField(6)
  final String description;

  @HiveField(7)
  final String poster;

  @HiveField(8)
  String? logoPath;

  @HiveField(9)
  double? rating;

  @HiveField(10)
  List<Season>? seasons;

  @HiveField(11)
  String? releaseDate;

  Contentclass({
    required this.id,
    required this.backdrop,
    required this.title,
    required this.language,
    required this.genres,
    required this.type,
    required this.description,
    required this.poster,
    this.logoPath,
    this.rating,
    this.seasons,
    this.releaseDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'backdrop': backdrop,
      'title': title,
      'language': language,
      'genres': genres,
      'type': type,
      'description': description,
      'poster': poster,
      'logoPath': logoPath,
      'rating': rating,
      'seasons': seasons?.map((s) => s.toJson()).toList(),
      'releaseDate': releaseDate,
    };
  }

  factory Contentclass.fromJson(Map<String, dynamic> json) {
    return Contentclass(
      id: json['id'] as int,
      title: json['title'] as String,
      poster: json['poster'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      language: json['language'] as String,
      genres: List<dynamic>.from(json['genres']),
      rating: json['rating'] as double?,
      backdrop: json['backdrop'] as String,
      logoPath: json['logoPath'] as String?,
      seasons: (json['seasons'] as List<dynamic>?)
          ?.map((e) => Season.fromJson(e as Map<String, dynamic>))
          .toList(),
      releaseDate: json['releaseDate'] as String?,
    );
  }
}

@HiveType(typeId: 3)
class Season {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int season;

  @HiveField(2)
  final String? airDate;

  Season({
    required this.id,
    required this.season,
    this.airDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'season': season,
      'airDate': airDate,
    };
  }

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] as int,
      season: json['season'] as int,
      airDate: json['airDate'] as String?,
    );
  }
}
