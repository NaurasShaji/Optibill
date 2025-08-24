// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceItemAdapter extends TypeAdapter<InvoiceItem> {
  @override
  final int typeId = 2;

  @override
  InvoiceItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceItem(
      productId: fields[0] as String,
      productName: fields[1] as String,
      productType: fields[2] as String,
      unitSellingPrice: fields[3] as double,
      unitCostPrice: fields[4] as double,
      quantity: fields[5] as int,
      discountAmount: fields[6] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.productType)
      ..writeByte(3)
      ..write(obj.unitSellingPrice)
      ..writeByte(4)
      ..write(obj.unitCostPrice)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.discountAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
