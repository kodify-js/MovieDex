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

import 'package:moviedex/api/contentproviders/anime_providers/aniwave.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/autoembed.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/coitus.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/embed.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidsrc.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidsrcsu.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vietautoembed.dart';

/// Manages and coordinates multiple streaming providers
class ContentProvider {
  /// Content identifier

  final String title;
  final int id;

  /// Content type (movie/tv)
  final String type;

  /// Episode number for TV shows
  final int? episodeNumber;

  /// Season number for TV shows
  final int? seasonNumber;

  final List? animeEpisode;

  final bool? isAnime;

  ContentProvider(
      {required this.id,
      required this.type,
      required this.title,
      this.isAnime = false,
      this.episodeNumber,
      this.seasonNumber,
      this.animeEpisode});

  /// Access to AutoEmbed provider instance
  AutoEmbed get autoembed => AutoEmbed(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  /// Access to VidSrc provider instance
  Vidsrc get vidsrc => Vidsrc(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  Embed get embed => Embed(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  VietAutoEmbed get vietautoembed => VietAutoEmbed(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  VidSrcSu get vidsecsu => VidSrcSu(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);
  Coitus get coitus => Coitus(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  Aniwave get aniwave => Aniwave(
      title: title,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber,
      animeEpisodes: animeEpisode);

  /// List of all available providers
  List get providers => isAnime == true
      ? [autoembed, vidsrc, aniwave, vidsecsu, vietautoembed, coitus, embed]
      : [autoembed, vidsrc, vidsecsu, vietautoembed, coitus, embed];
}
