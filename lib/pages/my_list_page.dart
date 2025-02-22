import 'package:flutter/material.dart';
import 'package:moviedex/services/cached_image_service.dart';
import 'package:moviedex/services/list_service.dart';
import 'package:moviedex/pages/info_page.dart';

class MyListPage extends StatelessWidget {
  const MyListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final myList = ListService.instance.getList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My List'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: myList.length,
          itemBuilder: (context, index) {
            final item = myList[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Infopage(
                      id: item.contentId,
                      type: item.type,
                      name: item.title,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedImageService.instance.getImage(
                  imageUrl: item.poster,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
