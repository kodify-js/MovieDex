import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/components/episode_selection_list.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/models/downloads_manager.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:moviedex/components/horizontal_scroll_list.dart';
import 'package:moviedex/pages/search_page.dart';
import 'package:moviedex/pages/watch_page.dart';
import 'package:moviedex/components/description_text.dart';
import 'package:moviedex/components/episodes_section.dart';
import 'package:hive/hive.dart';
import 'package:moviedex/services/list_service.dart';
import 'package:moviedex/services/m3u8_downloader_service.dart';
import 'package:moviedex/components/download_icon_widget.dart';
import 'package:moviedex/services/share_service.dart';
import 'package:moviedex/components/download_button_widget.dart';

class Infopage extends StatefulWidget {
  final int id;
  final String name;
  final String type;
  final Box? storage; // Add storage parameter

  const Infopage(
      {super.key,
      required this.id,
      required this.type,
      required this.name,
      this.storage}); // Add this parameter

  @override
  State<Infopage> createState() => _InfopageState();
}

class _InfopageState extends State<Infopage> {
  Api api = Api();
  TextEditingController textEditingController = TextEditingController();
  bool isDescriptionExpanded = false;
  int selectedSeason = 1;
  Box? storage;
  bool _isInList = false;
  bool _isProcessing = false;
  late ContentProvider contentProvider;
  int _providerIndex = 0;
  final M3U8DownloaderService _downloader = M3U8DownloaderService();
  List<StreamClass> _stream = [];
  bool isError = false;
  bool _isLoadingStream = false;
  String _appname = "";
  Contentclass? _contentData; // Add this variable to store content data

  Future<void> _initStorage() async {
    try {
      if (storage == null || !storage!.isOpen) {
        storage = await Hive.openBox(widget.name);
      }
    } catch (e) {
      debugPrint('Error initializing storage: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initStorage();
    _isInList = ListService.instance.isInList(widget.id);
  }

  void _navigateToPlayer(Contentclass data) async {
    await _initStorage(); // Ensure storage is open

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => WatchPage(
          data: data,
          episodeNumber:
              int.parse((storage?.get("episode") ?? "E1").replaceAll("E", "")),
          seasonNumber: selectedSeason,
          title: data.title,
          storage: storage,
        ),
      ),
    )
        .then((value) async {
      // Re-initialize storage when returning
      await _initStorage();
    });
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preparing download...'),
                  const SizedBox(height: 8),
                  Text(
                    'Getting available streams',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isLoadingStream = false);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download cancelled')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDownload(
    Contentclass data, {
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    try {
      setState(() => _isLoadingStream = true);
      if (data.type == ContentType.movie.value ||
          (data.type == ContentType.tv.value &&
              seasonNumber != null &&
              episodeNumber != null)) {
        _showLoadingDialog(); // Show loading dialog only for movies or selected TV episode
      }

      // Initialize stream data
      if (_stream.isEmpty) {
        await getStream();
      }

      if (_stream.isEmpty || isError) {
        throw 'No streams available';
      }

      // Close loading dialog if still showing
      if (mounted &&
          (data.type == ContentType.movie.value ||
              (data.type == ContentType.tv.value &&
                  seasonNumber != null &&
                  episodeNumber != null))) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (data.type == ContentType.tv.value) {
        if (seasonNumber != null && episodeNumber != null) {
          await _handleEpisodeDownload(
            data,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
          );
        } else {
          _showEpisodeDownloadDialog(data);
        }
      } else {
        await _handleMovieDownload(data);
      }
    } catch (e) {
      // Clear download state on error
      DownloadsProvider.instance.removeDownload(data.id);
      if (mounted) {
        // Close loading dialog if still showing
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStream = false);
      }
    }
  }

