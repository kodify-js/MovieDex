import 'package:flutter/material.dart';
import 'package:moviedex/api/Api.dart';
import 'package:moviedex/api/utils.dart';
import 'package:moviedex/components/carousel.dart';
import 'package:moviedex/components/category_list.dart';
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home>{
  Api api = Api();
  @override
  Widget build(BuildContext context){
    TextEditingController textEditingController = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Movie Dex",style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
        ),
         backgroundColor: Colors.black,
        actions: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 200,
              height: 40,  // Fixed height for better vertical centering
              child: TextField(
                controller: textEditingController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search",
                  contentPadding: EdgeInsets.zero,  // Removes internal padding
                  focusColor: Color.fromRGBO(0, 0, 0, 1),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromRGBO(0, 0, 0, 1)
                    ),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(20))
                  )
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: api.fetchPopular(type: ContentType.movie.value ,language: "en"),
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
            final data = snapshot.data;
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // main card
                  Carousel(data: data),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(), // Disable ListView scrolling
                      itemCount: movieGenres.length,
                      itemBuilder: (context, index) {
                        return Categorylist(
                          lable: movieGenres[index]['name'],
                          index: index,
                        );
                      }
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

