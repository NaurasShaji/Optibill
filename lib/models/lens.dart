import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'lens.g.dart'; // This file will be generated

@HiveType(typeId: 1)
class Lens extends HiveObject {
  @HiveField(0)
  final String id; // Unique Lens ID

  @HiveField(1)
  String name; // Lens name

  @HiveField(2, defaultValue: 0.0)
  double sellingPrice; // Selling price

  @HiveField(3, defaultValue: 0.0)
  double costPrice; // Cost price

  @HiveField(4)
  String company; // Sub-category for lenses

  @HiveField(5, defaultValue: 0.0)
  double stock; // Stock quantity

  @HiveField(6)
  String? description; // Optional description

  Lens({
    String? id,
    required this.name,
    required this.sellingPrice,
    required this.costPrice,
    required this.company,
    this.stock = 0,
    this.description,
  }) : id = id ?? const Uuid().v4();

  // Convert a Lens object to a JSON map
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sellingPrice': sellingPrice,
    'costPrice': costPrice,
    'company': company,
    'stock': stock,
    'description': description,
  };

  // Create a Lens object from a JSON map
  factory Lens.fromJson(Map<String, dynamic> json) => Lens(
    id: json['id'] as String,
    name: json['name'] as String,
    sellingPrice: json['sellingPrice'] as double,
    costPrice: json['costPrice'] as double,
    stock: json['stock'] as double? ?? 0,
    company: json['company'] as String,
    description: json['description'] as String?,
  );
}
