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

  @HiveField(5)
  final Map<String, dynamic>? content;

  ListItem({
    required this.contentId,
    required this.title,
    required this.poster,
    required this.type,
    required this.addedAt,
    this.content,
  });
}
