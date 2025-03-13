// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_state_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadStateAdapter extends TypeAdapter<DownloadState> {
  @override
  final int typeId = 7;

  @override
  DownloadState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadState(
      contentId: fields[0] as int,
      status: fields[1] as String,
      progress: fields[2] as double,
      url: fields[3] as String,
      quality: fields[4] as String,
      lastSegmentIndex: fields[5] as int?,
      episodeNumber: fields[6] as int?,
      seasonNumber: fields[7] as int?,
      speed: fields[8] as double,
      timeLeft: fields[9] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadState obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.contentId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.progress)
      ..writeByte(3)
      ..write(obj.url)
      ..writeByte(4)
      ..write(obj.quality)
      ..writeByte(5)
      ..write(obj.lastSegmentIndex)
      ..writeByte(6)
      ..write(obj.episodeNumber)
      ..writeByte(7)
      ..write(obj.seasonNumber)
      ..writeByte(8)
      ..write(obj.speed)
      ..writeByte(9)
      ..write(obj.timeLeft);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
