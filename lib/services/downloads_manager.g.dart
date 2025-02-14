// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_manager.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadItemAdapter extends TypeAdapter<DownloadItem> {
  @override
  final int typeId = 6;

  @override
  DownloadItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadItem(
      contentId: fields[0] as int,
      title: fields[1] as String,
      poster: fields[2] as String,
      type: fields[3] as String,
      filePath: fields[4] as String,
      downloadDate: fields[5] as DateTime,
      episodeNumber: fields[6] as int?,
      seasonNumber: fields[7] as int?,
      quality: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.contentId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.poster)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.downloadDate)
      ..writeByte(6)
      ..write(obj.episodeNumber)
      ..writeByte(7)
      ..write(obj.seasonNumber)
      ..writeByte(8)
      ..write(obj.quality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
