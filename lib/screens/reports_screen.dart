import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/invoice.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/invoice_service.dart';
import 'package:optibill/services/product_service.dart';
import 'package:optibill/screens/billing_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  // Services
  late final InvoiceService _invoiceService;
  late final ProductService _productService;
  
  // Tab Controller
  late final TabController _tabController;
  
  // Date selections
  DateTime _selectedDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYearForMonth = DateTime.now().year;
  int _selectedYear = DateTime.now().year;
  
  // Data storage
  List<Invoice> _dailyInvoices = [];
  List<Invoice> _monthlyInvoices = [];
  List<Invoice> _yearlyInvoices = [];
  
  // Formatters (cached for performance)
  late final NumberFormat _currencyFormatter;
  late final DateFormat _dateFormatter;
  late final DateFormat _timeFormatter;
  late final DateFormat _monthYearFormatter;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeFormatters();
    _initializeTabController();
    _loadAllReports();
  }

  void _initializeServices() {
    _invoiceService = InvoiceService();
    _productService = ProductService();
  }

  void _initializeFormatters() {
    _currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    _dateFormatter = DateFormat('dd-MM-yyyy');
    _timeFormatter = DateFormat('HH:mm');
    _monthYearFormatter = DateFormat('MMMM yyyy');
  }

  void _initializeTabController() {
    _tabController = TabController(length: 3, vsync: this);
  }

  void _loadAllReports() {
    _loadDailyReport();
    _loadMonthlyReport();
    _loadYearlyReport();
  }

  void _loadDailyReport() {
    if (mounted) {
      setState(() {
        _dailyInvoices = _invoiceService.getDailyInvoices(_selectedDate);
      });
    }
  }

  void _loadMonthlyReport() {
    if (mounted) {
      setState(() {
        _monthlyInvoices = _invoiceService.getMonthlyInvoices(
          _selectedMonth,
          _selectedYearForMonth,
        );
      });
    }
  }

  void _loadYearlyReport() {
    if (mounted) {
      setState(() {
        _yearlyInvoices = _invoiceService.getYearlyInvoices(_selectedYear);
      });
    }
  }

  double _calculateTotalRevenue(List<Invoice> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + invoice.totalAmount);
  }

  double _calculateTotalProfit(List<Invoice> invoices) {
    return invoices.fold(0.0, (sum, invoice) => sum + invoice.totalProfit);
  }

  Map<String, double> _getCategoryBreakdown(List<Invoice> invoices) {
    final Map<String, double> breakdown = {'Frames': 0.0, 'Lenses': 0.0};
    
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        final key = item.productType == 'Frame' ? 'Frames' : 'Lenses';
        breakdown[key] = (breakdown[key] ?? 0) + item.totalSellingPrice;
      }
    }
    
    return breakdown;
  }

  Map<String, double> _getSubCategoryBreakdown(
    List<Invoice> invoices,
    String categoryType,
  ) {
    final Map<String, double> breakdown = {};
    
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        if (item.productType == categoryType) {
          String? brandOrCompany;
          
          if (categoryType == 'Frame') {
            final frame = _productService.getFrameById(item.productId);
            brandOrCompany = frame?.brand;
          } else if (categoryType == 'Lens') {
            final lens = _productService.getLensById(item.productId);
            brandOrCompany = lens?.company;
          }
          
          if (brandOrCompany != null) {
            breakdown[brandOrCompany] = 
                (breakdown[brandOrCompany] ?? 0) + item.totalSellingPrice;
          }
        }
      }
    }
    
    return breakdown;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadDailyReport();
    }
  }

  Future<void> _selectMonthYear() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        int tempMonth = _selectedMonth;
        int tempYear = _selectedYearForMonth;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Month and Year'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: tempMonth,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(12, (index) => index + 1)
                        .map((month) => DropdownMenuItem(
                              value: month,
                              child: Text(DateFormat.MMMM()
                                  .format(DateTime(0, month))),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => tempMonth = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: tempYear,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: List.generate(10, (index) => DateTime.now().year - 5 + index)
                        .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => tempYear = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYearForMonth = tempYear;
                    });
                    _loadMonthlyReport();
                    Navigator.pop(context);
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectYear() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Year'),
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
                });
                _loadYearlyReport();
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteInvoice(Invoice invoice) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete Invoice'),
          content: Text(
            'Are you sure you want to delete invoice '
            '${invoice.invoiceId.substring(0, 8).toUpperCase()}? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await _invoiceService.deleteInvoice(invoice.invoiceId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadAllReports();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting invoice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editInvoice(Invoice invoice) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BillingScreen(invoiceToEdit: invoice),
      ),
    );

    if (result == true) {
      _loadAllReports();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            height: 45,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade800,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue.shade800,
              tabs: const [
                Tab(text: 'Daily'),
                Tab(text: 'Monthly' ),
                Tab(text: 'Yearly'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyReportTab(),
                _buildMonthlyReportTab(),
                _buildYearlyReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeader(
            title: 'Daily Report for ${_dateFormatter.format(_selectedDate)}',
            onTap: _selectDate,
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(_dailyInvoices),
          const SizedBox(height: 16),
          _buildInvoicesSection(_dailyInvoices),
        ],
      ),
    );
  }

  Widget _buildMonthlyReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeader(
            title: 'Monthly Report for ${_monthYearFormatter.format(DateTime(_selectedYearForMonth, _selectedMonth))}',
            onTap: _selectMonthYear,
            icon: Icons.calendar_month,
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(_monthlyInvoices),
          const SizedBox(height: 16),
          _buildBreakdownSection(_monthlyInvoices),
        ],
      ),
    );
  }

  Widget _buildYearlyReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeader(
            title: 'Yearly Report for $_selectedYear',
            onTap: _selectYear,
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(_yearlyInvoices),
          const SizedBox(height: 16),
          _buildBreakdownSection(_yearlyInvoices),
        ],
      ),
    );
  }

  Widget _buildReportHeader({
    required String title,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: onTap,
              icon: Icon(icon, color: Colors.blue.shade700),
              tooltip: 'Select date',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(List<Invoice> invoices) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildSummaryRow(
              'Total Revenue',
              _currencyFormatter.format(_calculateTotalRevenue(invoices)),
              Colors.blue.shade700,
              Icons.attach_money,
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              'Total Profit',
              _currencyFormatter.format(_calculateTotalProfit(invoices)),
              Colors.green.shade700,
              Icons.trending_up,
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              'Total Invoices',
              invoices.length.toString(),
              Colors.orange.shade700,
              Icons.receipt_long,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesSection(List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return const _EmptyStateWidget(message: 'No invoices for this period');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invoices (${invoices.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...invoices.map((invoice) => _buildInvoiceCard(invoice)),
      ],
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  invoice.invoiceId.substring(0, 8).toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _editInvoice(invoice),
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit Invoice',
                    ),
                    IconButton(
                      onPressed: () => _confirmDeleteInvoice(invoice),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete Invoice',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Customer',
                    invoice.customerName ?? 'N/A',
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Time',
                    _timeFormatter.format(invoice.saleDate),
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Amount',
                    _currencyFormatter.format(invoice.totalAmount),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Profit',
                    _currencyFormatter.format(invoice.totalProfit),
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return const _EmptyStateWidget(message: 'No data available for breakdown');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreakdownCard(
          'Category Breakdown',
          _getCategoryBreakdown(invoices),
          Icons.category,
        ),
        const SizedBox(height: 16),
        _buildBreakdownCard(
          'Frame Brand Breakdown',
          _getSubCategoryBreakdown(invoices, 'Frame'),
          Icons.visibility,
        ),
        const SizedBox(height: 16),
        _buildBreakdownCard(
          'Lens Company Breakdown',
          _getSubCategoryBreakdown(invoices, 'Lens'),
          Icons.lens,
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(
    String title,
    Map<String, double> data,
    IconData icon,
  ) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('No data available'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...data.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      _currencyFormatter.format(entry.value),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final String message;

  const _EmptyStateWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}