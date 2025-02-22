import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CachedImageService {
  static final CachedImageService instance = CachedImageService._internal();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  CachedImageService._internal();

  Widget getImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
    BorderRadius? borderRadius,
  }) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheManager: _cacheManager,
      placeholder: (context, url) => Container(
        color: Colors.grey[850],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: errorWidget ?? (context, url, error) => Container(
        color: Colors.grey[850],
        child: const Icon(Icons.error),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: image,
      );
    }

    return image;
  }

  Future<void> precacheImage(String imageUrl) async {
    try {
      await _cacheManager.downloadFile(imageUrl);
    } catch (e) {
      print('Error precaching image: $e');
    }
  }

  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }
}
