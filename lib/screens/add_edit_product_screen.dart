import 'package:flutter/material.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/product_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final dynamic product; // Can be Frame or Lens

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  String _productType = 'Frame'; // Default to Frame
  TextEditingController _nameModelController = TextEditingController();
  TextEditingController _sellingPriceController = TextEditingController();
  TextEditingController _costPriceController = TextEditingController();
  TextEditingController _brandCompanyController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _stockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      // Editing existing product
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

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        if (_productType == 'Frame') {
          final frame = Frame(
            id: widget.product is Frame ? widget.product.id : null,
            modelName: _nameModelController.text,
            sellingPrice: double.parse(_sellingPriceController.text),
            costPrice: double.parse(_costPriceController.text),
            brand: _brandCompanyController.text,
            stock: double.parse(_stockController.text),
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          );
          if (widget.product is Frame) {
            await _productService.updateFrame(frame);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Frame updated successfully!')),
            );
          } else {
            await _productService.addFrame(frame);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Frame added successfully!')),
            );
          }
        } else {
          final lens = Lens(
            id: widget.product is Lens ? widget.product.id : null,
            name: _nameModelController.text,
            sellingPrice: double.parse(_sellingPriceController.text),
            costPrice: double.parse(_costPriceController.text),
            company: _brandCompanyController.text,
            stock: double.parse(_stockController.text),
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          );
          if (widget.product is Lens) {
            await _productService.updateLens(lens);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lens updated successfully!')),
            );
          } else {
            await _productService.addLens(lens);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lens added successfully!')),
            );
          }
        }
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.product == null ? 'Add New Product' : 'Edit Product'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _productType,
                    decoration: InputDecoration(
                      labelText: 'Product Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    items: <String>['Frame', 'Lens'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: widget.product == null // Only allow changing type when adding new
                        ? (String? newValue) {
                      setState(() {
                        _productType = newValue!;
                      });
                    }
                        : null, // Disable if editing
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameModelController,
                    decoration: InputDecoration(
                      labelText: _productType == 'Frame' ? 'Model Name' : 'Lens Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name/model';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _sellingPriceController,
                    decoration: InputDecoration(
                      labelText: 'Selling Price',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter selling price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _costPriceController,
                    decoration: InputDecoration(
                      labelText: 'Cost Price',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter cost price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _brandCompanyController,
                    decoration: InputDecoration(
                      labelText: _productType == 'Frame' ? 'Brand' : 'Company',
                      hintText: _productType == 'Frame' ? 'e.g., Ray-Ban, Titan' : 'e.g., Essilor, Zeiss',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter brand/company';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Code (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField( // New Stock Count field
                    controller: _stockController,
                    decoration: InputDecoration(
                      labelText: 'Stock Count',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter stock count';
                      }
                      if (int.tryParse(value) == null || int.parse(value) < 0) {
                        return 'Please enter a valid non-negative integer';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _saveProduct,
                    icon: Icon(widget.product == null ? Icons.add : Icons.save),
                    label: Text(widget.product == null ? 'Add Product' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            ),
        );
    }
}
