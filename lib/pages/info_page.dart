import 'package:flutter/material.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/utils.dart';
import 'package:moviedex/components/horizontal_movie_list.dart';
import 'package:moviedex/pages/search_page.dart';
import 'package:moviedex/pages/watch_page.dart';
import 'package:moviedex/components/description_text.dart';
import 'package:moviedex/components/episodes_section.dart';
import 'package:hive/hive.dart';

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
  @override
  void initState() {
    super.initState();
    Hive.openBox(widget.name).then((value) => storage = value);
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
        title: Text(widget.name,style: TextStyle(
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
                                      child: TextButton(onPressed: (){
                                        
                                      },
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(const Color.fromARGB(177, 34, 34, 34)),
                                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add,size: 24,color: Colors.white),
                                          Text("Add to list",style: TextStyle(color: Colors.white,fontSize: 18,fontWeight: FontWeight.bold))
                                        ],
                                      )
                                      ),
                                    ):const SizedBox(),
                                  ],
                                ),
                              (Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android) && isMobile?
                              Container(
                                width: MediaQuery.of(context).size.width,
                                margin: const EdgeInsets.only(top: 8),
                                child: TextButton(onPressed: (){},
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(const Color.fromARGB(177, 34, 34, 34)),
                                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Download",style: TextStyle(color: Colors.white,fontSize: 18,fontWeight: FontWeight.bold))
                                  ],
                                )
                                ),
                              ):const SizedBox(),
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
                                isMobile?Column(
                                  children: [
                                    IconButton(onPressed: (){}, icon: Icon(Icons.add),color: Colors.white, iconSize: 32,),
                                    Text("Add to list",style: TextStyle(
                                      color: Colors.white
                                    ),)
                                  ],
                                ):Theme.of(context).platform == TargetPlatform.iOS || Theme.of(context).platform == TargetPlatform.android?
                                Column(
                                  children: [
                                    IconButton(onPressed: (){}, icon: Icon(Icons.download),color: Colors.white, iconSize: 32,),
                                    Text("Download",style: TextStyle(
                                      color: Colors.white
                                    ),)
                                  ],
                                ):const SizedBox(),
                                Column(
                                  children: [
                                    IconButton(onPressed: (){}, icon: Icon(Icons.share),color: Colors.white, iconSize: 32,),
                                    Text("Share",style: TextStyle(
                                      color: Colors.white
                                    ),)
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    data.type==ContentType.movie.value?
                    HorizontalMovieList(title: "Recommendations", fetchMovies: () => api.getRecommendations(id: widget.id, type: widget.type), showNumber: false):
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