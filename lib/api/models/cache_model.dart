import 'package:hive/hive.dart';

part 'cache_model.g.dart';

@HiveType(typeId: 1)
class CacheModel extends HiveObject {
  @HiveField(0)
  final String key;

  @HiveField(1)
  final dynamic data;

  @HiveField(2)
  final DateTime timestamp;

  CacheModel({
    required this.key,
    required this.data,
    required this.timestamp,
  });
}
