import 'package:flutter/material.dart';
import 'package:moviedex/services/cached_image_service.dart';
import 'package:moviedex/services/watch_history_service.dart';
import 'package:moviedex/pages/info_page.dart';

class WatchHistoryPage extends StatelessWidget {
  const WatchHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final watchHistory = WatchHistoryService.instance.getWatchHistory()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch History'),
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
          itemCount: watchHistory.length,
          itemBuilder: (context, index) {
            final item = watchHistory[index];
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
