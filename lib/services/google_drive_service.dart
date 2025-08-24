import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/models/invoice.dart';
import 'package:optibill/models/invoice_item.dart'; // Ensure InvoiceItem is imported

// Helper class for authenticated HTTP client
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  final List<String> _scopes = [drive.DriveApi.driveFileScope];

  late GoogleSignIn _googleSignIn;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  GoogleHttpClient? _authClient;

  // Singleton pattern to ensure consistent state across the app
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  
  GoogleDriveService._internal() {
    _googleSignIn = GoogleSignIn(
      scopes: [drive.DriveApi.driveFileScope],
    );
    _initializeSignInListener();
  }

  GoogleSignInAccount? get currentUser => _currentUser;

  void _initializeSignInListener() {
    // Listen to sign-in state changes
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      if (account != null) {
        _setupDriveApi();
      } else {
        _driveApi = null;
        _authClient = null;
      }
    });
  }

  Future<void> _setupDriveApi() async {
    if (_currentUser != null) {
      try {
        final headers = await _currentUser!.authHeaders;
        _authClient = GoogleHttpClient(headers);
        _driveApi = drive.DriveApi(_authClient!);
      } catch (e) {
        print('Error setting up Drive API: $e');
      }
    }
  }

  // Sign in manually
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;

      await _setupDriveApi();
      return true;
    } catch (e) {
      print('Google sign-in error: $e');
      return false;
    }
  }

  // Silent sign-in (used for background tasks and checking existing auth)
  Future<bool> signInSilently() async {
    try {
      // First check if we already have a current user
      if (_currentUser != null && _driveApi != null) {
        // Verify the current authentication is still valid
        try {
          final headers = await _currentUser!.authHeaders;
          _authClient = GoogleHttpClient(headers);
          _driveApi = drive.DriveApi(_authClient!);
          return true;
        } catch (e) {
          print('Current auth invalid, attempting silent sign-in: $e');
        }
      }

      // Attempt silent sign-in
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        await _setupDriveApi();
        return true;
      }
      return false;
    } catch (e) {
      print('Silent sign-in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      _driveApi = null;
      _authClient = null;
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  bool get isSignedIn => _currentUser != null && _driveApi != null;

  // Helper method to ensure we're authenticated before API calls
  Future<bool> _ensureAuthenticated() async {
    if (isSignedIn) return true;
    
    bool signedIn = await signInSilently();
    if (!signedIn) {
      signedIn = await signIn();
    }
    return signedIn;
  }

  // --- Backup Logic ---
  Future<void> backupData() async {
    if (!await _ensureAuthenticated()) {
      throw Exception('Failed to authenticate with Google Drive');
    }

    try {
      final framesBox = Hive.box<Frame>('frames');
      final lensesBox = Hive.box<Lens>('lenses');
      final invoicesBox = Hive.box<Invoice>('invoices');

      final backupData = {
        'frames': framesBox.values.map((f) => f.toJson()).toList(),
        'lenses': lensesBox.values.map((l) => l.toJson()).toList(),
        'invoices': invoicesBox.values.map((i) => i.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0', // Add version for future compatibility
      };

      final jsonString = jsonEncode(backupData);
      final fileName = 'optibill_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';

      final fileMetadata = drive.File()
        ..name = fileName
        ..description = 'OptiBill Data Backup';

      final media = drive.Media(
        Stream.value(utf8.encode(jsonString)),
        jsonString.length,
        contentType: 'application/json',
      );

      await _driveApi!.files.create(fileMetadata, uploadMedia: media);
      print('✅ Backup uploaded: $fileName');
    } catch (e) {
      print('❌ Backup error: $e');
      rethrow;
    }
  }

  // --- Restore Logic ---
  Future<List<drive.File>> listBackupFiles() async {
    if (!await _ensureAuthenticated()) {
      throw Exception('Failed to authenticate with Google Drive');
    }

    try {
      final fileList = await _driveApi!.files.list(
        q: "name contains 'optibill_backup_' and mimeType='application/json'",
        spaces: 'drive',
        orderBy: 'createdTime desc',
        pageSize: 50, // Limit results
      );
      return fileList.files ?? [];
    } catch (e) {
      print('❌ Error listing backups: $e');
      rethrow;
    }
  }

  Future<void> restoreData(String fileId) async {
    if (!await _ensureAuthenticated()) {
      throw Exception('Failed to authenticate with Google Drive');
    }

    try {
      final mediaFile = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final responseBytes = await mediaFile.stream.expand((bytes) => bytes).toList();
      final String jsonString = utf8.decode(responseBytes);
      final Map<String, dynamic> restoredData = jsonDecode(jsonString);

      // Validate backup data structure
      if (!restoredData.containsKey('frames') || 
          !restoredData.containsKey('lenses') || 
          !restoredData.containsKey('invoices')) {
        throw Exception('Invalid backup file format');
      }

      // Clear existing data
      await Hive.box<Frame>('frames').clear();
      await Hive.box<Lens>('lenses').clear();
      await Hive.box<Invoice>('invoices').clear();

      final framesBox = Hive.box<Frame>('frames');
      final lensesBox = Hive.box<Lens>('lenses');
      final invoicesBox = Hive.box<Invoice>('invoices');

      // Restore data with error handling
      int framesRestored = 0;
      int lensesRestored = 0;
      int invoicesRestored = 0;

      for (var frameJson in restoredData['frames']) {
        try {
          await framesBox.put(frameJson['id'], Frame.fromJson(frameJson));
          framesRestored++;
        } catch (e) {
          print('Error restoring frame: $e');
        }
      }

      for (var lensJson in restoredData['lenses']) {
        try {
          await lensesBox.put(lensJson['id'], Lens.fromJson(lensJson));
          lensesRestored++;
        } catch (e) {
          print('Error restoring lens: $e');
        }
      }

      for (var invoiceJson in restoredData['invoices']) {
        try {
          await invoicesBox.put(invoiceJson['invoiceId'], Invoice.fromJson(invoiceJson));
          invoicesRestored++;
        } catch (e) {
          print('Error restoring invoice: $e');
        }
      }

      print('✅ Restore complete from file ID: $fileId');
      print('📊 Restored: $framesRestored frames, $lensesRestored lenses, $invoicesRestored invoices');
    } catch (e) {
      print('❌ Restore error: $e');
      rethrow;
    }
  }

  // Additional utility method to check connection status
  Future<bool> testConnection() async {
    if (!await _ensureAuthenticated()) {
      return false;
    }

    try {
      // Try to make a simple API call to test connection
      await _driveApi!.files.list(pageSize: 1);
      return true;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}