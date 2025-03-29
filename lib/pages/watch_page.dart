import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:flutter/services.dart';
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/api/class/server_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:moviedex/components/content_player.dart';
import 'package:lottie/lottie.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:moviedex/services/settings_service.dart';

class WatchPage extends StatefulWidget {
  final Contentclass data;
  final int? episodeNumber, seasonNumber;
  final String title;
  final Box? storage; // Add storage parameter
  final int? providerIndex;
  final String? airDate;
  const WatchPage({
    super.key,
    required this.data,
    this.episodeNumber,
    this.seasonNumber,
    required this.title,
    this.storage,
    this.airDate,
    this.providerIndex = 0,
  });

  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> with WidgetsBindingObserver {
  TextEditingController textEditingController = TextEditingController();
  late ContentProvider contentProvider;
  int _providerIndex = 0;
  List<StreamClass> _stream = [];
  bool isError = false;
  List<Episode>? episodes;
  bool isLoading = true;
  int? currentEpisodeNumber;
  int? currentSeasonNumber;
  Box? storage;
  List<String> _addedSub = [];
  List<SubtitleClass>? subtitles;
  List<ServerClass> servers = [];

  void getStream() async {
    try {
      if (_providerIndex >= contentProvider.providers.length) {
        setState(() {
          isError = true;
        });
        return;
      }
      _stream = await contentProvider.providers[_providerIndex].getStream();
      _stream = _stream.where((element) => !element.isError).toList();
      if (_stream.isEmpty) {
        setState(() {
          servers[_providerIndex].status = ServerStatus.unavailable;
          _providerIndex++;
          if (_providerIndex < contentProvider.providers.length) {
            getStream();
          } else {
            isError = true;
          }
        });
      } else {
        setState(() {
          servers[_providerIndex].status = ServerStatus.active;

          // Save this working server as preference
          _savePreferredServer(servers[_providerIndex].name);
          if (_stream.first.subtitles != null &&
              _stream.first.subtitles!.isNotEmpty) {
            subtitles = _stream.first.subtitles;
          } else {
            getSubtitles(
                episode: contentProvider.episodeNumber,
                season: contentProvider.seasonNumber);
          }
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isError = true;
      });
    }
  }

  void getSubtitles({int? id, int? episode, int? season}) async {
    try {
      final api = new Api();
      final imdbId = await api.getExternalIds(
          id: id ?? widget.data.id, type: widget.data.type);
      if (imdbId.isEmpty) {
        throw Exception("No IMDB ID found for this content");
      }
      final data = await http.get(Uri.parse(widget.data.type ==
              ContentType.tv.value
          ? 'https://hilarious-rugelach-6767a8.netlify.app/?destination=https%3A%2F%2Frest.opensubtitles.org%2Fsearch%2Fepisode-${episode ?? widget.episodeNumber}%2Fimdbid-${imdbId.replaceAll("tt", "")}%2Fseason-${season ?? widget.seasonNumber}'
          : 'https://hilarious-rugelach-6767a8.netlify.app/?destination=https%3A%2F%2Frest.opensubtitles.org%2Fsearch%2Fimdbid-${imdbId.replaceAll("tt", "")}'));
      final response = jsonDecode(data.body);
      setState(() {
        subtitles = (response as List)
            .where((e) => !_addedSub.contains(e['LanguageName']))
            .where((e) => e['SubFormat'] == 'srt')
            .map((e) {
          _addedSub.add(e['LanguageName']);
          return SubtitleClass(
              language: e['SubLanguageID'],
              url: e['SubDownloadLink'].split(".gz")[0],
              label: e['LanguageName']);
        }).toList();
      });
    } catch (e) {
      subtitles = [];
    }
  }

  @override
  void initState() {
    super.initState();
    // Register as lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    currentEpisodeNumber = widget.episodeNumber;
    currentSeasonNumber = widget.seasonNumber;

    // Use provided storage or create new one
    storage = widget.storage;
    if (storage == null || !storage!.isOpen) {
      _initStorage();
    }

    if (widget.data.type == ContentType.tv.value) {
      _loadEpisodes();
    }

    // Set full immersive mode with improved reliability
    _setImmersiveMode();

    contentProvider = ContentProvider(
        title: widget.data.title,
        id: widget.data.id,
        type: widget.data.type,
        airDate: widget.airDate,
        episodeNumber: widget.episodeNumber,
        seasonNumber: widget.seasonNumber,
        isAnime: widget.data.genres.contains("Animation"));

    contentProvider.providers.forEach((element) {
      servers.add(ServerClass(name: element.name));
    });

    _loadPreferredServer().then((_) {
      if (_stream.isEmpty) {
        getStream();
      } else {
        setState(() {
          if (_stream.first.subtitles != null &&
              _stream.first.subtitles!.isNotEmpty) {
            subtitles = _stream.first.subtitles;
          } else {
            getSubtitles(
                episode: contentProvider.episodeNumber,
                season: contentProvider.seasonNumber);
          }
          isLoading = false;
        });
      }
    });
  }

  // Add method to set immersive mode reliably
  void _setImmersiveMode() {
    // Use a slight delay to ensure it works after any system UI changes
    Future.delayed(const Duration(milliseconds: 100), () {
      // Enter fullscreen mode - hide system UI
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );

      // Set landscape orientation for all platforms
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app is resumed, ensure we restore immersive mode
      _setImmersiveMode();
    }
  }

  // Enhanced method to load the preferred server with fallback
  Future<void> _loadPreferredServer() async {
    try {
      // Get the appropriate preference based on content type
      final preferredServer =
          await SettingsService.instance.getPreferredServer(widget.data);

      if (preferredServer != null) {
        bool preferredServerAvailable = false;
        bool preferredServerUsable = false;

        // Find index of preferred server if it exists
        for (int i = 0; i < servers.length; i++) {
          if (servers[i].name == preferredServer) {
            _providerIndex = i;
            preferredServerAvailable = true;

            // Try to get stream from preferred server
            try {
              _stream = await contentProvider.providers[i].getStream();
              _stream = _stream.where((element) => !element.isError).toList();
              if (_stream.isNotEmpty) {
                preferredServerUsable = true;
              }
            } catch (e) {
              debugPrint('Error loading stream from preferred server: $e');
            }
            break;
          }
        }

        // If preferred server isn't available or usable, fall back to default behavior
        if (!preferredServerAvailable || !preferredServerUsable) {
          debugPrint(
              'Preferred server "$preferredServer" not available/usable for this content');
          _providerIndex = widget.providerIndex ?? 0;
        }
      } else {
        _providerIndex = widget.providerIndex ?? 0;
      }
    } catch (e) {
      // Fallback to default or provided index
      debugPrint('Error loading preferred server: $e');
      _providerIndex = widget.providerIndex ?? 0;
    }
  }

  Future<void> _initStorage() async {
    try {
      if (storage?.isOpen ?? false) return;

      storage = await Hive.openBox(widget.data.title);
      await storage?.put("season", "S${widget.seasonNumber ?? 1}");
      await storage?.put("episode", "E${widget.episodeNumber ?? 1}");
    } catch (e) {
      debugPrint('Error initializing storage: $e');
    }
  }

  Future<void> _loadEpisodes() async {
    try {
      if (currentSeasonNumber == null) return;

      final episodesList = await Api().getEpisodes(
        id: widget.data.id,
        season: currentSeasonNumber!,
      );

      if (mounted) {
        setState(() {
          episodes = episodesList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      // Handle error
    }
  }

  void _handleEpisodeSelected(int episodeNumber) async {
    setState(() {
      isLoading = true;
      currentEpisodeNumber = episodeNumber;
      _stream = []; // Clear current stream
    });

    // Create new content provider for selected episode
    if (contentProvider.animeEpisode != null) {
      contentProvider = ContentProvider(
          title: widget.data.title,
          id: widget.data.id,
          type: widget.data.type,
          airDate: widget.airDate,
          episodeNumber: episodeNumber,
          seasonNumber: currentSeasonNumber,
          animeEpisode: contentProvider.animeEpisode,
          isAnime: contentProvider.isAnime);
    } else {
      contentProvider = ContentProvider(
          title: widget.data.title,
          id: widget.data.id,
          type: widget.data.type,
          episodeNumber: episodeNumber,
          airDate: widget.airDate,
          seasonNumber: currentSeasonNumber,
          isAnime: contentProvider.isAnime);
    }

    // Reset servers
    servers.clear();
    contentProvider.providers.forEach((element) {
      servers.add(ServerClass(name: element.name));
    });

    // Load preferred server index
    _loadPreferredServer().then((_) {
      if (_stream.isEmpty) {
        getStream();
      } else {
        setState(() {
          if (_stream.first.subtitles != null &&
              _stream.first.subtitles!.isNotEmpty) {
            subtitles = _stream.first.subtitles;
          } else {
            getSubtitles(
                episode: contentProvider.episodeNumber,
                season: contentProvider.seasonNumber);
          }
          isLoading = false;
        });
      }
    });
  }

  Future<bool> _resetActiveServers(int index) async {
    if (index == _providerIndex) {
      if (index >= servers.length) {
        setState(() {
          isError = true;
        });
        return false;
      }
      return _resetActiveServers(index + 1);
    }
    setState(() {
      isLoading = true;
    });
    try {
      List<StreamClass> stream =
          await contentProvider.providers[index].getStream();
      stream = stream.where((element) => !element.isError).toList();
      if (stream.isEmpty || stream.every((element) => element.isError)) {
        setState(() {
          if (index >= servers.length) {
            isError = true;
          }
          servers[index].status = ServerStatus.unavailable;
          isLoading = false;
        });
        if (index >= servers.length) {
          return false;
        }
        return _resetActiveServers(index + 1);
      } else {
        setState(() {
          isLoading = false;
          _stream = stream;
          if (_stream.first.subtitles != null &&
              _stream.first.subtitles!.isNotEmpty) {
            subtitles = _stream.first.subtitles;
          }
          _providerIndex = index;
          servers[index].status = ServerStatus.active;

          // Save preferred server
          _savePreferredServer(servers[index].name);
        });
        return true;
      }
    } catch (e) {
      setState(() {
        if (index >= servers.length) {
          isError = true;
        }
        isLoading = false;
        servers[index].status = ServerStatus.unavailable;
      });
      debugPrint('Error loading stream from server: $e');
      return false;
    }
  }

  Future<bool> _handleServerChanged(int index) async {
    if (index == _providerIndex || index >= servers.length) return false;

    setState(() {
      isLoading = true;
    });

    try {
      List<StreamClass> stream =
          await contentProvider.providers[index].getStream();
      stream = stream.where((element) => !element.isError).toList();
      if (stream.isEmpty || stream.every((element) => element.isError)) {
        setState(() {
          isLoading = false;
          servers[index].status = ServerStatus.unavailable;
        });
        return false;
      } else {
        setState(() {
          isLoading = false;
          _stream = stream;
          if (_stream.first.subtitles != null &&
              _stream.first.subtitles!.isNotEmpty) {
            subtitles = _stream.first.subtitles;
          }
          _providerIndex = index;
          servers[index].status = ServerStatus.active;

          // Save preferred server
          _savePreferredServer(servers[index].name);
        });
        return true;
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        servers[index].status = ServerStatus.unavailable;
      });
      debugPrint('Error loading stream from server: $e');
      return false;
    }
  }

  // Add new method to save preferred server
  Future<void> _savePreferredServer(String serverName) async {
    await SettingsService.instance.savePreferredServer(widget.data, serverName);
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Don't close the storage if it was passed from parent
    if (widget.storage == null && (storage?.isOpen ?? false)) {
      storage?.close();
    }

    // Reset system UI on exit with improved reliability
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    // Reset to all orientations
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Widget _buildLoadingState() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/error.json',
              width: 150,
              height: 150,
              repeat: false,
            ),
            const SizedBox(height: 24),
            const Text(
              "Oops! Stream not found",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "We couldn't find a stream for this content",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
              label: const Text("Go Back"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _stream.isNotEmpty && !isLoading && !isError
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: ContentPlayer(
                data: widget.data,
                streams: _stream,
                contentType: widget.data.type,
                title: widget.title,
                episodes: episodes,
                currentEpisode: currentEpisodeNumber,
                onEpisodeSelected: _handleEpisodeSelected,
                subtitles: subtitles,
                servers: servers,
                onServerChanged: _handleServerChanged,
                onActiveServerReset: _resetActiveServers,
                currentServerIndex: _providerIndex,
              ),
            )
          : !isError
              ? _buildLoadingState()
              : _buildErrorState(),
    );
  }
}
