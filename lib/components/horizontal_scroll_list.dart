import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/pages/info_page.dart';

class HorizontalScrollList extends StatefulWidget {
  final List<Contentclass> data;
  const HorizontalScrollList({super.key,required this.data});

  @override
  State<HorizontalScrollList> createState() => _HorizontalScrollListState();
}

class _HorizontalScrollListState extends State<HorizontalScrollList> {
  @override
  Widget build(BuildContext context) {
    final List<Contentclass> data = widget.data;
    return ListView.builder(
          itemCount: data!.length,
          scrollDirection: Axis.horizontal,
          controller: ScrollController(),
          physics: const PageScrollPhysics().applyTo(
            const BouncingScrollPhysics(),
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => Infopage(id: data[index].id,type: data[index].type)));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Card(
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
        );
  }
}