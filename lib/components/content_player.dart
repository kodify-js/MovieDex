/**
 * MovieDex Video Player Component
 * 
 * Advanced video player with features:
 * - Multi-source video playback
 * - Quality selection (Auto, 1080p, 720p, etc.)
 * - Multiple audio tracks support
 * - Playback speed control
 * - Picture-in-picture mode
 * - Double-tap seeking
 * - Pinch-to-zoom
 * - Auto-play next episode
 * - Watch history tracking
 * - Proxy support for region-locked content
 * - Custom controls overlay
 * 
 * Part of MovieDex - MIT Licensed
 * Copyright (c) 2024 MovieDex Contributors
 */

import 'dart:async';
import 'dart:convert'; // Add this import for base64Encode
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/components/episode_list_player.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:moviedex/services/watch_history_service.dart';
import 'package:moviedex/components/next_episode_button.dart';
import 'package:moviedex/services/proxy_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:moviedex/services/settings_service.dart';

/// Advanced video player supporting multiple sources and features
class ContentPlayer extends StatefulWidget {
  /// Content metadata
  final Contentclass data;
  
  /// Available video streams
  final List<StreamClass> streams;
  
  /// Content type (movie/tv)
  final String contentType;
  
  /// Current episode number for TV shows
  final int? currentEpisode;
  
  /// Content title
  final String title;
  
  /// Episode list for TV shows
  final List<Episode>? episodes;
  
  /// Callback when episode is selected
  final Function(int)? onEpisodeSelected;

  final Function(int)? onNextEpisode;
  final Function(int)? onPreviousEpisode;
  final bool hasNextEpisode;
  final bool hasPreviousEpisode;

  const ContentPlayer({
    super.key, 
    required this.data,
    required this.streams, 
    required this.contentType, 
    this.currentEpisode,
    required this.title,  
    this.episodes,
    this.onEpisodeSelected,  // Add this to constructor
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.hasNextEpisode = false,
    this.hasPreviousEpisode = false,
  });

  @override
  State<ContentPlayer> createState() => _ContentPlayerState();
}

class _ContentPlayerState extends State<ContentPlayer> with TickerProviderStateMixin {
  // Controller and state variables
  VideoPlayerController? _controller;
  Timer? _hideTimer;
  bool _isPlaying = false;
  bool _isCountrollesVisible = true;
  bool _isFullScreen = false;
  bool _isSettingsVisible = false;
  bool _isEpisodesVisible = false;
  bool _isBuffering = false;
  String _currentQuality = 'Auto';
  String _currentLanguage = 'original';
  String _settingsPage = 'main';
  Duration? _duration;
  Duration? _position;
  var _progress = 0.0;
  var _bufferingProgress = 0.0;
  List settingElements = ["Quality", "Language", "Speed"];
  bool _showForwardIndicator = false;
  bool _showRewindIndicator = false;
  late AnimationController _seekAnimationController;
  late Animation<double> _seekIconAnimation;
  late Animation<double> _seekTextAnimation;
  bool _isDraggingSlider = false;
  double _dragProgress = 0.0;

  late TransformationController _transformationController;
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  bool _isZoomed = false;
  final double _maxScale = 3.0;

  // Add new variables for double tap
  Timer? _doubleTapTimer;

  // Add these new variables
  int _consecutiveTaps = 0;
  Timer? _consecutiveTapTimer;
  bool _isShowingSeekIndicator = false;

  // Add new variables for playback speed
  double _playbackSpeed = 1.0;
  final List<Map<String, dynamic>> _speedOptions = [
    {'label': '0.25x', 'value': 0.25},
    {'label': '0.5x', 'value': 0.5},
    {'label': '0.75x', 'value': 0.75},
    {'label': 'Normal', 'value': 1.0},
    {'label': '1.25x', 'value': 1.25},
    {'label': '1.5x', 'value': 1.5},
    {'label': '1.75x', 'value': 1.75},
    {'label': '2x', 'value': 2.0},
  ];

