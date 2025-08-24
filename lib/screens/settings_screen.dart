import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Validates password format
  bool _isValidPassword(String password) {
    // Check minimum length
    if (password.length < 5) {
      return false;
    }
    
    // Check if contains only alphanumeric characters
    final alphanumericRegex = RegExp(r'^[a-zA-Z0-9]+$');
    return alphanumericRegex.hasMatch(password);
  }

  /// Gets password validation error message
  String? _getPasswordErrorMessage(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 5) {
      return 'Password must be at least 5 characters long';
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(password)) {
      return 'Password must contain only letters and numbers';
    }
    return null;
  }

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
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & FAQ'),
            subtitle: const Text('Get help and find answers to common questions'),
            onTap: () {
              _showHelpDialog(context);
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Help & FAQ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _buildFAQItem(
                  'How do I change my password?',
                  'Go to Settings > Change Password and enter your current password followed by your new password.',
                ),
                const SizedBox(height: 12),
                _buildFAQItem(
                  'What are the password requirements?',
                  'Passwords must be at least 5 characters long and contain only letters and numbers (no special characters).',
                ),
                const SizedBox(height: 12),
                _buildFAQItem(
                  'How do I update company details?',
                  'Tap on Company Details in the Settings menu to update your business information for invoices.',
                ),
                const SizedBox(height: 12),
                _buildFAQItem(
                  'I forgot my password, what should I do?',
                  'Use the "Forgot Password?" option on the login screen and answer the security question.',
                ),
                const SizedBox(height: 12),
                _buildFAQItem(
                  'How do I contact support?',
                  'You can reach our support team at optisupport@gmail.com',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Need more help?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Visit our website at www.optimakers.com/help or contact our support team for personalized assistance.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Q: $question',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'A: $answer',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Password Requirements Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                              const SizedBox(width: 6),
                              Text(
                                'Password Requirements:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• At least 5 characters long\n• Only letters and numbers allowed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Old Password Field
                    TextField(
                      controller: oldPasswordController,
                      obscureText: !oldPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
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
                    const SizedBox(height: 16),
                    
                    // New Password Field
                    TextField(
                      controller: newPasswordController,
                      obscureText: !newPasswordVisible,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), // Only alphanumeric
                      ],
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        helperText: 'Min. 5 characters, letters and numbers only',
                        helperMaxLines: 2,
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
                    const SizedBox(height: 16),
                    
                    // Confirm Password Field
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: !confirmPasswordVisible,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), // Only alphanumeric
                      ],
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: const OutlineInputBorder(),
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
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Dispose controllers
                    oldPasswordController.dispose();
                    newPasswordController.dispose();
                    confirmPasswordController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _changePassword(
                    oldPasswordController.text,
                    newPasswordController.text,
                    confirmPasswordController.text,
                    context,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Changes the password with comprehensive validation
  void _changePassword(String oldPassword, String newPassword, String confirmPassword, BuildContext context) async {
    try {
      // Get stored password
      final userBox = await Hive.openBox('user_credentials');
      final storedPassword = userBox.get('password', defaultValue: 'admin123');

      // Validate current password
      if (oldPassword != storedPassword) {
        _showSnackBar(context, 'Current password is incorrect', Colors.red);
        return;
      }

      // Validate new password format
      final passwordError = _getPasswordErrorMessage(newPassword);
      if (passwordError != null) {
        _showSnackBar(context, passwordError, Colors.red);
        return;
      }

      // Check if passwords match
      if (newPassword != confirmPassword) {
        _showSnackBar(context, 'New passwords do not match', Colors.red);
        return;
      }

      // Check if new password is different from current
      if (newPassword == oldPassword) {
        _showSnackBar(context, 'New password must be different from current password', Colors.orange);
        return;
      }

      // Save new password
      await userBox.put('password', newPassword);
      
      // Close dialog
      Navigator.of(context).pop();
      
      // Show success message
      _showSnackBar(context, 'Password changed successfully!', Colors.green);

    } catch (e) {
      _showSnackBar(context, 'An error occurred while changing password', Colors.red);
    }
  }

  /// Helper method to show snackbar messages
  void _showSnackBar(BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
     ),
    );
  }
}
