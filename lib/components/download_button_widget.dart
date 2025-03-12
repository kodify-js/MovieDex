import 'package:flutter/material.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/models/downloads_manager.dart';
import 'package:moviedex/services/m3u8_downloader_service.dart';
import 'package:moviedex/utils/format_utils.dart';

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
            backgroundColor:
                WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 12)),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)))),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 8),
            Text("Downloaded",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton(DownloadProgress progress) {
    const buttonHeight = 64.0;

    // Show initial button if cancelled or error
    if (progress.status == 'cancelled' || progress.status == 'error') {
      return _buildInitialButton();
    }

    // Show completed button if done
    if (progress.status == 'completed') {
      return _buildCompleteButton();
    }

    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: TextButton(
        onPressed: () {
          if (progress.isPaused) {
            _handleResume();
          } else if (progress.status == 'downloading') {
            _showCancelDialog();
          }
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.grey[800]),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
          minimumSize:
              WidgetStateProperty.all(const Size.fromHeight(buttonHeight)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (progress.status != 'error')
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.progress,
                      heightFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          progress.isPaused
                              ? 'Resume Download'
                              : "Downloading ${FormatUtils.formatProgress(progress.progress)}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        if (!progress.isPaused &&
                            progress.status == 'downloading')
                          Text(
                            '${FormatUtils.formatDownloadSpeed(progress.speed ?? progress.lastSpeed)} • '
                            '${FormatUtils.formatTimeLeft(progress.timeRemaining ?? progress.lastTimeRemaining)}',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 12,
                            ),
                          )
                      ],
                    ),
                  ),
                  if (progress.status == 'downloading' || progress.isPaused)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            progress.isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (progress.isPaused) {
                              _handleResume();
                            } else {
                              M3U8DownloaderService().pauseDownload();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _showCancelDialog,
                        ),
                      ],
                    ),
                ],
              ),
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
        onPressed: widget.isLoadingStream
            ? null
            : () async {
                try {
                  // Update UI immediately to show preparing state
                  _downloadProvider.updateProgress(
                    widget.data.id,
                    0.0,
                    'preparing',
                    widget.data.title,
                    widget.data.poster,
                    'Auto',
                  );

                  // Start download
                  await widget.onDownloadStarted();
                } catch (e) {
                  // Clear progress on error
                  _downloadProvider.removeDownload(widget.data.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download error: $e')),
                    );
                  }
                }
              },
        style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(Colors.grey[800]),
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 12)),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)))),
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
                  fontWeight: FontWeight.bold),
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
        content: const Text(
            'This will stop the current download. You can start it again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              M3U8DownloaderService().cancelDownload();
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        _downloadProvider,
        _downloadProvider.getDownloadProgressNotifier(widget.data.id),
      ]),
      builder: (context, _) {
        final downloadProgress =
            _downloadProvider.getDownloadProgress(widget.data.id);

        // Show completed state if downloaded
        if (_isDownloaded()) {
          return _buildCompleteButton();
        }

        // Show progress if download is active
        if (downloadProgress != null) {
          return _buildProgressButton(downloadProgress);
        }

        return _buildInitialButton();
      },
    );
  }
}
