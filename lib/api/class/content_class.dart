class Contentclass {
  int id;
  String backdrop,title,language,description,poster;
  String type;
  String? logoPath;
  double? rating;
  List genres;
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
  });
}