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
      rightEyeDV: fields[7] as String?,
      rightEyeNV: fields[8] as String?,
      leftEyeDV: fields[9] as String?,
      leftEyeNV: fields[10] as String?,
      note: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Invoice obj) {
    writer
      ..writeByte(12)
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
      ..write(obj.totalDiscountOnBill)
      ..writeByte(7)
      ..write(obj.rightEyeDV)
      ..writeByte(8)
      ..write(obj.rightEyeNV)
      ..writeByte(9)
      ..write(obj.leftEyeDV)
      ..writeByte(10)
      ..write(obj.leftEyeNV)
      ..writeByte(11)
      ..write(obj.note);
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
