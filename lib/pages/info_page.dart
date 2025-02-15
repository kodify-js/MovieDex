import 'package:flutter/material.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/services/downloads_manager.dart';
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
  const Infopage({super.key, required this.id,required this.type,required this.name});

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
  @override
  void initState() {
    super.initState();
    Hive.openBox(widget.name).then((value) => storage = value);
    _isInList = ListService.instance.isInList(widget.id);
  }

  void _navigateToPlayer(Contentclass data) async {
    // Ensure the box is open before navigating
    if (!storage!.isOpen) {
      storage = await Hive.openBox(widget.name);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WatchPage(
          data: data,
          episodeNumber: int.parse((storage?.get("episode")??"E1").replaceAll("E", "")),
          seasonNumber: selectedSeason,
          title: '${data.title} ${data.type=='tv'?storage!.get("episode"):""}',
          storage: storage,
        ),
      ),
    ).then((value) async {
      // Reopen the box if it was closed when returning
      if (storage != null && !storage!.isOpen) {
        storage = await Hive.openBox(widget.name);
      }
    });
  }

  Future<void> _handleDownload(Contentclass data) async {
    try {
      setState(() => _isLoadingStream = true);

      if (_stream.isEmpty) {
        await getStream();
      }
      
      if (_stream.isEmpty || isError) {
        throw 'No streams available';
      }

      // Show quality selection dialog
      final quality = await _showQualityDialog(_stream.first);
      if (quality == null) return;

      final language = _stream.length > 1 
          ? await _showLanguageDialog(_stream) 
          : _stream.first.language;
      if (language == null) return;

      // Get selected stream
      final stream = _stream.firstWhere((s) => s.language == language);
      final url = quality == 'Auto' 
          ? stream.url 
          : stream.sources.firstWhere((s) => s.quality == quality).url;

      final fileName = '${data.title}${data.type == ContentType.tv.value ? '_S${selectedSeason}E${storage?.get("episode")?.toString().replaceAll("E", "")}' : ''}_$quality';
      
      // Initialize downloader with callbacks that use DownloadsProvider
      _downloader.setCallbacks(
        onProgress: (progress) {
          // Update progress through DownloadsProvider instead of setState
          DownloadsProvider.instance.updateProgress(
            data.id,
            progress,
            'downloading',
            data.title,
            data.poster,
            quality,
          );
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        },
      );

      await _downloader.startDownload(
        context,
        url,
        fileName,
        data,
        quality,
        episodeNumber: data.type == ContentType.tv.value 
            ? int.parse((storage?.get("episode") ?? "E1").replaceAll("E", ""))
            : null,
        seasonNumber: data.type == ContentType.tv.value ? selectedSeason : null,
      );

    } catch (e) {
      if (mounted) {
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

  Future<void> getStream() async {
    try {
      contentProvider = ContentProvider(
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
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...stream.sources.map((source) => ListTile(
              title: Text('${source.quality}p'),
              onTap: () => Navigator.pop(context, source.quality),
            )),
          ],
        ),
      ),
    );
  }

  Future<String?> _showLanguageDialog(List<StreamClass> streams) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: streams.map((stream) => ListTile(
            title: Text(stream.language),
            onTap: () => Navigator.pop(context, stream.language),
          )).toList(),
        ),
      ),
    );
  }

  bool _isDownloaded(Contentclass data, {int? episodeNumber, int? seasonNumber}) {
    final downloads = DownloadsManager.instance.getDownloads();
    return downloads.any((download) {
      bool isSameContent = download.contentId == data.id;
      
      if (data.type == ContentType.tv.value) {
        // For TV shows, check episode and season
        return isSameContent && 
               download.episodeNumber == episodeNumber &&
               download.seasonNumber == seasonNumber;
      }
      
      // For movies, just check content ID
      return isSameContent;
    });
  }

  void _showEpisodeDownloadDialog(Contentclass data) {
    if (data.seasons == null || data.seasons == 0) {
      // Show error if no seasons data
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No episodes available for download')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Episode to Download',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Season $selectedSeason'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: selectedSeason,
                    items: List.generate(
                      data.seasons?.length??0, // Use seasons count directly
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('Season ${i + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedSeason = value);
                      }
                    },
                  ),
                ],
              ),
              FutureBuilder(
                future: api.getEpisodes(
                  id: data.id,
                  season: selectedSeason,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final episodes = snapshot.data!;
                  return Expanded(
                    child: ListView.builder(
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        final isDownloaded = _isDownloaded(
                          data,
                          episodeNumber: episode.episode,
                          seasonNumber: selectedSeason,
                        );

                        return ListTile(
                          title: Text('Episode ${episode.episode}'),
                          subtitle: Text(episode.name),
                          trailing: isDownloaded
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : const Icon(Icons.download),
                          onTap: isDownloaded
                              ? null  // Disable if already downloaded
                              : () {
                                  Navigator.pop(context);
                                  _handleDownload(data); // Changed from _startDownload to _handleDownload
                                },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddToListButton(Contentclass data) {
    return TextButton(
      onPressed: _isProcessing ? null : () async {
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
          _isInList ? Theme.of(context).colorScheme.primary : const Color.fromARGB(177, 34, 34, 34),
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
    return Column(
      children: [
        IconButton(
          onPressed: _isProcessing ? null : () async {
            final data = await api.getDetails(id: widget.id, type: widget.type);
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
    );
  }

  Widget _buildDownloadIcon(Contentclass data) {
    return DownloadIconWidget(
      contentId: data.id,
      data: data,
      onDownload: _handleDownload,
    );
  }

  @override
  void dispose() {
    if (storage?.isOpen ?? false) {
      storage?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    storage?.get("season")??hivePut(storage: storage,key: "season",value: "S1");
    selectedSeason = int.parse((storage?.get("season")??"S1").replaceAll("S", ""));
    storage?.get("episode")??hivePut(storage: storage,key: "episode",value: "E1");
    final width = MediaQuery.of(context).size.width;
    final isMobile = width<600;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name!=''?widget.name:_appname,style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
        ),
        actions: [
          IconButton(onPressed: (){
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SearchPage()));
          }, icon: Icon(Icons.search)),
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
                    height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
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
                              Theme.of(context).colorScheme.surface.withValues(
                                alpha: 0.8,
                              ),
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: isMobile?CrossAxisAlignment.center:CrossAxisAlignment.start,
                            mainAxisAlignment: isMobile?MainAxisAlignment.center:MainAxisAlignment.start,
                            children: [
                              Spacer(),
                              Container(
                                margin: const EdgeInsets.only(left: 16,right: 16),
                                child: data.logoPath==null
                                ? Text(
                                    data.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold
                                    ),
                                  )
                                : SizedBox(
                                    width: isMobile?width/2:width/4,
                                    child: Image.network(
                                      data.logoPath ?? '',
                                      fit: BoxFit.cover, // ensures the logo fits within bounds
                                    ),
                                  ),
                              ),
                              isMobile?TextButton(onPressed: (){
                                        _navigateToPlayer(data);
                                      },
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(Colors.white),
                                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_arrow_rounded,size: 24,color: Colors.black),
                                          Text("Play ${widget.type==ContentType.tv.value?'${storage?.get("season")??"S1"}${storage?.get("episode")??"E1"}':""}",style: TextStyle(color: Colors.black,fontSize: 18,fontWeight: FontWeight.bold))
                                        ],
                                      )
                                ):Container(),
                                Row(
                                  spacing: 8,
                                  children: [
                                    !isMobile?Container(
                                      width :150,
                                      margin: isMobile?const EdgeInsets.only(top: 8):const EdgeInsets.only(left: 8,right: 8,top: 8),
                                      child: TextButton(onPressed: (){
                                        _navigateToPlayer(data);
                                      },
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(Colors.white),
                                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_arrow_rounded,size: 24,color: Colors.black),
                                          Text("Play ${widget.type==ContentType.tv.value?'${storage?.get("season")??"S1"}${storage?.get("episode")??"E1"}':""}",style: TextStyle(color: Colors.black,fontSize: 18,fontWeight: FontWeight.bold))
                                        ],
                                      )
                                      ),
                                    ):Container(),
                                    !isMobile?
                                    Container(
                                      width: isMobile?width:150,
                                      margin: isMobile?const EdgeInsets.only(top: 8):const EdgeInsets.only(left: 8,right: 8,top: 8),
                                      child: _buildAddToListButton(data),
                                    ):const SizedBox(),
                                  ],
                                ),
                              (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android) && isMobile?
                              Padding(
                                padding: EdgeInsets.zero, // Remove padding
                                child: DownloadButtonWidget(
                                  data: data,
                                  isLoadingStream: _isLoadingStream,
                                  onDownloadStarted: () => _handleDownload(data),
                                ),
                              ) : const SizedBox(),
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
                          Text("Genres: ${data.genres.join(", ")}",style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey
                          )),
                          Row(
                            children: [
                              Text("Rating: ${data.rating}",style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey
                              )),
                              Icon(Icons.star_rounded,color: Colors.yellow,)
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16,top: 8),
                            child: Row(
                              spacing: 16,
                              children: [
                                isMobile ? _buildMobileListButton() : Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android?
                                _buildDownloadIcon(data):const SizedBox(),
                                Column(
                                  children: [
                                    IconButton(
                                      onPressed: () => ShareService.shareContent(
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
                    data.type==ContentType.movie.value?
                    HorizontalScrollList(title: "Recommendations", fetchMovies: () => api.getRecommendations(id: widget.id, type: widget.type), showNumber: false):
                    EpisodesSection(data: data,initialSeason: selectedSeason), 
                  ],
                );
              },
            ),
          ],
        ),
      )
    );
  }
}