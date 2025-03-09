import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:flutter/services.dart';
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/class/subtitle_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:moviedex/components/content_player.dart';
import 'package:lottie/lottie.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class WatchPage extends StatefulWidget {
  final Contentclass data;
  final int? episodeNumber, seasonNumber;
  final String title;
  final Box? storage; // Add storage parameter
  final int? providerIndex;
  const WatchPage({
    super.key, 
    required this.data, 
    this.episodeNumber, 
    this.seasonNumber,
    required this.title,
    this.storage,
    this.providerIndex = 0,
  });
  
  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> {
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
  void getStream() async {
    try{
    if(_providerIndex >= contentProvider.providers.length) throw Exception("Stream not found");
    _stream = await contentProvider.providers[_providerIndex].getStream();
    _stream = _stream.where((element) => !element.isError).toList();
    if(_stream.isEmpty){
      _providerIndex++;
      getStream();
    }else{
      setState(() {});
    }
    }catch(e){
      setState(() {
        isError = true;
      });
    }
  }
  void getSubtitles({int? id,int? episode,int? season}) async {
    try {
      final api = new Api();
      final imdbId = await api.getExternalIds(id: id??widget.data.id, type: widget.data.type);
      if (imdbId.isEmpty) {
        throw Exception("No IMDB ID found for this content");
      }
      final data = await http.get(Uri.parse(widget.data.type == ContentType.tv.value ? 'https://hilarious-rugelach-6767a8.netlify.app/?destination=https%3A%2F%2Frest.opensubtitles.org%2Fsearch%2Fepisode-${episode??widget.episodeNumber}%2Fimdbid-${imdbId.replaceAll("tt", "")}%2Fseason-${season??widget.seasonNumber}':'https://hilarious-rugelach-6767a8.netlify.app/?destination=https%3A%2F%2Frest.opensubtitles.org%2Fsearch%2Fimdbid-${imdbId.replaceAll("tt", "")}'));
      final response = jsonDecode(data.body);
      subtitles = (response as List).where((e)=>!_addedSub.contains(e['LanguageName'])).where((e)=>e['SubFormat']=='srt').map((e){ 
        _addedSub.add(e['LanguageName']);
        print(e['SubDownloadLink']);
        return SubtitleClass(language: e['SubLanguageID'],url: e['SubDownloadLink'].split(".gz")[0],label: e['LanguageName']);}).toList();
    } catch (e) {
      subtitles = [];
    }
  }
  @override
  void initState() {
    super.initState();
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
    // Set full immersive mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    contentProvider = ContentProvider(id: widget.data.id,type: widget.data.type,episodeNumber: widget.episodeNumber,seasonNumber: widget.seasonNumber);
    getSubtitles();
    _providerIndex = widget.providerIndex ?? 0;
    getStream();
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
    contentProvider = ContentProvider(
      id: widget.data.id,
      type: widget.data.type,
      episodeNumber: episodeNumber,
      seasonNumber: currentSeasonNumber,
    );
    
    getSubtitles(episode: episodeNumber,season: currentSeasonNumber);
    // Reset provider index
    _providerIndex = widget.providerIndex ?? 0;
    
    // Get new stream
    getStream();
  }

  @override
  void dispose() {
    // Don't close the storage if it was passed from parent
    if (widget.storage == null && (storage?.isOpen ?? false)) {
      storage?.close();
    }
    // Reset system UI on exit
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    // Reset to Default Orientation
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
            icon: const Icon(Icons.arrow_back,color: Colors.white,),
            label: const Text("Go Back"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      body: _stream.isNotEmpty 
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
            ),
          )
        : !isError 
            ? _buildLoadingState()
            : _buildErrorState(),
    );
  }
}