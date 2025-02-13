import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/utils/utils.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/pages/watch_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  Api api = Api();
  bool isSearching = false;
  bool isSearched = false;
  String searchQuery = '';
  TextEditingController textEditingController = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  void _handleTextFieldChange(String value) {
  const duration = Duration(milliseconds: 500);
  _debouncer.debounce(
    duration: duration,
    onDebounce: () {
      setState(() {
        searchQuery = value;
        isSearched = true;
      });
    },
  );
}
  @override
  void initState() {
    super.initState();
    textEditingController.addListener(() {
      if(textEditingController.text.isNotEmpty){
      if(textEditingController.text.toString()!=searchQuery){
        _handleTextFieldChange(textEditingController.text);
      }
      }else{
        setState(() {
          isSearched = false;
        });
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width<600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: textEditingController,
              autofocus: true,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Search",
                  contentPadding: EdgeInsets.zero,  // Removes internal padding
                  focusColor: Color.fromRGBO(0, 0, 0, 1),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color.fromRGBO(0, 0, 0, 1)
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(8))
                  )
                ),
            ),
          ),
          SizedBox(height:16),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: isSearched && searchQuery.isNotEmpty?
            Text("Results for: $searchQuery",style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold
            )):
            Text("Popular Movies",style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold
            )),
          ),
          Container(
            child: isSearched && searchQuery.isNotEmpty?
            FutureBuilder(
              future: api.search(query: searchQuery), 
              builder: (context,snapshot){
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
                final List<Contentclass> data = snapshot.data;
                return isSearching?
                Center(
                  child: CircularProgressIndicator.adaptive(),
                ):
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      scrollDirection: Axis.vertical,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile?3:6,
                        childAspectRatio: 1/1.4,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4
                      ),
                      itemCount: data.length,
                      itemBuilder: (context,index){
                        return GestureDetector(
                          onTap: (){
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => Infopage(id: data[index].id,name: data[index].title,type: data[index].type)));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                                    height: isMobile?60:80,
                                    child: AspectRatio(
                                      aspectRatio: 1/1.4,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.network(
                                          data[index].poster,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(child: Icon(Icons.error));
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }
                    ),
                  ),
                );
              }
            ): 
            FutureBuilder(
              future: api.getPopular(type: "movie",imageSize: ImageSize.w342,language: "en"), 
              builder: (context,snapshot){
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
                final List<Contentclass> data = snapshot.data!;
                return Expanded(
                  child: isMobile?
                  ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context,index){
                      return GestureDetector(
                        onTap: (){
                          Navigator.of(context).push(MaterialPageRoute(builder: (context) => Infopage(id: data[index].id,name: data[index].title,type: data[index].type)));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            child: Row(
                              children:[ 
                              SizedBox(
                                width: 180,
                                child: AspectRatio(
                                  aspectRatio: 16/9,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: Image.network(
                                      data[index].backdrop,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(child: Icon(Icons.error));
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(left: 16,right: 8),
                                width: 150,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data[index].title,style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold
                                    )),
                                  ],
                                ), 
                              )
                            ]
                            ),
                          ),
                        ),
                      );
                    }
                  ):
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      scrollDirection: Axis.vertical,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile?3:6,
                        childAspectRatio: 1/1.4,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4
                      ),
                      itemCount: data.length,
                      itemBuilder: (context,index){
                        return GestureDetector(
                          onTap: (){
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => Infopage(id: data[index].id,name: data[index].title,type: data[index].type)));
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: SizedBox(
                                    height: isMobile?60:80,
                                    child: AspectRatio(
                                      aspectRatio: 1/1.4,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.network(
                                          data[index].poster,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(child: Icon(Icons.error));
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }
                    ),
                  ),
                )
                );
              }
            ),
          )
        ],
      )
    );
  }
}