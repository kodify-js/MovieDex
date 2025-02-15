// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_history_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchHistoryItemAdapter extends TypeAdapter<WatchHistoryItem> {
  @override
  final int typeId = 4;

  @override
  WatchHistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchHistoryItem(
      contentId: fields[0] as int,
      title: fields[1] as String,
      poster: fields[2] as String,
      type: fields[3] as String,
      watchedAt: fields[4] as DateTime,
      progress: fields[5] as Duration?,
      totalDuration: fields[6] as Duration?,
      episodeNumber: fields[7] as int?,
      episodeTitle: fields[8] as String?,
      content: (fields[9] as Map?)?.cast<String, dynamic>(),
      seasonNumber: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WatchHistoryItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.contentId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.poster)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.watchedAt)
      ..writeByte(5)
      ..write(obj.progress)
      ..writeByte(6)
      ..write(obj.totalDuration)
      ..writeByte(7)
      ..write(obj.episodeNumber)
      ..writeByte(8)
      ..write(obj.episodeTitle)
      ..writeByte(9)
      ..write(obj.content)
      ..writeByte(10)
      ..write(obj.seasonNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchHistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
