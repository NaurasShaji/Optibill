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

  GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  GoogleHttpClient? _authClient;

  GoogleSignInAccount? get currentUser => _currentUser;

  // Sign in manually
  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;

      final headers = await _currentUser!.authHeaders;
      _authClient = GoogleHttpClient(headers);
      _driveApi = drive.DriveApi(_authClient!);
      return true;
    } catch (e) {
      print('Google sign-in error: $e');
      return false;
    }
  }

  // Silent sign-in (used for background tasks)
  Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        final headers = await _currentUser!.authHeaders;
        _authClient = GoogleHttpClient(headers);
        _driveApi = drive.DriveApi(_authClient!);
        return true;
      }
      return false;
    } catch (e) {
      print('Silent sign-in failed: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _authClient = null;
  }

  bool get isSignedIn => _currentUser != null;

  // --- Backup Logic ---
  Future<void> backupData() async {
    if (!isSignedIn) {
      bool signedIn = await signInSilently();
      if (!signedIn) signedIn = await signIn();
      if (!signedIn) return;
    }

    try {
      final framesBox = Hive.box<Frame>('frames');
      final lensesBox = Hive.box<Lens>('lenses');
      final invoicesBox = Hive.box<Invoice>('invoices');

      final backupData = {
        'frames': framesBox.values.map((f) => f.toJson()).toList(),
        'lenses': lensesBox.values.map((l) => l.toJson()).toList(),
        'invoices': invoicesBox.values.map((i) => i.toJson()).toList(),
      };

      final jsonString = jsonEncode(backupData);
      final fileName = 'optibill_backup_${DateTime.now().toIso8601String()}.json';

      final fileMetadata = drive.File()..name = fileName;

      final media = drive.Media(
        Stream.value(utf8.encode(jsonString)),
        jsonString.length,
        contentType: 'application/json',
      );

      await _driveApi!.files.create(fileMetadata, uploadMedia: media);
      print(' Backup uploaded: $fileName');
    } catch (e) {
      print(' Backup error: $e');
      rethrow;
    }
  }

  // --- Restore Logic ---
  Future<List<drive.File>> listBackupFiles() async {
    if (!isSignedIn) {
      bool signedIn = await signInSilently();
      if (!signedIn) signedIn = await signIn();
      if (!signedIn) return [];
    }

    try {
      final fileList = await _driveApi!.files.list(
        q: "name contains 'optibill_backup_' and mimeType='application/json'",
        spaces: 'drive',
        orderBy: 'createdTime desc',
      );
      return fileList.files ?? [];
    } catch (e) {
      print(' Error listing backups: $e');
      return [];
    }
  }

  Future<void> restoreData(String fileId) async {
    if (!isSignedIn) {
      bool signedIn = await signInSilently();
      if (!signedIn) signedIn = await signIn();
      if (!signedIn) return;
    }

    try {
      final mediaFile = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final responseBytes = await mediaFile.stream.expand((bytes) => bytes).toList();
      final String jsonString = utf8.decode(responseBytes);
      final Map<String, dynamic> restoredData = jsonDecode(jsonString);

      await Hive.box<Frame>('frames').clear();
      await Hive.box<Lens>('lenses').clear();
      await Hive.box<Invoice>('invoices').clear();

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

      print(' Restore complete from file ID: $fileId');
    } catch (e) {
      print(' Restore error: $e');
      rethrow;
    }
  }
}
