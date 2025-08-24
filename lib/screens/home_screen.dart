import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optibill/screens/login_screen.dart';
import 'package:optibill/screens/product_list_screen.dart';
import 'package:optibill/screens/billing_screen.dart';
import 'package:optibill/screens/reports_screen.dart';
import 'package:optibill/screens/backup_restore_screen.dart';
import 'package:optibill/screens/settings_screen.dart';
import 'package:hive/hive.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  
  // Use lazy initialization for widgets to improve memory efficiency
  late final List<Widget> _pages;

  // Static configuration data
  static const List<String> _appBarTitles = [
    'New Invoice',
    'Products',
    'Reports',
    'Backup & Restore',
  ];

  static const List<BottomNavigationBarItem> _bottomNavItems = [
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
      icon: Icon(Icons.archive),
      label: 'Archive',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Initialize pages lazily
    _pages = const [
      BillingScreen(),
      ProductListScreen(),
      ReportsScreen(),
      BackupRestoreScreen(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      final authBox = Hive.box('auth');
      await authBox.put('isLoggedIn', false);
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Handle error if needed
      debugPrint('Logout error: $e');
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'settings':
        _navigateToSettings();
        break;
      case 'logout':
        _handleLogout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitles[_selectedIndex]),
          centerTitle: true,
          backgroundColor: Colors.blue,
          actions: [
            PopupMenuButton<String>(
              onSelected: _handleMenuSelection,
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'settings',
                  child: _MenuOption(
                    icon: Icons.settings,
                    text: 'Settings',
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: _MenuOption(
                    icon: Icons.logout,
                    text: 'Logout',
                  ),
                ),
              ],
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: _bottomNavItems,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue[800],
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
        ),
      ),
    );
  }
}

// Extracted menu option widget for better reusability and performance
class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MenuOption({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
