import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optibill/services/google_drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/invoice.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced backup and restore screen with professional architecture
class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0, // Inside your AppBar properties
          bottom: const TabBar(
            indicatorWeight: 3,
            tabs: [
              Tab(
                text: 'Customer Lookup',
                icon: Icon(Icons.search_outlined),
              ),
              Tab(
                text: 'Backup & Restore',
                icon: Icon(Icons.backup_outlined),
              ),
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

/// Enhanced backup and restore tab with professional features
class BackupRestoreTab extends StatefulWidget {
  const BackupRestoreTab({super.key});

  @override
  State<BackupRestoreTab> createState() => _BackupRestoreTabState();
}

class _BackupRestoreTabState extends State<BackupRestoreTab>
    with AutomaticKeepAliveClientMixin {
  
  // Constants
  static const String _lastAutoBackupTimeKey = 'lastAutoBackupTime';
  static const String _autoBackupEnabledKey = 'autoBackupEnabled';
  static const Duration _autoBackupInterval = Duration(days: 7);
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const int _maxBackupFilesToShow = 5; // Limit to 5 backup files
  
  // Services
  final GoogleDriveService _googleDriveService = GoogleDriveService();
  final Connectivity _connectivity = Connectivity();
  
  // State management
  bool _isSigningIn = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isAutoBackingUp = false;
  List<drive.File> _backupFiles = [];
  List<drive.File> _allBackupFiles = []; // Store all backup files
  bool _autoBackupEnabled = true;
  
  // Auto backup management
  Timer? _autoBackupTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  DateTime? _lastAutoBackupTime;
  
  // UI state
  bool _isInitializing = true;
  String? _lastError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeBackupSystem();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  /// Initialize the entire backup system
  Future<void> _initializeBackupSystem() async {
    try {
      await _loadSettings();
      await _checkSignInStatus();
      _setupConnectivityListener();
      _setupAutoBackupTimer();
    } catch (error) {
      _handleError('Failed to initialize backup system', error);
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// Clean up all resources and subscriptions
  void _cleanupResources() {
    _autoBackupTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// Load user settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load last backup time
      final lastBackupMillis = prefs.getInt(_lastAutoBackupTimeKey);
      if (lastBackupMillis != null) {
        _lastAutoBackupTime = DateTime.fromMillisecondsSinceEpoch(lastBackupMillis);
      }
      
      // Load auto backup preference
      _autoBackupEnabled = prefs.getBool(_autoBackupEnabledKey) ?? true;
      
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Error loading settings: $error');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_lastAutoBackupTime != null) {
        await prefs.setInt(_lastAutoBackupTimeKey, _lastAutoBackupTime!.millisecondsSinceEpoch);
      }
      
      await prefs.setBool(_autoBackupEnabledKey, _autoBackupEnabled);
    } catch (error) {
      debugPrint('Error saving settings: $error');
    }
  }

  /// Check existing sign-in status
  Future<void> _checkSignInStatus() async {
    if (!mounted) return;
    
    setState(() => _isSigningIn = true);
    
    try {
      final isSignedIn = await _googleDriveService.signInSilently()
          .timeout(_connectionTimeout);
      
      if (isSignedIn) {
        await _listBackupFiles();
        debugPrint('User already signed in to Google Drive');
      }
    } catch (error) {
      _handleError('Failed to check sign-in status', error, showSnackBar: false);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  /// Setup connectivity listener for network changes
  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        if (result != ConnectivityResult.none && 
            _googleDriveService.isSignedIn && 
            _shouldPerformAutoBackup()) {
          _performAutoBackup();
        }
      },
    );
  }

  /// Setup auto backup timer
  void _setupAutoBackupTimer() {
    if (!_autoBackupEnabled) return;
    
    final timeUntilNextBackup = _calculateTimeUntilNextBackup();
    
    _autoBackupTimer = Timer(timeUntilNextBackup, () {
      _performAutoBackup();
      // Setup periodic timer after first backup
      _autoBackupTimer?.cancel();
      _autoBackupTimer = Timer.periodic(_autoBackupInterval, (_) {
        _performAutoBackup();
      });
    });
  }

  /// Calculate time until next backup is due
  Duration _calculateTimeUntilNextBackup() {
    if (_lastAutoBackupTime == null) {
      return Duration.zero; // Backup immediately if never backed up
    }
    
    final timeSinceLastBackup = DateTime.now().difference(_lastAutoBackupTime!);
    if (timeSinceLastBackup >= _autoBackupInterval) {
      return Duration.zero; // Backup immediately if overdue
    }
    
    return _autoBackupInterval - timeSinceLastBackup;
  }

  /// Check if auto backup should be performed
  bool _shouldPerformAutoBackup() {
    if (!_autoBackupEnabled || !_googleDriveService.isSignedIn) {
      return false;
    }
    
    if (_lastAutoBackupTime == null) {
      return true; // Never backed up
    }
    
    final timeSinceLastBackup = DateTime.now().difference(_lastAutoBackupTime!);
    return timeSinceLastBackup >= _autoBackupInterval;
  }

  /// Perform automatic backup
  Future<void> _performAutoBackup() async {
    if (_isBackingUp || _isAutoBackingUp) return;
    
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint('No internet connection for auto-backup');
        return;
      }
      
      debugPrint('Performing auto-backup...');
      setState(() => _isAutoBackingUp = true);
      
      await _googleDriveService.backupData().timeout(_connectionTimeout);
      
      _lastAutoBackupTime = DateTime.now();
      await _saveSettings();
      await _listBackupFiles();
      
      debugPrint('Auto-backup completed successfully');
      
      if (mounted) {
        _showSuccessSnackBar('Auto-backup completed successfully');
      }
      
    } catch (error) {
      debugPrint('Auto-backup failed: $error');
      _handleError('Auto-backup failed', error, showSnackBar: false);
    } finally {
      if (mounted) {
        setState(() => _isAutoBackingUp = false);
      }
    }
  }

  /// Handle Google sign in
  Future<void> _handleSignIn() async {
    if (_isSigningIn) return;
    
    setState(() => _isSigningIn = true);
    
    try {
      final success = await _googleDriveService.signIn()
          .timeout(_connectionTimeout);
      
      if (success) {
        await _listBackupFiles();
        if (mounted) {
          _showSuccessSnackBar('Successfully signed in to Google Drive');
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('Google Sign-In cancelled or failed');
        }
      }
    } catch (error) {
      _handleError('Sign-in failed', error);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  /// Handle Google sign out
  Future<void> _handleSignOut() async {
    try {
      await _googleDriveService.signOut();
      
      setState(() {
        _backupFiles.clear();
        _allBackupFiles.clear();
      });
      
      if (mounted) {
        _showInfoSnackBar('Signed out from Google Drive');
      }
    } catch (error) {
      _handleError('Sign-out failed', error);
    }
  }

  /// Handle manual backup
  Future<void> _handleManualBackup() async {
    if (_isBackingUp) return;
    
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No internet connection available');
      }
      
      setState(() => _isBackingUp = true);
      
      await _googleDriveService.backupData().timeout(_connectionTimeout);
      
      _lastAutoBackupTime = DateTime.now();
      await _saveSettings();
      await _listBackupFiles();
      
      if (mounted) {
        _showSuccessSnackBar('Data backed up successfully');
      }
      
    } catch (error) {
      _handleError('Backup failed', error);
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  /// Load available backup files - Now limits display to last 5 backups
  Future<void> _listBackupFiles() async {
    if (!_googleDriveService.isSignedIn) return;
    
    try {
      final files = await _googleDriveService.listBackupFiles()
          .timeout(_connectionTimeout);
      
      if (mounted) {
        setState(() {
          _allBackupFiles = files; // Store all backup files
          // Sort by creation time (newest first) and take only the last 5
          final sortedFiles = List<drive.File>.from(files);
          sortedFiles.sort((a, b) {
            final aTime = a.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime); // Newest first
          });
          _backupFiles = sortedFiles.take(_maxBackupFilesToShow).toList();
        });
      }
    } catch (error) {
      _handleError('Failed to load backup files', error, showSnackBar: false);
    }
  }

  /// Handle data restoration
  Future<void> _handleRestore(drive.File file) async {
    final confirmed = await _showRestoreConfirmation(file.name ?? 'Unknown File');
    if (!confirmed) return;
    
    setState(() => _isRestoring = true);
    
    try {
      await _googleDriveService.restoreData(file.id!)
          .timeout(_connectionTimeout);
      
      await _listBackupFiles();
      
      if (mounted) {
        _showSuccessSnackBar('Data restored successfully');
      }
    } catch (error) {
      _handleError('Restore failed', error);
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  /// Show restore confirmation dialog
  Future<bool> _showRestoreConfirmation(String fileName) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Confirm Restore'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action will permanently overwrite all your current data with the backup data.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restoring from:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(fileName),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '⚠️ This action cannot be undone. Make sure you have a recent backup of your current data.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore Data'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }

  /// Toggle auto backup setting
  void _toggleAutoBackup(bool enabled) {
    setState(() {
      _autoBackupEnabled = enabled;
    });
    
    _saveSettings();
    
    if (enabled) {
      _setupAutoBackupTimer();
    } else {
      _autoBackupTimer?.cancel();
    }
    
    _showInfoSnackBar(
      enabled ? 'Auto-backup enabled' : 'Auto-backup disabled',
    );
  }

  /// Handle errors with consistent messaging
  void _handleError(String message, dynamic error, {bool showSnackBar = true}) {
    debugPrint('$message: $error');
    
    setState(() {
      _lastError = message;
    });
    
    if (showSnackBar && mounted) {
      final errorMessage = _getUserFriendlyErrorMessage(error);
      _showErrorSnackBar('$message: $errorMessage');
    }
  }

  /// Convert technical errors to user-friendly messages
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Please check your internet connection';
    } else if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again';
    } else if (errorString.contains('permission') || errorString.contains('access')) {
      return 'Permission denied. Please sign in again';
    } else if (errorString.contains('storage') || errorString.contains('quota')) {
      return 'Not enough storage space available';
    } else {
      return 'An unexpected error occurred';
    }
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            if (_googleDriveService.isSignedIn) {
              _listBackupFiles();
            } else {
              _handleSignIn();
            }
          },
        ),
      ),
    );
  }

  /// Show info snackbar
  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Format file size for display
  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get backup button text based on state
  String _getBackupButtonText() {
    if (_isBackingUp) return 'Backing Up...';
    if (_isAutoBackingUp) return 'Auto-Backup in Progress...';
    return 'Backup Data to Google Drive';
  }

  /// Build the main UI
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing backup system...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_googleDriveService.isSignedIn) {
          await _listBackupFiles();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAccountSection(),
            const SizedBox(height: 24),
            _buildBackupSection(),
            const SizedBox(height: 24),
            _buildSettingsSection(),
            const SizedBox(height: 24),
            _buildBackupFilesSection(),
          ],
        ),
      ),
    );
  }

  /// Build account management section
  Widget _buildAccountSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _googleDriveService.isSignedIn 
                        ? Colors.green.shade50 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _googleDriveService.isSignedIn 
                        ? Icons.cloud_done 
                        : Icons.cloud_off,
                    color: _googleDriveService.isSignedIn 
                        ? Colors.green 
                        : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _googleDriveService.isSignedIn 
                            ? 'Google Drive Connected' 
                            : 'Connect to Google Drive',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_googleDriveService.isSignedIn) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Signed in as: ${_googleDriveService.currentUser?.displayName ?? 'N/A'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!_googleDriveService.isSignedIn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSigningIn ? null : _handleSignIn,
                  icon: _isSigningIn 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    _isSigningIn ? 'Signing In...' : 'Sign In with Google',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.red.shade300),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build backup operations section
  Widget _buildBackupSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup Operations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_lastAutoBackupTime != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last backup: ${DateFormat('MMM dd, yyyy \'at\' HH:mm').format(_lastAutoBackupTime!)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _googleDriveService.isSignedIn && 
                              !_isBackingUp && !_isAutoBackingUp 
                        ? _handleManualBackup 
                        : null,
                    icon: (_isBackingUp || _isAutoBackingUp)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_getBackupButtonText()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _googleDriveService.isSignedIn && 
                              !_isRestoring
                        ? _listBackupFiles 
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Backup List'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build settings section
  Widget _buildSettingsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Backup'),
              subtitle: Text(
                _autoBackupEnabled 
                    ? 'Automatically backup data every 7 days'
                    : 'Manual backup only',
              ),
              value: _autoBackupEnabled,
              onChanged: _toggleAutoBackup,
              secondary: Icon(
                _autoBackupEnabled ? Icons.backup : Icons.backup_outlined,
                color: _autoBackupEnabled ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build backup files section - Shows only last 5 backups
  Widget _buildBackupFilesSection() {
    if (!_googleDriveService.isSignedIn) {
      return const SizedBox.shrink();
    }
    
    if (_backupFiles.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(
                Icons.backup_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No backup files found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first backup to get started',
                style: TextStyle(
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Backups (${_backupFiles.length}/${_allBackupFiles.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_allBackupFiles.length > _maxBackupFilesToShow)
                      Text(
                        'Showing ${_maxBackupFilesToShow} most recent backups',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  onPressed: _listBackupFiles,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh backup list',
                ),
              ],
            ),
            if (_allBackupFiles.length > _maxBackupFilesToShow) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only the ${_maxBackupFilesToShow} most recent backups are shown. Older backups are still available in your Google Drive.',
                        style: TextStyle(
                          color: Colors.amber.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _backupFiles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = _backupFiles[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.backup,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      file.name ?? 'Unknown File',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (file.createdTime != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Created: ${DateFormat('MMM dd, yyyy \'at\' HH:mm').format(file.createdTime!)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (file.size != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Size: ${_formatFileSize(int.parse(file.size!))}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      onPressed: _isRestoring ? null : () => _handleRestore(file),
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange.shade50,
                        foregroundColor: Colors.orange.shade700,
                      ),
                      tooltip: 'Restore from this backup',
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

/// Customer lookup tab with enhanced search functionality
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
                
                // Search Results
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
                
                // All Customers List
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
