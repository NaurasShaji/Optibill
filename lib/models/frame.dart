import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'frame.g.dart'; // This file will be generated

@HiveType(typeId: 0)
class Frame extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String modelName;

  @HiveField(2, defaultValue: 0.0)
  double sellingPrice;

  @HiveField(3, defaultValue: 0.0)
  double costPrice;

  @HiveField(4)
  String brand; // Sub-category for frames

  @HiveField(5, defaultValue: 0.0)
  double stock;

  @HiveField(6)
  String? description; // Optional

  Frame({
    String? id,
    required this.modelName,
    required this.sellingPrice,
    required this.costPrice,
    required this.brand,
    this.stock = 0,
    this.description,
  }) : id = id ?? const Uuid().v4();

  // Convert a Frame object to a JSON map
  Map<String, dynamic> toJson() => {
    'id': id,
    'modelName': modelName,
    'sellingPrice': sellingPrice,
    'costPrice': costPrice,
    'brand': brand,
    'stock': stock,
    'description': description,
  };

  // Create a Frame object from a JSON map
  factory Frame.fromJson(Map<String, dynamic> json) => Frame(
    id: json['id'] as String,
    modelName: json['modelName'] as String,
    sellingPrice: json['sellingPrice'] as double,
    costPrice: json['costPrice'] as double,
    stock: json['stock'] as double? ?? 0,
    brand: json['brand'] as String,
    description: json['description'] as String?,
  );
}
