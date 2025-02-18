import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/services/downloads_manager.dart';
import 'package:moviedex/services/m3u8_downloader_service.dart';

class DownloadButtonWidget extends StatefulWidget {
  final Contentclass data;
  final Function() onDownloadStarted;
  final bool isLoadingStream;

  const DownloadButtonWidget({
    super.key,
    required this.data,
    required this.onDownloadStarted,
    required this.isLoadingStream,
  });

  @override
  State<DownloadButtonWidget> createState() => _DownloadButtonWidgetState();
}

class _DownloadButtonWidgetState extends State<DownloadButtonWidget> {
  final _downloadProvider = DownloadsProvider.instance;
  final _downloader = M3U8DownloaderService();

  bool _isDownloaded() {
    return DownloadsManager.instance.hasDownload(widget.data.id);
  }

  Widget _buildCompleteButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: null,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 8),
            Text("Downloaded", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton(DownloadProgress progress) {
    const buttonHeight = 48.0;  // Define standard button height
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: TextButton(
        onPressed: () {
          if (progress.status == 'error' || progress.isPaused) {
            _handleResume();
          } else {
            _showCancelDialog();
          }
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.grey[800]),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(buttonHeight)),  // Ensure consistent height
        ),
        child: Stack(
          fit: StackFit.expand,  // Make stack fill the button
          children: [
            // Progress bar - now fills entire height
            Positioned.fill(
              child: ClipRRect(  // Clip the progress fill to match button radius
                borderRadius: BorderRadius.circular(5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress.progress,
                    heightFactor: 1.0,  // Fill full height
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Content
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (progress.status == 'error')
                  const Icon(Icons.error_outline, color: Colors.red)
                else if (progress.isPaused)
                  const Icon(Icons.play_arrow, color: Colors.white)
                else
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: progress.progress,
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  progress.status == 'error' ? 'Retry Download'
                  : progress.isPaused ? 'Resume'
                  : "Downloading ${(progress.progress * 100).toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: widget.isLoadingStream ? null : widget.onDownloadStarted,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.grey[800]),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)))
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoadingStream)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              const Icon(Icons.download, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              "Download",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download?'),
        content: const Text('This will stop the current download.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              DownloadsProvider.instance.removeDownload(widget.data.id);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleResume() async {
    try {
      await M3U8DownloaderService().resumeDownload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resume error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _downloadProvider.getDownloadProgressNotifier(widget.data.id),
      builder: (context, downloadProgress, _) {
        if (downloadProgress != null) {
          return _buildProgressButton(downloadProgress);
        }

        return _buildInitialButton();
      },
    );
  }
}
