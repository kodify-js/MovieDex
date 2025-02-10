import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animated_icons/icons8.dart';
import 'package:moviedex/api/class/source_class.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:video_player/video_player.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html; 

class ContentPlayer extends StatefulWidget {
  final List<StreamClass> streams;
  const ContentPlayer({super.key, required this.streams});

  @override
  State<ContentPlayer> createState() => _ContentPlayerState();
}

class _ContentPlayerState extends State<ContentPlayer> with TickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _replayController;
  late AnimationController _forwardController;
  late Timer _hideTimer;
  bool _isPlaying = false;
  bool _isCountrollesVisible = true;
  bool _isFullScreen = false;
  bool _isSettingsVisible = false;
  String _currentQuality = 'Auto';
  String _settingsPage = 'main';
  Duration? _duration;
  Duration? _position;
  var _progress = 0.0;
  var _onUpdateControllerTime;

  void _onControllerUpdate() async {
    final controller = _controller;
    if (controller.value.isInitialized) {
      _onUpdateControllerTime = 0;

      final now = DateTime.now().microsecondsSinceEpoch;
      if (_onUpdateControllerTime > now) {
        return;
      }
      _onUpdateControllerTime = now + 500;
      _duration ??= _controller.value.duration;
      var duration = _duration;
      if (duration == null) return;
      var position = controller.value.position;
      _position = position;
      final isPlaying = controller.value.isPlaying;
      if (isPlaying) {
        setState(() {
          _isPlaying = true;
          _progress = position.inMilliseconds.ceilToDouble() / duration.inMilliseconds.ceilToDouble();
        });
      } else {
        _isPlaying = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    String videoUrl = widget.streams[0].url;
    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        setState(() {
          _controller.addListener(_onControllerUpdate);
          _controller.play();
        });
      });
    _replayController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _forwardController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _startHideTimer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _isCountrollesVisible = false;
        if (!_isSettingsVisible) {
          _isSettingsVisible = false;
        }
      });
    });
  }

  void _cancelAndRestartHideTimer() {
    _hideTimer.cancel();
    _startHideTimer();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        if (kIsWeb) {
          html.document.documentElement?.requestFullscreen();
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
        }
      } else {
        if (kIsWeb) {
          html.document.exitFullscreen();
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
        }
      }
    });
  }

  void _toggleSettingsMenu() {
    setState(() {
      _isSettingsVisible = !_isSettingsVisible;
      _settingsPage = 'main';
      _cancelAndRestartHideTimer();
    });
  }

  void _showSettingsOptions(String page) {
    setState(() {
      _settingsPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: _controller.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                children: [
                  VideoPlayer(_controller),
                  AnimatedOpacity(
                    opacity: _isCountrollesVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _isCountrollesVisible
                        ? Container(
                            decoration: BoxDecoration(color: const Color.fromARGB(85, 22, 22, 22)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 50),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                            onDoubleTap: () {
                                              _controller.seekTo(Duration(seconds: _position!.inSeconds - 10));
                                              _replayController.reset();
                                              _replayController.forward();
                                            },
                                            onTap: () {
                                              setState(() {
                                                _isCountrollesVisible = false;
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(color: const Color.fromARGB(0, 0, 0, 0)),
                                              width: width / 2.5,
                                              height: height,
                                              child: Center(
                                                child: Container(
                                                  margin: EdgeInsets.only(left: width / 4),
                                                  width: 50,
                                                  height: 50,
                                                  child: ColorFiltered(
                                                    colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                                    child: IconButton(
                                                        color: Colors.white,
                                                        onPressed: () {
                                                          _controller.seekTo(Duration(seconds: _position!.inSeconds - 10));
                                                          _replayController.reset();
                                                          _replayController.forward();
                                                        },
                                                        icon: Lottie.asset(Icons8.skip_backwards, controller: _replayController)),
                                                  ),
                                                ),
                                              ),
                                            )),
                                        SizedBox(
                                          width: width / 5,
                                          height: height,
                                          child: Center(
                                            child: IconButton(
                                                onPressed: () {
                                                  if (_isPlaying) {
                                                    _controller.pause();
                                                    setState(() {
                                                      _isPlaying = false;
                                                    });
                                                  } else {
                                                    _controller.play();
                                                    setState(() {
                                                      _isPlaying = true;
                                                    });
                                                  }
                                                  _cancelAndRestartHideTimer();
                                                },
                                                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                                color: Colors.white,
                                                iconSize: 40),
                                          ),
                                        ),
                                        GestureDetector(
                                            onDoubleTap: () {
                                              _controller.seekTo(Duration(seconds: _position!.inSeconds + 10));
                                              _forwardController.reset();
                                              _forwardController.forward();
                                            },
                                            onTap: () {
                                              setState(() {
                                                _isCountrollesVisible = false;
                                              });
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(color: const Color.fromARGB(0, 0, 0, 0)),
                                              width: width / 2.5,
                                              height: height,
                                              child: Center(
                                                child: Container(
                                                  margin: EdgeInsets.only(right: width / 4),
                                                  width: 50,
                                                  height: 50,
                                                  child: ColorFiltered(
                                                    colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                                    child: IconButton(
                                                        color: Colors.white,
                                                        onPressed: () {
                                                          _forwardController.reset();
                                                          _forwardController.forward();
                                                          _cancelAndRestartHideTimer();
                                                        },
                                                        icon: Lottie.asset(Icons8.skip_forwards, controller: _forwardController)),
                                                  ),
                                                ),
                                              ),
                                            ))
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: SliderTheme(
                                              data: SliderTheme.of(context).copyWith(
                                                  activeTrackColor: Theme.of(context).colorScheme.primary,
                                                  inactiveTrackColor: const Color.fromARGB(167, 204, 204, 204),
                                                  trackShape: RectangularSliderTrackShape(),
                                                  trackHeight: 3.0,
                                                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10)),
                                              child: Slider(
                                                value: max(0, min(_progress * 100, 100)),
                                                min: 0,
                                                max: 100,
                                                label: _position.toString(),
                                                onChanged: (double value) {
                                                  setState(() {
                                                    _progress = value * 0.01;
                                                  });
                                                  _cancelAndRestartHideTimer();
                                                },
                                                onChangeEnd: (value) {
                                                  final duration = _controller.value.duration;
                                                  var newValue = max(0, min(value, 99)) * 0.01;
                                                  var millis = (duration.inMilliseconds * newValue).toInt();
                                                  _controller.seekTo(Duration(milliseconds: millis));
                                                },
                                              ))),
                                      Text(_duration.toString().split('.')[0])
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: width,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                            onPressed: _toggleSettingsMenu,
                                            icon: Icon(Icons.settings),
                                            iconSize: 20,
                                            color: Colors.white),
                                        IconButton(
                                            onPressed: _toggleFullScreen,
                                            icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                                            iconSize: 20,
                                            color: Colors.white)
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              SizedBox(
                                width: width / 2,
                                height: height,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isCountrollesVisible = true;
                                      _cancelAndRestartHideTimer();
                                    });
                                  },
                                  onDoubleTap: () {
                                    setState(() {
                                      _isCountrollesVisible = true;
                                      _controller.seekTo(Duration(seconds: _position!.inSeconds - 10));
                                      _replayController.reset();
                                      _replayController.forward();
                                      _cancelAndRestartHideTimer();
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: width / 2,
                                height: height,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isCountrollesVisible = true;
                                      _cancelAndRestartHideTimer();
                                    });
                                  },
                                  onDoubleTap: () {
                                    setState(() {
                                      _isCountrollesVisible = true;
                                      _controller.seekTo(Duration(seconds: _position!.inSeconds + 10));
                                      _forwardController.reset();
                                      _forwardController.forward();
                                      _cancelAndRestartHideTimer();
                                    });
                                  },
                                ),
                              )
                            ],
                           )         
                  ),
                  _isSettingsVisible
                      ? Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 250,
                            color: Colors.black.withOpacity(0.8),
                            child: _settingsPage == 'main'
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        leading: IconButton(
                                          icon: Icon(Icons.close, color: Colors.white),
                                          onPressed: _toggleSettingsMenu,
                                        ),
                                      ),
                                      ListTile(
                                        title: TextButton(
                                          onPressed: () => _showSettingsOptions('quality'),
                                          style: TextButton.styleFrom(
                                            backgroundColor: colorScheme.secondary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text('Quality', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                      ListTile(
                                        title: TextButton(
                                          onPressed: () => _showSettingsOptions('language'),
                                          style: TextButton.styleFrom(
                                            backgroundColor: colorScheme.secondary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text('Language', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                      ListTile(
                                        title: TextButton(
                                          onPressed: () => _showSettingsOptions('server'),
                                          style: TextButton.styleFrom(
                                            backgroundColor: colorScheme.secondary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text('Server', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        leading: IconButton(
                                          icon: Icon(Icons.arrow_back, color: Colors.white),
                                          onPressed: () => _showSettingsOptions('main'),
                                        ),
                                      ),
                                      if (_settingsPage == 'quality') ...[
                                        SizedBox(
                                          width: 250,
                                          child: TextButton(
                                              onPressed: () {
                                               _controller.dispose();
                                                   _controller = VideoPlayerController.networkUrl(Uri.parse(widget.streams[0]))
                                                      ..initialize().then((_) {
                                                        setState(() {
                                                          _controller.addListener(_onControllerUpdate);
                                                          _controller.play();
                                                        });
                                                      });
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: colorScheme.secondary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(0),
                                                ),
                                              ),
                                              child: Text("Auto", style: TextStyle(color: Colors.white)),
                                            ),
                                        ),
                                        for(SourceClass data in widget.streams[0].sources)
                                          SizedBox(
                                            width: 250,
                                            child: TextButton(
                                              onPressed: () {
                                                // Handle auto quality selection
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: colorScheme.secondary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(0),
                                                ),
                                              ),
                                              child: Text(data.quality, style: TextStyle(color: Colors.white)),
                                            ),
                                          )
                                      ] else if (_settingsPage == 'language') ...[
                                        ListTile(
                                          title: TextButton(
                                            onPressed: () {
                                              // Handle language selection
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: colorScheme.secondary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('English', style: TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                        ListTile(
                                          title: TextButton(
                                            onPressed: () {
                                              // Handle language selection
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: colorScheme.secondary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('Spanish', style: TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                        // Add more languages as needed
                                      ] else if (_settingsPage == 'server') ...[
                                        ListTile(
                                          title: TextButton(
                                            onPressed: () {
                                              // Handle server selection
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: colorScheme.secondary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('Server 1', style: TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                        ListTile(
                                          title: TextButton(
                                            onPressed: () {
                                              // Handle server selection
                                            },
                                            style: TextButton.styleFrom(
                                              backgroundColor: colorScheme.secondary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('Server 2', style: TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                        // Add more servers as needed
                                      ],
                                    ],
                                  ),
                          ),
                        )
                      : Container(),
                ],
              ),
            )
          : Row(
              children: [
                GestureDetector(
                  onDoubleTap: () {
                    _controller.seekTo(Duration(seconds: _position!.inSeconds - 10));
                    _replayController.reset();
                    _replayController.forward();
                  },
                  child: Container(
                    width: width / 2,
                    height: height,
                    decoration: BoxDecoration(color: Color.fromARGB(0, 0, 0, 0)),
                  ),
                )
              ],
            ),
    );
  }
}