import 'package:hive/hive.dart';

part 'invoice_item.g.dart'; // This file will be generated

@HiveType(typeId: 2)
class InvoiceItem extends HiveObject {
  @HiveField(0)
  final String productId; // ID of the Frame or Lens sold

  @HiveField(1)
  final String productName; // Name of the product at time of sale

  @HiveField(2)
  final String productType; // "Frame" or "Lens"

  @HiveField(3)
  double unitSellingPrice; // Changed from 'final double' to 'double' to allow editing

  @HiveField(4)
  final double unitCostPrice; // Cost at the time of sale

  @HiveField(5)
  int quantity;

  @HiveField(6) // Re-added
  double? discountAmount; // Optional, discount applied to this item

  InvoiceItem({
    required this.productId,
    required this.productName,
    required this.productType,
    required this.unitSellingPrice,
    required this.unitCostPrice,
    required this.quantity,
    this.discountAmount, // Re-added
  });

  // Computed Property: totalSellingPrice ((unitSellingPrice * quantity) - (discountAmount ?? 0) )
  double get totalSellingPrice => (unitSellingPrice * quantity) - (discountAmount ?? 0);

  // Computed Property: totalCostPrice
  double get totalCostPrice => unitCostPrice * quantity;

  // Computed Property: itemProfit (totalSellingPrice - totalCostPrice)
  double get itemProfit => totalSellingPrice - totalCostPrice;

  // Convert an InvoiceItem object to a JSON map
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'productType': productType,
    'unitSellingPrice': unitSellingPrice,
    'unitCostPrice': unitCostPrice,
    'quantity': quantity,
    'discountAmount': discountAmount, // Re-added
  };

  // Create an InvoiceItem object from a JSON map
  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    productType: json['productType'] as String,
    unitSellingPrice: json['unitSellingPrice'] as double,
    unitCostPrice: json['unitCostPrice'] as double,
    quantity: json['quantity'] as int,
    discountAmount: json['discountAmount'] as double?, // Re-added
  );
}
