import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';

class Carousel extends StatelessWidget {
  const Carousel({
    super.key,
    required this.data,
  });

  final List<Contentclass> data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
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
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                image: DecorationImage(image: NetworkImage(data[index].backdrop))
              ),
              child: Container(
                color: Color.fromARGB(100, 0, 0, 0),
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
                          height: 60, // 15% of screen height
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
                          onPressed: (){},
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
                        onPressed: (){},
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