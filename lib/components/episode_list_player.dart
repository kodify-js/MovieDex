import 'package:flutter/material.dart';

class EpisodeListForPlayer extends StatelessWidget {
  final int? currentEpisode;
  final Function(int) onEpisodeSelected;

  const EpisodeListForPlayer({super.key, this.currentEpisode, required this.onEpisodeSelected});

  @override
  Widget build(BuildContext context) {
    final episodes = List.generate(20, (index) => index + 1); // Example episode list

    return Container(
      width: 250,
      color: Colors.black.withOpacity(0.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final episode = episodes[index];
                return ListTile(
                  title: Text(
                    'Episode $episode',
                    style: TextStyle(
                      color: episode == currentEpisode ? Colors.blue : Colors.white,
                    ),
                  ),
                  onTap: () {
                    onEpisodeSelected(episode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
