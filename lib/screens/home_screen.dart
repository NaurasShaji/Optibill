import 'package:flutter/material.dart';
import 'package:optibill/screens/login_screen.dart'; // To navigate on logout
import 'package:optibill/screens/product_list_screen.dart';
import 'package:optibill/screens/billing_screen.dart';
import 'package:optibill/screens/reports_screen.dart';
import 'package:optibill/screens/backup_restore_screen.dart';
import 'package:optibill/screens/settings_screen.dart'; // Import the new settings screen
import 'package:hive/hive.dart'; // Added for Hive

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of the widgets to display for each tab.
  static const List<Widget> _widgetOptions = <Widget>[
    BillingScreen(),
    ProductListScreen(),
    ReportsScreen(),
    BackupRestoreScreen(),
  ];

  // List of titles corresponding to each tab.
  static const List<String> _appBarTitles = <String>[
    'New Invoice',
    'Products',
    'Reports',
    'Backup & Restore',
  ];

  // This function is called when a tab is tapped.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- Handles selection from the three-dot menu ---
  void _handleMenuSelection(String value) async {
    switch (value) {
      case 'settings':
      // --- Updated: Navigate to the SettingsScreen ---
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;
      case 'logout':
      // --- "Stay Logged In" logic added here ---
      // Clear the login state from Hive so the user has to log in next time.
        final authBox = Hive.box('auth');
        await authBox.put('isLoggedIn', false);
        // --- End of added logic ---

        // Navigate to the LoginScreen and remove all previous routes.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          // The title now dynamically updates based on the selected index.
          title: Text(_appBarTitles[_selectedIndex]),
          centerTitle: true,
          // Set the AppBar color.
          backgroundColor: Colors.blue[800],
          // Add the three-dot menu.
          actions: <Widget>[
            PopupMenuButton<String>(
              onSelected: _handleMenuSelection,
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.black54),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.black54),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
        body: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
        bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt),
                label: 'Billing',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.cloud_upload),
                label: 'Backup/Restore',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.blue[800],
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed, // Ensures all labels are visible
            ),
        );
    }
}
