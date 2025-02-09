import 'package:appinio_video_player/appinio_video_player.dart';
import 'package:flutter/material.dart';
import 'package:moviedex/api/class/stream_class.dart';



class ContentPlayer extends StatefulWidget {
  final List<StreamClass> streams;
  const ContentPlayer({super.key,required this.streams});

  @override
  State<ContentPlayer> createState() => _ContentPlayerState();
}

class _ContentPlayerState extends State<ContentPlayer> {
  final CustomVideoPlayerSettings _customVideoPlayerSettings =
      const CustomVideoPlayerSettings(showSeekButtons: true);
  late VideoPlayerController _videoPlayerController;
  late CustomVideoPlayerController _customVideoPlayerController;


  @override
  void initState() {
    super.initState();
    String? videoUrl = widget.streams[0].url;
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) => setState(() {}));
    _customVideoPlayerController = CustomVideoPlayerController(
      context: context,
      videoPlayerController: _videoPlayerController,
      customVideoPlayerSettings: _customVideoPlayerSettings,
      additionalVideoSources: {
        "Auto": _videoPlayerController,
      },
    );
    widget.streams[0].sources.forEach((source) {
      _customVideoPlayerController.additionalVideoSources?['${source.quality}p'] = VideoPlayerController.networkUrl(Uri.parse(source.url));
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _customVideoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomVideoPlayer(
        customVideoPlayerController: _customVideoPlayerController,
      ),
    );
  }
}