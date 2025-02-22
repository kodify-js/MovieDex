/**
 * MovieDex Utility Functions and Constants
 * 
 * Common utilities for the MovieDex application including:
 * - Content type definitions
 * - Image size configurations
 * - Genre mappings
 * - Path resolvers
 * - Storage helpers
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'package:hive/hive.dart';
import 'package:moviedex/services/cached_image_service.dart';

/// Content type enumeration for Movies and TV Shows
enum ContentType {
  movie("movie"),
  tv("tv");
  
  final String value;
  const ContentType(this.value);
}

/// Image size configuration for TMDB API
enum ImageSize {
  w342("w342"),    // Medium quality
  original("original"); // Full quality
  
  final String value;
  const ImageSize(this.value);
}

/// Standard movie genres from TMDB
final List<Map<String, dynamic>> movieGenres = [
  {"id": 28, "name": "Action"},
  {"id": 12, "name": "Adventure"},
  {"id": 16, "name": "Animation"},
  {"id": 35, "name": "Comedy"},
  {"id": 80, "name": "Crime"},
  {"id": 99, "name": "Documentary"},
  {"id": 18, "name": "Drama"},
  {"id": 10751, "name": "Family"},
  {"id": 14, "name": "Fantasy"},
  {"id": 36, "name": "History"},
  {"id": 27, "name": "Horror"},
  {"id": 10402, "name": "Music"},
  {"id": 9648, "name": "Mystery"},
  {"id": 10749, "name": "Romance"},
  {"id": 878, "name": "Science Fiction"},
  {"id": 10770, "name": "TV Movie"},
  {"id": 53, "name": "Thriller"},
  {"id": 10752, "name": "War"},
  {"id": 37, "name": "Western"}
];

/// Standard TV show genres from TMDB
final List<Map<String, dynamic>> tvGenres = [
  {"id": 10759, "name": "Action & Adventure"},
  {"id": 16, "name": "Animation"},
  {"id": 35, "name": "Comedy"},
  {"id": 80, "name": "Crime"},
  {"id": 99, "name": "Documentary"},
  {"id": 18, "name": "Drama"},
  {"id": 10751, "name": "Family"},
  {"id": 10762, "name": "Kids"},
  {"id": 9648, "name": "Mystery"},
  {"id": 10763, "name": "News"},
  {"id": 10764, "name": "Reality"},
  {"id": 10765, "name": "Sci-Fi & Fantasy"},
  {"id": 10766, "name": "Soap"},
  {"id": 10767, "name": "Talk"},
  {"id": 10768, "name": "War & Politics"},
  {"id": 37, "name": "Western"}
];

/// Constructs optimized image URL with WebP conversion and optional precaching
String imagePath({
  required ImageSize size, 
  required String path, 
  bool precache = false
}) {
  final url = 'https://wsrv.nl/?url=https://image.tmdb.org/t/p/${size.value}$path&output=webp';
  
  if (precache) {
    CachedImageService.instance.precacheImage(url);
  }
  
  return url;
}

/// Helper function for safe Hive storage operations
Future<void> hivePut({
  Box? storage,
  required String key,
  required String value
}) async {
  if (storage?.isOpen ?? false) {
    await storage?.put(key, value);
  }
}