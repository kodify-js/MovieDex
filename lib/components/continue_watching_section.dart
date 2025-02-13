import 'package:flutter/material.dart';
import 'package:moviedex/api/models/watch_history_model.dart';
import 'package:moviedex/services/watch_history_service.dart';

class ContinueWatchingSection extends StatelessWidget {
  final String? contentType;
  final Function(WatchHistoryItem) onItemTap;

  const ContinueWatchingSection({
    super.key,
    this.contentType,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final continueWatchingList = WatchHistoryService.instance.getContinueWatching(
      type: contentType
    );

    if (continueWatchingList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: continueWatchingList.length,
            itemBuilder: (context, index) {
              final item = continueWatchingList[index];
              return GestureDetector(
                onTap: () => onItemTap(item),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.poster,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: item.progress!.inSeconds / item.totalDuration!.inSeconds,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
