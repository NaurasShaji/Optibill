import 'package:flutter/material.dart';
import 'package:optibill/services/google_drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/invoice.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

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
  Timer? _autoBackupTimer;
  DateTime? _lastAutoBackupTime;

  static const String _lastAutoBackupTimeKey = 'lastAutoBackupTime';
  static const Duration _autoBackupInterval = Duration(days: 7);

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
    _loadLastAutoBackupTime();
    _startAutoBackupTimer();
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLastAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupMillis = prefs.getInt(_lastAutoBackupTimeKey);
    if (lastBackupMillis != null) {
      _lastAutoBackupTime = DateTime.fromMillisecondsSinceEpoch(lastBackupMillis);
    }
    if (mounted) {
      setState(() {}); // Update UI to show last backup time
    }
  }

  Future<void> _saveLastAutoBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAutoBackupTimeKey, DateTime.now().millisecondsSinceEpoch);
    _lastAutoBackupTime = DateTime.now();
    if (mounted) {
      setState(() {}); // Update UI
    }
  }

  void _startAutoBackupTimer() {
    // Calculate time until next backup
    Duration timeUntilNextBackup = _autoBackupInterval;
    if (_lastAutoBackupTime != null) {
      final timeSinceLastBackup = DateTime.now().difference(_lastAutoBackupTime!);
      if (timeSinceLastBackup < _autoBackupInterval) {
        timeUntilNextBackup = _autoBackupInterval - timeSinceLastBackup;
      } else {
        // If more than 2 weeks have passed, schedule backup immediately
        timeUntilNextBackup = Duration.zero;
      }
    }

    _autoBackupTimer = Timer.periodic(timeUntilNextBackup, (timer) {
      _performAutoBackup();
      // After the first backup, the timer will tick every 2 weeks
      _autoBackupTimer?.cancel(); // Cancel the current timer
      _autoBackupTimer = Timer.periodic(_autoBackupInterval, (timer) {
        _performAutoBackup();
      });
    });
  }

  Future<void> _performAutoBackup() async {
    // Only perform auto-backup if signed in and connected to the internet
    if (_googleDriveService.isSignedIn) {
      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        print('Attempting auto-backup...');
        try {
          await _googleDriveService.backupData();
          print('Auto-backup successful!');
          _saveLastAutoBackupTime(); // Save timestamp of successful auto-backup
        } catch (e) {
          print('Auto-backup failed: $e');
          // Handle backup failure (e.g., show a silent notification)
        }
      } else {
        print('No internet connection for auto-backup.');
      }
    } else {
      print('Not signed in to Google Drive for auto-backup.');
    }
  }

  // FIXED: Properly check existing sign-in status
  Future<void> _checkSignInStatus() async {
    if (!mounted) return;
    
    setState(() {
      _isSigningIn = true; // Show loading while checking
    });
    
    try {
      // Check if user is already signed in silently
      bool isSignedIn = await _googleDriveService.signInSilently();
      
      if (isSignedIn) {
        // If signed in, load backup files automatically
        await _listBackupFiles();
        print('User already signed in to Google Drive');
      } else {
        print('User not signed in to Google Drive');
      }
    } catch (e) {
      print('Error checking sign-in status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleSignIn() async {
    if (!mounted) return;
    
    setState(() {
      _isSigningIn = true;
    });
    try {
      bool success = await _googleDriveService.signIn();
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed in to Google Drive!')),
          );
        }
        await _listBackupFiles(); // Load backup files after successful sign-in
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Sign-In cancelled or failed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sign-in: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _googleDriveService.signOut();
    if (mounted) {
      setState(() {
        _backupFiles.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out from Google Drive.')),
      );
    }
  }

  Future<void> _handleBackup() async {
    if (!mounted) return;
    
    setState(() {
      _isBackingUp = true;
    });
    try {
      await _googleDriveService.backupData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data backed up successfully!')),
        );
      }
      await _listBackupFiles(); // Refresh backup files list
      _saveLastAutoBackupTime(); // Also save timestamp for manual backups
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _listBackupFiles() async {
    if (!_googleDriveService.isSignedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to list backup files.')),
        );
      }
      return;
    }
    try {
      final files = await _googleDriveService.listBackupFiles();
      if (mounted) {
        setState(() {
          _backupFiles = files;
        });
        if (files.isEmpty) {
          print('No backup files found.'); // Changed to print instead of snackbar for silent loading
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error listing backup files: $e')),
        );
      }
    }
  }

  Future<void> _handleRestore(drive.File file) async {
    if (!mounted) return;
    
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
                if (mounted) {
                  setState(() {
                    _isRestoring = true;
                  });
                }
                try {
                  await _googleDriveService.restoreData(file.id!);
                  await _listBackupFiles();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data restored successfully!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restore failed: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isRestoring = false;
                    });
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
          Text(
            _lastAutoBackupTime == null
                ? 'Last auto-backup: Never'
                : 'Last auto-backup: ${DateFormat('dd-MM-yyyy HH:mm').format(_lastAutoBackupTime!)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
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
                          subtitle: Text(
                              'Backup Date: ${file.createdTime != null ? DateFormat('dd-MM-yyyy HH:mm').format(file.createdTime!) : 'N/A'}'),
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


class CustomerLookupTab extends StatefulWidget {
  const CustomerLookupTab({super.key});

  @override
  State<CustomerLookupTab> createState() => _CustomerLookupTabState();
}

class _CustomerLookupTabState extends State<CustomerLookupTab> {
  // Controllers and state
  late final TextEditingController _customerNameController;
  late final ScrollController _scrollController;
  
  final List<Invoice> _foundInvoices = [];
  final List<Invoice> _allCustomers = [];
  Invoice? _selectedInvoice;
  bool _isSearching = false;
  bool _isLoading = true;
  
  // Cached formatters for performance
  late final NumberFormat _currencyFormatter;
  late final DateFormat _dateFormatter;
  
  // Debounce timer for search optimization
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeFormatters();
    _loadAllCustomers();
  }

  void _initializeControllers() {
    _customerNameController = TextEditingController();
    _scrollController = ScrollController();
  }

  void _initializeFormatters() {
    _currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    _dateFormatter = DateFormat('dd-MM-yyyy');
  }

  Future<void> _loadAllCustomers() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final invoiceBox = Hive.box<Invoice>('invoices');
      final Map<String, Invoice> latestInvoicesByCustomer = {};
      
      // Process all invoices to find latest per customer
      for (final invoice in invoiceBox.values) {
        final customerName = (invoice.customerName?.trim().toLowerCase() ?? '').isEmpty 
            ? 'unknown' 
            : invoice.customerName!.trim().toLowerCase();
        final customerContact = invoice.customerContact?.trim() ?? '';
        final key = '$customerName|$customerContact';

        if (!latestInvoicesByCustomer.containsKey(key) ||
            invoice.saleDate.isAfter(latestInvoicesByCustomer[key]!.saleDate)) {
          latestInvoicesByCustomer[key] = invoice;
        }
      }

      // Sort customers by name
      final sortedCustomers = latestInvoicesByCustomer.values.toList()
        ..sort((a, b) {
          final aName = a.customerName?.toLowerCase() ?? '';
          final bName = b.customerName?.toLowerCase() ?? '';
          return aName.compareTo(bName);
        });

      if (mounted) {
        setState(() {
          _allCustomers.clear();
          _allCustomers.addAll(sortedCustomers);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading customers: $e');
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _searchCustomers(query);
    });
  }

  Future<void> _searchCustomers(String query) async {
    if (!mounted) return;
    
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.isEmpty) {
      setState(() {
        _foundInvoices.clear();
        _selectedInvoice = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final queryLower = trimmedQuery.toLowerCase();
      final results = _allCustomers
          .where((invoice) =>
              (invoice.customerName?.toLowerCase().contains(queryLower) ?? false) ||
              (invoice.customerContact?.contains(trimmedQuery) ?? false))
          .take(10)
          .toList();

      if (mounted) {
        setState(() {
          _foundInvoices.clear();
          _foundInvoices.addAll(results);
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showErrorSnackBar('Error searching customers: $e');
      }
    }
  }

  void _clearSearch() {
    _customerNameController.clear();
    setState(() {
      _foundInvoices.clear();
      _selectedInvoice = null;
    });
  }

  void _selectInvoice(Invoice invoice) {
    setState(() => _selectedInvoice = invoice);
    // Smooth scroll to show selected invoice details
    if (_selectedInvoice != null) {
      _scrollController.animateTo(
        400,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _customerNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const _LoadingWidget()
          : CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Search Card
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverToBoxAdapter(
                    child: _buildSearchCard(),
                  ),
                ),
                
                // Loading indicator
                if (_isSearching)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                
                // Search Results as Sliver
                if (_foundInvoices.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverToBoxAdapter(
                      child: _buildSearchResultsHeader(),
                    ),
                  ),
                
                if (_foundInvoices.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final invoice = _foundInvoices[index];
                          return _buildCustomerListItem(invoice, isSearchResult: true);
                        },
                        childCount: _foundInvoices.length,
                      ),
                    ),
                  ),
                
                // Selected Invoice Details
                if (_selectedInvoice != null)
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverToBoxAdapter(
                      child: _buildInvoiceDetailsCard(),
                    ),
                  ),
                
                // All Customers Header
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverToBoxAdapter(
                    child: _buildAllCustomersHeader(),
                  ),
                ),
                
                // All Customers List as Sliver
                if (_allCustomers.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final invoice = _allCustomers[index];
                          return _buildCustomerListItem(invoice);
                        },
                        childCount: _allCustomers.length,
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: _EmptyStateWidget(message: 'No customers found'),
                    ),
                  ),
                
                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Customer Lookup',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _customerNameController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search by name or contact',
                hintText: 'Enter customer name or phone number',
                prefixIcon: const Icon(Icons.person_search),
                suffixIcon: _customerNameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultsHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'Search Results (${_foundInvoices.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCustomersHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'All Customers (${_allCustomers.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: _loadAllCustomers,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh customers',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerListItem(Invoice invoice, {bool isSearchResult = false}) {
    final isSelected = _selectedInvoice?.invoiceId == invoice.invoiceId;
    final color = isSearchResult ? Colors.blue : Colors.purple;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: color.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.shade50 : null,
        ),
        child: ListTile(
          onTap: () => _selectInvoice(invoice),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Hero(
            tag: 'customer_${invoice.invoiceId}',
            child: CircleAvatar(
              backgroundColor: color.shade100,
              child: Text(
                (invoice.customerName ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: color.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            invoice.customerName ?? 'Unknown Customer',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? color.shade800 : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (invoice.customerContact?.isNotEmpty ?? false)
                Text(
                  invoice.customerContact!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Last visit: ${_dateFormatter.format(invoice.saleDate)}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currencyFormatter.format(invoice.totalAmount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: color.shade600,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceDetailsCard() {
    if (_selectedInvoice == null) return const SizedBox.shrink();

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Customer Details: ${_selectedInvoice!.customerName ?? "Unknown"}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInvoiceDetails(_selectedInvoice!),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDetails(Invoice invoice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basic Info Section
        _buildSectionCard(
          'Basic Information',
          Icons.info_outline,
          Colors.blue,
          [
            _buildInfoRow('Date', _dateFormatter.format(invoice.saleDate)),
            _buildInfoRow('Contact', invoice.customerContact ?? 'N/A'),
            _buildInfoRow('Invoice ID', invoice.invoiceId.substring(0, 8).toUpperCase()),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Prescription Section
        _buildSectionCard(
          'Prescription Details',
          Icons.visibility,
          Colors.orange,
          [
            Row(
              children: [
                Expanded(child: _buildVisionCard('Right Eye DV', invoice.rightEyeDV)),
                const SizedBox(width: 12),
                Expanded(child: _buildVisionCard('Right Eye NV', invoice.rightEyeNV)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildVisionCard('Left Eye DV', invoice.leftEyeDV)),
                const SizedBox(width: 12),
                Expanded(child: _buildVisionCard('Left Eye NV', invoice.leftEyeNV)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Purchased Items Section
        _buildSectionCard(
          'Purchased Items (${invoice.items.length})',
          Icons.shopping_bag,
          Colors.green,
          [
            ...invoice.items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${item.productType} • Qty: ${item.quantity}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormatter.format(item.totalSellingPrice),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        '@ ${_currencyFormatter.format(item.unitSellingPrice)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),

        const SizedBox(height: 16),

        // Bill Summary Section
        _buildBillSummaryCard(invoice),
      ],
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionCard(String title, String? value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'N/A',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBillSummaryCard(Invoice invoice) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Bill Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Subtotal', _currencyFormatter.format(invoice.subtotal)),
          _buildInfoRow('Discount', _currencyFormatter.format(invoice.totalDiscountOnBill ?? 0)),
          _buildInfoRow('Payment Method', invoice.paymentMethod),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currencyFormatter.format(invoice.totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading customers...'),
        ],
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final String message;

  const _EmptyStateWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.person_outline,
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
    );
  }
}
