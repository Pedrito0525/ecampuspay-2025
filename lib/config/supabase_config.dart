import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration class that loads configuration from environment variables
///
/// This class provides a centralized way to access Supabase configuration
/// while keeping sensitive data in environment variables for security.
class SupabaseConfig {
  // Initialize environment variables - call this in main() before runApp()
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
  }

  // Supabase configuration from environment variables
  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env: SUPABASE_URL');
    }
    return _ensureHttps(value);
  }

  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env: SUPABASE_ANON_KEY');
    }
    return value;
  }

  // Service role key for admin operations (bypasses RLS)
  static String get supabaseServiceKey {
    // Align with deno.env naming: SUPABASE_SERVICE_ROLE_KEY
    final value = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env: SUPABASE_SERVICE_ROLE_KEY');
    }
    return value;
  }

  // Custom app secret
  static String get ecampusPaySecret {
    final value = dotenv.env['ECAMPUSPAY_SECRET'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env: ECAMPUSPAY_SECRET');
    }
    return value;
  }

  // Table names (these can remain as constants since they don't contain secrets)
  static const String studentInfoTable =
      'student_info'; // For CSV import and autofill
  static const String authStudentsTable =
      'auth_students'; // For authentication registration

  // Helper method to validate that required environment variables are loaded
  static bool get isEnvironmentLoaded => dotenv.isInitialized;

  // Ensure Supabase URL uses HTTPS and has a proper scheme
  static String _ensureHttps(String url) {
    var normalized = url.trim();
    if (normalized.isEmpty) return normalized;

    // Add scheme if missing
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://' + normalized;
    }

    // Force https
    if (normalized.startsWith('http://')) {
      normalized = normalized.replaceFirst('http://', 'https://');
    }

    // Remove trailing slash for consistency
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}
