import 'package:flutter/material.dart';
import 'package:moviedex/api/Api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/components/horizontal_scroll_list.dart';

class Infopage extends StatefulWidget {
  final int id;
  final String type;
  const Infopage({super.key, required this.id,required this.type});

  @override
  State<Infopage> createState() => _InfopageState();
}

class _InfopageState extends State<Infopage> {
  Api api = Api();
  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            FutureBuilder(
              future: api.getDetails(id: widget.id, type: widget.type),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text('No data available'));
                }

                Contentclass data = snapshot.data;
                return Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.6,
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
                            children: [
                              Spacer(),
                              Container(
                                margin: const EdgeInsets.all(16),
                                child:                               data.logoPath!.isEmpty
                                ? Text(
                                    data.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold
                                    ),
                                  )
                                : SizedBox(
                                    height: 60, // 15% of screen height
                                    child: Image.network(
                                      data.logoPath ?? '',
                                      alignment: Alignment.centerLeft,
                                      fit: BoxFit.contain, // ensures the logo fits within bounds
                                    ),
                                  ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: TextButton(onPressed: (){},
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(Colors.white),
                                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_arrow_rounded,size: 24,color: Colors.black),
                                    Text("Play",style: TextStyle(color: Colors.black,fontSize: 18,fontWeight: FontWeight.bold))
                                  ],
                                )
                                ),
                              ),
                              Container(
                                width: MediaQuery.of(context).size.width,
                                margin: const EdgeInsets.only(top: 8),
                                child: TextButton(onPressed: (){},
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.secondary),
                                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded,size: 24,color: Theme.of(context).colorScheme.onSecondary),
                                    Text("Download",style: TextStyle(color: Theme.of(context).colorScheme.onSecondary,fontSize: 18,fontWeight: FontWeight.bold))
                                  ],
                                )
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FutureBuilder(
                      future: api.getRecommendations(id: widget.id, type: widget.type), 
                      builder: (context,snapshot){
                        if (snapshot.connectionState == ConnectionState.waiting) {
                         return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No data available'));
                        }
                        final List<Contentclass> data = snapshot.data!;
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Recommendations",style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold
                                )),
                                SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: HorizontalScrollList(data: data),
                                ),
                              ],
                            ),
                          );
                        }
                    )                     
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