import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/services/downloads_manager.dart';

class DownloadIconWidget extends StatefulWidget {
  final int contentId;
  final Contentclass data;
  final Future<void> Function(Contentclass) onDownload;

  const DownloadIconWidget({
    Key? key,
    required this.contentId,
    required this.data,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<DownloadIconWidget> createState() => _DownloadIconWidgetState();
}

class _DownloadIconWidgetState extends State<DownloadIconWidget> {
  void _showCancelDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download?'),
        content: const Text('This will cancel the download in progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              DownloadsProvider.instance.removeDownload(widget.contentId);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DownloadProgress?>(
      valueListenable: DownloadsProvider.instance.getDownloadProgressNotifier(widget.contentId),
      builder: (context, downloadProgress, child) {
        if (DownloadsManager.instance.hasDownload(widget.contentId)) {
          return Column(
            children: [
              IconButton(
                onPressed: () {
                  // Add logic to open the downloaded file
                },
                icon: const Icon(Icons.check_circle),
                color: Theme.of(context).colorScheme.primary,
                iconSize: 32,
              ),
              const Text(
                "Downloaded",
                style: TextStyle(color: Colors.white),
              ),
            ],
          );
        }

        if (downloadProgress != null) {
          return Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      value: downloadProgress.progress,
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  IconButton(
                    onPressed: _showCancelDownloadDialog,
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    iconSize: 20,
                  ),
                ],
              ),
              const Text(
                "Downloading",
                style: TextStyle(color: Colors.white),
              ),
            ],
          );
        }

        return Column(
          children: [
            IconButton(
              onPressed: () => widget.onDownload(widget.data),
              icon: const Icon(Icons.download),
              color: Colors.white,
              iconSize: 32,
            ),
            const Text(
              "Download",
              style: TextStyle(color: Colors.white),
            ),
          ],
        );
      },
    );
  }
}
