import 'package:flutter/material.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/product_service.dart';

class ViewProductScreen extends StatefulWidget {
  final dynamic product; // Can be Frame or Lens

  const ViewProductScreen({super.key, required this.product});

  @override
  State<ViewProductScreen> createState() => _ViewProductScreenState();
}

class _ViewProductScreenState extends State<ViewProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  String _productType = 'Frame';
  TextEditingController _nameModelController = TextEditingController();
  TextEditingController _sellingPriceController = TextEditingController();
  TextEditingController _costPriceController = TextEditingController();
  TextEditingController _brandCompanyController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _stockController = TextEditingController();

  bool _isEditing = false; // Track edit mode

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  void _loadProductData() {
    if (widget.product is Frame) {
      _productType = 'Frame';
      _nameModelController.text = widget.product.modelName;
      _sellingPriceController.text = widget.product.sellingPrice.toString();
      _costPriceController.text = widget.product.costPrice.toString();
      _brandCompanyController.text = widget.product.brand;
      _stockController.text = widget.product.stock.toInt().toString();
      _descriptionController.text = widget.product.description ?? '';
    } else if (widget.product is Lens) {
      _productType = 'Lens';
      _nameModelController.text = widget.product.name;
      _sellingPriceController.text = widget.product.sellingPrice.toString();
      _costPriceController.text = widget.product.costPrice.toString();
      _brandCompanyController.text = widget.product.company;
      _stockController.text = widget.product.stock.toInt().toString();
      _descriptionController.text = widget.product.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameModelController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    _brandCompanyController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        if (_productType == 'Frame') {
          final frame = Frame(
            id: widget.product.id,
            modelName: _nameModelController.text,
            sellingPrice: double.parse(_sellingPriceController.text),
            costPrice: double.parse(_costPriceController.text),
            brand: _brandCompanyController.text,
            stock: double.parse(_stockController.text),
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          );
          await _productService.updateFrame(frame);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Frame updated successfully!')),
          );
        } else {
          final lens = Lens(
            id: widget.product.id,
            name: _nameModelController.text,
            sellingPrice: double.parse(_sellingPriceController.text),
            costPrice: double.parse(_costPriceController.text),
            company: _brandCompanyController.text,
            stock: double.parse(_stockController.text),
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          );
          await _productService.updateLens(lens);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lens updated successfully!')),
          );
        }
        setState(() {
          _isEditing = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e')),
        );
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
    // Reload original data
    _loadProductData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Product'),
        centerTitle: true,
        actions: [
          if (_isEditing) ...[
            IconButton(
              onPressed: _cancelEdit,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              color: Colors.red,
            ),
            IconButton(
              onPressed: _saveProduct,
              icon: const Icon(Icons.save),
              color: Colors.blue,
              tooltip: 'Save',
            ),
          ] else
            IconButton(
              onPressed: _toggleEditMode,
              icon: const Icon(Icons.edit),
              color: Colors.blue,
              tooltip: 'Edit',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Type (always read-only)
              TextFormField(
                initialValue: _productType,
                decoration: InputDecoration(
                  labelText: 'Product Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                readOnly: true,
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameModelController,
                decoration: InputDecoration(
                  labelText: _productType == 'Frame' ? 'Model Name' : 'Lens Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                readOnly: !_isEditing,
                style: TextStyle(
                  color: _isEditing ? null : Colors.black,
                ),
                validator: _isEditing ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name/model';
                  }
                  return null;
                } : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sellingPriceController,
                decoration: InputDecoration(
                  labelText: 'Selling Price',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                keyboardType: _isEditing ? TextInputType.number : null,
                readOnly: !_isEditing,
                style: TextStyle(
                  color: _isEditing ? null : Colors.black,
                ),
                validator: _isEditing ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter selling price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                } : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costPriceController,
                decoration: InputDecoration(
                  labelText: 'Cost Price',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                keyboardType: _isEditing ? TextInputType.number : null,
                readOnly: !_isEditing,
                style: TextStyle(
                  color: _isEditing ? null : Colors.black,
                ),
                validator: _isEditing ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter cost price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                } : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandCompanyController,
                decoration: InputDecoration(
                  labelText: _productType == 'Frame' ? 'Brand' : 'Company',
                  hintText: _isEditing
                      ? (_productType == 'Frame' ? 'e.g., Ray-Ban, Titan' : 'e.g., Essilor, Zeiss')
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                readOnly: !_isEditing,
                style: TextStyle(
                  color: _isEditing ? null : Colors.black,
                ),
                validator: _isEditing ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter brand/company';
                  }
                  return null;
                } : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Code (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                maxLines: 2,
                readOnly: !_isEditing,
                style: TextStyle(
                  color: _isEditing ? null : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Stock Count',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                keyboardType: _isEditing ? TextInputType.number : null,
                readOnly: !_isEditing,
                style: TextStyle(
                  color: _isEditing ? null : Colors.black,
                ),
                validator: _isEditing ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter stock count';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'Please enter a valid non-negative integer';
                  }
                  return null;
                } : null,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cancelEdit,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveProduct,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}