import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:optibill/screens/home_screen.dart';
import 'package:optibill/screens/login_screen.dart';

// Import your models (assuming they are needed for other initializations)
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/models/invoice_item.dart';
import 'package:optibill/models/invoice.dart';

void main() async {
  // Ensure that Flutter widgets are initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local data storage.
  final appDocumentDir = await getApplicationDocumentsDirectory();
  // Corrected a small typo here from appDocument_dir to appDocumentDir
  await Hive.initFlutter(appDocumentDir.path);

  // Register all necessary Hive Adapters.
  Hive.registerAdapter(FrameAdapter());
  Hive.registerAdapter(LensAdapter());
  Hive.registerAdapter(InvoiceItemAdapter());
  Hive.registerAdapter(InvoiceAdapter());

  // Open Hive boxes to store and retrieve data.
  await Hive.openBox<Frame>('frames');
  await Hive.openBox<Lens>('lenses');
  await Hive.openBox<Invoice>('invoices');
  await Hive.openBox('user_credentials');

  // --- Open a box for authentication state ---
  await Hive.openBox('auth');
  final authBox = Hive.box('auth');
  // Check if the user is already logged in.
  final bool isLoggedIn = authBox.get('isLoggedIn', defaultValue: false);

  // Pass the login status to the MyApp widget.
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  // --- This property holds the login status ---
  final bool isLoggedIn;

  // --- The constructor now accepts the isLoggedIn parameter ---
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OptiBill',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter', // Using Inter font as requested
      ),
      // --- Choose the home screen based on the login status ---
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
