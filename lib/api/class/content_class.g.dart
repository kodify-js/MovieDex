// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_class.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContentclassAdapter extends TypeAdapter<Contentclass> {
  @override
  final int typeId = 2;

  @override
  Contentclass read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Contentclass(
      id: fields[0] as int,
      backdrop: fields[1] as String,
      title: fields[2] as String,
      language: fields[3] as String,
      genres: (fields[4] as List).cast<dynamic>(),
      type: fields[5] as String,
      description: fields[6] as String,
      poster: fields[7] as String,
      logoPath: fields[8] as String?,
      rating: fields[9] as double?,
      seasons: (fields[10] as List?)?.cast<Season>(),
    );
  }

  @override
  void write(BinaryWriter writer, Contentclass obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.backdrop)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.language)
      ..writeByte(4)
      ..write(obj.genres)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.poster)
      ..writeByte(8)
      ..write(obj.logoPath)
      ..writeByte(9)
      ..write(obj.rating)
      ..writeByte(10)
      ..write(obj.seasons);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentclassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SeasonAdapter extends TypeAdapter<Season> {
  @override
  final int typeId = 3;

  @override
  Season read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Season(
      id: fields[0] as int,
      season: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Season obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.season);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeasonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
