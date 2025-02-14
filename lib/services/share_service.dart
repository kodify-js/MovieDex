import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class ShareService {
  static const String domain = 'https://moviedex.co';

  static Future<void> shareContent(int id, String type, String title) async {
    final String url = '$domain/$type/$id';
    String text = 'Check out $title on MovieDex\n$url';

    try {
      if (kIsWeb) {
        // For web, try navigator.share or fallback to clipboard
        await _webShare(text, title, url);
      } else {
        await Share.share(text, subject: title);
      }
    } catch (e) {
      debugPrint('Share error: $e');
      await _fallbackToClipboard(text);
    }
  }

  static Future<void> _webShare(String text, String title, String url) async {
    try {
      if (await _canUseWebShare()) {
        // Use Web Share API if available
        final Map<String, dynamic> shareData = {
          'title': title,
          'text': text,
          'url': url,
        };
        await _invokeWebShare(shareData);
      } else {
        await _fallbackToClipboard(text);
      }
    } catch (e) {
      await _fallbackToClipboard(text);
    }
  }

  static Future<bool> _canUseWebShare() async {
    if (kIsWeb) {
      try {
        // Check if navigator.share is available
        return await url_launcher.canLaunch('web+share://');
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<void> _invokeWebShare(Map<String, dynamic> data) async {
    // This is a placeholder - actual web share implementation would be done in JavaScript
    await _fallbackToClipboard(data['text']);
  }

  static Future<void> _fallbackToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      debugPrint('Content copied to clipboard');
    } catch (e) {
      debugPrint('Clipboard error: $e');
    }
  }

  static Future<bool> handleDeepLink(String link) async {
    try {
      final uri = Uri.parse(link);
      if (uri.host == 'moviedex.co') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          final type = pathSegments[0];
          final id = int.tryParse(pathSegments[1]);
          if (id != null) {
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing deep link: $e');
    }
    return false;
  }
}
