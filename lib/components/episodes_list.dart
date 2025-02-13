import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/class/episode_class.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:moviedex/pages/watch_page.dart';

class EpisodesList extends StatefulWidget {
  final Episode episode;
  final Contentclass data;
  const EpisodesList({super.key,required this.episode,required this.data}); 

  @override
  State<EpisodesList> createState() => _EpisodesListState();
}

class _EpisodesListState extends State<EpisodesList> {
  bool isHovered = false;
  bool isPressed = false;
  Box? storage;

  @override
  void initState() {
    super.initState();
    Hive.openBox(widget.data.title).then((value) => storage = value);
  }
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width<600;
    final episode = widget.episode;
    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed = true),
      onTapUp: (_) => setState(() => isPressed = false),
      onTapCancel: () => setState(() => isPressed = false),
      onTap: (){
        hivePut(storage:storage,key: "episode",value: 'E${episode.episode}');
        hivePut(storage: storage,key: "season",value: 'S${episode.season}');
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => WatchPage(data: widget.data,episodeNumber: episode.episode,seasonNumber: episode.season,title: episode.name,)));
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() {
          isHovered = false;
          isPressed = false;
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              children: [
                Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(episode.image,fit: BoxFit.cover,width: isMobile?width/2.5:200,height: 100,),
                      Container(
                        width: isMobile?width/2.5:200,
                        height: 100,
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                ),
                SizedBox(
                  width: width/2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${episode.episode}. ${episode.name}',maxLines: 2,style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold,overflow: TextOverflow.ellipsis),),
                      Text("Season ${episode.season} Episode ${episode.episode}",style: TextStyle(fontSize: 16,color: Colors.grey)),
                      Text(episode.airDate,style: TextStyle(fontSize: 14,color: Colors.grey),),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(episode.description,maxLines: 3, style: TextStyle(fontSize: 14,color: Colors.grey,overflow: TextOverflow.ellipsis)),
            ),
          ],
        ),
      ),
    );
  }
}