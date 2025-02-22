import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' as cache_manager;
import 'package:moviedex/models/downloads_manager.dart';
import 'package:moviedex/providers/downloads_provider.dart' as downloads;
import 'package:moviedex/services/m3u8_downloader_service.dart';

class DownloadsList extends StatelessWidget {
  const DownloadsList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: downloads.DownloadsProvider.instance,
      builder: (context, _) {
        final downloadsList = DownloadsManager.instance.getDownloads();
        final activeDownloads = downloads.DownloadsProvider.instance.activeDownloads;

        if (downloadsList.isEmpty && activeDownloads.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.download_done_rounded,
                    size: 48,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No downloads yet",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Show active downloads first
            ...activeDownloads.values.map((content) {
              // Ensure all required values are present
              if (content.title.isEmpty || content.poster.isEmpty) {
                return const SizedBox(); // Skip invalid downloads
              }

              return _buildActiveDownload(context, content); // Pass context here
            }),

            // Show completed downloads
            ...downloadsList.map((download) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                height: 150,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            download.poster,
                            cacheManager: cache_manager.DefaultCacheManager(),
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Info overlay
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            download.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (download.episodeNumber != null)
                            Text(
                              'S${download.seasonNumber}E${download.episodeNumber}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          Text(
                            'Downloaded • ${download.quality}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildActiveDownload(BuildContext context, downloads.DownloadProgress content) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 150,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(content.poster),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.7),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  LinearProgressIndicator(
                    value: content.progress,
                    backgroundColor: Colors.black45,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    ),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    content.isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (content.isPaused) {
                      M3U8DownloaderService().resumeDownload();
                    } else {
                      M3U8DownloaderService().pauseDownload();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    M3U8DownloaderService().cancelDownload();
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(content.progress * 100).toInt()}% • ${content.isPaused ? 'Paused' : 'Downloading'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
