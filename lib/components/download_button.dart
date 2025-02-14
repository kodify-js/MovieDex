// ...existing imports...

import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/services/m3u8_downloader_service.dart';

class DownloadButton extends StatelessWidget {
  final Contentclass content;
  final String quality;
  final String m3u8Url;

  const DownloadButton({
    super.key,
    required this.content,
    required this.quality,
    required this.m3u8Url,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        try {
          final downloader = M3U8DownloaderService();
          await downloader.startDownload(
            context,  // Pass context here
            m3u8Url,
            content.title,
            content,
            quality,
          );
        } catch (e) {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      icon: const Icon(Icons.download),
    );
  }
}
