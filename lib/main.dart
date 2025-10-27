import 'package:flutter/material.dart';
import 'splash/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'services/session_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment variables first
  await SupabaseConfig.initialize();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize session service
  await SessionService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect app state changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    print(
      'DEBUG: App lifecycle state changed from $_appLifecycleState to $state',
    );

    // Only clear session when app is terminated or force-closed
    // DO NOT clear session when app is paused, hidden, or detached
    // This allows the user to resume the app from background
    if (state == AppLifecycleState.detached) {
      print(
        'DEBUG: App detached (force closed) - session will be cleared on next open',
      );
      // Don't clear session here - let the login page check if it's valid
    }

    _appLifecycleState = state;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eCampusPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
