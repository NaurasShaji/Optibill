import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'invoice_item.dart'; // Ensure InvoiceItem is imported

part 'invoice.g.dart'; // This file will be generated

@HiveType(typeId: 3)
class Invoice extends HiveObject {
  @HiveField(0)
  final String invoiceId;

  @HiveField(1)
  final DateTime saleDate;

  @HiveField(2)
  final List<InvoiceItem> items;

  @HiveField(3)
  String? customerName; // Optional

  @HiveField(4)
  String? customerContact; // Optional

  @HiveField(5)
  String paymentMethod; // e.g., "Cash", "Card", "UPI"

  @HiveField(6)
  double? totalDiscountOnBill; // Optional, discount applied to the whole bill

  Invoice({
    String? invoiceId,
    required this.saleDate,
    required this.items,
    this.customerName,
    this.customerContact,
    required this.paymentMethod,
    this.totalDiscountOnBill,
  }) : invoiceId = invoiceId ?? const Uuid().v4();

  // Computed Property: subtotal (sum of unitSellingPrice * quantity for all items before bill-level discount)
  double get subtotal => items.fold(0.0, (sum, item) => sum + (item.unitSellingPrice * item.quantity));

  // Computed Property: totalAmount (subtotal - totalDiscountOnBill)
  double get totalAmount => subtotal - (totalDiscountOnBill ?? 0);

  // Computed Property: totalProfit (sum of itemProfit for all items - totalDiscountOnBill if applied at bill level)
  double get totalProfit {
    double itemsProfit = items.fold(0.0, (sum, item) => sum + item.itemProfit);
    return itemsProfit - (totalDiscountOnBill ?? 0);
  }

  // Convert an Invoice object to a JSON map
  Map<String, dynamic> toJson() => {
    'invoiceId': invoiceId,
    'saleDate': saleDate.toIso8601String(), // Convert DateTime to ISO string
    'items': items.map((item) => item.toJson()).toList(), // Convert list of InvoiceItems
    'customerName': customerName,
    'customerContact': customerContact,
    'paymentMethod': paymentMethod,
    'totalDiscountOnBill': totalDiscountOnBill,
  };

  // Create an Invoice object from a JSON map
  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    invoiceId: json['invoiceId'] as String,
    saleDate: DateTime.parse(json['saleDate'] as String), // Parse ISO string back to DateTime
    items: (json['items'] as List)
        .map((itemJson) => InvoiceItem.fromJson(itemJson as Map<String, dynamic>))
        .toList(),
    customerName: json['customerName'] as String?,
    customerContact: json['customerContact'] as String?,
    paymentMethod: json['paymentMethod'] as String,
    totalDiscountOnBill: json['totalDiscountOnBill'] as double?,
  );
}
