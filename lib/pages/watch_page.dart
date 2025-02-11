import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:flutter/services.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/components/content_player.dart';
import 'package:lottie/lottie.dart';

class Watch extends StatefulWidget {
  final Contentclass? data;
  final int? episodeNumber,seasonNumber;
  final String title;
  const Watch({super.key, this.data, this.episodeNumber, this.seasonNumber,required this.title});

  @override
  State<Watch> createState() => _WatchState();
}

class _WatchState extends State<Watch> {
  TextEditingController textEditingController = TextEditingController();
  late ContentProvider contentProvider;
  int _providerIndex = 0;
  final List<String> _loadingMessages = [
    "Fetching the best quality streams...",
    "Preparing your entertainment...",
    "Almost there...",
    "Setting up your video...",
    "Loading awesome content..."
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;
  List<StreamClass> _stream = [];
  bool isError = false;
  void getStream() async {
    try{
    if(_providerIndex >= contentProvider.providers.length) isError = true;
    _stream = await contentProvider.providers[_providerIndex].getStream();
    _stream = _stream.where((element) => !element.isError).toList();
    if(_stream.isEmpty){
      _providerIndex++;
      getStream();
    }else{
      setState(() {});
    }
    }catch(e){
      isError = true;
    }
  }
  @override
  void initState() {
    super.initState();
    // Set full immersive mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    contentProvider = ContentProvider(id: widget.data!.id,type: widget.data!.type,episodeNumber: widget.episodeNumber,seasonNumber: widget.seasonNumber);
    getStream();
    _startMessageRotation();
  }

  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _loadingMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
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
    return Center(
      child: Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading.json',
            width: 200,
            height: 200,
            repeat: true,
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _loadingMessages[_currentMessageIndex],
              key: ValueKey(_currentMessageIndex),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    )
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
      body: _stream.isNotEmpty?SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: ContentPlayer(
                streams: _stream,
                contentType: widget.data!.type,
                title: widget.title,
              ),
      ):!isError?_buildLoadingState():_buildErrorState(),
    );
  }
}