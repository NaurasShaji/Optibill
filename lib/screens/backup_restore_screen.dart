import 'package:flutter/material.dart';
import 'package:optibill/services/google_drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
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
        _listBackupFiles(); // List files immediately after sign-in
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
      _listBackupFiles(); // Refresh list after backup
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
                Navigator.of(context).pop(); // Close dialog
                setState(() {
                  _isRestoring = true;
                });
                try {
                  await _googleDriveService.restoreData(file.id!);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  SizedBox(height: 16),
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
                        // Corrected access to currentUser
                        Text('Signed in as: ${_googleDriveService.currentUser?.displayName ?? 'N/A'}'),
                        SizedBox(height: 10),
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
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _googleDriveService.isSignedIn && !_isBackingUp
                ? _handleBackup
                : null,
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
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _googleDriveService.isSignedIn && !_isRestoring
                ? _listBackupFiles // First list, then user selects to restore
                : null,
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
          SizedBox(height: 24),
          if (_backupFiles.isNotEmpty && _googleDriveService.isSignedIn)
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Backups:', style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
