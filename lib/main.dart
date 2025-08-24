import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:optibill/screens/home_screen.dart';
import 'package:optibill/screens/login_screen.dart';
import 'package:optibill/utils/initial_data.dart';
import 'package:optibill/services/google_drive_service.dart'; // Import the Google Drive service
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
  await InitialDataLoader.loadInitialProducts();

  // Attempt silent sign-in to Google Drive at startup if user is logged in
  bool googleDriveSignedIn = false;
  googleDriveSignedIn = await GoogleDriveService().signInSilently();

  // Pass the login status and Google Drive sign-in status to the MyApp widget.
  runApp(MyApp(isLoggedIn: isLoggedIn, googleDriveSignedIn: googleDriveSignedIn));
}

class MyApp extends StatelessWidget {
  // --- This property holds the login status ---
  final bool isLoggedIn;
  final bool googleDriveSignedIn; // Add property for Google Drive sign-in status

  // --- The constructor now accepts the isLoggedIn and googleDriveSignedIn parameters ---
  const MyApp({super.key, required this.isLoggedIn, required this.googleDriveSignedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OptiBill',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter', // Using Inter font as requested
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0, // Always use fixed 1.0 scale factor
          ),
          child: child!,
        );
      },
      // --- Choose the home screen based on the login status ---
      // You might want to pass googleDriveSignedIn to HomeScreen if needed there
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}