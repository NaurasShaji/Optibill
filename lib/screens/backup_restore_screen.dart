import 'package:flutter/material.dart';
import 'package:optibill/services/google_drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/invoice.dart';

class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          title: const Text('Utilities'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Customer Lookup', icon: Icon(Icons.search)),
              Tab(text: 'Backup & Restore', icon: Icon(Icons.backup)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CustomerLookupTab(),
            BackupRestoreTab(),
          ],
        ),
      ),
    );
  }
}

// --- BackupRestoreTab ---
class BackupRestoreTab extends StatefulWidget {
  const BackupRestoreTab({super.key});

  @override
  State<BackupRestoreTab> createState() => _BackupRestoreTabState();
}

class _BackupRestoreTabState extends State<BackupRestoreTab> {
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  bool _isSigningIn = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  List<drive.File> _backupFiles = [];

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  Future<void> _checkSignInStatus() async {
    setState(() {
      _isSigningIn = false;
    });
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      bool success = await _googleDriveService.signIn();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in to Google Drive!')),
        );
        _listBackupFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In cancelled or failed.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during sign-in: $e')),
      );
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await _googleDriveService.signOut();
    setState(() {
      _backupFiles.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out from Google Drive.')),
    );
  }

  Future<void> _handleBackup() async {
    setState(() {
      _isBackingUp = true;
    });
    try {
      await _googleDriveService.backupData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data backed up successfully!')),
      );
      _listBackupFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    } finally {
      setState(() {
        _isBackingUp = false;
      });
    }
  }

  Future<void> _listBackupFiles() async {
    if (!_googleDriveService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to list backup files.')),
      );
      return;
    }
    try {
      final files = await _googleDriveService.listBackupFiles();
      setState(() {
        _backupFiles = files;
      });
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backup files found.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error listing backup files: $e')),
      );
    }
  }

  Future<void> _handleRestore(drive.File file) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Restore'),
          content: Text('Are you sure you want to restore data from "${file.name}"? This will overwrite all existing local data.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Restore', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _isRestoring = true;
                });
                try {
                  await _googleDriveService.restoreData(file.id!);
                  await _listBackupFiles();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data restored successfully!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e')),
                  );
                } finally {
                  setState(() {
                    _isRestoring = false;
                  });
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    _googleDriveService.isSignedIn ? 'Google Drive Connected' : 'Connect to Google Drive',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (!_googleDriveService.isSignedIn)
                    ElevatedButton.icon(
                      onPressed: _isSigningIn ? null : _handleSignIn,
                      icon: _isSigningIn ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.login),
                      label: Text(_isSigningIn ? 'Signing In...' : 'Sign In with Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text('Signed in as: ${_googleDriveService.currentUser?.displayName ?? 'N/A'}'),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _handleSignOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _googleDriveService.isSignedIn && !_isBackingUp ? _handleBackup : null,
            icon: _isBackingUp ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.cloud_upload),
            label: Text(_isBackingUp ? 'Backing Up...' : 'Backup Data to Google Drive'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _googleDriveService.isSignedIn && !_isRestoring ? _listBackupFiles : null,
            icon: _isRestoring ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.cloud_download),
            label: Text(_isRestoring ? 'Restoring...' : 'Restore Data from Google Drive'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),
          if (_backupFiles.isNotEmpty && _googleDriveService.isSignedIn)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Backups:', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _backupFiles.length,
                      itemBuilder: (context, index) {
                        final file = _backupFiles[index];
                        return ListTile(
                          title: Text(file.name ?? 'Unknown File'),
                          subtitle: Text('ID: ${file.id ?? 'N/A'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.restore, color: Colors.blue),
                            onPressed: () => _handleRestore(file),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- CustomerLookupTab ---
class CustomerLookupTab extends StatefulWidget {
  const CustomerLookupTab({super.key});

  @override
  State<CustomerLookupTab> createState() => _CustomerLookupTabState();
}

class _CustomerLookupTabState extends State<CustomerLookupTab> {
  final _customerNameController = TextEditingController();
  List<Invoice> _foundInvoices = [];
  Invoice? _selectedInvoice;
  bool _isSearching = false;

  // New: List of all unique customers (latest invoice per customer)
  List<Invoice> _allCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadAllCustomers();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCustomers() async {
    try {
      final invoiceBox = Hive.box<Invoice>('invoices');

      final Map<String, Invoice> latestInvoicesByCustomer = {};
      for (final invoice in invoiceBox.values) {
        final customerName = invoice.customerName?.trim().toLowerCase() ?? '';
        final customerContact = invoice.customerContact?.trim() ?? '';
        final key = '$customerName|$customerContact';

        if (!latestInvoicesByCustomer.containsKey(key) ||
            invoice.saleDate.isAfter(latestInvoicesByCustomer[key]!.saleDate)) {
          latestInvoicesByCustomer[key] = invoice;
        }
      }

      setState(() {
        _allCustomers = latestInvoicesByCustomer.values.toList()
          ..sort((a, b) {
            final aKey = (a.customerName ?? '') + (a.customerContact ?? '');
            final bKey = (b.customerName ?? '') + (b.customerContact ?? '');
            return aKey.compareTo(bKey);
          });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading all customers: $e')),
      );
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _foundInvoices = [];
        _selectedInvoice = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _selectedInvoice = null;
    });

    try {
      final invoiceBox = Hive.box<Invoice>('invoices');
      final queryLower = query.trim().toLowerCase();

      final matchingInvoices = invoiceBox.values
          .where((invoice) =>
      invoice.customerName?.trim().toLowerCase().startsWith(queryLower) ?? false)
          .toList();

      final Map<String, Invoice> latestInvoicesByCustomer = {};
      for (final invoice in matchingInvoices) {
        final customerName = invoice.customerName?.trim().toLowerCase() ?? '';
        final customerContact = invoice.customerContact?.trim() ?? '';
        final key = '$customerName|$customerContact';
        if (!latestInvoicesByCustomer.containsKey(key) ||
            invoice.saleDate.isAfter(latestInvoicesByCustomer[key]!.saleDate)) {
          latestInvoicesByCustomer[key] = invoice;
        }
      }

      final results = latestInvoicesByCustomer.values.toList()
        ..sort((a, b) {
          final aKey = (a.customerName ?? '') + (a.customerContact ?? '');
          final bKey = (b.customerName ?? '') + (b.customerContact ?? '');
          return aKey.compareTo(bKey);
        });

      setState(() {
        _foundInvoices = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for customers: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // --- First Card: Search Field and Results ---
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Customer Details Lookup',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _customerNameController.clear();
                          setState(() {
                            _foundInvoices = [];
                            _selectedInvoice = null;
                          });
                        },
                      ),
                    ),
                    onChanged: _searchCustomers,
                  ),
                  const SizedBox(height: 12),
                  if (_isSearching)
                    const Center(child: CircularProgressIndicator()),
                  if (_foundInvoices.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: _foundInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _foundInvoices[index];
                          return Card(
                            child: ListTile(
                              title: Text(invoice.customerName ?? 'No Name'),
                              subtitle: Text(
                                'Last Visit:  ${DateFormat('dd-MM-yyyy').format(invoice.saleDate)}',
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedInvoice = invoice;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  if (_selectedInvoice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: _buildInvoiceDetails(_selectedInvoice!),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Second Card: All Customers List Below ---
          if (_allCustomers.isNotEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All Customers', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: _allCustomers.length,
                        itemBuilder: (context, index) {
                          final invoice = _allCustomers[index];
                          return ListTile(
                            title: Text(invoice.customerName ?? 'No Name'),
                            subtitle: Text(invoice.customerContact ?? ''),
                            trailing: Text('Last: ${DateFormat('dd-MM-yyyy').format(invoice.saleDate)}'),
                            onTap: () {
                              setState(() {
                                _selectedInvoice = invoice;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetails(Invoice invoice) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Latest Details for ${invoice.customerName}:',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _buildDetailRow('Date:', invoice.saleDate.toLocal().toString().split(' ')[0]),
        _buildDetailRow('Contact:', invoice.customerContact ?? 'N/A'),
        const Divider(height: 20),
        Text('Prescription Details:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildVisionDetail('Right Eye DV', invoice.rightEyeDV),
            _buildVisionDetail('Right Eye NV', invoice.rightEyeNV),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildVisionDetail('Left Eye DV', invoice.leftEyeDV),
            _buildVisionDetail('Left Eye NV', invoice.leftEyeNV),
          ],
        ),
        const Divider(height: 20),
        Text('Purchased Items:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...invoice.items.map((item) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text('${item.productName} (${item.productType})'),
            subtitle: Text(
                'Qty: ${item.quantity} @ ${formatCurrency.format(item.unitSellingPrice)}'),
            trailing: Text(formatCurrency.format(item.totalSellingPrice)),
          ),
        )),
        const Divider(height: 20),
        Text('Bill Summary:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildDetailRow('Subtotal:', formatCurrency.format(invoice.subtotal)),
        _buildDetailRow('Discount:', formatCurrency.format(invoice.totalDiscountOnBill ?? 0)),
        _buildDetailRow('Payment Method:', invoice.paymentMethod),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Amount:',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(formatCurrency.format(invoice.totalAmount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildVisionDetail(String title, String? value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value ?? 'N/A'),
      ],
    );
  }
}
