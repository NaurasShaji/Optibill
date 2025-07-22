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

class _BillingScreenState extends State<BillingScreen> {
  final ProductService _productService = ProductService();
  final InvoiceService _invoiceService = InvoiceService();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerContactController = TextEditingController();
  final TextEditingController _billDiscountController = TextEditingController();
  // Add new controllers for eye prescription fields
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

  final List<String> _paymentMethods = ['Cash', 'Card', 'UPI', 'Bank Transfer', 'Other'];

  @override
  void initState() {
    super.initState();
    _billDiscountController.addListener(_calculateTotals);
    _initializeBillingSession();
  }

  void _initializeBillingSession() {
    if (widget.invoiceToEdit != null) {
      _editingInvoiceId = widget.invoiceToEdit!.invoiceId;
      _customerNameController.text = widget.invoiceToEdit!.customerName ?? '';
      _customerContactController.text = widget.invoiceToEdit!.customerContact ?? '';
      _selectedPaymentMethod = widget.invoiceToEdit!.paymentMethod;
      _billDiscountController.text = (widget.invoiceToEdit!.totalDiscountOnBill ?? 0.0).toStringAsFixed(2);
      _currentItems = List.from(widget.invoiceToEdit!.items);
      // Initialize new eye prescription fields
      _rightEyeDVController.text = widget.invoiceToEdit!.rightEyeDV ?? '';
      _rightEyeNVController.text = widget.invoiceToEdit!.rightEyeNV ?? '';
      _leftEyeDVController.text = widget.invoiceToEdit!.leftEyeDV ?? '';
      _leftEyeNVController.text = widget.invoiceToEdit!.leftEyeNV ?? '';
      _noteController.text = widget.invoiceToEdit!.note ?? '';
    }
    _calculateTotals();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerContactController.dispose();
    _billDiscountController.dispose();
    // Dispose new controllers
    _rightEyeDVController.dispose();
    _rightEyeNVController.dispose();
    _leftEyeDVController.dispose();
    _leftEyeNVController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    double currentSubtotal = 0.0;
    double currentTotalProfit = 0.0;

    for (var item in _currentItems) {
      currentSubtotal += (item.unitSellingPrice * item.quantity);
      // If you have per-item discounts, cap them here
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

    setState(() {
      _subtotal = currentSubtotal;
      _totalDiscountOnBill = billDiscount;
      _totalAmount = finalTotalAmount;
      _totalProfit = finalTotalProfit;
    });
  }

  void _addItemToInvoice(dynamic product, int quantity) {
    int existingIndex = _currentItems.indexWhere((item) => item.productId == (product is Frame ? product.id : product.id));

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
    setState(() {
      _currentItems.removeAt(index);
    });
    _calculateTotals();
  }

  void _editItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItemFromInvoice(index);
    } else {
      setState(() {
        _currentItems[index].quantity = newQuantity;
      });
    }
    _calculateTotals();
  }

  void _editItemPrice(int index, double newPrice) {
    setState(() {
      _currentItems[index].unitSellingPrice = newPrice;
    });
    _calculateTotals();
  }

  void _editItemDiscount(int index, double? discount) {
    setState(() {
      _currentItems[index].discountAmount = discount;
    });
    _calculateTotals();
  }

  Future<void> _showProductPicker() async {
    final selectedProduct = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ProductPicker(productService: _productService);
      },
    );

    if (selectedProduct != null) {
      _addItemToInvoice(selectedProduct, 1);
    }
  }

  Future<void> _saveOrUpdateInvoice() async {
    // Defensive: ensure _currentItems is not empty
    if (_currentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to the invoice.')),
      );
      return;
    }

    // Check stock availability before proceeding
    for (var item in _currentItems) {
      final product = _productService.getProductById(item.productId, item.productType);
      if (product == null || product.stock < item.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insufficient stock for ${item.productName}. Available: ${product?.stock ?? 0}')),
        );
        return;
      }
    }

    // Defensive: treat empty discount as 0.0
    double billDiscount = double.tryParse(_billDiscountController.text) ?? 0.0;
    if (billDiscount < 0) billDiscount = 0.0;
    if (billDiscount > _subtotal) billDiscount = _subtotal;

    final invoice = Invoice(
      invoiceId: _editingInvoiceId,
      saleDate: widget.invoiceToEdit?.saleDate ?? DateTime.now(),
      items: List.from(_currentItems), // Defensive copy
      customerName: _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim(),
      customerContact: _customerContactController.text.trim().isEmpty
          ? null
          : _customerContactController.text.trim(),
      paymentMethod: _selectedPaymentMethod,
      totalDiscountOnBill: billDiscount > 0 ? billDiscount : null,
      // Add new fields
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

    try {
      if (_editingInvoiceId != null) {
        // Restore stock for old invoice items
        for (var oldItem in widget.invoiceToEdit!.items) {
          await _productService.increaseStock(oldItem.productId, oldItem.productType, oldItem.quantity);
        }
        // Check again for new stock after restoration
        for (var item in _currentItems) {
          final product = _productService.getProductById(item.productId, item.productType);
          if (product == null || product.stock < item.quantity) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Insufficient stock for ${item.productName}. Available: ${product?.stock ?? 0}')),
            );
            // Re-decrease stock for old items to keep state consistent
            for (var oldItem in widget.invoiceToEdit!.items) {
              await _productService.decreaseStock(oldItem.productId, oldItem.productType, oldItem.quantity);
            }
            return;
          }
        }
        // Decrease stock for new invoice items
        for (var item in _currentItems) {
          await _productService.decreaseStock(item.productId, item.productType, item.quantity);
        }
        await _invoiceService.updateInvoice(invoice);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice updated successfully!')),
        );
      } else {
        // Decrease stock for new invoice items
        for (var item in _currentItems) {
          await _productService.decreaseStock(item.productId, item.productType, item.quantity);
        }
        await _invoiceService.addInvoice(invoice);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully!')),
        );
      }

      if (mounted) {
        await _showPdfGenerationDialog(invoice);
      }

      // Only clear after successful save and only for new invoice
      if (_editingInvoiceId == null) {
        setState(() {
          _currentItems.clear();
          _customerNameController.clear();
          _customerContactController.clear();
          _billDiscountController.clear();
          _selectedPaymentMethod = 'Cash';
        });
        _calculateTotals();
      } else {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('Error saving/updating invoice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving/updating invoice: $e')),
      );
    }
  }

  Future<void> _showPdfGenerationDialog(Invoice invoice) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invoice Saved!'),
          content: const Text('Do you want to generate and share the PDF invoice?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No, Thanks'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Generate PDF'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final pdfBytes = await PdfGenerator.generateInvoicePdf(invoice);
                  await PdfGenerator.printAndSharePdf(pdfBytes, 'OptiBill_Invoice_${invoice.invoiceId.substring(0, 8)}.pdf');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF generated and ready to share!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error generating PDF: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteInvoice(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete Invoice'),
          content: Text('Are you sure you want to delete invoice ${invoice.invoiceId.substring(0, 8).toUpperCase()}? This action cannot be undone.'),
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
                // Restore stock for all items in the invoice
                for (var item in invoice.items) {
                  await _productService.increaseStock(item.productId, item.productType, item.quantity);
                }
                await _invoiceService.deleteInvoice(invoice.invoiceId);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice deleted successfully!')),
                );
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
    final formatDate = DateFormat('dd-MM-yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingInvoiceId != null ? 'Edit Invoice' : 'New Invoice'),
        centerTitle: true,
        leading: _editingInvoiceId != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
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
                    // Pass new controllers
                    rightEyeDVController: _rightEyeDVController,
                    rightEyeNVController: _rightEyeNVController,
                    leftEyeDVController: _leftEyeDVController,
                    leftEyeNVController: _leftEyeNVController,
                    noteController: _noteController,
                  ),
                  _ItemsSectionCard(
                    currentItems: _currentItems,
                    editingInvoiceId: _editingInvoiceId,
                    formatCurrency: formatCurrency,
                    showProductPicker: _showProductPicker,
                    removeItemFromInvoice: _removeItemFromInvoice,
                    editItemPrice: _editItemPrice,
                    editItemQuantity: _editItemQuantity,
                    editItemDiscount: _editItemDiscount,
                  ),
                  _BillSummaryCard(
                    subtotal: _subtotal,
                    billDiscountController: _billDiscountController,
                    totalAmount: _totalAmount,
                    totalProfit: _totalProfit,
                    formatCurrency: formatCurrency,
                  ),
                  if (_editingInvoiceId == null)
                    _RecentInvoicesCard(
                      formatDate: formatDate,
                      formatCurrency: formatCurrency,
                      confirmDeleteInvoice: _confirmDeleteInvoice,
                    ),
                ],
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveOrUpdateInvoice,
              icon: Icon(_editingInvoiceId != null ? Icons.save : Icons.add),
              label: Text(_editingInvoiceId != null ? 'Update Invoice' : 'Save Invoice'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extracted Widgets for better readability and compactness

class _CustomerDetailsCard extends StatelessWidget {
  final TextEditingController customerNameController;
  final TextEditingController customerContactController;
  final String selectedPaymentMethod;
  final List<String> paymentMethods;
  final ValueChanged<String?> onPaymentMethodChanged;
  // Add new controllers
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
            Text('Customer Details', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 10),
            TextField(
              controller: customerNameController,
              decoration: InputDecoration(
                labelText: 'Customer Name (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: customerContactController,
              decoration: InputDecoration(
                labelText: 'Customer Contact (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 10),
            // New fields for eye prescription
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: rightEyeDVController,
                    decoration: InputDecoration(
                      labelText: 'Right Eye DV',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: rightEyeNVController,
                    decoration: InputDecoration(
                      labelText: 'Right Eye NV',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: leftEyeDVController,
                    decoration: InputDecoration(
                      labelText: 'Left Eye DV',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: leftEyeNVController,
                    decoration: InputDecoration(
                      labelText: 'Left Eye NV',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'note(Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedPaymentMethod,
              decoration: InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
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
}

class _ItemsSectionCard extends StatelessWidget {
  final List<InvoiceItem> currentItems;
  final String? editingInvoiceId;
  final NumberFormat formatCurrency;
  final VoidCallback showProductPicker;
  final Function(int) removeItemFromInvoice;
  final Function(int, double) editItemPrice;
  final Function(int, int) editItemQuantity;
  final Function(int, double?) editItemDiscount;

  const _ItemsSectionCard({
    required this.currentItems,
    required this.editingInvoiceId,
    required this.formatCurrency,
    required this.showProductPicker,
    required this.removeItemFromInvoice,
    required this.editItemPrice,
    required this.editItemQuantity,
    required this.editItemDiscount,
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
                Text('Items', style: Theme.of(context).textTheme.titleLarge),
                if (editingInvoiceId == null)
                  ElevatedButton.icon(
                    onPressed: showProductPicker,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10),
            currentItems.isEmpty
                ? const Center(child: Text('No items added yet.'))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentItems.length,
              itemBuilder: (context, index) {
                final item = currentItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.productName} (${item.productType})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (editingInvoiceId == null)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removeItemFromInvoice(index),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Text('Unit Price: '),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: item.unitSellingPrice.toStringAsFixed(2),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  double? newPrice = double.tryParse(value);
                                  if (newPrice != null) {
                                    editItemPrice(index, newPrice);
                                  }
                                },
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: UnderlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (editingInvoiceId == null)
                          Row(
                            children: [
                              const Text('Qty: '),
                              SizedBox(
                                width: 50,
                                child: TextFormField(
                                  initialValue: item.quantity.toString(),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    int? newQty = int.tryParse(value);
                                    if (newQty != null) {
                                      editItemQuantity(index, newQty);
                                    }
                                  },
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: UnderlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Item Total: ${formatCurrency.format(item.totalSellingPrice)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
            Text('Bill Summary', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text(formatCurrency.format(subtotal)),
              ],
            ),
            SizedBox(height: 10),
            TextField(
              controller: billDiscountController,
              decoration: InputDecoration(
                labelText: 'Total Bill Discount (₹)',
                hintText: 'Max: ${formatCurrency.format(subtotal)}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Text(
                  formatCurrency.format(totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Profit:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  formatCurrency.format(totalProfit),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
            Text('Recent Invoices', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 10),
            ValueListenableBuilder(
              valueListenable: Hive.box<Invoice>('invoices').listenable(),
              builder: (context, Box<Invoice> box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text('No invoices saved yet.'));
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
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      child: ListTile(
                        title: Text('Invoice ID: ${invoice.invoiceId.substring(0, 8).toUpperCase()}'),
                        subtitle: Text(
                          '${formatDate.format(invoice.saleDate)} - ${formatCurrency.format(invoice.totalAmount)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BillingScreen(invoiceToEdit: invoice),
                                  ),
                                ).then((value) {
                                  // This callback runs when the BillingScreen is popped
                                  // ValueListenableBuilder will automatically update.
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => confirmDeleteInvoice(context, invoice),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Product Picker Modal Bottom Sheet (remains unchanged)
class ProductPicker extends StatefulWidget {
  final ProductService productService;

  const ProductPicker({super.key, required this.productService});

  @override
  State<ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<ProductPicker> {
  String _selectedCategory = 'All';
  String _selectedSubCategory = 'All';
  TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _filterProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterProducts() {
    setState(() {
      List<dynamic> allProducts = widget.productService.getAllProducts();
      List<dynamic> tempProducts = [];

      if (_selectedCategory == 'Frame') {
        tempProducts = allProducts.whereType<Frame>().toList();
      } else if (_selectedCategory == 'Lens') {
        tempProducts = allProducts.whereType<Lens>().toList();
      } else {
        tempProducts = allProducts;
      }

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
    List<dynamic> products = widget.productService.getAllProducts();

    if (_selectedCategory == 'Frame') {
      for (var product in products.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
    } else if (_selectedCategory == 'Lens') {
      for (var product in products.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    } else {
      for (var product in products.whereType<Frame>()) {
        subCategories.add(product.brand);
      }
      for (var product in products.whereType<Lens>()) {
        subCategories.add(product.company);
      }
    }
    return subCategories.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Product', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16),
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
                      _selectedSubCategory = 'All';
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
                    if (_filteredProducts.isEmpty) {
                      return const Center(child: Text('No products found.'));
                    }
                    return ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            title: Text(
                              product is Frame ? product.modelName : product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  'Type:  ${product is Frame ? 'Frame' : 'Lens'}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                Text(
                                  'Brand/Company:  ${product is Frame ? product.brand : product.company}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                Text(
                                  'Stock:  ${product.stock}',
                                  style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Selling Price:  ${formatCurrency.format(product.sellingPrice)}',
                                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                              onPressed: () {
                                Navigator.pop(context, product);
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
