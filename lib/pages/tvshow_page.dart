import 'package:flutter/material.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/utils.dart';
import 'package:moviedex/components/carousel.dart';
import 'package:moviedex/components/horizontal_movie_list.dart';
import 'package:moviedex/pages/search_page.dart';
class Tvshows extends StatefulWidget {
  const Tvshows({super.key});
  @override
  State<Tvshows> createState() => _TvshowsState();
}

class _TvshowsState extends State<Tvshows>{
  Api api = Api();
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text("Movie Dex",style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
        ),
        actions: [
          IconButton(onPressed: (){
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SearchPage()));
          }, icon: Icon(Icons.search)),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: api.getPopular(type: ContentType.tv.value ,language: "en"),
          builder: (context,snapshot) {
            if(snapshot.connectionState == ConnectionState.waiting){
              return const Center(
                child: CircularProgressIndicator.adaptive(),
              );
            }
            if(snapshot.hasError){
              return Center(
                child: Text(snapshot.error.toString(),style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),),
              );
            }
            final data = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // main card
                  Carousel(data: data),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      children: [
                        HorizontalMovieList(
                          title: "Trending Tv Shows",
                          fetchMovies: () => api.getTrending(type: ContentType.tv.value, language: "en"),
                          showNumber: true,
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(), // Disable ListView scrolling
                          itemCount: tvGenres.length,
                          itemBuilder: (context, index) {
                            return HorizontalMovieList(title: movieGenres[index]['name'], fetchMovies: () => api.getGenresContent(type: ContentType.tv.value, id: movieGenres[index]['id']));
                          }
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
    }
}

