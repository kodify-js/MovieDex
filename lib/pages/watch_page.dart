import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:flutter/services.dart';
import 'package:moviedex/api/class/stream_class.dart';
import 'package:moviedex/api/contentproviders/contentprovider.dart';
import 'package:moviedex/components/content_player.dart';


class Watch extends StatefulWidget {
  final Contentclass? data;
  final int? episodeNumber,seasonNumber;
  const Watch({super.key, this.data, this.episodeNumber, this.seasonNumber});

  @override
  State<Watch> createState() => _WatchState();
}

class _WatchState extends State<Watch> {
  TextEditingController textEditingController = TextEditingController();
  late ContentProvider contentProvider;

  Future getStream() async {
    var stream = await contentProvider.autoembed.getStream();
    stream = stream.where((data)=>!data.isError).toList();
    if(stream.isEmpty){
      stream = await contentProvider.vidsrc.getStream();
    }
    return stream;
  }
  @override
  void initState() {
    super.initState();
    contentProvider = ContentProvider(id: widget.data!.id,type: widget.data!.type,episodeNumber: widget.episodeNumber,seasonNumber: widget.seasonNumber);
  }

  @override
void dispose() {
  // Reset to Default Orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);

    return Scaffold(
      body: FutureBuilder(
        future: getStream(),
        builder: (context,snapshot){
            if(snapshot.connectionState == ConnectionState.waiting){
              return const Center(
                child: CircularProgressIndicator.adaptive(),
              );
            }
            if(snapshot.hasError){
              return Center(
                // child: WebViewWidget(controller: controller),
              );
            }
            List<StreamClass> streams = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ContentPlayer(streams:streams,contentType: widget.data!.type,)),
            ],
          );
        }
        ),
    );
  }
}