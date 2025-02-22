import 'package:hive/hive.dart';

part 'list_item_model.g.dart';

@HiveType(typeId: 5)
class ListItem extends HiveObject {
  @HiveField(0)
  final int contentId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String poster;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final DateTime addedAt;

  ListItem({
    required this.contentId,
    required this.title,
    required this.poster,
    required this.type,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'content_id': contentId,
      'title': title,
      'poster': poster,
      'type': type,
      'added_at': addedAt.toIso8601String(),
    };
  }

  factory ListItem.fromJson(Map<String, dynamic> json) {
    return ListItem(
      contentId: json['content_id'],
      title: json['title'],
      poster: json['poster'],
      type: json['type'],
      addedAt: DateTime.parse(json['added_at']),
    );
  }
}
