import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class DownloadPoster extends StatelessWidget {
  final String posterUrl;
  final double progress;
  final String downloadPath;
  final double width;
  final double height;
  
  const DownloadPoster({
    super.key,
    required this.posterUrl,
    required this.progress,
    required this.downloadPath,
    this.width = 120,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base poster image with offline support
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: posterUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheManager: DefaultCacheManager(),
            placeholder: (context, url) => Container(
              color: Colors.grey[850],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.grey[850],
              child: const Icon(Icons.error),
            ),
          ),
        ),
        
        // Download progress overlay
        if (progress < 1.0)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _DownloadProgressPainter(
                  progress: progress,
                  primaryColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          
        // Download status indicators
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadProgressPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;

  _DownloadProgressPainter({
    required this.progress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Gray background
    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Colored progress
    final progressPaint = Paint()
      ..color = primaryColor.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Offset.zero & Size(size.width, size.height * progress),
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_DownloadProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
