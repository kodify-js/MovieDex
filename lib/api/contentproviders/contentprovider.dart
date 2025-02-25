/**
 * MovieDex Content Provider Manager
 * 
 * Central manager for all streaming providers that:
 * - Aggregates multiple stream sources
 * - Manages provider instantiation
 * - Handles provider selection
 * - Provides unified access to streams
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'package:moviedex/api/contentproviders/autoembed.dart';
import 'package:moviedex/api/contentproviders/vidsrc.dart';

/// Manages and coordinates multiple streaming providers
class ContentProvider {
  /// Content identifier
  final int id;
  
  /// Content type (movie/tv)
  final String type;
  
  /// Episode number for TV shows
  final int? episodeNumber;
  
  /// Season number for TV shows
  final int? seasonNumber;
  
  /// Additional provider parameters
  late Map<String, dynamic> params;

  ContentProvider({
    required this.id,
    required this.type,
    this.episodeNumber,
    this.seasonNumber
  });

  /// Access to AutoEmbed provider instance
  AutoEmbed get autoembed => AutoEmbed(
    id: id,
    type: type,
    episodeNumber: episodeNumber,
    seasonNumber: seasonNumber
  );

  /// Access to VidSrc provider instance
  Vidsrc get vidsrc => Vidsrc(
    id: id,
    type: type,
    episodeNumber: episodeNumber,
    seasonNumber: seasonNumber
  );
  
  /// List of all available providers
  List get providers => [autoembed, vidsrc];
}