// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceAdapter extends TypeAdapter<Invoice> {
  @override
  final int typeId = 3;

  @override
  Invoice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Invoice(
      invoiceId: fields[0] as String?,
      saleDate: fields[1] as DateTime,
      items: (fields[2] as List).cast<InvoiceItem>(),
      customerName: fields[3] as String?,
      customerContact: fields[4] as String?,
      paymentMethod: fields[5] as String,
      totalDiscountOnBill: fields[6] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Invoice obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.invoiceId)
      ..writeByte(1)
      ..write(obj.saleDate)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.customerName)
      ..writeByte(4)
      ..write(obj.customerContact)
      ..writeByte(5)
      ..write(obj.paymentMethod)
      ..writeByte(6)
      ..write(obj.totalDiscountOnBill);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
