class FormatUtils {
  static String formatDownloadSpeed(double? speed) {
    if (speed == null) return '0 MB/s';
    if (speed < 1.0) {
      return '${(speed * 1000).toStringAsFixed(0)} KB/s';
    }
    return '${speed.toStringAsFixed(1)} MB/s';
  }

  static String formatTimeLeft(Duration? duration) {
    if (duration == null) return '--:--';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m left';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s left';
    } else {
      return '${seconds}s left';
    }
  }

  static String formatProgress(double progress) {
    return '${(progress * 100).toInt()}%';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
