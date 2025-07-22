// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lens.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LensAdapter extends TypeAdapter<Lens> {
  @override
  final int typeId = 1;

  @override
  Lens read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lens(
      id: fields[0] as String?,
      name: fields[1] as String,
      sellingPrice: fields[2] == null ? 0.0 : fields[2] as double,
      costPrice: fields[3] == null ? 0.0 : fields[3] as double,
      company: fields[4] as String,
      stock: fields[5] == null ? 0.0 : fields[5] as double,
      description: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Lens obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sellingPrice)
      ..writeByte(3)
      ..write(obj.costPrice)
      ..writeByte(4)
      ..write(obj.company)
      ..writeByte(5)
      ..write(obj.stock)
      ..writeByte(6)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LensAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
