import 'package:flutter/material.dart';
import 'package:moviedex/api/Api.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/utils.dart';
import 'package:moviedex/components/horizontal_scroll_list.dart';


class Categorylist extends StatefulWidget {

  const Categorylist({
    super.key,
    required this.lable,
    required this.index
  });
  final String lable;
  final int index;

  @override
  State<Categorylist> createState() => _CategorylistState();
}

class _CategorylistState extends State<Categorylist> {
  Api api = Api();
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(widget.lable,style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold
                    )),
                    SizedBox(height: 8),
                    SizedBox(
    height: isMobile ? 200 : 250,
    child: FutureBuilder(
      future: api.getCatagorylist(type: ContentType.movie.value, language: "en", index: widget.index),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        final List<Contentclass>? data = snapshot.data?[0][widget.lable];
        return HorizontalScrollList(data: data!);
      }
    ),
  ),
      ],
    );
  }
}
