import 'package:flutter/material.dart';
import 'splash_page.dart';
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

  // Force clear any existing session to ensure fresh login
  await SessionService.initialize();
  await SessionService.forceClearSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const SplashPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Removed the default counter page; app now starts at LoginPage.
