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

import 'dart:convert';
import 'dart:io';

import 'package:moviedex/api/contentproviders/anime_providers/gogo.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/Autoembed.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/embed.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidsrc.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidsrcsu.dart';
import 'package:moviedex/api/contentproviders/movie-tv_providers/vidzee.dart';
import 'package:moviedex/api/contentproviders/rive_providers/rive.dart';
import 'package:http/http.dart' as http;

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
  List<Rive> riveProviders = [];
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
  Future<void> loadRiveProviders() async {
    try {
      final baseUrl = "http://scrapper.rivestream.org/api/providers";
      final response = await http.get(Uri.parse(baseUrl));
      final providers = jsonDecode(response.body);
      List<Rive> riveProviders = [];
      for (final provider in providers['data']) {
        riveProviders.add(Rive(
          id: id,
          type: type,
          episodeNumber: episodeNumber,
          seasonNumber: seasonNumber,
          name: provider,
        ));
      }
      this.riveProviders = riveProviders;
    } catch (e) {
      print("Error loading Rive providers: $e");
      this.riveProviders = [];
    }
  }

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

  Gogo get gogo => Gogo(
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
                  Gogo(
                    title: title,
                    type: type,
                    airDate: airDate,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                    animeEpisodes: animeEpisode,
                  ),
                  Vidzee(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  ...this.riveProviders,
                  VidSrcSu(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  Autoembed(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  )
                ]
              : [
                  Gogo(
                    title: title,
                    type: type,
                    airDate: airDate,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                    animeEpisodes: animeEpisode,
                  ),
                  Vidzee(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  ...this.riveProviders,
                  VidSrcSu(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  Autoembed(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  )
                ]
          : Platform.isWindows
              ? [
                  Vidzee(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  ...this.riveProviders,
                  VidSrcSu(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  Autoembed(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                ]
              : [
                  Vidzee(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  ...this.riveProviders,
                  Vidsrc(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                  Autoembed(
                    id: id,
                    type: type,
                    episodeNumber: episodeNumber,
                    seasonNumber: seasonNumber,
                  ),
                ]
      : isAnime == true
          ? Platform.isWindows
              ? [
                  vidzee,
                  gogo,
                  ...this.riveProviders,
                  vidsrc,
                  vidsecsu,
                  autoembed,
                ]
              : [
                  vidzee,
                  gogo,
                  ...this.riveProviders,
                  vidsrc,
                  vidsecsu,
                  embed,
                  autoembed,
                ]
          : Platform.isWindows
              ? [
                  vidzee,
                  ...this.riveProviders,
                  vidsrc,
                  vidsecsu,
                  autoembed,
                ]
              : [
                  vidzee,
                  ...this.riveProviders,
                  vidsrc,
                  embed,
                  vidsecsu,
                  autoembed,
                ];
}
