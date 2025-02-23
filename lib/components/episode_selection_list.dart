import 'package:flutter/material.dart';
import 'package:moviedex/api/class/episode_class.dart';

class EpisodeSelectionList extends StatefulWidget {
  final List<Episode> episodes;
  final Function(Episode) onEpisodeSelected;

  const EpisodeSelectionList({
    Key? key,
    required this.episodes,
    required this.onEpisodeSelected,
  }) : super(key: key);

  @override
  State<EpisodeSelectionList> createState() => _EpisodeSelectionListState();
}

class _EpisodeSelectionListState extends State<EpisodeSelectionList> {
  List<Episode> selectedEpisodes = [];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.episodes.length,
      itemBuilder: (context, index) {
        final episode = widget.episodes[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              episode.image,
              width: 120,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          title: Text('Episode ${episode.episode}'),
          subtitle: Text(episode.name),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => widget.onEpisodeSelected(episode),
          ),
        );
      },
    );
  }
}
