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
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/api/class/server_class.dart';
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/components/episode_list_player.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:moviedex/services/watch_history_service.dart';
import 'package:moviedex/components/next_episode_button.dart';
import 'package:moviedex/services/proxy_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zoom_widget/zoom_widget.dart';
import '../api/class/subtitle_class.dart';
import '../services/subtitle_service.dart';
// Add window_manager import for desktop platforms
import 'package:window_manager/window_manager.dart';

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

  final List<SubtitleClass>? subtitles;

  final List<ServerClass> servers;
  final Function(int)? onServerChanged;
  final Function(int)? onActiveServerReset;
  final int currentServerIndex;

  const ContentPlayer({
    super.key,
    required this.data,
    required this.streams,
    required this.contentType,
    this.currentEpisode,
    required this.title,
    this.episodes,
    this.onEpisodeSelected, // Add this to constructor
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.hasNextEpisode = false,
    this.hasPreviousEpisode = false,
    this.subtitles,
    required this.servers,
    this.onServerChanged,
    this.onActiveServerReset,
    required this.currentServerIndex,
  });

  @override
  State<ContentPlayer> createState() => _ContentPlayerState();
}

class _ContentPlayerState extends State<ContentPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Add WidgetsBindingObserver mixin
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
  List settingElements = [
    "Quality",
    "Language",
    "Speed",
    "Subtitles",
    "Servers"
  ];
  bool _showForwardIndicator = false;
  bool _showRewindIndicator = false;
  late AnimationController _seekAnimationController;
  late Animation<double> _seekIconAnimation;
  late Animation<double> _seekTextAnimation;
  bool _isDraggingSlider = false;
  double _dragProgress = 0.0;

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
  String _preferredLanguage = 'original';
  String _preferredServer = '';

  late Box? storage;

  // Add lock state
  bool _isLocked = false;

  // Add new state variables
  SubtitleClass? _currentSubtitle;
  List<SubtitleEntry>? _subtitleEntries;
  String? _currentSubtitleText;
  bool _subtitlesEnabled = true;

  String? _currentPlaybackUrl; // Track current playback URL for reinitializing

  // Add new variables for volume control
  double _volume = 1.0;
  bool _isMuted = false;

  // Add new variable for keyboard focus
  final FocusNode _playerFocusNode = FocusNode();

  // Add flag to track if we're on a desktop platform
  bool get _isDesktopPlatform =>
      Theme.of(context).platform == TargetPlatform.windows ||
      Theme.of(context).platform == TargetPlatform.linux ||
      Theme.of(context).platform == TargetPlatform.macOS;

  // Store pre-fullscreen window bounds
  Rect? _windowBoundsBeforeFullScreen;

  String getSourceOfQuality(StreamClass data) {
    final source = data.sources
        .where((source) => source.quality == _currentQuality)
        .toList();
    if (source.isEmpty) {
      _currentQuality = 'Auto';
      return data.url;
    } else {
      return source[0].url;
    }
  }

  void _onControllerUpdate() async {
    if (!mounted ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        _isDraggingSlider) return;

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
        // _isBuffering = _controller!.value.isBuffering && !_isPlaying;

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
          _bufferingProgress =
              bufferedEnd.inMilliseconds / duration.inMilliseconds;
        });
      }
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  Future<void> _initSettings() async {
    _settingsBox = await Hive.openBox('settings');
    _defaultQuality = _settingsBox.get('defaultQuality', defaultValue: 'Auto');
    _preferredLanguage =
        _settingsBox.get('preferredLanguage', defaultValue: 'original');
    _preferredServer = _settingsBox.get('preferredServer', defaultValue: '');
    _useCustomProxy = _settingsBox.get('useCustomProxy', defaultValue: false);
    _autoPlayNext = _settingsBox.get('autoPlayNext', defaultValue: true);
    _useHardwareDecoding =
        _settingsBox.get('useHardwareDecoding', defaultValue: true);
  }

  void _tryUsePreferredLanguage() {
    if (_preferredLanguage != 'original' && widget.streams.isNotEmpty) {
      // Look for streams with preferred language
      final preferredStreams = widget.streams
          .where((stream) => stream.language == _preferredLanguage)
          .toList();
      if (preferredStreams.isNotEmpty) {
        _currentLanguage = _preferredLanguage;
      } else {
        // Fallback to default language if preferred not available
        _currentLanguage = widget.streams[0].language;
      }
    } else {
      // Use first available language if no preference
      _currentLanguage =
          widget.streams.isNotEmpty ? widget.streams[0].language : 'original';
    }
  }

  void _tryUsePreferredSubtitle() {
    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      final preferredSubtitleLanguage =
          _settingsBox.get('preferredSubtitleLanguage', defaultValue: null);

      if (preferredSubtitleLanguage != null) {
        final preferredSubtitles = widget.subtitles!
            .where((subtitle) => subtitle.language == preferredSubtitleLanguage)
            .toList();
        if (preferredSubtitles.isNotEmpty) {
          _currentSubtitle = preferredSubtitles.first;
        } else {
          _currentSubtitle = widget.subtitles!.first;
        }
      } else {
        _currentSubtitle = widget.subtitles!.first;
      }

      _loadSubtitles();
    }
  }

  Future<void> _initializeVideoPlayer(String url) async {
    // Store the current URL for possible reinitialization
    _currentPlaybackUrl = url;
    try {
      final Map<String, String> headers = {
        "origin": widget.streams.first.baseUrl ?? "",
        "Referer": widget.streams.first.baseUrl ?? "",
      };
      print(widget.streams.first.baseUrl);
      // Normal initialization without proxy
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: true, // Allow background buffering
        ),
      );
      // Set a longer timeout for initialization
      await _controller?.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Video initialization timed out');
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _duration = _controller!.value.duration;
          _position = _controller!.value.position;
          _controller!.addListener(_onControllerUpdate);
          _controller!.play();

          // Set volume to match current state
          _controller!.setVolume(_isMuted ? 0.0 : _volume);

          // Set playback speed to match current state
          if (_playbackSpeed != 1.0) {
            _controller!.setPlaybackSpeed(_playbackSpeed);
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');

      if (mounted) {
        // Handle playback error by trying alternative sources
        await _handlePlaybackError();
      }
    }
  }

  /// Handles playback errors by trying alternative sources in this order:
  /// 1. Try different quality of same language
  /// 2. Try different language if available
  /// 3. Try different server if available
  Future<void> _handlePlaybackError() async {
    // Check if Auto quality and try specific quality instead
    if (_currentQuality == 'Auto') {
      final currentStream = widget.streams
          .where((stream) => stream.language == _currentLanguage)
          .toList();

      if (currentStream.isNotEmpty && currentStream[0].sources.isNotEmpty) {
        // Try first specific quality instead of Auto
        final sourceToTry = currentStream[0].sources.first;
        debugPrint(
            'Trying specific quality: ${sourceToTry.quality} instead of Auto');

        setState(() {
          _isBuffering = true;
          _currentQuality = sourceToTry.quality;
        });

        return _initializeVideoPlayer(sourceToTry.url)
            .catchError((_) => _tryNextLanguageOrServer());
      } else {
        return _tryNextLanguageOrServer();
      }
    } else {
      // Already using specific quality, try next language or server
      return _tryNextLanguageOrServer();
    }
  }

  /// Try next available language or server
  Future<void> _tryNextLanguageOrServer() async {
    // First try a different language if available
    final availableLanguages = widget.streams
        .map((stream) => stream.language)
        .where((lang) => lang != _currentLanguage)
        .toList();

    if (availableLanguages.isNotEmpty) {
      debugPrint('Trying next language: ${availableLanguages.first}');
      // Find stream with this language
      final nextLanguageStream = widget.streams
          .firstWhere((stream) => stream.language == availableLanguages.first);

      setState(() {
        _isBuffering = true;
        _currentLanguage = availableLanguages.first;
        _currentQuality = 'Auto'; // Reset quality for new language
      });

      return _initializeVideoPlayer(nextLanguageStream.url)
          .catchError((_) => _tryNextServer());
    } else {
      return _tryNextServer();
    }
  }

  /// Try next available server
  Future<void> _tryNextServer() async {
    if (widget.servers.length > 1 && widget.onServerChanged != null) {
      // Find next available server index
      int nextServerIndex;
      if (widget.currentServerIndex == 0) {
        nextServerIndex =
            (widget.currentServerIndex + 1) % widget.servers.length;
      } else {
        nextServerIndex = 0;
      }
      // Skip servers marked as unavailable
      while (nextServerIndex != widget.currentServerIndex &&
          widget.servers[nextServerIndex].status == ServerStatus.unavailable) {
        nextServerIndex = (nextServerIndex + 1) % widget.servers.length;
      }

      if (nextServerIndex != widget.currentServerIndex) {
        debugPrint(
            'Trying next server: ${widget.servers[nextServerIndex].name}');

        // Show a notification to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Playback error. Trying server: ${widget.servers[nextServerIndex].name}'),
            duration: Duration(seconds: 2),
          ),
        );

        // Use the onServerChanged callback to switch to next server
        widget.onActiveServerReset!(nextServerIndex).then((isSuccess) {
          if (isSuccess) {
            setState(() {
              _controller?.dispose();
              initPlayer();
            });
          }
        });
        return;
      }
    }

    // If we've tried everything, show error dialog
    _showPlaybackErrorDialog();
  }

  void _showPlaybackErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playback Error'),
        content: const Text(
          'Unable to play this content with current settings. '
          'Please try a different server, quality or check your connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void initPlayer() {
    _tryUsePreferredLanguage();
    StreamClass streamToUse;
    if (widget.streams.isNotEmpty) {
      final preferredStreams = widget.streams
          .where((stream) => stream.language == _currentLanguage)
          .toList();
      streamToUse = preferredStreams.isNotEmpty
          ? preferredStreams.first
          : widget.streams.first;
      _currentLanguage = streamToUse.language;
      // Try to use preferred quality if available
      List<SourceClass> sources = streamToUse.sources
          .where((e) => e.quality == _defaultQuality.replaceAll("p", ""))
          .toList();

      if (sources.isNotEmpty) {
        setState(() {
          _currentQuality = _defaultQuality.replaceAll("p", "");
        });
        _initializeVideoPlayer(sources.first.url);
      } else {
        // Fallback to Auto quality
        setState(() {
          _currentQuality = 'Auto';
        });
        _initializeVideoPlayer(streamToUse.url);
      }
    }

    // Load preferred subtitle if available
    _tryUsePreferredSubtitle();
  }

  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Request focus when player is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _playerFocusNode.requestFocus();
      }
    });

    WakelockPlus.enable();
    _initStorage();
    _initSettings().then((_) => initPlayer());

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

    // Initialize subtitles if available
    if (widget.subtitles != null && widget.subtitles!.isNotEmpty) {
      _currentSubtitle = widget.subtitles!.first;
      _loadSubtitles();
    }

    // Add subtitle update timer
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateSubtitles();
    });

    // Initialize window manager for desktop platforms
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initWindowManager();
    });
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

  Future<void> _initWindowManager() async {
    if (_isDesktopPlatform) {
      // Initialize window manager
      await windowManager.ensureInitialized();

      // Create concrete implementation of WindowListener with renamed callback fields
      windowManager.addListener(_WindowListenerImpl(
        onEnterFullScreen: () {
          if (!_isFullScreen && mounted) {
            setState(() => _isFullScreen = true);
          }
        },
        onLeaveFullScreen: () {
          if (_isFullScreen && mounted) {
            setState(() => _isFullScreen = false);
          }
        },
      ));
    }
  }

  @override
  void dispose() {
    // Remove observer when disposing
    WidgetsBinding.instance.removeObserver(this);

    // Dispose of focus node
    _playerFocusNode.dispose();

    WakelockPlus.disable();
    // Add to history when finished watching
    if (_progress >= 0.9) {
      WatchHistoryService.instance.addToHistory(widget.data);
    }
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

    // Exit fullscreen if active before disposing
    if (_isFullScreen) {
      if (_isDesktopPlatform) {
        windowManager.setFullScreen(false).catchError((error) {
          debugPrint('Error exiting fullscreen on dispose: $error');
        });
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
        SystemChrome.setPreferredOrientations([]);
      }
    }

    super.dispose();
  }

  // Add this method to handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is back in foreground
      if (_controller != null &&
          !_controller!.value.isInitialized &&
          _currentPlaybackUrl != null) {
        // Only reinitialize if the controller is no longer initialized
        // to avoid unnecessary video reloading
        _reinitializeVideoPlayer();
      } else if (_controller != null && _isPlaying) {
        // If controller is still valid but might be paused by the system
        _controller!.play();
      }

      // Re-enable wakelock that might have been disabled in inactive state
      WakelockPlus.enable();

      // Re-request focus for keyboard events
      _playerFocusNode.requestFocus();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // App is going to background - pause video and disable wakelock
      if (_controller != null && _controller!.value.isInitialized) {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        }
        WakelockPlus.disable();
      }
    }
  }

  // Create a separate method for reinitialization to simplify the code
  Future<void> _reinitializeVideoPlayer() async {
    if (!mounted || _currentPlaybackUrl == null) return;

    setState(() {
      _isBuffering = true;
    });

    try {
      final currentPosition = _position ?? Duration.zero;
      await _initializeVideoPlayer(_currentPlaybackUrl!);

      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.seekTo(currentPosition);
        if (_isPlaying) {
          await _controller!.play();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
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

  // Improved fullscreen toggle with better error handling
  void _toggleFullScreen() async {
    try {
      // For desktop platforms, use window_manager
      if (_isDesktopPlatform) {
        if (!_isFullScreen) {
          // Store current window bounds before going fullscreen
          _windowBoundsBeforeFullScreen = await windowManager.getBounds();

          // Enter fullscreen mode
          await windowManager.setFullScreen(true);
          setState(() => _isFullScreen = true);
        } else {
          // Exit fullscreen mode
          await windowManager.setFullScreen(false);

          // Restore previous window bounds if available
          if (_windowBoundsBeforeFullScreen != null) {
            try {
              await windowManager.setBounds(_windowBoundsBeforeFullScreen!);
            } catch (e) {
              debugPrint('Error restoring window bounds: $e');
            }
          }
          setState(() => _isFullScreen = false);
        }
      } else {
        // For mobile platforms, use the existing implementation
        setState(() {
          _isFullScreen = !_isFullScreen;

          if (_isFullScreen) {
            // Enter fullscreen mode - hide system UI
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

            // Set orientation for all platforms
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeRight,
              DeviceOrientation.landscapeLeft,
            ]);
          } else {
            // Exit fullscreen mode - restore system UI
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.manual,
              overlays: SystemUiOverlay.values,
            );

            // For mobile, maintain landscape orientation
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeRight,
              DeviceOrientation.landscapeLeft,
            ]);
          }
        });
      }

      // Re-request focus to ensure keyboard events still work
      _playerFocusNode.requestFocus();
    } catch (e) {
      debugPrint('Error toggling fullscreen: $e');
      // Reset fullscreen state if an error occurs
      setState(() => _isFullScreen = false);
    }
  }

  // Add volume control methods
  void _changeVolume(double amount) {
    if (_controller == null) return;

    setState(() {
      _volume = (_volume + amount).clamp(0.0, 1.0);
      _controller!.setVolume(_volume);
      _isMuted = _volume == 0;

      // Show volume indicator temporarily
      _isCountrollesVisible = true;
      _cancelAndRestartHideTimer();
    });
  }

  void _toggleMute() {
    if (_controller == null) return;

    setState(() {
      if (_isMuted) {
        // Unmute - restore previous volume or set to 50% if was 0
        _volume = _volume == 0 ? 0.5 : _volume;
        _controller!.setVolume(_volume);
        _isMuted = false;
      } else {
        // Store current volume and mute
        _controller!.setVolume(0);
        _isMuted = true;
      }

      // Show controls when mute state changes
      _isCountrollesVisible = true;
      _cancelAndRestartHideTimer();
    });
  }

  // Improved key event handling with specific handling for ESC key
  bool _handleKeyEvent(KeyEvent event) {
    // Always handle ESC key for fullscreen exit regardless of lock state
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _isFullScreen) {
      _toggleFullScreen();
      return true;
    }

    if (_isLocked) {
      // Only handle lock toggle key when locked
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyL) {
        _handleLockToggle();
        return true;
      }
      return false;
    }

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.space:
          _togglePlayPause();
          return true;

        case LogicalKeyboardKey.arrowLeft:
          _seekRelative(-10);
          return true;

        case LogicalKeyboardKey.arrowRight:
          _seekRelative(10);
          return true;

        case LogicalKeyboardKey.arrowUp:
          _changeVolume(0.1);
          return true;

        case LogicalKeyboardKey.arrowDown:
          _changeVolume(-0.1);
          return true;

        case LogicalKeyboardKey.keyF:
          _toggleFullScreen();
          return true;

        case LogicalKeyboardKey.keyM:
          _toggleMute();
          return true;

        case LogicalKeyboardKey.keyL:
          _handleLockToggle();
          return true;

        case LogicalKeyboardKey.escape:
          if (_isSettingsVisible) {
            _handleSettingsBack();
            return true;
          } else if (_isEpisodesVisible) {
            setState(() {
              _isEpisodesVisible = false;
            });
            return true;
          }
      }
    }

    return false;
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
        _currentPlaybackUrl = url; // Update current URL

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
      final newUrl =
          _currentQuality == 'Auto' ? data.url : getSourceOfQuality(data);

      setState(() {
        _controller?.dispose();
        _currentLanguage = data.language;
        _saveSetting('preferredLanguage', data.language);
        _currentPlaybackUrl = newUrl; // Update current URL

        // Initialize with new language url using proxy if configured
        _initializeVideoPlayer(newUrl).then((_) {
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

  void _selectSubtitle(SubtitleClass? subtitle) async {
    setState(() {
      _currentSubtitle = subtitle;
      _currentSubtitleText = '';
      _subtitleEntries = null;
    });

    if (subtitle != null) {
      await _loadSubtitles();
      _saveSetting('preferredSubtitleLanguage', subtitle.language);
    }

    _isSettingsVisible = false;
  }

  Future<void> _loadSubtitles() async {
    if (_currentSubtitle != null) {
      _subtitleEntries =
          await SubtitleService.instance.loadSubtitles(_currentSubtitle!.url);
    }
  }

  void _updateSubtitles() {
    if (!mounted ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        _subtitleEntries == null) return;

    final position = _controller!.value.position;
    final entry = _subtitleEntries!.firstWhere(
      (entry) => position >= entry.start && position <= entry.end,
      orElse: () =>
          SubtitleEntry(start: Duration.zero, end: Duration.zero, text: ''),
    );

    if (mounted && _subtitlesEnabled) {
      setState(() {
        _currentSubtitleText = entry.text;
      });
    }
  }

  void _handleTap() {
    if (_isLocked) return;
    setState(() {
      _isCountrollesVisible = !_isCountrollesVisible;
      if (_isCountrollesVisible) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
        // Hide settings and episodes menu when hiding controls
        _isSettingsVisible = false;
        _isEpisodesVisible = false;
      }
    });
  }

  void _handleDoubleTapSeek(BuildContext context, TapDownDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    setState(() {
      _consecutiveTaps++; // Keep for timer and animation reset
      _isShowingSeekIndicator = true;
      _isCountrollesVisible = false;

      // Always seek by 10 seconds
      const int seekAmount = 10;

      if (tapPosition < screenWidth * 0.5) {
        // Left side - Rewind
        _showRewindIndicator = true;
        _seekRewindAnimationController
          ..reset()
          ..forward();
        _seekRelative(-seekAmount);
      } else {
        // Right side - Forward
        _showForwardIndicator = true;
        _seekForwardAnimationController
          ..reset()
          ..forward();
        _seekRelative(seekAmount);
      }
    });

    _consecutiveTapTimer?.cancel();
    _consecutiveTapTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        // Ensure widget is still mounted
        setState(() {
          _consecutiveTaps = 0;
          _showRewindIndicator = false;
          _showForwardIndicator = false;
          _isShowingSeekIndicator = false;
        });
      }
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
    if (_controller == null) return;

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
      _position =
          Duration(milliseconds: (duration.inMilliseconds * value).round());
    });
  }

  void _handleProgressChangeEnd(double value) {
    if (!_controller!.value.isInitialized) return;

    final duration = _controller!.value.duration;
    final position =
        Duration(milliseconds: (duration.inMilliseconds * value).round());

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
      right: _isSettingsVisible ? 0 : -300, // Changed from right to left
      top: 0,
      bottom: 0,
      child: Container(
        width: 300,
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
                    _settingsPage == 'main'
                        ? 'Settings'
                        : _settingsPage == 'quality'
                            ? 'Quality'
                            : _settingsPage == 'language'
                                ? 'Language'
                                : _settingsPage == 'subtitles'
                                    ? 'Subtitles'
                                    : _settingsPage == 'servers'
                                        ? 'Servers'
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
                        children: settingElements
                            .map(
                              (element) => ListTile(
                                onTap: () =>
                                    _showSettingsOptions(element.toLowerCase()),
                                title: Text(
                                  element,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: SizedBox(
                                  width:
                                      120, // Constrain width of trailing widget
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          element == 'Quality'
                                              ? _currentQuality
                                              : element == 'Language'
                                                  ? _currentLanguage
                                                  : element == 'Subtitles'
                                                      ? (_currentSubtitle
                                                              ?.label ??
                                                          'Off')
                                                      : element == 'Servers'
                                                          ? (widget.servers
                                                                  .isNotEmpty
                                                              ? widget
                                                                  .servers[widget
                                                                      .currentServerIndex]
                                                                  .name
                                                              : 'Default')
                                                          : _playbackSpeed ==
                                                                  1.0
                                                              ? 'Normal'
                                                              : '${_playbackSpeed}x',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right,
                                          color: Colors.white.withOpacity(0.7)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : Column(
                        children: _settingsPage == 'servers' &&
                                widget.servers.isNotEmpty
                            ? widget.servers
                                .asMap()
                                .entries
                                .map(
                                  (entry) => ListTile(
                                    onTap: entry.value.status !=
                                            ServerStatus.unavailable
                                        ? () {
                                            if (widget.onServerChanged !=
                                                null) {
                                              widget.onServerChanged!(entry.key)
                                                  .then((isSuccess) {
                                                if (isSuccess) {
                                                  _controller?.dispose();
                                                  initPlayer();
                                                }
                                              });
                                              // Save preferred server with content-specific key
                                              final preferenceKey = widget
                                                      .data.genres
                                                      .contains("Animation")
                                                  ? 'preferredAnimeServer'
                                                  : 'preferredServer';
                                              _saveSetting(preferenceKey,
                                                  entry.value.name);
                                            }
                                            setState(() =>
                                                _isSettingsVisible = false);
                                          }
                                        : null,
                                    title: Text(
                                      entry.value.name,
                                      style: TextStyle(
                                        color: entry.value.status ==
                                                ServerStatus.unavailable
                                            ? Colors.grey
                                            : Colors.white,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (entry.value.status ==
                                            ServerStatus.active)
                                          Icon(
                                            Icons.check_circle,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          )
                                        else if (entry.value.status ==
                                            ServerStatus.unavailable)
                                          const Icon(
                                            Icons.error,
                                            color: Colors.red,
                                          ),
                                        if (entry.key ==
                                            widget.currentServerIndex)
                                          const SizedBox(width: 8),
                                        if (entry.key ==
                                            widget.currentServerIndex)
                                          const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                          ),
                                      ],
                                    ),
                                    enabled: entry.value.status !=
                                        ServerStatus.unavailable,
                                  ),
                                )
                                .toList()
                            : _settingsPage == 'quality'
                                ? _buildCurrentQualityOptions()
                                : _settingsPage == 'language'
                                    ? _buildCurrentLanguageOptions()
                                    : _settingsPage == 'subtitles'
                                        ? [
                                            _buildOptionTile(
                                              'Off',
                                              _currentSubtitle == null,
                                              () => _selectSubtitle(null),
                                            ),
                                            if (widget.subtitles != null)
                                              ...widget.subtitles!.map(
                                                  (subtitle) =>
                                                      _buildOptionTile(
                                                        subtitle.label ??
                                                            subtitle.language,
                                                        _currentSubtitle
                                                                ?.language ==
                                                            subtitle.language,
                                                        () => _selectSubtitle(
                                                            subtitle),
                                                      )),
                                          ]
                                        : _speedOptions
                                            .map((option) => ListTile(
                                                  onTap: () => _selectSpeed(
                                                      option['value']),
                                                  title: Text(
                                                    option['label'],
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                  trailing: _playbackSpeed ==
                                                          option['value']
                                                      ? Icon(Icons.check,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary)
                                                      : null,
                                                  selected: _playbackSpeed ==
                                                      option['value'],
                                                  selectedTileColor: Colors
                                                      .white
                                                      .withOpacity(0.1),
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

  // New methods to display only current available options
  List<Widget> _buildCurrentQualityOptions() {
    // Find available qualities for current language
    final currentStream = widget.streams
        .where((stream) => stream.language == _currentLanguage)
        .toList();
    if (currentStream.isEmpty) return [];

    // Always add Auto option
    final widgets = [
      _buildOptionTile('Auto', _currentQuality == 'Auto',
          () => _selectQuality('Auto', currentStream[0].url)),
    ];

    // Add available qualities for current stream
    final sources = currentStream[0].sources;
    for (var source in sources) {
      if (source.quality != 'Auto') {
        widgets.add(_buildOptionTile(
          '${source.quality}p',
          _currentQuality == source.quality,
          () => _selectQuality(source.quality, source.url),
        ));
      }
    }

    return widgets;
  }

  List<Widget> _buildCurrentLanguageOptions() {
    // Show only available languages for current video
    return widget.streams
        .map((stream) => _buildOptionTile(stream.language,
            _currentLanguage == stream.language, () => _selectLanguage(stream)))
        .toList();
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

  Widget _buildControlButton(IconData icon, VoidCallback onPressed,
      [bool isForward = true]) {
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
            Icons.replay_10_rounded, () => _seekRelative(-10), false),
        const SizedBox(width: 32),
        _buildPlayPauseButton(),
        const SizedBox(width: 32),
        _buildControlButton(
            Icons.forward_10_rounded, () => _seekRelative(10), true),
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
    ));
  }

  Widget _buildProgressBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
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
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: Theme.of(context).colorScheme.primary,
                    overlayColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                              Colors.white.withOpacity(0.3)),
                          minHeight: 4,
                        ),
                      ),
                      // Playback progress
                      if (_isInitialized)
                        Slider(
                          value: _isDraggingSlider
                              ? _dragProgress.clamp(0.0, 1.0)
                              : _progress.clamp(0.0, 1.0),
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
    if (widget.contentType == 'tv' &&
        widget.episodes != null &&
        widget.currentEpisode != null) {
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
              icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
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
    final bool showBuffering = _isBuffering && !_isPlaying;

    if (showBuffering) {
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
    if (!mounted || _controller == null || !_controller!.value.isInitialized)
      return;

    // Check if video is near the end (95% or more)
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final progress = position.inMilliseconds / duration.inMilliseconds;

    if (progress >= 0.95 && !_isAutoPlayDialogShowing) {
      // Check conditions for auto-play next
      if (widget.contentType == 'tv' &&
          widget.currentEpisode != null &&
          widget.episodes != null &&
          widget.currentEpisode! < widget.episodes!.length) {
        if (_autoPlayNext) {
          // If auto-play is enabled, show dialog with countdown
          _showAutoPlayDialog();
        }
      }
    }
  }

  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _autoPlayTimer;
  bool _isAutoPlayDialogShowing = false;

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showAutoPlayDialog() {
    setState(() => _isAutoPlayDialogShowing = true);

    _autoPlayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.currentEpisode != null) {
        _handleNextEpisode();
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
              _handleNextEpisode();
            },
            child: const Text('Play Now'),
          ),
        ],
      ),
    );
  }

  void _handleLockToggle() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _isCountrollesVisible = false;
        _isSettingsVisible = false;
        _isEpisodesVisible = false;
        _hideTimer?.cancel();
      } else {
        _isCountrollesVisible = true;
        _startHideTimer();
      }
    });
  }

  Widget _buildLockButton() {
    return Positioned(
      left: 16,
      top: MediaQuery.of(context).size.height * 0.5 - 24, // Center vertically
      child: AnimatedOpacity(
        opacity: _isCountrollesVisible || _isLocked ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: _handleLockToggle,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              _isLocked ? Icons.lock : Icons.lock_open,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  // Add this function to detect RTL languages
  bool _isRTL(String text) {
    if (text.isEmpty) return false;

    // Arabic, Hebrew, Persian, and other RTL Unicode character ranges
    final rtlRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\u0590-\u05FF\uFB50-\uFDFF\uFE70-\uFEFF]');

    // Check if the text contains RTL characters
    return rtlRegex.hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final hasNextEpisode = widget.episodes != null &&
        widget.currentEpisode != null &&
        widget.currentEpisode! < widget.episodes!.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _playerFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                color: Colors.black,
                child: Zoom(
                  initTotalZoomOut: true,
                  maxZoomWidth: MediaQuery.of(context).size.width,
                  maxZoomHeight: MediaQuery.of(context).size.height,
                  canvasColor: Colors.black,
                  backgroundColor: Colors.black,
                  colorScrollBars: Colors.transparent,
                  opacityScrollBars: 0.0,
                  scrollWeight: 0.0,
                  centerOnScale: true,
                  enableScroll: !_isLocked,
                  doubleTapZoom: !_isLocked,
                  zoomSensibility: _isLocked ? 0 : 1.0,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.isInitialized
                            ? _controller!.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Controls Layer - make sure it's above the video
            Positioned.fill(
              child: Stack(
                children: [
                  if (_showRewindIndicator || _showForwardIndicator)
                    _buildSeekIndicators(),
                  _buildTapOverlay(),

                  // Controls overlay
                  Stack(
                    children: [
                      // Controls overlay with animation
                      AnimatedOpacity(
                        opacity: _isCountrollesVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Stack(
                          children: [
                            if (_isCountrollesVisible)
                              Container(
                                color: Colors.black.withOpacity(0.3),
                              ),
                            if (_isCountrollesVisible)
                              GestureDetector(
                                onTap: _handleTap,
                                onDoubleTapDown: (details) =>
                                    _handleDoubleTapSeek(context, details),
                                child: _buildControlsOverlay(),
                              ),
                          ],
                        ),
                      ),

                      // Settings and episodes menus
                      _buildSettingsMenu(),
                      if (widget.contentType == 'tv')
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          right: _isEpisodesVisible ? 0 : -400,
                          top: 0,
                          bottom: 0,
                          child: EpisodeListForPlayer(
                            episodes: widget.episodes ?? [],
                            currentEpisode: widget.currentEpisode,
                            onEpisodeSelected: _handleEpisodeSelected,
                            hasNextEpisode: hasNextEpisode,
                          ),
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

                      // Lock button
                      _buildLockButton(),
                    ],
                  ),
                ],
              ),
            ),

            // Add subtitle overlay to the Stack
            if (_subtitlesEnabled &&
                _currentSubtitleText != "" &&
                _currentSubtitleText != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 50,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Directionality(
                      textDirection: _isRTL(_currentSubtitleText!)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Text(
                        _currentSubtitleText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily:
                              'Arial', // Use a font that supports Arabic well
                          shadows: [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.black,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
              // Display shows the cumulative taps * 10s for this sequence
              '${(_consecutiveTaps * 10).toString()}s',
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

// Concrete implementation of WindowListener with renamed fields
class _WindowListenerImpl extends WindowListener {
  final VoidCallback? onEnterFullScreen; // Renamed from onWindowEnterFullScreen
  final VoidCallback? onLeaveFullScreen; // Renamed from onWindowLeaveFullScreen

  _WindowListenerImpl({
    this.onEnterFullScreen,
    this.onLeaveFullScreen,
  });

  @override
  void onWindowEnterFullScreen() {
    // Call the renamed callback
    onEnterFullScreen?.call();
  }

  @override
  void onWindowLeaveFullScreen() {
    // Call the renamed callback
    onLeaveFullScreen?.call();
  }
}
