import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/product_service.dart';
import 'package:optibill/screens/add_edit_product_screen.dart';
import 'package:optibill/screens/view_product_screen.dart';
import 'package:intl/intl.dart';

/// A professional product list screen with advanced filtering, search, and performance optimizations.
/// 
/// Features:
/// - Real-time search with debouncing
/// - Category and subcategory filtering
/// - Memory-efficient list rendering
/// - Pull-to-refresh functionality
/// - Stock level color coding
/// - Professional UI/UX design
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  
  // Constants
  static const Duration _searchDebounceDelay = Duration(milliseconds: 300);
  static const Duration _dataRefreshInterval = Duration(seconds: 30);
  static const int _lowStockThreshold = 5;
  static const int _mediumStockThreshold = 10;
  
  // Services
  final ProductService _productService = ProductService();
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  
  // State variables
  String _selectedCategory = ProductCategory.all.displayName;
  String _selectedSubCategory = SubCategory.all.displayName;
  
  // Data management
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  List<String> _availableSubCategories = [SubCategory.all.displayName];
  
  // UI state
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Performance optimizations
  Timer? _debounceTimer;
  Timer? _refreshTimer;
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN', 
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      default:
        break;
    }
  }

  /// Initialize screen components and load initial data
  void _initializeScreen() {
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    _initializeData();
    _startPeriodicRefresh();
  }

  /// Clean up all resources to prevent memory leaks
  void _cleanupResources() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _refreshTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
  }

  /// Handle app being paused - free memory
  void _handleAppPaused() {
    if (mounted) {
      setState(() {
        _filteredProducts = [];
      });
    }
  }

  /// Handle app being resumed - reload data
  void _handleAppResumed() {
    _initializeData();
  }

  /// Start periodic data refresh
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(_dataRefreshInterval, (_) {
      if (mounted && !_isLoading) {
        _refreshData();
      }
    });
  }

  /// Initialize and load product data
  Future<void> _initializeData() async {
    if (_isLoading) return;
    
    try {
      _setLoadingState(true, null);
      
      await Future.microtask(() async {
        final products = _productService.getAllProducts();
        
        if (mounted) {
          setState(() {
            _allProducts = products;
            _isInitialized = true;
          });
          
          _updateAvailableSubCategories();
          _filterProducts();
        }
      });
      
    } catch (error) {
      debugPrint('Error initializing data: $error');
      _setLoadingState(false, 'Failed to load products. Please try again.');
    } finally {
      if (mounted) {
        _setLoadingState(false, null);
      }
    }
  }

  /// Set loading state and error message
  void _setLoadingState(bool isLoading, String? errorMessage) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
        _errorMessage = errorMessage;
      });
    }
  }

  /// Handle search input changes with debouncing
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounceDelay, () {
      if (mounted) {
        _filterProducts();
      }
    });
  }

  /// Update available subcategories based on selected main category
  void _updateAvailableSubCategories() {
    final Set<String> subCategories = {SubCategory.all.displayName};

    switch (_selectedCategory) {
      case 'Frame':
        _allProducts.whereType<Frame>().forEach((frame) {
          subCategories.add(frame.brand);
        });
        break;
      case 'Lens':
        _allProducts.whereType<Lens>().forEach((lens) {
          subCategories.add(lens.company);
        });
        break;
      default:
        // All products - add both frame brands and lens companies
        _allProducts.whereType<Frame>().forEach((frame) {
          subCategories.add(frame.brand);
        });
        _allProducts.whereType<Lens>().forEach((lens) {
          subCategories.add(lens.company);
        });
    }
    
    _availableSubCategories = subCategories.toList()..sort();
  }

  /// Filter products based on category, subcategory, and search query
  void _filterProducts() {
    final stopwatch = Stopwatch()..start();
    
    try {
      List<dynamic> filteredProducts = List.from(_allProducts);

      // Apply category filter
      filteredProducts = _applyCategoryFilter(filteredProducts);
      
      // Apply subcategory filter
      filteredProducts = _applySubCategoryFilter(filteredProducts);
      
      // Apply search filter
      filteredProducts = _applySearchFilter(filteredProducts);

      if (mounted) {
        setState(() {
          _filteredProducts = filteredProducts;
        });
      }
    } catch (error) {
      debugPrint('Error filtering products: $error');
      if (mounted) {
        setState(() {
          _filteredProducts = [];
        });
      }
    } finally {
      stopwatch.stop();
      debugPrint('Filter operation completed in ${stopwatch.elapsedMilliseconds}ms for ${_filteredProducts.length} products');
    }
  }

  /// Apply category-based filtering
  List<dynamic> _applyCategoryFilter(List<dynamic> products) {
    switch (_selectedCategory) {
      case 'Frame':
        return products.whereType<Frame>().toList();
      case 'Lens':
        return products.whereType<Lens>().toList();
      default:
        return products;
    }
  }

  /// Apply subcategory-based filtering
  List<dynamic> _applySubCategoryFilter(List<dynamic> products) {
    if (_selectedSubCategory == SubCategory.all.displayName) {
      return products;
    }

    return products.where((product) {
      if (product is Frame) {
        return product.brand == _selectedSubCategory;
      } else if (product is Lens) {
        return product.company == _selectedSubCategory;
      }
      return false;
    }).toList();
  }

  /// Apply search query filtering
  List<dynamic> _applySearchFilter(List<dynamic> products) {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return products;

    return products.where((product) {
      final searchText = _getProductSearchText(product).toLowerCase();
      return searchText.contains(query);
    }).toList();
  }

  /// Get searchable text for a product
  String _getProductSearchText(dynamic product) {
    if (product is Frame) {
      return '${product.modelName} ${product.brand}';
    } else if (product is Lens) {
      return '${product.name} ${product.company}';
    }
    return '';
  }

  /// Handle category selection change
  void _onCategoryChanged(String? newCategory) {
    if (newCategory == null || newCategory == _selectedCategory) return;

    setState(() {
      _selectedCategory = newCategory;
      _selectedSubCategory = SubCategory.all.displayName;
    });
    
    _updateAvailableSubCategories();
    _filterProducts();
  }

  /// Handle subcategory selection change
  void _onSubCategoryChanged(String? newSubCategory) {
    if (newSubCategory == null || newSubCategory == _selectedSubCategory) return;

    setState(() {
      _selectedSubCategory = newSubCategory;
    });
    
    _filterProducts();
  }

  /// Show confirmation dialog for product deletion
  Future<void> _showDeleteConfirmation(BuildContext context, dynamic product) async {
    final productName = _getProductName(product);
    
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                const TextSpan(text: 'Are you sure you want to delete '),
                TextSpan(
                  text: productName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '?\n\nThis action cannot be undone.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && mounted) {
      await _deleteProduct(product);
    }
  }

  /// Delete a product and handle the result
  Future<void> _deleteProduct(dynamic product) async {
    try {
      _setLoadingState(true, null);
      
      if (product is Frame) {
        await _productService.deleteFrame(product.id);
      } else if (product is Lens) {
        await _productService.deleteLens(product.id);
      } else {
        throw Exception('Unknown product type');
      }

      await _refreshData();
      _showSnackBar('Product deleted successfully', isError: false);
      
    } catch (error) {
      debugPrint('Error deleting product: $error');
      _showSnackBar('Failed to delete product: ${error.toString()}', isError: true);
    } finally {
      _setLoadingState(false, null);
    }
  }

  /// Refresh product data
  Future<void> _refreshData() async {
    try {
      await Future.microtask(() {
        _allProducts = _productService.getAllProducts();
        _updateAvailableSubCategories();
        _filterProducts();
      });
    } catch (error) {
      debugPrint('Error refreshing data: $error');
      _showSnackBar('Failed to refresh data', isError: true);
    }
  }

  /// Navigate to product view screen
  void _navigateToViewScreen(dynamic product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ViewProductScreen(product: product),
      ),
    ).then((_) => _refreshData());
  }

  /// Navigate to add/edit product screen
  void _navigateToAddEditScreen([dynamic product]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(product: product),
      ),
    ).then((_) => _refreshData());
  }

  /// Show snackbar message
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
        action: isError ? SnackBarAction(
          label: 'RETRY',
          onPressed: _refreshData,
          textColor: Colors.white,
        ) : null,
      ),
    );
  }

  /// Get product name for display
  String _getProductName(dynamic product) {
    if (product is Frame) return product.modelName;
    if (product is Lens) return product.name;
    return 'Unknown Product';
  }

  /// Get stock level color based on quantity
  Color _getStockLevelColor(num stock) {
    if (stock <= _lowStockThreshold) return Colors.red;
    if (stock <= _mediumStockThreshold) return Colors.orange;
    return Colors.green;
  }

  /// Build search field widget
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search Products',
          hintText: 'Search by name, model, or brand...',
          prefixIcon: const Icon(Icons.search_outlined),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_outlined),
                  onPressed: () {
                    _searchController.clear();
                    _filterProducts();
                  },
                  tooltip: 'Clear search',
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        ),
      ),
    );
  }

  /// Build filter widgets
  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterDropdown(
            label: 'Category',
            value: _selectedCategory,
            items: ProductCategory.values.map((e) => e.displayName).toList(),
            onChanged: _onCategoryChanged,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFilterDropdown(
            label: 'Sub-Category',
            value: _selectedSubCategory,
            items: _availableSubCategories,
            onChanged: _onSubCategoryChanged,
          ),
        ),
      ],
    );
  }

  /// Build individual filter dropdown
  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        ),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  /// Build product list widget
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

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _filteredProducts.length,
        padding: const EdgeInsets.only(bottom: 80), // Space for FAB
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  /// Build error state widget
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Build empty state widget
  Widget _buildEmptyState() {
    final hasSearchQuery = _searchController.text.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearchQuery ? Icons.search_off_outlined : Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearchQuery 
                ? 'No Results Found'
                : 'No Products Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearchQuery 
                ? 'No products match "${_searchController.text}"\nTry adjusting your search or filters.'
                : 'Start by adding your first product.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (hasSearchQuery) ...[
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _filterProducts();
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () => _navigateToAddEditScreen(),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build individual product card
  Widget _buildProductCard(dynamic product) {
    final name = _getProductName(product);
    final type = product is Frame ? 'Frame' : 'Lens';
    final brandCompany = product is Frame ? product.brand : product.company;
    final sellingPrice = _currencyFormatter.format(product.sellingPrice);
    final costPrice = _currencyFormatter.format(product.costPrice);
    final stock = product.stock.toString();
    final stockColor = _getStockLevelColor(product.stock);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _navigateToViewScreen(product),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(name, type, brandCompany, product),
              const SizedBox(height: 12),
              _buildCardDetails(sellingPrice, costPrice, stock, stockColor),
            ],
          ),
        ),
      ),
      ),
    );
    
  }

  /// Build card header with product name and actions
  Widget _buildCardHeader(String name, String type, String brandCompany, dynamic product) {
    return Row(
      children: [
        Expanded(
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
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildTypeChip(type),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      brandCompany,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildCardActions(product),
      ],
    );
  }

  /// Build type chip
  Widget _buildTypeChip(String type) {
    final isFrame = type == 'Frame';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFrame ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFrame ? Colors.blue.shade200 : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 12,
          color: isFrame ? Colors.blue.shade700 : Colors.green.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Build card action buttons
  Widget _buildCardActions(dynamic product) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600, size: 20),
          onPressed: () => _navigateToAddEditScreen(product),
          tooltip: 'Edit Product',
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(40, 40),
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
          onPressed: () => _showDeleteConfirmation(context, product),
          tooltip: 'Delete Product',
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(40, 40),
          ),
        ),
      ],
    );
  }

  /// Build card details section
  Widget _buildCardDetails(String sellingPrice, String costPrice, String stock, Color stockColor) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoChip('Selling Price', sellingPrice, Colors.green.shade50, Colors.green.shade700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildInfoChip('Cost Price', costPrice, Colors.orange.shade50, Colors.orange.shade700),
        ),
        const SizedBox(width: 8),
        _buildInfoChip('Stock', stock, stockColor.withOpacity(0.1), stockColor),
      ],
    );
  }

  /// Build information chip
  Widget _buildInfoChip(String label, String value, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
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
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSearchField(),
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(child: _buildProductList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEditScreen(),
        label: const Text('Add Product'),
        icon: const Icon(Icons.add_outlined),
        backgroundColor: Colors.blue.shade600,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
    );
  }
}

// Enums for better type safety and maintainability
enum ProductCategory {
  all('All'),
  frame('Frame'),
  lens('Lens');

  const ProductCategory(this.displayName);
  final String displayName;
}

enum SubCategory {
  all('All');

  const SubCategory(this.displayName);
  final String displayName;
}