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

    // Clear session when app is paused, detached, or hidden
    // This ensures session is cleared when app is closed/backgrounded
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      print('DEBUG: App lifecycle changed to $state - clearing session');
      _clearSessionOnAppClose();
    }
  }

  /// Clear session when app closes or goes to background
  Future<void> _clearSessionOnAppClose() async {
    try {
      // Only clear session if user is actually logged in
      if (SessionService.isLoggedIn) {
        print('DEBUG: User is logged in, clearing session due to app close');
        await SessionService.clearSessionOnAppClose();
      } else {
        print('DEBUG: No active session to clear');
      }
    } catch (e) {
      print('DEBUG: Error clearing session on app close: $e');
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecampuspay',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB01212)),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        // Add responsive design support
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Removed the default counter page; app now starts at LoginPage.
