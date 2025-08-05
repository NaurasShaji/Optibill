import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/product_service.dart';
import 'package:optibill/screens/add_edit_product_screen.dart';
import 'package:optibill/screens/view_product_screen.dart';
import 'package:intl/intl.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ProductService _productService = ProductService();
  String _selectedCategory = 'All';
  String _selectedSubCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  
  // Cached data
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  List<String> _availableSubCategories = ['All'];
  
  // Performance optimizations
  static final NumberFormat _formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool _isInitialized = false;
  Timer? _debounceTimer;
  bool _isLoading = false;
  
  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Clear filtered products to free memory when app is paused
      if (mounted) {
        setState(() {
          _filteredProducts.clear();
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reload data when app resumes
      _initializeData();
    }
  }

  Future<void> _initializeData() async {
    if (!_isInitialized || _allProducts.isEmpty) {
      setState(() {
        _isLoading = true;
      });
      
      // Use Future.microtask to prevent blocking UI
      await Future.microtask(() {
        _allProducts = _productService.getAllProducts();
        _updateAvailableSubCategories();
        _filterProducts();
        _isInitialized = true;
      });
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Debounced search to prevent excessive filtering
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _filterProducts();
      }
    });
  }

  void _updateAvailableSubCategories() {
    final Set<String> subCategories = {'All'};

    if (_selectedCategory == 'Frame') {
      for (final product in _allProducts.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
    } else if (_selectedCategory == 'Lens') {
      for (final product in _allProducts.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    } else {
      // All products
      for (final product in _allProducts.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
      for (final product in _allProducts.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    }
    
    _availableSubCategories = subCategories.toList()..sort();
  }

  void _filterProducts() {
    final stopwatch = Stopwatch()..start();
    
    List<dynamic> tempProducts = _allProducts;

    // Filter by main category
    if (_selectedCategory == 'Frame') {
      tempProducts = tempProducts.whereType<Frame>().toList();
    } else if (_selectedCategory == 'Lens') {
      tempProducts = tempProducts.whereType<Lens>().toList();
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
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempProducts = tempProducts.where((product) {
        if (product is Frame) {
          return product.modelName.toLowerCase().contains(query);
        } else if (product is Lens) {
          return product.name.toLowerCase().contains(query);
        }
        return false;
      }).toList();
    }

    if (mounted) {
      setState(() {
        _filteredProducts = tempProducts;
      });
    }
    
    stopwatch.stop();
    debugPrint('Filter took: ${stopwatch.elapsedMilliseconds}ms for ${tempProducts.length} products');
  }

  void _onCategoryChanged(String? newValue) {
    if (newValue != null && newValue != _selectedCategory) {
      setState(() {
        _selectedCategory = newValue;
        _selectedSubCategory = 'All';
      });
      _updateAvailableSubCategories();
      _filterProducts();
    }
  }

  void _onSubCategoryChanged(String? newValue) {
    if (newValue != null && newValue != _selectedSubCategory) {
      setState(() {
        _selectedSubCategory = newValue;
      });
      _filterProducts();
    }
  }

  void _confirmDelete(BuildContext context, dynamic product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text(
            'Are you sure you want to delete ${product is Frame ? product.modelName : product.name}?'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  if (product is Frame) {
                    await _productService.deleteFrame(product.id);
                  } else if (product is Lens) {
                    await _productService.deleteLens(product.id);
                  }
                  Navigator.of(context).pop();
                  await _refreshData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Product deleted successfully')),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting product: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshData() async {
    await Future.microtask(() {
      _allProducts = _productService.getAllProducts();
      _updateAvailableSubCategories();
      _filterProducts();
    });
  }

  void _navigateToViewScreen(dynamic product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewProductScreen(product: product),
      ),
    ).then((_) => _refreshData());
  }

  void _navigateToAddEditScreen([dynamic product]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(product: product),
      ),
    ).then((_) => _refreshData());
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        labelText: 'Search Products',
        hintText: 'Search by name or model',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _filterProducts();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            ),
            items: const <String>['All', 'Frame', 'Lens'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: _onCategoryChanged,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedSubCategory,
            decoration: InputDecoration(
              labelText: 'Sub-Category',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            ),
            items: _availableSubCategories.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: _onSubCategoryChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildProductList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products...'),
          ],
        ),
      );
    }

    if (_filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty 
                ? 'No products found matching "${_searchController.text}"'
                : 'No products found.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _filterProducts();
                },
                child: const Text('Clear search'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final String name = product is Frame ? product.modelName : product.name;
    final String type = product is Frame ? 'Frame' : 'Lens';
    final String brandCompany = product is Frame ? product.brand : product.company;
    final String sellingPrice = _formatCurrency.format(product.sellingPrice);
    final String stock = product is Frame ? product.stock.toInt().toString() : product.stock.toString();
    final String costPrice = _formatCurrency.format(product.costPrice);

    // Color coding for stock levels
    Color stockColor = Colors.green;
    if (product is Frame) {
      if (product.stock <= 5) stockColor = Colors.red;
      else if (product.stock <= 10) stockColor = Colors.orange;
    } else if (product is Lens) {
      if (product.stock <= 5) stockColor = Colors.red;
      else if (product.stock <= 10) stockColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      elevation: 1,
      child: InkWell(
        onTap: () => _navigateToViewScreen(product),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: type == 'Frame' ? Colors.blue.shade100 : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: type == 'Frame' ? Colors.blue.shade800 : Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                brandCompany,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                        onPressed: () => _navigateToAddEditScreen(product),
                        tooltip: 'Edit',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _confirmDelete(context, product),
                        tooltip: 'Delete',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip('Selling', sellingPrice, Colors.green.shade100, Colors.green.shade800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip('Cost', costPrice, Colors.orange.shade100, Colors.orange.shade800),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip('Stock', stock, stockColor.withOpacity(0.1), stockColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    debugPrint('ProductListScreen building...');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)).take(1), // Minimal stream for initial load
                builder: (context, snapshot) {
                  return _buildProductList();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEditScreen(),
        label: const Text('Add Product'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      ),
    );
  }
}