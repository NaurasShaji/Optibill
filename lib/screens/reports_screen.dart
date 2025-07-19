import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/invoice.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/invoice_service.dart';
import 'package:optibill/services/product_service.dart';
import 'package:optibill/screens/billing_screen.dart'; // Import BillingScreen for navigation

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final ProductService _productService = ProductService();

  // For Daily Report
  DateTime _selectedDate = DateTime.now();
  List<Invoice> _dailyInvoices = [];

  // For Monthly Report
  int _selectedMonth = DateTime.now().month;
  int _selectedYearForMonth = DateTime.now().year;
  List<Invoice> _monthlyInvoices = [];

  // For Yearly Report
  int _selectedYear = DateTime.now().year;
  List<Invoice> _yearlyInvoices = [];

  @override
  void initState() {
    super.initState();
    _loadDailyReport();
    _loadMonthlyReport();
    _loadYearlyReport();
  }

  void _loadDailyReport() {
    setState(() {
      _dailyInvoices = _invoiceService.getDailyInvoices(_selectedDate);
    });
  }

  void _loadMonthlyReport() {
    setState(() {
      _monthlyInvoices = _invoiceService.getMonthlyInvoices(_selectedMonth, _selectedYearForMonth);
    });
  }

  void _loadYearlyReport() {
    setState(() {
      _yearlyInvoices = _invoiceService.getYearlyInvoices(_selectedYear);
    });
  }

  double _calculateTotalRevenue(List<Invoice> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + invoice.totalAmount);
  }

  double _calculateTotalProfit(List<Invoice> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + invoice.totalProfit);
  }

  Map<String, double> _getCategoryBreakdown(List<Invoice> invoices) {
    Map<String, double> breakdown = {'Frames': 0.0, 'Lenses': 0.0};
    for (var invoice in invoices) {
      for (var item in invoice.items) {
        if (item.productType == 'Frame') {
          breakdown['Frames'] = (breakdown['Frames'] ?? 0) + item.totalSellingPrice;
        } else if (item.productType == 'Lens') {
          breakdown['Lenses'] = (breakdown['Lenses'] ?? 0) + item.totalSellingPrice;
        }
      }
    }
    return breakdown;
  }

  Map<String, double> _getSubCategoryBreakdown(List<Invoice> invoices, String categoryType) {
    Map<String, double> breakdown = {};
    for (var invoice in invoices) {
      for (var item in invoice.items) {
        if (categoryType == 'Frame' && item.productType == 'Frame') {
          final frame = _productService.getFrameById(item.productId);
          if (frame != null) {
            breakdown[frame.brand] = (breakdown[frame.brand] ?? 0) + item.totalSellingPrice;
          }
        } else if (categoryType == 'Lens' && item.productType == 'Lens') {
          final lens = _productService.getLensById(item.productId);
          if (lens != null) {
            breakdown[lens.company] = (breakdown[lens.company] ?? 0) + item.totalSellingPrice;
          }
        }
      }
    }
    return breakdown;
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
                await _invoiceService.deleteInvoice(invoice.invoiceId);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice deleted successfully!')),
                );
                // Reload reports after deletion to reflect changes
                _loadDailyReport();
                _loadMonthlyReport();
                _loadYearlyReport();
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
    final formatDate = DateFormat('dd-MM-yyyy');
    final formatTime = DateFormat('HH:mm');
    final formatMonthYear = DateFormat('MMMM yyyy');

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Daily'),
              Tab(text: 'Monthly'),
              Tab(text: 'Yearly'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Daily Report Tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Report for ${formatDate.format(_selectedDate)}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null && picked != _selectedDate) {
                                setState(() {
                                  _selectedDate = picked;
                                  _loadDailyReport();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Revenue:', style: TextStyle(fontSize: 18)),
                                  Text(
                                    formatCurrency.format(_calculateTotalRevenue(_dailyInvoices)),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Profit:', style: TextStyle(fontSize: 18)),
                                  Text(
                                    formatCurrency.format(_calculateTotalProfit(_dailyInvoices)),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Invoices for the day:', style: Theme.of(context).textTheme.titleMedium),
                      Expanded(
                        child: _dailyInvoices.isEmpty
                            ? const Center(child: Text('No invoices for this day.'))
                            : SingleChildScrollView(
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
                                        DataColumn(label: Text('Invoice ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Profit', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: _dailyInvoices.map((invoice) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(invoice.invoiceId.substring(0, 8).toUpperCase())),
                                            DataCell(Text(invoice.customerName ?? 'N/A')),
                                            DataCell(Text(formatTime.format(invoice.saleDate))),
                                            DataCell(Text(formatCurrency.format(invoice.totalAmount))),
                                            DataCell(Text(formatCurrency.format(invoice.totalProfit))),
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
                                                          builder: (context) => BillingScreen(invoiceToEdit: invoice),
                                                        ),
                                                      ).then((_) {
                                                        _loadDailyReport();
                                                        _loadMonthlyReport();
                                                        _loadYearlyReport();
                                                      });
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                    onPressed: () => _confirmDeleteInvoice(context, invoice),
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
                    ],
                  ),
                ),

                // Monthly Report Tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Report for ${formatMonthYear.format(DateTime(_selectedYearForMonth, _selectedMonth))}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: () async {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  int tempMonth = _selectedMonth;
                                  int tempYear = _selectedYearForMonth;
                                  return AlertDialog(
                                    title: const Text('Select Month and Year'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DropdownButton<int>(
                                          value: tempMonth,
                                          items: List.generate(12, (index) => index + 1).map((month) {
                                            return DropdownMenuItem(
                                              value: month,
                                              child: Text(DateFormat.MMMM().format(DateTime(0, month))),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            if (value != null) tempMonth = value;
                                          },
                                        ),
                                        DropdownButton<int>(
                                          value: tempYear,
                                          items: List.generate(10, (index) => DateTime.now().year - 5 + index).map((year) {
                                            return DropdownMenuItem(
                                              value: year,
                                              child: Text(year.toString()),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            if (value != null) tempYear = value;
                                          },
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedMonth = tempMonth;
                                            _selectedYearForMonth = tempYear;
                                            _loadMonthlyReport();
                                          });
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Select'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Revenue:', style: TextStyle(fontSize: 18)),
                                  Text(
                                    formatCurrency.format(_calculateTotalRevenue(_monthlyInvoices)),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Profit:', style: TextStyle(fontSize: 18)),
                                  Text(
                                    formatCurrency.format(_calculateTotalProfit(_monthlyInvoices)),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Breakdown by Category (Revenue):', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 20,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                          columns: const [
                            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _getCategoryBreakdown(_monthlyInvoices).entries.map((entry) {
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key)),
                                DataCell(Text(formatCurrency.format(entry.value))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('Breakdown by Frame Brand (Revenue):', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 20,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                          columns: const [
                            DataColumn(label: Text('Brand', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _getSubCategoryBreakdown(_monthlyInvoices, 'Frame').entries.map((entry) {
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key)),
                                DataCell(Text(formatCurrency.format(entry.value))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('Breakdown by Lens Company (Revenue):', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 20,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                          columns: const [
                            DataColumn(label: Text('Company', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _getSubCategoryBreakdown(_monthlyInvoices, 'Lens').entries.map((entry) {
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key)),
                                DataCell(Text(formatCurrency.format(entry.value))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Yearly Report Tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Yearly Report for $_selectedYear',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Select Year"),
                                    content: SizedBox(
                                      width: 300,
                                      height: 300,
                                      child: YearPicker(
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now(),
                                        selectedDate: DateTime(_selectedYear),
                                        onChanged: (DateTime dateTime) {
                                          setState(() {
                                            _selectedYear = dateTime.year;
                                            _loadYearlyReport();
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Revenue:', style: TextStyle(fontSize: 18)),
                                  Text(
                                    formatCurrency.format(_calculateTotalRevenue(_yearlyInvoices)),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Profit:', style: TextStyle(fontSize: 18)),
                                  Text(
                                    formatCurrency.format(_calculateTotalProfit(_yearlyInvoices)),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Breakdown by Category (Revenue):', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 20,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                          columns: const [
                            DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _getCategoryBreakdown(_yearlyInvoices).entries.map((entry) {
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key)),
                                DataCell(Text(formatCurrency.format(entry.value))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('Breakdown by Frame Brand (Revenue):', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 20,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                          columns: const [
                            DataColumn(label: Text('Brand', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _getSubCategoryBreakdown(_yearlyInvoices, 'Frame').entries.map((entry) {
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key)),
                                DataCell(Text(formatCurrency.format(entry.value))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('Breakdown by Lens Company (Revenue):', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 20,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 60,
                          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                          columns: const [
                            DataColumn(label: Text('Company', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Revenue', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _getSubCategoryBreakdown(_yearlyInvoices, 'Lens').entries.map((entry) {
                            return DataRow(
                              cells: [
                                DataCell(Text(entry.key)),
                                DataCell(Text(formatCurrency.format(entry.value))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
