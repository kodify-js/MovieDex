import 'package:flutter/material.dart';
import 'package:moviedex/services/connectivity_service.dart';
import 'package:moviedex/utils/error_handlers.dart';

class ContentErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ContentErrorWidget({
    Key? key,
    required this.error,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isNetworkError = ErrorHandlers.isNetworkError(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.signal_wifi_off : Icons.error_outline,
              size: 64,
              color: isNetworkError ? Colors.grey : Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError
                  ? 'Network Connection Issue'
                  : 'Something Went Wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (isNetworkError)
              StreamBuilder<bool>(
                stream: ConnectivityService.instance.connectionStatus,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == true) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Connection restored! Try again.',
                        style: TextStyle(color: Colors.green),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }
}