  Future<void> _downloadFullSeason(Contentclass data, int season) async {
    try {
      final episodes = await api.getEpisodes(id: data.id, season: season);

      // Show quality selection
      if (_stream.isEmpty) {
        await getStream();
      }

      if (_stream.isEmpty || isError) {
        throw 'No streams available';
      }

      final quality = await _showQualityDialog(_stream.first);
      if (quality == null) return;

      // Show progress dialog
      if (!mounted) return;
      _showDownloadProgressDialog(episodes.length);

      // Download each episode
      for (var episode in episodes) {
        if (!mounted) break;

        await _startDownload(
          data,
          quality,
          _stream.first.language,
          episodeNumber: episode.episode,
          seasonNumber: season,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Season $season downloaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading season: $e')),
        );
      }
    }
  }

  void _showDownloadProgressDialog(int totalEpisodes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Downloading Season'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Downloading $totalEpisodes episodes...'),
          ],
        ),
      ),
    );
  }

  void _showSeasonEpisodeSelection(Contentclass data, int season) async {
    final episodes = await api.getEpisodes(id: data.id, season: season);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Episodes - Season $season'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: EpisodeSelectionList(
            episodes: episodes,
            onEpisodeSelected: (episode) async {
              Navigator.pop(context);
              await _handleEpisodeDownload(
                data,
                seasonNumber: season,
                episodeNumber: episode.episode,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleEpisodeDownload(
    Contentclass data, {
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    try {
      if (_stream.isEmpty) {
        await getStream();
      }

      if (_stream.isEmpty || isError) {
        throw 'No streams available';
      }

      final quality = await _showQualityDialog(_stream.first);
      if (quality == null) return;

      final language = _stream.length > 1
          ? await _showLanguageDialog(_stream)
          : _stream.first.language;
      if (language == null) return;

      await _startDownload(
        data,
        quality,
        language,
        episodeNumber: episodeNumber,
        seasonNumber: seasonNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Episode $episodeNumber downloaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading episode: $e')),
        );
      }
    }
  }

  Future<void> _handleMovieDownload(Contentclass data) async {
    if (_stream.isEmpty) {
      await getStream();
    }

    if (_stream.isEmpty || isError) {
      throw 'No streams available';
    }

    final quality = await _showQualityDialog(_stream.first);
    if (quality == null) return;

    final language = _stream.length > 1
        ? await _showLanguageDialog(_stream)
        : _stream.first.language;
    if (language == null) return;

    await _startDownload(data, quality, language);
  }

  Future<void> _startDownload(
    Contentclass data,
    String quality,
    String language, {
    int? episodeNumber,
    int? seasonNumber,
  }) async {
    // Get selected stream
    final stream = _stream.firstWhere((s) => s.language == language);
    print('Selected stream: $stream');
    final url = quality == 'Auto'
        ? stream.url
        : stream.sources.firstWhere((s) => s.quality == quality).url;

    final fileName =
        '${data.title}${data.type == ContentType.tv.value ? '_S${seasonNumber}E$episodeNumber' : ''}_$quality';

    // Initialize downloader callbacks
    _downloader.setCallbacks(
      onProgress: (progress) {
        DownloadsProvider.instance.updateProgress(
          data.id,
          progress,
          'downloading',
          data.title,
          data.poster,
          quality,
        );
        if (mounted) {
          setState(() {}); // Update UI to reflect download progress
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
    );

    // Add to downloading list and update button text
    DownloadsProvider.instance.updateProgress(
      data.id,
      0.0,
      'downloading',
      data.title,
      data.poster,
      quality,
    );
    if (mounted) {
      setState(() {}); // Update UI to reflect download start
    }

    await _downloader.startDownload(
      context,
      url,
      fileName,
      data,
      quality,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber,
    );
  }

  Future<void> getStream() async {
    try {
      contentProvider = ContentProvider(
        title: widget.name,
        id: widget.id,
        type: widget.type,
      );

      if (_providerIndex >= contentProvider.providers.length) {
        isError = true;
        return;
      }

      _stream = await contentProvider.providers[_providerIndex].getStream();
      _stream = _stream.where((element) => !element.isError).toList();

      if (_stream.isEmpty) {
        _providerIndex++;
        await getStream();
      }
    } catch (e) {
      isError = true;
      debugPrint('Stream error: $e');
    }
  }

  Future<String?> _showQualityDialog(StreamClass stream) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Quality',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...stream.sources.map((source) => ListTile(
                          title: Text('${source.quality}p',
                              style: const TextStyle(color: Colors.white)),
                          onTap: () => Navigator.pop(context, source.quality),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showLanguageDialog(List<StreamClass> streams) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: streams
                      .map((stream) => ListTile(
                            title: Text(
                              stream.language,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () =>
                                Navigator.pop(context, stream.language),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEpisodeDownloadDialog(Contentclass data) {
    if (data.seasons == null || data.seasons == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No episodes available for download')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Download Episodes',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Season selector
                        _buildSeasonPicker(data),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Download all button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadFullSeason(data, selectedSeason);
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download All Episodes'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Episodes list
              Expanded(
                child: FutureBuilder(
                  future: api.getEpisodes(id: data.id, season: selectedSeason),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final episodes = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        final isDownloaded = _isEpisodeDownloaded(
                          episode.episode,
                          selectedSeason,
                        );

                        return _buildDownloadEpisodeItem(
                          episode: episode,
                          isDownloaded: isDownloaded,
                          onTap: () async {
                            Navigator.pop(context);
                            await _handleEpisodeDownload(
                              data,
                              seasonNumber: selectedSeason,
                              episodeNumber: episode.episode,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonPicker(Contentclass data) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: PopupMenuButton<int>(
        initialValue: selectedSeason,
        onSelected: (season) => setState(() => selectedSeason = season),
        itemBuilder: (context) => List.generate(
          data.seasons?.length ?? 0,
          (index) => PopupMenuItem(
            value: index + 1,
            child: Text('Season ${index + 1}'),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Season $selectedSeason',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadEpisodeItem({
    required Episode episode,
    required bool isDownloaded,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 120,
          height: 68,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                episode.image,
                fit: BoxFit.cover,
              ),
              if (isDownloaded)
                Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      Text(
                        'S${selectedSeason}E${episode.episode}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            'S${selectedSeason}E${episode.episode}',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              episode.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        episode.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: Icon(isDownloaded ? Icons.check : Icons.download),
        onPressed: isDownloaded ? null : onTap,
      ),
    );
  }

  Widget _buildAddToListButton(Contentclass data) {
    return TextButton(
      onPressed: _isProcessing
          ? null
          : () async {
              setState(() => _isProcessing = true);
              try {
                if (_isInList) {
                  await ListService.instance.removeFromList(data.id);
                } else {
                  await ListService.instance.addToList(data);
                }
                setState(() {
                  _isInList = !_isInList;
                  _isProcessing = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isInList ? 'Added to My List' : 'Removed from My List',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              } catch (e) {
                setState(() => _isProcessing = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          _isInList
              ? Theme.of(context).colorScheme.primary
              : const Color.fromARGB(177, 34, 34, 34),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(
              _isInList ? Icons.check : Icons.add,
              size: 24,
              color: Colors.white,
            ),
          const SizedBox(width: 8),
          Text(
            _isInList ? "In My List" : "Add to List",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileListButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          children: [
            IconButton(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      final data = await api.getDetails(
                          id: widget.id, type: widget.type);
                      setState(() => _isProcessing = true);
                      try {
                        if (_isInList) {
                          await ListService.instance.removeFromList(data.id);
                        } else {
                          await ListService.instance.addToList(data);
                        }
                        setState(() {
                          _isInList = !_isInList;
                          _isProcessing = false;
                        });
                      } catch (e) {
                        setState(() => _isProcessing = false);
                      }
                    },
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _isInList ? Icons.check : Icons.add,
                      color: Colors.white,
                      size: 32,
                    ),
            ),
            Text(
              _isInList ? "In My List" : "Add to List",
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(width: 16), // Add spacing between buttons
      ],
    );
  }

  Widget _buildDownloadIcon(Contentclass data) {
    return DownloadIconWidget(
      contentId: data.id,
      data: data,
      onDownload: (data) => _handleDownload(data),
    );
  }

  void _playDownloadedEpisode(Episode episode) {
    if (_contentData == null) return;
    // code for playing Downloaded Episode
  }

  String _getEpisodeDisplayText(int seasonNumber, int episodeNumber) {
    return 'S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
  }

  bool _isEpisodeDownloaded(int episodeNumber, int seasonNumber) {
    return DownloadsManager.instance.hasEpisodeDownload(
      widget.id,
      episodeNumber: episodeNumber,
      seasonNumber: seasonNumber,
    );
  }

  Future<void> _handleSingleEpisodeDownload(Episode episode) async {
    if (_isEpisodeDownloaded(episode.episode, selectedSeason)) {
      // Episode already downloaded - show play option
      final download = DownloadsManager.instance.getDownload(
        widget.id,
        episodeNumber: episode.episode,
        seasonNumber: selectedSeason,
      );

      if (download != null) {
        _playDownloadedEpisode(episode);
        return;
      }
    }

    // Not downloaded - start new download
    await storage?.put('episode', 'E${episode.episode}');
    await storage?.put('season', 'S$selectedSeason');

    if (_contentData != null) {
      await _handleDownload(
        _contentData!,
        seasonNumber: selectedSeason,
        episodeNumber: episode.episode,
      );
    }
  }

  Widget _buildEpisodeListItem(Episode episode) {
    final isDownloaded = _isEpisodeDownloaded(episode.episode, selectedSeason);
    final episodeText = _getEpisodeDisplayText(selectedSeason, episode.episode);

    return ListTile(
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              episode.image,
              width: 120,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          if (isDownloaded)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Downloaded',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(
            episodeText,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              episode.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        episode.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDownloaded)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _handleDownload(
                _contentData!,
                seasonNumber: selectedSeason,
                episodeNumber: episode.episode,
              ),
            ),
          IconButton(
            icon: Icon(isDownloaded ? Icons.play_arrow : Icons.preview),
            onPressed: () => _handleEpisodeSelected(episode.episode),
          ),
        ],
      ),
    );
  }

  void _handleEpisodeSelected(int episodeNumber) async {
    if (_contentData == null) return;

    await storage?.put('episode', 'E$episodeNumber');
    await storage?.put('season', 'S$selectedSeason');

    if (_isEpisodeDownloaded(episodeNumber, selectedSeason)) {
      _playDownloadedEpisode(Episode(
        id: widget.id,
        season: selectedSeason,
        episode: episodeNumber,
        airDate: '',
        name: '', // These fields aren't used in playback
        description: '',
        image: '',
      ));
    } else {
      _navigateToPlayer(_contentData!);
    }
  }

  Widget _buildDownloadButton(Contentclass data) {
    return DownloadButtonWidget(
      data: data,
      onDownloadStarted: () => _handleDownload(data),
      isLoadingStream: _isLoadingStream,
    );
  }

  @override
  void dispose() {
    // Only close if we own the box (not passed from parent)
    if (storage != null && storage!.isOpen && storage != widget.storage) {
      storage!.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(
        () => _initStorage()); // Ensure storage is open when rebuilding
    storage?.get("season") ??
        hivePut(storage: storage, key: "season", value: "S1");
    selectedSeason =
        int.parse((storage?.get("season") ?? "S1").replaceAll("S", ""));
    storage?.get("episode") ??
        hivePut(storage: storage, key: "episode", value: "E1");
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.name != '' ? widget.name : _appname,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => const SearchPage()));
                },
                icon: Icon(Icons.search)),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              FutureBuilder(
                future: api.getDetails(id: widget.id, type: widget.type),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height -
                          AppBar().preferredSize.height,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: Text('No data available'));
                  }

                  Contentclass data = snapshot.data!;
                  _contentData = data; // Store the content data
                  _appname = data.title;
                  return Column(
                    children: [
                      Container(
                        width: width,
                        height: 500,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(data.poster),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(
                                      alpha: 0.8,
                                    ),
                                Theme.of(context).colorScheme.surface,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: isMobile
                                  ? CrossAxisAlignment.center
                                  : CrossAxisAlignment.start,
                              mainAxisAlignment: isMobile
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Spacer(),
                                Container(
                                  margin: const EdgeInsets.only(
                                      left: 16, right: 16),
                                  child: data.logoPath == null
                                      ? Text(
                                          data.title,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold),
                                        )
                                      : SizedBox(
                                          width:
                                              isMobile ? width / 2 : width / 4,
                                          child: Image.network(
                                            data.logoPath ?? '',
                                            fit: BoxFit
                                                .cover, // ensures the logo fits within bounds
                                          ),
                                        ),
                                ),
                                isMobile
                                    ? TextButton(
                                        onPressed: () {
                                          _navigateToPlayer(data);
                                        },
                                        style: ButtonStyle(
                                            backgroundColor:
                                                WidgetStatePropertyAll(
                                                    Colors.white),
                                            shape: WidgetStatePropertyAll(
                                                RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5)))),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.play_arrow_rounded,
                                                size: 24, color: Colors.black),
                                            Text(
                                                "Play ${widget.type == ContentType.tv.value ? '${storage?.get("season") ?? "S1"}${storage?.get("episode") ?? "E1"}' : ""}",
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold))
                                          ],
                                        ))
                                    : Container(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    !isMobile
                                        ? Container(
                                            width: 200,
                                            margin: isMobile
                                                ? const EdgeInsets.only(top: 8)
                                                : const EdgeInsets.only(
                                                    left: 8, right: 8, top: 8),
                                            child: TextButton(
                                              onPressed: () =>
                                                  _navigateToPlayer(data),
                                              style: ButtonStyle(
                                                  backgroundColor:
                                                      WidgetStateProperty.all(
                                                          Colors.white),
                                                  shape: WidgetStateProperty.all(
                                                      RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      5)))),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                      Icons.play_arrow_rounded,
                                                      size: 24,
                                                      color: Colors.black),
                                                  Text(
                                                      "Play ${widget.type == ContentType.tv.value ? '${storage?.get("season") ?? "S1"}${storage?.get("episode") ?? "E1"}' : ""}",
                                                      style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold))
                                                ],
                                              ),
                                            ),
                                          )
                                        : Container(),
                                    const SizedBox(width: 8),
                                    !isMobile
                                        ? Container(
                                            width: 150,
                                            margin: isMobile
                                                ? const EdgeInsets.only(top: 8)
                                                : const EdgeInsets.only(
                                                    left: 8, right: 8, top: 8),
                                            child: _buildAddToListButton(data),
                                          )
                                        : const SizedBox(),
                                  ],
                                ),
                                (Theme.of(context).platform ==
                                                TargetPlatform.iOS ||
                                            Theme.of(context).platform ==
                                                TargetPlatform.android) &&
                                        isMobile
                                    ? Padding(
                                        padding: EdgeInsets.zero,
                                        child: _buildDownloadButton(data),
                                      )
                                    : const SizedBox(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 8),
                            DescriptionText(text: data.description),
                            SizedBox(height: 8),
                            Text("Genres: ${data.genres.join(", ")}",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            Row(
                              children: [
                                Text("Rating: ${data.rating}",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey)),
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.yellow,
                                )
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16, top: 8),
                              child: Row(
                                spacing: 16,
                                children: [
                                  isMobile
                                      ? _buildMobileListButton()
                                      : !kIsWeb
                                          ? _buildDownloadIcon(data)
                                          : const SizedBox(),
                                  Column(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            ShareService.shareContent(
                                          data.id,
                                          data.type,
                                          data.title,
                                        ),
                                        icon: Icon(Icons.share),
                                        color: Colors.white,
                                        iconSize: 32,
                                      ),
                                      Text(
                                        "Share",
                                        style: TextStyle(color: Colors.white),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      data.type == ContentType.movie.value
                          ? HorizontalScrollList(
                              title: "Recommendations",
                              fetchMovies: () => api.getRecommendations(
                                  id: widget.id, type: widget.type),
                              showNumber: false)
                          : EpisodesSection(
                              data: data, initialSeason: selectedSeason),
                    ],
                  );
                },
              ),
            ],
          ),
        ));
  }
}
