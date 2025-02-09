import 'package:hive/hive.dart';

enum ContentType{
  movie("movie"),
  tv("tv");
  final String value;
  const ContentType(this.value);
}
enum ImageSize{
  w342("w342"),
  original("original");
  final String value;
  const ImageSize(this.value);
}

List movieGenres = [{"id":28,"name":"Action"},{"id":12,"name":"Adventure"},{"id":16,"name":"Animation"},{"id":35,"name":"Comedy"},{"id":80,"name":"Crime"},{"id":99,"name":"Documentary"},{"id":18,"name":"Drama"},{"id":10751,"name":"Family"},{"id":14,"name":"Fantasy"},{"id":36,"name":"History"},{"id":27,"name":"Horror"},{"id":10402,"name":"Music"},{"id":9648,"name":"Mystery"},{"id":10749,"name":"Romance"},{"id":878,"name":"Science Fiction"},{"id":10770,"name":"TV Movie"},{"id":53,"name":"Thriller"},{"id":10752,"name":"War"},{"id":37,"name":"Western"}];

imagePath({required ImageSize size,required path}){
  return 'https://wsrv.nl/?url=https://image.tmdb.org/t/p/${size.value}$path&output=webp';
}

hivePut({Box? storage,required String key,required String value})async {
  await storage?.put(key, value);
}