  // Add new variable for initialization state
  bool _isInitialized = false;

  // Add new animation controllers
  late AnimationController _forwardAnimationController;
  late AnimationController _rewindAnimationController;
  late Animation<double> _forwardRotation;
  late Animation<double> _rewindRotation;

  // Add new animation controllers for double tap indicators
  late AnimationController _seekForwardAnimationController;
  late AnimationController _seekRewindAnimationController;
  late Animation<double> _seekForwardRotation;
  late Animation<double> _seekRewindRotation;
  
  //_settings
  late Box _settingsBox;
  bool _useCustomProxy = false;
  bool _autoPlayNext = true;
  bool _useHardwareDecoding = true;
  String _defaultQuality = 'Auto';
  
  late Box? storage;

  String getSourceOfQuality(StreamClass data){
    final source = data.sources.where((source)=>source.quality==_currentQuality).toList();
    if(source.isEmpty){
      _currentQuality = 'Auto';
      return data.url;
    }else{
      return source[0].url;
    }
  }

  void _onControllerUpdate() async {
    if (!mounted || _controller == null || !_controller!.value.isInitialized || _isDraggingSlider) return;

    final duration = _controller!.value.duration;
    final position = _controller!.value.position;
    
    // Add to history when user starts watching (after 30 seconds)
    if (position.inSeconds == 30) {
      await WatchHistoryService.instance.addToHistory(widget.data);
    }

    // Update values only if they have changed
    if (duration != _duration || position != _position) {
      setState(() {
        _duration = duration;
        _position = position;
        _isPlaying = _controller!.value.isPlaying;
        _isBuffering = _controller!.value.isBuffering;
        
        // Calculate progress only if duration is valid
        if (duration.inMilliseconds > 0) {
          _progress = position.inMilliseconds / duration.inMilliseconds;
        } else {
          _progress = 0.0;
        }
      });
    }

    // Update buffer progress
    if (_controller!.value.buffered.isNotEmpty) {
      final bufferedEnd = _controller!.value.buffered.last.end;
      if (mounted && duration.inMilliseconds > 0) {
        setState(() {
          _bufferingProgress = bufferedEnd.inMilliseconds / duration.inMilliseconds;
        });
      }
    }

    // Save to continue watching every 5 seconds
    if (position.inSeconds % 5 == 0 && duration.inMilliseconds > 0) {
      await WatchHistoryService.instance.updateContinueWatching(
        widget.data,
        position,
        duration,
      );
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }


   Future<void> _initSettings() async {
    _settingsBox = await Hive.openBox('settings');
    _defaultQuality = _settingsBox.get('defaultQuality', defaultValue: 'Auto');
    _useCustomProxy = _settingsBox.get('useCustomProxy', defaultValue: false);
    _autoPlayNext = _settingsBox.get('autoPlayNext', defaultValue: true);
    _useHardwareDecoding = _settingsBox.get('useHardwareDecoding', defaultValue: true);
  }

  Future<void> _initializeVideoPlayer(String url) async {
    final proxyService = ProxyService.instance;
    final proxyUrl = proxyService.activeProxy;

    try {
      if (proxyUrl != null && proxyUrl.isNotEmpty) {
        // Configure video player with proxy
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0',
            'Proxy-Authorization': 'Basic ${base64.encode(utf8.encode(proxyUrl))}', // Fixed base64Encode
          },
        );
      } else {
        // Normal initialization without proxy
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      await _controller?.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _duration = _controller!.value.duration;
          _position = _controller!.value.position;
          _controller!.addListener(_onControllerUpdate);
          _controller!.play();
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      // Show error dialog
      if (mounted) {
                print(_currentQuality);
          if(_currentQuality=='Auto'){
        setState(() {
          _controller?.dispose();        
          // Initialize with new quality url using proxy if configured
          final sources = widget.streams.where((e)=>e.language==_currentLanguage).toList()[0].sources;
          _currentQuality = sources[0].quality;
          _initializeVideoPlayer(sources.where((e)=>e.quality==_currentQuality).toList()[0].url).then((_) {
            _controller!.play();
          });
        _isSettingsVisible = false;
        });
        }else{
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Playback Error'),
            content: Text('Failed to load video${proxyUrl != null ? ' using proxy' : ''}: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initStorage();
    _initSettings().then((_) {
      List<SourceClass> source = widget.streams[0].sources.where((e)=>e.quality==_defaultQuality.replaceAll("p", "")).toList();
      if(source.isNotEmpty){
        setState(() {
          _currentQuality = _defaultQuality;
        });
      }
      String videoUrl = _defaultQuality=='Auto'?widget.streams[0].url:source.isNotEmpty?source[0].url:widget.streams[0].url;
      _currentLanguage = widget.streams[0].language;
      
      // Initialize video player with proxy support
      _initializeVideoPlayer(videoUrl);
    });
    _transformationController = TransformationController();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener(_onZoomAnimationStatus);

    _startHideTimer();

    // Add periodic position update
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (mounted && _controller != null && _controller!.value.isInitialized) {
        _onControllerUpdate();
      }
    });

    _seekAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _seekIconAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _seekAnimationController,
      curve: Curves.easeOut,
    ));

    _seekTextAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _seekAnimationController,
      curve: Curves.easeOut,
    ));

    // Initialize seek button animations
    _forwardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rewindAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _forwardRotation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _forwardAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _rewindRotation = Tween(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(
        parent: _rewindAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize seek indicator animations
    _seekForwardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _seekRewindAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _seekForwardRotation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _seekForwardAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _seekRewindRotation = Tween(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(
        parent: _seekRewindAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _startControlsTimer();
    _controller?.addListener(_onVideoProgress);
  }

  Future<void> _initStorage() async {
    try {
      storage = await Hive.openBox(widget.data.title);
      if (!storage!.isOpen) return;
      
      // Initialize episode info if not set
      if (!storage!.containsKey("season")) {
        await storage?.put("season", "S${widget.currentEpisode ?? 1}");
      }
      if (!storage!.containsKey("episode")) {
        await storage?.put("episode", "E${widget.currentEpisode ?? 1}");
      }
    } catch (e) {
      debugPrint('Error initializing storage: $e');
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    // Update continue watching when exiting player
    if (_controller != null && _controller!.value.isInitialized) {
      final position = _controller!.value.position;
      final duration = _controller!.value.duration;
      
      // Only add to continue watching if watched more than 1% and less than 95%
      if (position.inSeconds > 0 && 
          (position.inSeconds / duration.inSeconds) < 0.95) {
        WatchHistoryService.instance.updateContinueWatching(
          widget.data,
          position,
          duration,
        );
      } else if (position.inSeconds / duration.inSeconds >= 0.95) {
        // Remove from continue watching if exists
        WatchHistoryService.instance.removeFromContinueWatching(widget.data.id);
      }
    }

    // Add to history when finished watching
    if (_progress >= 0.9) {
      WatchHistoryService.instance.addToHistory(widget.data);
    }
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    _seekAnimationController.dispose();
    _doubleTapTimer?.cancel();
    _consecutiveTapTimer?.cancel();
    _controller?.dispose();
    _hideTimer?.cancel();
    _forwardAnimationController.dispose();
    _rewindAnimationController.dispose();
    _seekForwardAnimationController.dispose();
    _seekRewindAnimationController.dispose();
    _controlsTimer?.cancel();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _onZoomAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _zoomAnimation?.removeListener(_onZoomAnimation);
      _zoomAnimation = null;
      _zoomAnimationController.reset();
    }
  }

  void _onZoomAnimation() {
    if (_zoomAnimation != null) {
      _transformationController.value = _zoomAnimation!.value;
    }
  }

  void _handleZoomReset() {
    _isZoomed = false;
    final Matrix4 current = _transformationController.value;
    _zoomAnimation = Matrix4Tween(
      begin: current,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeOutExpo,
    ));
    _zoomAnimation!.addListener(_onZoomAnimation);
    _zoomAnimationController.forward();
    _currentScale = 1.0;
    _baseScale = 1.0;
  }

  void _handleZoomUpdate(ScaleUpdateDetails details) {
    if (_zoomAnimationController.isAnimating) return;

    final double newScale = (_baseScale * details.scale).clamp(1.0, _maxScale);
    
    if (newScale == 1.0 && _currentScale != 1.0) {
      _handleZoomReset();
      return;
    }

    setState(() {
      _currentScale = newScale;
      _isZoomed = _currentScale > 1.0;

      // Calculate the focal point for zooming
      final Offset centerOffset = details.localFocalPoint;
      final Matrix4 matrix = Matrix4.identity()
        ..translate(centerOffset.dx, centerOffset.dy)
        ..scale(_currentScale)
        ..translate(-centerOffset.dx, -centerOffset.dy);

      _transformationController.value = matrix;
    });
  }

  void _handleZoomEnd(ScaleEndDetails details) {
    _baseScale = _currentScale;
    if (_currentScale <= 1.1) {
      _handleZoomReset();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!_isSettingsVisible && !_isEpisodesVisible && mounted) {
        setState(() {
          _isCountrollesVisible = false;
        });
      }
    });
  }

  void _cancelAndRestartHideTimer() {
    _hideTimer?.cancel();
    setState(() {
      _isCountrollesVisible = true;
    });
    _startHideTimer();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        // Enable true fullscreen including notch area
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );
      } else {
        // Return to normal mode
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        ).then((_) {
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
          );
        });
      }
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    });
  }

  void _toggleSettingsMenu() {
    setState(() {
      _isSettingsVisible = !_isSettingsVisible;
      _settingsPage = 'main';
      _cancelAndRestartHideTimer();
    });
  }

  void _toggleEpisodesMenu() {
    setState(() {
      _isEpisodesVisible = !_isEpisodesVisible;
      _cancelAndRestartHideTimer();
    });
  }

  void _showSettingsOptions(String page) {
    setState(() {
      _settingsPage = page;
      _cancelAndRestartHideTimer();
    });
  }

  void _handleSettingsBack() {
    setState(() {
      if (_settingsPage == 'main') {
        _isSettingsVisible = false;
      } else {
        _settingsPage = 'main';
      }
      _cancelAndRestartHideTimer();
    });
  }

  void _selectQuality(String quality, String url) async {
    if (_currentQuality != quality) {
      // Store current position before disposing
      final currentPosition = _controller?.value.position ?? Duration.zero;
      final wasPlaying = _controller?.value.isPlaying ?? false;
      
      setState(() {
        _controller?.dispose();
        _currentQuality = quality;
        _saveSetting('defaultQuality', '${quality}p');
        
        // Initialize with new quality url using proxy if configured
        _initializeVideoPlayer(url).then((_) {
          if (_controller != null && _controller!.value.isInitialized) {
            _controller!.seekTo(currentPosition).then((_) {
              if (wasPlaying) {
                _controller!.play();
              }
            });
          }
        });
        
        _isSettingsVisible = false;
      });
    }
  }

  void _selectLanguage(StreamClass data) async {
    if (_currentLanguage != data.language) {
      // Store current position
      final currentPosition = _controller?.value.position ?? Duration.zero;
      final wasPlaying = _controller?.value.isPlaying ?? false;
      
      setState(() {
        _controller?.dispose();
        _currentLanguage = data.language;
        
        // Initialize with new language url using proxy if configured
        _initializeVideoPlayer(
          _currentQuality == 'Auto' ? data.url : getSourceOfQuality(data)
        ).then((_) {
          if (_controller != null && _controller!.value.isInitialized) {
            _controller!.seekTo(currentPosition).then((_) {
              if (wasPlaying) {
                _controller!.play();
              }
            });
          }
        });
        
        _isSettingsVisible = false;
      });
    }
  }

  void _selectSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _controller?.setPlaybackSpeed(speed);
      _isSettingsVisible = false;
    });
  }

  void _handleTap() {
    setState(() {
        _isCountrollesVisible = !_isCountrollesVisible;
        if (_isCountrollesVisible) {
          _cancelAndRestartHideTimer();
        }
    });
  }


  void _handleDoubleTapSeek(BuildContext context, TapDownDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;
    
    setState(() {
      _consecutiveTaps++;
      _isShowingSeekIndicator = true;
      _isCountrollesVisible = false;
      
      if (tapPosition < screenWidth * 0.5) {
        // Left side - Rewind
        _showRewindIndicator = true;
        _seekRewindAnimationController
          ..reset()
          ..forward();
        _seekRelative(-10 * _consecutiveTaps);
      } else {
        // Right side - Forward
        _showForwardIndicator = true;
        _seekForwardAnimationController
          ..reset()
          ..forward();
        _seekRelative(10 * _consecutiveTaps);
      }
    });

    _consecutiveTapTimer?.cancel();
    _consecutiveTapTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _consecutiveTaps = 0;
        _showRewindIndicator = false;
        _showForwardIndicator = false;
        _isShowingSeekIndicator = false;
      });
    });
  }


  void _seekRelative(int seconds) async {
    if (!_controller!.value.isInitialized) return;

    final currentPosition = _controller!.value.position;
    final duration = _controller!.value.duration;
    final newPosition = currentPosition + Duration(seconds: seconds);

    // Ensure we don't seek beyond bounds
    if (newPosition < Duration.zero) {
      await _controller!.seekTo(Duration.zero);
    } else if (newPosition > duration) {
      await _controller!.seekTo(duration);
    } else {
      await _controller!.seekTo(newPosition);
    }

    // Update progress after seeking
    setState(() {
      _position = _controller!.value.position;
      _progress = _position!.inMilliseconds / duration.inMilliseconds;
    });
  }

  void _togglePlayPause() {
    if (_isBuffering || _controller == null) return;
    setState(() {
      if (_isPlaying) {
        _controller!.pause();
        WakelockPlus.disable();
      } else {
        _controller!.play();
        WakelockPlus.enable();
      }
      _isPlaying = !_isPlaying;
      _isCountrollesVisible = true;
      _cancelAndRestartHideTimer();
    });
  }


  void _handleProgressChanged(double value) {
    if (!_controller!.value.isInitialized) return;

    setState(() {
      _isDraggingSlider = true;
      _dragProgress = value;
      _progress = value; // Update visual progress
      final duration = _controller!.value.duration;
      _position = Duration(milliseconds: (duration.inMilliseconds * value).round());
    });
  }

  void _handleProgressChangeEnd(double value) {
    if (!_controller!.value.isInitialized) return;
    
    final duration = _controller!.value.duration;
    final position = Duration(milliseconds: (duration.inMilliseconds * value).round());
    
    _controller!.seekTo(position).then((_) {
      setState(() {
        _isDraggingSlider = false;
        _progress = value;
        _position = position;
      });
    });
    
    _cancelAndRestartHideTimer();
  }

  Widget _buildSettingsMenu() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      right: _isSettingsVisible ? 0 : -250, // Changed from right to left
      top: 0,
      bottom: 0,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _settingsPage == 'main' ? Icons.close : Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: _handleSettingsBack,
                  ),
                  Text(
                    _settingsPage == 'main' ? 'Settings' 
                    : _settingsPage == 'quality' ? 'Quality' 
                    : _settingsPage == 'language' ? 'Language'
                    : 'Speed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: _settingsPage == 'main'
                    ? Column(
                        children: settingElements.map((element) => 
                          ListTile(
                            onTap: () => _showSettingsOptions(element.toLowerCase()),
                            title: Text(
                              element,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  element == 'Quality' ? _currentQuality 
                                  : element == 'Language' ? _currentLanguage
                                  : _playbackSpeed == 1.0 ? 'Normal' : '${_playbackSpeed}x',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
                              ],
                            ),
                          ),
                        ).toList(),
                      )
                    : Column(
                        children: _settingsPage == 'quality'
                            ? [
                                _buildOptionTile('Auto', _currentQuality == 'Auto',() => _selectQuality('Auto', widget.streams.where((e)=>e.language==_currentLanguage).toList()[0].url)),
                                ...widget.streams[0].sources
                                    .where((source) => source.quality != 'Auto')
                                    .map((source) => _buildOptionTile(
                                        '${source.quality}p',
                                        _currentQuality == source.quality,
                                        () => _selectQuality(source.quality, source.url)))
                              ]
                            : _settingsPage == 'language'
                            ? widget.streams
                                .map((stream) => _buildOptionTile(
                                    stream.language,
                                    _currentLanguage == stream.language,
                                    () => _selectLanguage(stream)))
                                .toList()
                            : _speedOptions.map((option) => ListTile(
                                onTap: () => _selectSpeed(option['value']),
                                title: Text(
                                  option['label'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: _playbackSpeed == option['value']
                                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                                    : null,
                                selected: _playbackSpeed == option['value'],
                                selectedTileColor: Colors.white.withOpacity(0.1),
                              )).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(String title, bool isSelected, [Function()? onTap]) {
    return ListTile(
      onTap: onTap,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed, [bool isForward = true]) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onPressed();
          if (isForward) {
            _forwardAnimationController.forward(from: 0.0);
          } else {
            _rewindAnimationController.forward(from: 0.0);
          }
          _cancelAndRestartHideTimer();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: RotationTransition(
            turns: isForward ? _forwardRotation : _rewindRotation,
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          Icons.replay_10_rounded,
          () => _seekRelative(-10),
          false
        ),
        const SizedBox(width: 32),
        _buildPlayPauseButton(),
        const SizedBox(width: 32),
        _buildControlButton(
          Icons.forward_10_rounded,
          () => _seekRelative(10),
          true
        ),
      ],
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedOpacity(
      opacity: _isCountrollesVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background.withOpacity(0.8),
              Colors.transparent,
              Colors.transparent,
              Theme.of(context).colorScheme.background.withOpacity(0.8),
            ],
            stops: const [0.0, 0.2, 0.8, 1.0],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTopBar(),
            if (!_isInitialized) 
              _buildLoadingIndicator()
            else
              _buildControlsRow(),
            _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            _formatDuration(_position ?? Duration.zero),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: Theme.of(context).colorScheme.primary,
                    overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Buffer progress
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 12),
                        child: LinearProgressIndicator(
                          value: _bufferingProgress,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.3)
                          ),
                          minHeight: 4,
                        ),
                      ),
                      // Playback progress
                      if (_isInitialized)
                        Slider(
                          value: _isDraggingSlider ? _dragProgress.clamp(0.0, 1.0) : _progress.clamp(0.0, 1.0),
                          min: 0.0,
                          max: 1.0,
                          onChanged: _handleProgressChanged,
                          onChangeEnd: _handleProgressChangeEnd,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(_duration ?? Duration.zero),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Widget _buildTopBar() {
    // Get current episode title if available
    String currentTitle = widget.title;
    if (widget.contentType == 'tv' && widget.episodes != null && widget.currentEpisode != null) {
      final currentEpisodeData = widget.episodes!.firstWhere(
        (ep) => ep.episode == widget.currentEpisode,
        orElse: () => widget.episodes!.first,
      );
      currentTitle = '${widget.title} - ${currentEpisodeData.name}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            iconSize: 24,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.contentType == 'tv' && widget.currentEpisode != null)
                  Text(
                    'Episode ${widget.currentEpisode}${widget.episodes != null ? " - ${widget.episodes!.firstWhere((ep) => ep.episode == widget.currentEpisode, orElse: () => widget.episodes!.first).name}" : ""}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // ...rest of existing action buttons
          if (_isZoomed)
            _buildZoomIndicator(),
          if (widget.contentType == 'tv')
            IconButton(
              onPressed: _toggleEpisodesMenu,
              icon: const Icon(Icons.playlist_play_rounded),
              iconSize: 32,
              color: Colors.white,
            ),
          IconButton(
            onPressed: _toggleSettingsMenu,
            icon: const Icon(Icons.settings),
            iconSize: 28,
            color: Colors.white,
          ),
          if (Theme.of(context).platform != TargetPlatform.android && 
              Theme.of(context).platform != TargetPlatform.iOS)
            IconButton(
              onPressed: _toggleFullScreen,
              icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
              iconSize: 28,
              color: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildTapOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Left tap area
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.5,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: (details) {
                if (!_isSettingsVisible && !_isEpisodesVisible) {
                  _handleDoubleTapSeek(context, details);
                }
              },
              onDoubleTap: () {},
              onTap: _handleTap,
            ),
          ),
          // Right tap area
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.5,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: (details) {
                if (!_isSettingsVisible && !_isEpisodesVisible) {
                  _handleDoubleTapSeek(context, details);
                }
              },
              onDoubleTap: () {},
              onTap: _handleTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    if (_isBuffering) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: InkWell(
          onTap: _togglePlayPause,
          borderRadius: BorderRadius.circular(28),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Future<void> _handleEpisodeSelected(int episodeNumber) async {
    if (episodeNumber == -1) {
      setState(() => _isEpisodesVisible = false);
      return;
    }

    if (widget.onEpisodeSelected != null && widget.episodes != null) {
      try {
        if (storage?.isOpen ?? false) {
          await storage?.put("episode", "E$episodeNumber");
        }
        widget.onEpisodeSelected!(episodeNumber);
      } catch (e) {
        debugPrint('Error updating episode: $e');
      }
    }
  }

  Future<void> _handleNextEpisode() async {
    if (widget.onEpisodeSelected != null && 
        widget.currentEpisode != null && 
        widget.episodes != null &&
        widget.currentEpisode! < widget.episodes!.length) {
      final nextEpisode = widget.currentEpisode! + 1;
      try {
        if (storage?.isOpen ?? false) {
          await storage?.put("episode", "E$nextEpisode");
        }
        widget.onEpisodeSelected!(nextEpisode);
      } catch (e) {
        debugPrint('Error updating to next episode: $e');
      }
    }
  }

  void _onVideoProgress() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;

    // Check if video is near the end (95% or more)
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final progress = position.inMilliseconds / duration.inMilliseconds;

    if (progress >= 0.95) {
      // Check conditions for auto-play next
      if (widget.contentType == 'tv' && 
          widget.currentEpisode != null && 
          widget.episodes != null &&
          widget.currentEpisode! < widget.episodes!.length &&
          _autoPlayNext) {
        _handleNextEpisode();
      }
    }
  }

  bool _isLocked = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _autoPlayTimer;
  bool _isAutoPlayDialogShowing = false;

  void _startControlsTimer() {
    if (_isLocked) return;
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isLocked) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showAutoPlayDialog() {
    setState(() => _isAutoPlayDialogShowing = true);
    
    _autoPlayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.onNextEpisode != null) {
        widget.onNextEpisode!(widget.currentEpisode! + 1);
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Next Episode'),
        content: const Text('Playing next episode in 5 seconds...'),
        actions: [
          TextButton(
            onPressed: () {
              _autoPlayTimer?.cancel();
              setState(() => _isAutoPlayDialogShowing = false);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _autoPlayTimer?.cancel();
              Navigator.pop(context);
              widget.onNextEpisode?.call(widget.currentEpisode! + 1);
            },
            child: const Text('Play Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNextEpisode = widget.episodes != null && 
                          widget.currentEpisode != null && 
                          widget.currentEpisode! < widget.episodes!.length;

    return Scaffold(
      body: Stack(
        children: [
          // Video Layer
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: _maxScale,
              onInteractionUpdate: _handleZoomUpdate,
              onInteractionEnd: _handleZoomEnd,
              clipBehavior: Clip.none,
              panEnabled: _isZoomed,
              scaleEnabled: true,
              child: AspectRatio(
                aspectRatio: _controller!.value.isInitialized
                    ? _controller!.value.aspectRatio
                    : MediaQuery.of(context).size.width / MediaQuery.of(context).size.height,
                child: _controller != null 
                    ? VideoPlayer(_controller!)
                    : const Center(
                        child: CircularProgressIndicator(),
                      ),
              ),
            ),
          ),
          if (_showRewindIndicator || _showForwardIndicator)
            _buildSeekIndicators(),
          _buildTapOverlay(),

          Stack(
            children: [
              // Controls overlay with animation
              AnimatedOpacity(
                opacity: _isCountrollesVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Stack(
                  children: [
                    // Background when controls are visible
                    if (_isCountrollesVisible)
                      Container(color: Colors.black.withOpacity(0.3)),
                    // Controls
                    if (_isCountrollesVisible)
                      GestureDetector(
                        onTap: _handleTap,
                        onDoubleTapDown: (details) => _handleDoubleTapSeek(context, details),
                        child: _buildControlsOverlay(),
                      ),
                  ],
                ),
              ),

              // Settings menu (separate opacity animation)
              _buildSettingsMenu(),

              // Episodes menu with modified visibility handling
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                right: _isEpisodesVisible ? 0 : -400,
                top: 0,
                bottom: 0,
                child: EpisodeListForPlayer(
                  episodes: widget.episodes ?? [], // Provide empty list as fallback
                  currentEpisode: widget.currentEpisode,
                  onEpisodeSelected: _handleEpisodeSelected,
                  hasNextEpisode: hasNextEpisode,
                ),
              ),
            ],
          ),

          // Next episode button
          if (widget.contentType == 'tv' && 
              _isInitialized && 
              hasNextEpisode &&
              !_autoPlayNext)
            Positioned(
              right: 24,
              bottom: 100,
              child: NextEpisodeButton(
                progress: _progress,
                onTap: _handleNextEpisode,
              ),
            ),

          // Custom controls overlay
          if (_showControls)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black54,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Lock button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(
                          _isLocked ? Icons.lock : Icons.lock_open,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(() => _isLocked = !_isLocked),
                      ),
                    ),

                    // Episode navigation
                    if (!_isLocked && widget.contentType == 'tv')
                      Positioned(
                        bottom: 80,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.hasPreviousEpisode)
                              _NavigationButton(
                                icon: Icons.skip_previous,
                                label: 'Previous',
                                onPressed: () => widget.onPreviousEpisode?.call(
                                  widget.currentEpisode! - 1,
                                ),
                              ),
                            if (widget.hasNextEpisode) ...[
                              const SizedBox(width: 16),
                              _NavigationButton(
                                icon: Icons.skip_next,
                                label: 'Next',
                                onPressed: () => widget.onNextEpisode?.call(
                                  widget.currentEpisode! + 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeekIndicators() {
    return Row(
      children: [
        Expanded(
          child: AnimatedOpacity(
            opacity: _showRewindIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _buildSeekIndicator(Icons.replay_10, "-10s", false),
          ),
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.2),
        Expanded(
          child: AnimatedOpacity(
            opacity: _showForwardIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _buildSeekIndicator(Icons.forward_10, "+10s", true),
          ),
        ),
      ],
    );
  }

  Widget _buildSeekIndicator(IconData icon, String text, bool isForward) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: isForward ? _seekForwardRotation : _seekRewindRotation,
              child: Icon(
                icon,
                color: Colors.white,
                size: 45,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_consecutiveTaps * 10}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isZoomed ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.zoom_in, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${(_currentScale * 100).toInt()}%',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}