import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/pages/info_page.dart'; // Add this import
import 'package:moviedex/components/cached_poster.dart';

class HorizontalScrollList extends StatelessWidget {
  final String title;
  final Future<dynamic> Function() fetchMovies;
  final bool showNumber;
  final double itemWidth;

  const HorizontalScrollList({
    super.key,
    required this.title,
    required this.fetchMovies,
    this.showNumber = false,
    this.itemWidth = 150,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: FutureBuilder<dynamic>(
            future: fetchMovies(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No data available'));
              }

              final data = snapshot.data!;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: data.length,
                itemBuilder: (context, index) {
                  Contentclass item = data[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Infopage(id: item.id,name: item.title,type: item.type),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: itemWidth,
                      height: isMobile ? 200 : 250,
                      child: Stack(
                        children: [
                          // Movie Poster with hover effect
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedPoster(
                                imageUrl: item.poster,
                                width: itemWidth,
                                height: isMobile ? 200 : 250,
                              ),
                            ),
                          ),
                          // Number Badge (if enabled)
                          if (showNumber)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.5),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.black.withOpacity(0.2),
                                    ),
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Add hover effect overlay
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                splashColor: Colors.white.withOpacity(0.1),
                                highlightColor: Colors.white.withOpacity(0.05),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Infopage(id: item.id,name: item.title,type: item.type),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
