import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/product_service.dart';
import 'package:optibill/screens/add_edit_product_screen.dart';
import 'package:intl/intl.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductService _productService = ProductService();
  String _selectedCategory = 'All'; // 'All', 'Frame', 'Lens'
  String _selectedSubCategory = 'All'; // Brand for frames, Company for lenses
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _filterProducts(); // Initial filter
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    setState(() {
      List<dynamic> allProducts = _productService.getAllProducts();
      List<dynamic> tempProducts = [];

      // Filter by main category
      if (_selectedCategory == 'Frame') {
        tempProducts = allProducts.whereType<Frame>().toList();
      } else if (_selectedCategory == 'Lens') {
        tempProducts = allProducts.whereType<Lens>().toList();
      } else {
        tempProducts = allProducts;
      }

      // Filter by sub-category
      if (_selectedSubCategory != 'All') {
        tempProducts = tempProducts.where((product) {
          if (product is Frame) {
            return product.brand == _selectedSubCategory;
          } else if (product is Lens) {
            return product.company == _selectedSubCategory;
          }
          return false;
        }).toList();
      }

      // Filter by search query
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        tempProducts = tempProducts.where((product) {
          if (product is Frame) {
            return product.modelName.toLowerCase().contains(query);
          } else if (product is Lens) {
            return product.name.toLowerCase().contains(query);
          }
          return false;
        }).toList();
      }

      _filteredProducts = tempProducts;
    });
  }

  List<String> _getAvailableSubCategories() {
    Set<String> subCategories = {'All'};
    List<dynamic> products = _productService.getAllProducts();

    if (_selectedCategory == 'Frame') {
      for (var product in products.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
    } else if (_selectedCategory == 'Lens') {
      for (var product in products.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    } else { // All products
      for (var product in products.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
      for (var product in products.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    }
    return subCategories.toList()..sort();
  }

  void _confirmDelete(BuildContext context, dynamic product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${product is Frame ? product.modelName : product.name}?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                if (product is Frame) {
                  await _productService.deleteFrame(product.id);
                } else if (product is Lens) {
                  await _productService.deleteLens(product.id);
                }
                Navigator.of(context).pop();
                _filterProducts(); // Refresh list
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Products',
              hintText: 'Search by name or model',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                  ),
                  items: <String>['All', 'Frame', 'Lens'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue!;
                      _selectedSubCategory = 'All'; // Reset sub-category on category change
                      _filterProducts();
                    });
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  decoration: InputDecoration(
                    labelText: 'Sub-Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                  ),
                  items: _getAvailableSubCategories().map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSubCategory = newValue!;
                      _filterProducts();
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<Frame>('frames').listenable(),
              builder: (context, Box<Frame> framesBox, _) {
                return ValueListenableBuilder(
                  valueListenable: Hive.box<Lens>('lenses').listenable(),
                  builder: (context, Box<Lens> lensesBox, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _filterProducts();
                    });

                    if (_filteredProducts.isEmpty) {
                      return const Center(child: Text('No products found.'));
                    }

                    // Excel-like DataTable with both vertical and horizontal scrolling
                    return Container(
                      // You can adjust the height as needed, or use double.infinity for max available
                      width: double.infinity,
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                              child: DataTable(
                                columnSpacing: 20,
                                dataRowMinHeight: 40,
                                dataRowMaxHeight: 60,
                                headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                                columns: [
                                  DataColumn(label: Text('Name/Model', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Brand/Company', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Cost Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _filteredProducts.map((product) {
                                  String name = product is Frame ? product.modelName : product.name;
                                  String type = product is Frame ? 'Frame' : 'Lens';
                                  String brandCompany = product is Frame ? product.brand : product.company;
                                  String sellingPrice = formatCurrency.format(product.sellingPrice);
                                  String costPrice = formatCurrency.format(product.costPrice);

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(name)),
                                      DataCell(Text(type)),
                                      DataCell(Text(brandCompany)),
                                      DataCell(Text(sellingPrice)),
                                      DataCell(Text(costPrice)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => AddEditProductScreen(product: product),
                                                  ),
                                                ).then((_) => _filterProducts());
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                              onPressed: () => _confirmDelete(context, product),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddEditProductScreen()),
                ).then((_) => _filterProducts());
              },
              label: const Text('Add Product'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            ),
          ),
        ],
      ),
    );
  }
}