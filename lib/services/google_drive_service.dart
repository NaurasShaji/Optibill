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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope], // CHANGED: Using drive.file scope for visible files
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;

  // Initialize and sign in
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) {
        return false; // User cancelled sign-in
      }
      final authHeaders = await _currentUser!.authHeaders;
      final authenticatedClient = GoogleHttpClient(authHeaders);
      _driveApi = drive.DriveApi(authenticatedClient);
      return true;
    } catch (e) {
      print('Error signing in to Google Drive: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  bool get isSignedIn => _currentUser != null;

  // --- Backup Logic ---
  Future<void> backupData() async {
    if (!isSignedIn) {
      print('Not signed in to Google Drive.');
      bool success = await signIn();
      if (!success) return;
    }

    try {
      // 1. Collect all data from Hive boxes
      final framesBox = Hive.box<Frame>('frames');
      final lensesBox = Hive.box<Lens>('lenses');
      final invoicesBox = Hive.box<Invoice>('invoices');

      final Map<String, dynamic> backupData = {
        'frames': framesBox.values.map((f) => f.toJson()).toList(),
        'lenses': lensesBox.values.map((l) => l.toJson()).toList(),
        'invoices': invoicesBox.values.map((i) => i.toJson()).toList(),
      };

      final String jsonString = jsonEncode(backupData);
      final String fileName = 'optibill_backup_${DateTime.now().toIso8601String()}.json';

      // 2. Upload to Google Drive (directly in My Drive)
      final drive.File fileMetadata = drive.File();
      fileMetadata.name = fileName;
      // Removed parents = ['appDataFolder'] as we are now using drive.file scope,
      // which puts files in My Drive by default or a specified folder.
      // If you want a specific folder in My Drive, you'd need to find/create its ID.
      // For simplicity, it will go to the root of My Drive.

      final media = drive.Media(
        Stream.value(utf8.encode(jsonString)),
        jsonString.length,
        contentType: 'application/json',
      );

      await _driveApi!.files.create(fileMetadata, uploadMedia: media);
      print('Backup successful: $fileName');
    } catch (e) {
      print('Error during backup: $e');
      rethrow; // Re-throw to handle in UI
    }
  }

  // --- Restore Logic ---
  Future<List<drive.File>> listBackupFiles() async {
    if (!isSignedIn) {
      print('Not signed in to Google Drive.');
      bool success = await signIn();
      if (!success) return [];
    }

    try {
      // List files from 'root' (My Drive) when using drive.file scope
      final fileList = await _driveApi!.files.list(q: "name contains 'optibill_backup_' and mimeType='application/json'", spaces: 'drive');
      return fileList.files ?? [];
    } catch (e) {
      print('Error listing backup files: $e');
      return [];
    }
  }

  Future<void> restoreData(String fileId) async {
    if (!isSignedIn) {
      print('Not signed in to Google Drive.');
      bool success = await signIn();
      if (!success) return;
    }

    try {
      // 1. Download the selected file
      final mediaFile = await _driveApi!.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final responseBytes = await mediaFile.stream.expand((bytes) => bytes).toList();
      final String jsonString = utf8.decode(responseBytes);
      final Map<String, dynamic> restoredData = jsonDecode(jsonString);

      // 2. Clear existing Hive data (with confirmation in UI)
      await Hive.box<Frame>('frames').clear();
      await Hive.box<Lens>('lenses').clear();
      await Hive.box<Invoice>('invoices').clear();

      // 3. Populate Hive with restored data
      final framesBox = Hive.box<Frame>('frames');
      final lensesBox = Hive.box<Lens>('lenses');
      final invoicesBox = Hive.box<Invoice>('invoices');

      for (var frameJson in restoredData['frames']) {
        await framesBox.put(frameJson['id'], Frame.fromJson(frameJson));
      }
      for (var lensJson in restoredData['lenses']) {
        await lensesBox.put(lensJson['id'], Lens.fromJson(lensJson));
      }
      for (var invoiceJson in restoredData['invoices']) {
        await invoicesBox.put(invoiceJson['invoiceId'], Invoice.fromJson(invoiceJson));
      }

      print('Restore successful from file ID: $fileId');
    } catch (e) {
      print('Error during restore: $e');
      rethrow; // Re-throw to handle in UI
    }
  }
}
