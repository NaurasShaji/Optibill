import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue[800],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Change Password'),
            subtitle: const Text('Update the login password'),
            onTap: () {
              _showChangePasswordDialog(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Company Details'),
            subtitle: const Text('Set your company name and address for invoices'),
            onTap: () {
              // TODO: Navigate to a company details screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Company Details Tapped')),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'), // Example version number
            onTap: () {},
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool oldPasswordVisible = false;
    bool newPasswordVisible = false;
    bool confirmPasswordVisible = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPasswordController,
                    obscureText: !oldPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Old Password',
                      suffixIcon: IconButton(
                        icon: Icon(oldPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            oldPasswordVisible = !oldPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPasswordController,
                    obscureText: !newPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(newPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            newPasswordVisible = !newPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !confirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      suffixIcon: IconButton(
                        icon: Icon(confirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            confirmPasswordVisible = !confirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final userBox = await Hive.openBox('user_credentials');
                    final storedPassword = userBox.get('password');
                    if (oldPasswordController.text != storedPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Old password is incorrect'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (newPasswordController.text != confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New passwords do not match'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (newPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New password cannot be empty'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    await userBox.put('password', newPasswordController.text);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}