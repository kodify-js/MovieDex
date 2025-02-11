import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/pages/watch_page.dart';

class Carousel extends StatelessWidget {
  const Carousel({
    super.key,
    required this.data,
  });

  final List<Contentclass> data;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    return SizedBox(
      width: width,
      height: isMobile ? 300 : 500,
      child: AspectRatio(
        aspectRatio: 16/9,
        child: ListView.builder(
          itemCount: 5,
          controller: ScrollController(),
          scrollDirection: Axis.horizontal,
          physics: const PageScrollPhysics().applyTo(
          const ClampingScrollPhysics(),
          ),
          itemBuilder: (context, index) {
            return Container(
              width: width,
              decoration: BoxDecoration(
                image: DecorationImage(image: NetworkImage(data[index].backdrop),fit: BoxFit.cover)
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                      Colors.transparent
                    ]
                  )
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    data[index].logoPath!.isEmpty
                      ? Text(
                          data[index].title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                          ),
                        )
                      : SizedBox(
                          width: isMobile?width/2:width/4,
                          child: Image.network(
                            data[index].logoPath ?? '',
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.contain, // ensures the logo fits within bounds
                          ),
                        ),
                    SizedBox(height: 18),
                    Row(
                      children:[ 
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton(
                          onPressed: (){
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => Watch(data: data[index],title: data[index].title,)));
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primary),
                            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
                          ),
                          child: SizedBox(
                            width: 120,
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow_rounded,size: 24,color: Colors.white),
                                Text(
                                "Watch Now",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold
                                )
                            )
                              ],
                            ),
                          )
                                                              ),
                        ),
                        TextButton(
                        onPressed: (){
                                                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => Infopage(id: data[index].id,name: data[index].title, type: data[index].type,)));
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(Color.fromARGB(199, 0, 0, 0)),
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                        ),
                        child: SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              SizedBox(width: 5),
                              Icon(Icons.info_outline_rounded,size: 24,color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                "More info",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold
                                )
                            )
                            ]
                            ),
                        )
                      ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}