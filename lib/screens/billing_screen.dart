import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/invoice.dart';
import 'package:optibill/models/invoice_item.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/invoice_service.dart';
import 'package:optibill/services/product_service.dart';
import 'package:optibill/utils/pdf_generator.dart';

class BillingScreen extends StatefulWidget {
  final Invoice? invoiceToEdit;

  const BillingScreen({super.key, this.invoiceToEdit});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ProductService _productService = ProductService();
  final InvoiceService _invoiceService = InvoiceService();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerContactController = TextEditingController();
  final TextEditingController _billDiscountController = TextEditingController();
  final TextEditingController _rightEyeDVController = TextEditingController();
  final TextEditingController _rightEyeNVController = TextEditingController();
  final TextEditingController _leftEyeDVController = TextEditingController();
  final TextEditingController _leftEyeNVController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<InvoiceItem> _currentItems = [];
  String _selectedPaymentMethod = 'Cash';
  String? _editingInvoiceId;

  double _subtotal = 0.0;
  double _totalDiscountOnBill = 0.0;
  double _totalAmount = 0.0;
  double _totalProfit = 0.0;

  bool _isInitialized = false;
  bool _isSaving = false;
  Timer? _calculationDebounce;

  static const List<String> _paymentMethods = ['Cash', 'UPI', 'CARD', 'Bank Transfer', 'Other'];
  static final NumberFormat _formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final DateFormat _formatDate = DateFormat('dd-MM-yyyy HH:mm');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _billDiscountController.addListener(_onDiscountChanged);
    _initializeBillingSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calculationDebounce?.cancel();
    _customerNameController.dispose();
    _customerContactController.dispose();
    _billDiscountController.dispose();
    _rightEyeDVController.dispose();
    _rightEyeNVController.dispose();
    _leftEyeDVController.dispose();
    _leftEyeNVController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isSaving) {
      // Auto-save draft when app is paused
      _saveDraft();
    }
  }

  void _saveDraft() {
    // Save current state as draft - implement based on your requirements
    debugPrint('Auto-saving draft...');
  }

  void _onDiscountChanged() {
    _calculationDebounce?.cancel();
    _calculationDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _calculateTotals();
      }
    });
  }

  Future<void> _initializeBillingSession() async {
    if (_isInitialized) return;

    try {
      if (widget.invoiceToEdit != null) {
        await _loadInvoiceForEditing();
      }
      _calculateTotals();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing billing session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoice: $e')),
        );
      }
    }
  }

  Future<void> _loadInvoiceForEditing() async {
    final invoice = widget.invoiceToEdit!;
    
    _editingInvoiceId = invoice.invoiceId;
    _customerNameController.text = invoice.customerName ?? '';
    _customerContactController.text = invoice.customerContact ?? '';
    _selectedPaymentMethod = invoice.paymentMethod;
    _billDiscountController.text = (invoice.totalDiscountOnBill ?? 0.0).toStringAsFixed(2);
    _currentItems = List.from(invoice.items);
    _rightEyeDVController.text = invoice.rightEyeDV ?? '';
    _rightEyeNVController.text = invoice.rightEyeNV ?? '';
    _leftEyeDVController.text = invoice.leftEyeDV ?? '';
    _leftEyeNVController.text = invoice.leftEyeNV ?? '';
    _noteController.text = invoice.note ?? '';

    // Restore stock when editing (add back the quantities that were sold)
    for (var item in invoice.items) {
      await _productService.increaseStock(item.productId, item.productType, item.quantity);
    }
  }

  void _calculateTotals() {
    final stopwatch = Stopwatch()..start();
    
    double currentSubtotal = 0.0;
    double currentTotalProfit = 0.0;

    for (var item in _currentItems) {
      currentSubtotal += (item.unitSellingPrice * item.quantity);
      double itemProfit = (item.unitSellingPrice - item.unitCostPrice) * item.quantity;
      currentTotalProfit += itemProfit;
    }

    double billDiscount = double.tryParse(_billDiscountController.text) ?? 0.0;
    if (billDiscount < 0) billDiscount = 0.0;
    if (billDiscount > currentSubtotal) billDiscount = currentSubtotal;

    double finalTotalAmount = currentSubtotal - billDiscount;
    double finalTotalProfit = currentTotalProfit - billDiscount;

    if (finalTotalAmount < 0) finalTotalAmount = 0.0;
    if (finalTotalProfit < 0) finalTotalProfit = 0.0;

    if (mounted) {
      setState(() {
        _subtotal = currentSubtotal;
        _totalDiscountOnBill = billDiscount;
        _totalAmount = finalTotalAmount;
        _totalProfit = finalTotalProfit;
      });
    }

    stopwatch.stop();
    debugPrint('Calculation took: ${stopwatch.elapsedMilliseconds}ms');
  }

  void _addItemToInvoice(dynamic product, int quantity) {
    int existingIndex = _currentItems.indexWhere(
      (item) => item.productId == (product is Frame ? product.id : product.id)
    );

    if (existingIndex != -1) {
      setState(() {
        _currentItems[existingIndex].quantity += quantity;
        _currentItems[existingIndex].discountAmount = null;
      });
    } else {
      setState(() {
        _currentItems.add(
          InvoiceItem(
            productId: product is Frame ? product.id : product.id,
            productName: product is Frame ? product.modelName : product.name,
            productType: product is Frame ? 'Frame' : 'Lens',
            unitSellingPrice: product.sellingPrice,
            unitCostPrice: product.costPrice,
            quantity: quantity,
            discountAmount: null,
          ),
        );
      });
    }
    _calculateTotals();
  }

  void _removeItemFromInvoice(int index) {
    if (index >= 0 && index < _currentItems.length) {
      setState(() {
        _currentItems.removeAt(index);
      });
      _calculateTotals();
    }
  }

  void _editItemQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _currentItems.length) {
      if (newQuantity <= 0) {
        _removeItemFromInvoice(index);
      } else {
        setState(() {
          _currentItems[index].quantity = newQuantity;
        });
        _calculateTotals();
      }
    }
  }

  void _editItemPrice(int index, double newPrice) {
    if (index >= 0 && index < _currentItems.length && newPrice >= 0) {
      setState(() {
        _currentItems[index].unitSellingPrice = newPrice;
      });
      _calculateTotals();
    }
  }

  void _editItemDiscount(int index, double? discount) {
    if (index >= 0 && index < _currentItems.length) {
      setState(() {
        _currentItems[index].discountAmount = discount;
      });
      _calculateTotals();
    }
  }

  Future<void> _showProductPicker() async {
    try {
      final selectedProduct = await showModalBottomSheet<dynamic>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) {
          return ProductPicker(productService: _productService);
        },
      );

      if (selectedProduct != null) {
        _addItemToInvoice(selectedProduct, 1);
      }
    } catch (e) {
      debugPrint('Error showing product picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  Future<bool> _validateInvoice() async {
    if (_currentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to the invoice.')),
      );
      return false;
    }

    // Check stock availability
    for (var item in _currentItems) {
      final product = _productService.getProductById(item.productId, item.productType);
      if (product == null || product.stock < item.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient stock for ${item.productName}. Available: ${product?.stock ?? 0}'
            ),
          ),
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _saveOrUpdateInvoice() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (!await _validateInvoice()) {
        return;
      }

      double billDiscount = double.tryParse(_billDiscountController.text) ?? 0.0;
      if (billDiscount < 0) billDiscount = 0.0;
      if (billDiscount > _subtotal) billDiscount = _subtotal;

      final invoice = Invoice(
        invoiceId: _editingInvoiceId,
        saleDate: widget.invoiceToEdit?.saleDate ?? DateTime.now(),
        items: List.from(_currentItems),
        customerName: _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        customerContact: _customerContactController.text.trim().isEmpty
            ? null
            : _customerContactController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
        totalDiscountOnBill: billDiscount > 0 ? billDiscount : null,
        rightEyeDV: _rightEyeDVController.text.trim().isEmpty
            ? null
            : _rightEyeDVController.text.trim(),
        rightEyeNV: _rightEyeNVController.text.trim().isEmpty
            ? null
            : _rightEyeNVController.text.trim(),
        leftEyeDV: _leftEyeDVController.text.trim().isEmpty
            ? null
            : _leftEyeDVController.text.trim(),
        leftEyeNV: _leftEyeNVController.text.trim().isEmpty
            ? null
            : _leftEyeNVController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (_editingInvoiceId != null) {
        await _updateExistingInvoice(invoice);
      } else {
        await _createNewInvoice(invoice);
      }

      if (mounted) {
        await _showPdfGenerationDialog(invoice);
      }

      _handlePostSaveActions();
    } catch (e) {
      debugPrint('Error saving/updating invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving/updating invoice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updateExistingInvoice(Invoice invoice) async {
    // For editing: stock was already restored in initState, now just decrease for new quantities
    for (var item in _currentItems) {
      await _productService.decreaseStock(item.productId, item.productType, item.quantity);
    }
    await _invoiceService.updateInvoice(invoice);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice updated successfully!')),
      );
    }
  }

  Future<void> _createNewInvoice(Invoice invoice) async {
    // Decrease stock for new invoice items
    for (var item in _currentItems) {
      await _productService.decreaseStock(item.productId, item.productType, item.quantity);
    }
    await _invoiceService.addInvoice(invoice);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved successfully!')),
      );
    }
  }

  void _handlePostSaveActions() {
    if (_editingInvoiceId == null) {
      // Clear form for new invoice
      _clearForm();
    } else {
      // Navigate back for edited invoice
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _clearForm() {
    setState(() {
      _currentItems.clear();
      _customerNameController.clear();
      _customerContactController.clear();
      _billDiscountController.clear();
      _rightEyeDVController.clear();
      _rightEyeNVController.clear();
      _leftEyeDVController.clear();
      _leftEyeNVController.clear();
      _noteController.clear();
      _selectedPaymentMethod = 'Cash';
    });
    _calculateTotals();
  }

  Future<bool> _onWillPop() async {
    if (_editingInvoiceId != null) {
      // If editing, restore the original stock state
      for (var item in widget.invoiceToEdit!.items) {
        await _productService.decreaseStock(item.productId, item.productType, item.quantity);
      }
    }
    return true;
  }

  Future<void> _showPdfGenerationDialog(Invoice invoice) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invoice Saved!'),
          content: const Text('Do you want to generate and share the PDF invoice?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No, Thanks'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Generate PDF'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _generateAndSharePdf(invoice);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateAndSharePdf(Invoice invoice) async {
    try {
      final pdfBytes = await PdfGenerator.generateInvoicePdf(invoice);
      await PdfGenerator.printAndSharePdf(
        pdfBytes,
        'OptiBill_Invoice_${invoice.invoiceId.substring(0, 8)}.pdf'
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generated and ready to share!')),
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  void _confirmDeleteInvoice(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete Invoice'),
          content: Text(
            'Are you sure you want to delete invoice ${invoice.invoiceId.substring(0, 8).toUpperCase()}? This action cannot be undone.'
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
                  // Restore stock for all items in the invoice
                  for (var item in invoice.items) {
                    await _productService.increaseStock(item.productId, item.productType, item.quantity);
                  }
                  await _invoiceService.deleteInvoice(invoice.invoiceId);
                  Navigator.of(context).pop();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invoice deleted successfully!')),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting invoice: $e')),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    debugPrint('BillingScreen building...');

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: _editingInvoiceId != null 
          ? AppBar(
              title: const Text('Edit Invoice'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  final shouldPop = await _onWillPop();
                  if (shouldPop && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 2,
            )
          : null,
        body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Saving invoice...'),
                ],
              ),
            )
          : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _initializeBillingSession();
              },
              child: ListView(
                children: [
                  _CustomerDetailsCard(
                    customerNameController: _customerNameController,
                    customerContactController: _customerContactController,
                    selectedPaymentMethod: _selectedPaymentMethod,
                    paymentMethods: _paymentMethods,
                    onPaymentMethodChanged: (newValue) {
                      setState(() {
                        _selectedPaymentMethod = newValue!;
                      });
                    },
                    rightEyeDVController: _rightEyeDVController,
                    rightEyeNVController: _rightEyeNVController,
                    leftEyeDVController: _leftEyeDVController,
                    leftEyeNVController: _leftEyeNVController,
                    noteController: _noteController,
                  ),
                  _ItemsSectionCard(
                    currentItems: _currentItems,
                    editingInvoiceId: _editingInvoiceId,
                    formatCurrency: _formatCurrency,
                    showProductPicker: _showProductPicker,
                    removeItemFromInvoice: _removeItemFromInvoice,
                    editItemPrice: _editItemPrice,
                    editItemQuantity: _editItemQuantity,
                    editItemDiscount: _editItemDiscount,
                    productService: _productService,
                    parentSetState: setState,
                  ),
                  _BillSummaryCard(
                    subtotal: _subtotal,
                    billDiscountController: _billDiscountController,
                    totalAmount: _totalAmount,
                    totalProfit: _totalProfit,
                    formatCurrency: _formatCurrency,
                  ),
                  if (_editingInvoiceId == null)
                    _RecentInvoicesCard(
                      formatDate: _formatDate,
                      formatCurrency: _formatCurrency,
                      confirmDeleteInvoice: _confirmDeleteInvoice,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveOrUpdateInvoice,
              icon: Icon(_editingInvoiceId != null ? Icons.save : Icons.add),
              label: Text(_editingInvoiceId != null ? 'Update Invoice' : 'Save Invoice'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Optimized Customer Details Card
class _CustomerDetailsCard extends StatelessWidget {
  final TextEditingController customerNameController;
  final TextEditingController customerContactController;
  final String selectedPaymentMethod;
  final List<String> paymentMethods;
  final ValueChanged<String?> onPaymentMethodChanged;
  final TextEditingController rightEyeDVController;
  final TextEditingController rightEyeNVController;
  final TextEditingController leftEyeDVController;
  final TextEditingController leftEyeNVController;
  final TextEditingController noteController;

  const _CustomerDetailsCard({
    required this.customerNameController,
    required this.customerContactController,
    required this.selectedPaymentMethod,
    required this.paymentMethods,
    required this.onPaymentMethodChanged,
    required this.rightEyeDVController,
    required this.rightEyeNVController,
    required this.leftEyeDVController,
    required this.leftEyeNVController,
    required this.noteController,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Customer Details', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: customerNameController,
              labelText: 'Customer Name (Optional)',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: customerContactController,
              labelText: 'Customer Contact (Optional)',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Text(
              'Eye Prescription',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: rightEyeDVController,
                    labelText: 'Right DV',
                    prefixIcon: Icons.remove_red_eye,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: rightEyeNVController,
                    labelText: 'Right NV',
                    prefixIcon: Icons.remove_red_eye_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: leftEyeDVController,
                    labelText: 'Left DV',
                    prefixIcon: Icons.remove_red_eye,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: leftEyeNVController,
                    labelText: 'Left NV',
                    prefixIcon: Icons.remove_red_eye_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: noteController,
              labelText: 'Note (Optional)',
              prefixIcon: Icons.note,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedPaymentMethod,
              decoration: InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: const Icon(Icons.payment),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              ),
              items: paymentMethods.map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: onPaymentMethodChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }
}

// Optimized Items Section Card
class _ItemsSectionCard extends StatelessWidget {
  final List<InvoiceItem> currentItems;
  final String? editingInvoiceId;
  final NumberFormat formatCurrency;
  final VoidCallback showProductPicker;
  final Function(int) removeItemFromInvoice;
  final Function(int, double) editItemPrice;
  final Function(int, int) editItemQuantity;
  final Function(int, double?) editItemDiscount;
  final ProductService productService;
  final void Function(void Function()) parentSetState;

  const _ItemsSectionCard({
    required this.currentItems,
    required this.editingInvoiceId,
    required this.formatCurrency,
    required this.showProductPicker,
    required this.removeItemFromInvoice,
    required this.editItemPrice,
    required this.editItemQuantity,
    required this.editItemDiscount,
    required this.productService,
    required this.parentSetState,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('Items (${currentItems.length})', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: showProductPicker,
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Add Product'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8), // Small gap between buttons
                    ElevatedButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => _QuickAddDialog(
                          onAdd: (lens, quantity) async {
                            await productService.addLens(lens);
                            parentSetState(() {
                              currentItems.add(
                                InvoiceItem(
                                  productId: lens.id,
                                  productName: lens.name,
                                  productType: 'Lens',
                                  unitSellingPrice: lens.sellingPrice,
                                  unitCostPrice: lens.costPrice,
                                  quantity: quantity,
                                  discountAmount: null,
                                ),
                              );
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                      ),
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            currentItems.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No items added yet.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: showProductPicker,
                          icon: const Icon(Icons.add),
                          label: const Text('Add your first product'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentItems.length,
                    itemBuilder: (context, index) {
                      final item = currentItems[index];
                      return _buildItemCard(item, index, context);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(InvoiceItem item, int index, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.productType == 'Frame' ? Colors.blue.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.productType,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.productType == 'Frame' ? Colors.blue.shade800 : Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => removeItemFromInvoice(index),
                  tooltip: 'Remove item',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Unit Price', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Container(
                        height: 36,
                        child: TextFormField(
                          initialValue: item.unitSellingPrice.toStringAsFixed(2),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            double? newPrice = double.tryParse(value);
                            if (newPrice != null && newPrice >= 0) {
                              editItemPrice(index, newPrice);
                            }
                          },
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quantity', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                if (item.quantity > 1) {
                                  editItemQuantity(index, item.quantity - 1);
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 36,
                                child: const Icon(Icons.remove, size: 16),
                              ),
                            ),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('${item.productId}_${item.quantity}'),
                                initialValue: item.quantity.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  int? newQty = int.tryParse(value);
                                  if (newQty != null && newQty > 0) {
                                    editItemQuantity(index, newQty);
                                  }
                                },
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => editItemQuantity(index, item.quantity + 1),
                              child: Container(
                                width: 32,
                                height: 36,
                                child: const Icon(Icons.add, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        formatCurrency.format(item.totalSellingPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Optimized Bill Summary Card
class _BillSummaryCard extends StatelessWidget {
  final double subtotal;
  final TextEditingController billDiscountController;
  final double totalAmount;
  final double totalProfit;
  final NumberFormat formatCurrency;

  const _BillSummaryCard({
    required this.subtotal,
    required this.billDiscountController,
    required this.totalAmount,
    required this.totalProfit,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Bill Summary', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal:', formatCurrency.format(subtotal), false),
                  const SizedBox(height: 8),
                  TextField(
                    controller: billDiscountController,
                    decoration: InputDecoration(
                      labelText: 'Bill Discount',
                      hintText: 'Max: ${formatCurrency.format(subtotal)}',
                      prefixIcon: const Icon(Icons.discount),
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Total Amount:',
                    formatCurrency.format(totalAmount),
                    true,
                    valueColor: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Estimated Profit:',
                    formatCurrency.format(totalProfit),
                    false,
                    valueColor: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isTotal, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 18 : 16,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 20 : 16,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}

// Optimized Recent Invoices Card
class _RecentInvoicesCard extends StatelessWidget {
  final DateFormat formatDate;
  final NumberFormat formatCurrency;
  final Function(BuildContext, Invoice) confirmDeleteInvoice;

  const _RecentInvoicesCard({
    required this.formatDate,
    required this.formatCurrency,
    required this.confirmDeleteInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.purple),
                const SizedBox(width: 8),
                Text('Recent Invoices', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: Hive.box<Invoice>('invoices').watch(),
              builder: (context, snapshot) {
                final box = Hive.box<Invoice>('invoices');
                
                if (box.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No invoices saved yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final recentInvoices = box.values.toList()
                  ..sort((a, b) => b.saleDate.compareTo(a.saleDate));
                final displayInvoices = recentInvoices.take(5).toList();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = displayInvoices[index];
                    return _buildInvoiceCard(invoice, context);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            invoice.invoiceId.substring(0, 2).toUpperCase(),
            style: TextStyle(
              color: Colors.blue.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          'Invoice #${invoice.invoiceId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDate.format(invoice.saleDate)),
            Text(
              formatCurrency.format(invoice.totalAmount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BillingScreen(invoiceToEdit: invoice),
                  ),
                );
              },
              tooltip: 'Edit invoice',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => confirmDeleteInvoice(context, invoice),
              tooltip: 'Delete invoice',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

// Optimized Product Picker
class ProductPicker extends StatefulWidget {
  final ProductService productService;

  const ProductPicker({super.key, required this.productService});

  @override
  State<ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<ProductPicker> with AutomaticKeepAliveClientMixin {
  String _selectedCategory = 'All';
  String _selectedSubCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredProducts = [];
  List<dynamic> _allProducts = [];
  Timer? _searchDebounce;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _initializeData() {
    if (!_isInitialized) {
      _allProducts = widget.productService.getAllProducts();
      _filterProducts();
      _isInitialized = true;
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _filterProducts();
      }
    });
  }

  void _filterProducts() {
    List<dynamic> tempProducts = _allProducts;

    // Filter by category
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

    setState(() {
      _filteredProducts = tempProducts;
    });
  }

  List<String> _getAvailableSubCategories() {
    Set<String> subCategories = {'All'};

    if (_selectedCategory == 'Frame') {
      for (var product in _allProducts.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
    } else if (_selectedCategory == 'Lens') {
      for (var product in _allProducts.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    } else {
      for (var product in _allProducts.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
      for (var product in _allProducts.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    }
    return subCategories.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Product',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
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
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        items: const <String>['All', 'Frame', 'Lens'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                            _selectedSubCategory = 'All';
                          });
                          _filterProducts();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubCategory,
                        decoration: InputDecoration(
                          labelText: 'Sub-Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
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
                          });
                          _filterProducts();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No products found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final String name = product is Frame ? product.modelName : product.name;
    final String type = product is Frame ? 'Frame' : 'Lens';
    final String brandCompany = product is Frame ? product.brand : product.company;
    final double stock = product.stock;
    final double sellingPrice = product.sellingPrice;

    // Stock color coding
    Color stockColor = Colors.green;
    if (stock <= 5) stockColor = Colors.red;
    else if (stock <= 10) stockColor = Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: () => Navigator.pop(context, product),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: stockColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory, size: 14, color: stockColor),
                              const SizedBox(width: 4),
                              Text(
                                'Stock: ${stock.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: stockColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(sellingPrice),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
                  onPressed: () => Navigator.pop(context, product),
                  tooltip: 'Add to invoice',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick Add Dialog
class _QuickAddDialog extends StatefulWidget {
  final Function(Lens lens, int quantity) onAdd;

  const _QuickAddDialog({required this.onAdd});

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String _selectedType = 'Lens'; // Default value
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Add Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name*',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price*',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _sellingPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price*',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity*',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
           TextField(
            style: const TextStyle(color: Colors.black),
            enabled: false, // Makes it read-only
            decoration: const InputDecoration(
            labelText: 'Type',
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: 'Lens'),
         ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final costPrice = double.tryParse(_costPriceController.text) ?? 0;
            final sellingPrice = double.tryParse(_sellingPriceController.text) ?? 0;
            final quantity = int.tryParse(_quantityController.text) ?? 0;
            final company = _companyController.text.trim();
            final description = _descriptionController.text.trim();

            if (name.isEmpty || costPrice <= 0 || sellingPrice <= 0 || quantity <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields correctly')),
              );
              return;
            }

            final lens = Lens(
              name: name,
              costPrice: costPrice,
              sellingPrice: sellingPrice,
              company: company,
              stock: quantity.toDouble(),
              description: description.isEmpty ? null : description,
            );
            widget.onAdd(lens, quantity);
          },
          child: const Text('Add'),
        ),
      ],
    );
 }
}
