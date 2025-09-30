class SupabaseConfig {
  // Supabase configuration
  static const String supabaseUrl = 'https://weesgvewyuozivhedhej.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlZXNndmV3eXVveml2aGVkaGVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNzUzMTUsImV4cCI6MjA3MjY1MTMxNX0.CVjV_oUll7IfOdITgyAB9jNrWpS_sYNnfQG5Ke7IgbU';

  // Service role key for admin operations (bypasses RLS)
  static const String supabaseServiceKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlZXNndmV3eXVveml2aGVkaGVqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA3NTMxNSwiZXhwIjoyMDcyNjUxMzE1fQ.jd0rmNyc9x6lPpWk0-WXJTeb929mqah1PbNuh8C6hE0';

  // Table names
  static const String studentInfoTable =
      'student_info'; // For CSV import and autofill
  static const String authStudentsTable =
      'auth_students'; // For authentication registration
}
