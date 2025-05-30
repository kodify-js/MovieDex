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

import 'dart:io';

import 'package:moviedex/api/contentproviders/anime_providers/hianime.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/xprime.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/Autoembed.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/embed.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidsrc.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidsrcsu.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidzee.dart';

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

  final String? airDate;

  final bool? isDownloadMode;

  ContentProvider(
      {required this.id,
      required this.type,
      required this.title,
      this.isAnime = false,
      this.episodeNumber,
      this.airDate,
      this.seasonNumber,
      this.animeEpisode,
      this.isDownloadMode = false});

  /// Access to AutoEmbed provider instance
  Xprime get xprime => Xprime(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  Embed get embed => Embed(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  VidSrcSu get vidsecsu => VidSrcSu(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);
  Autoembed get autoembed => Autoembed(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  Hianime get hianime => Hianime(
      title: title,
      type: type,
      airDate: airDate,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber,
      animeEpisodes: animeEpisode);

  Vidzee get vidzee => Vidzee(
      id: id,
      type: type,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber);

  /// List of all available providers
  List get providers => isDownloadMode == true
      ? isAnime == true
          ? Platform.isWindows
              ? [
                  hianime,
                ]
              : [
                  hianime,
                ]
          : Platform.isWindows
              ? [vidsecsu, xprime, autoembed]
              : [vidzee, vidsecsu, xprime, autoembed]
      : isAnime == true
          ? Platform.isWindows
              ? [
                  vidzee,
                  hianime,
                  vidsecsu,
                  xprime,
                  autoembed,
                ]
              : [
                  vidzee,
                  hianime,
                  vidsecsu,
                  embed,
                  xprime,
                  autoembed,
                ]
          : Platform.isWindows
              ? [vidzee, vidsecsu, autoembed, xprime]
              : [vidzee, embed, vidsecsu, autoembed, xprime];
}
