import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import '../config/supabase_config.dart';
import 'encryption_service.dart';

class SessionService {
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userTypeKey = 'user_type';

  // Current user data
  static Map<String, dynamic>? _currentUserData;
  static String? _currentUserType;

  /// Initialize session service
  static Future<void> initialize() async {
    await SupabaseService.initialize();
    await _loadStoredSession();
  }

  /// Load stored session from SharedPreferences
  static Future<void> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn) {
        final userDataString = prefs.getString(_userDataKey);
        final userType = prefs.getString(_userTypeKey);

        if (userDataString != null && userType != null) {
          _currentUserData = Map<String, dynamic>.from(
            Uri.splitQueryString(userDataString),
          );
          _currentUserType = userType;
        }
      }
    } catch (e) {
      print('Error loading stored session: $e');
    }
  }

  /// Save session to SharedPreferences
  static Future<void> saveSession(
    Map<String, dynamic> userData,
    String userType,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userTypeKey, userType);

      // Convert user data to query string format for storage
      final userDataString = userData.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      await prefs.setString(_userDataKey, userDataString);

      _currentUserData = userData;
      _currentUserType = userType;
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  /// Clear session
  static Future<void> clearSession() async {
    try {
      // Clear local variables first
      _currentUserData = null;
      _currentUserType = null;

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userDataKey);
      await prefs.remove(_userTypeKey);

      // Sign out from Supabase
      await SupabaseService.client.auth.signOut();

      print('Session cleared successfully');
    } catch (e) {
      print('Error clearing session: $e');
      // Even if there's an error, clear local data
      _currentUserData = null;
      _currentUserType = null;
    }
  }

  /// Force clear all session data (more aggressive)
  static Future<void> forceClearSession() async {
    try {
      print('DEBUG: Starting force clear session...');

      // Clear local variables
      _currentUserData = null;
      _currentUserType = null;

      // Get SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Save the username before clearing (if it exists)
      final savedUsername = prefs.getString('last_used_username');
      print('DEBUG: Found saved username before clear: $savedUsername');

      // Clear all SharedPreferences data
      await prefs.clear();
      print('DEBUG: SharedPreferences cleared');

      // Restore the saved username
      if (savedUsername != null && savedUsername.isNotEmpty) {
        await prefs.setString('last_used_username', savedUsername);
        print('DEBUG: Restored saved username: $savedUsername');

        // Verify the restore
        final restoredUsername = prefs.getString('last_used_username');
        print(
          'DEBUG: Verification - restored username is now: $restoredUsername',
        );
      } else {
        print('DEBUG: No username to restore');
      }

      // Sign out from Supabase
      await SupabaseService.client.auth.signOut();

      print('DEBUG: Session force cleared successfully');
    } catch (e) {
      print('Error force clearing session: $e');
      // Even if there's an error, clear local data
      _currentUserData = null;
      _currentUserType = null;
    }
  }

  /// Clear session on app termination (preserves username)
  static Future<void> clearSessionOnAppClose() async {
    try {
      print('DEBUG: Clearing session on app close...');

      // Clear local variables
      _currentUserData = null;
      _currentUserType = null;

      // Get SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Save the username before clearing session data
      final savedUsername = prefs.getString('last_used_username');
      print('DEBUG: Preserving username: $savedUsername');

      // Clear only session-related data, preserve username
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userDataKey);
      await prefs.remove(_userTypeKey);

      // Sign out from Supabase
      await SupabaseService.client.auth.signOut();

      print('DEBUG: Session cleared on app close, username preserved');
    } catch (e) {
      print('Error clearing session on app close: $e');
      // Even if there's an error, clear local data
      _currentUserData = null;
      _currentUserType = null;
    }
  }

  /// Check if user is logged in
  static bool get isLoggedIn {
    return _currentUserData != null && _currentUserType != null;
  }

  /// Get current user data
  static Map<String, dynamic>? get currentUserData => _currentUserData;

  /// Get current user type
  static String? get currentUserType => _currentUserType;

  /// Login with email and password
  static Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with Supabase Auth
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {
          'success': false,
          'message': 'Login failed. Please check your credentials.',
        };
      }

      // Get user data from auth_students table
      final userDataResult = await _getUserDataFromAuthStudents(
        response.user!.id,
      );

      if (!userDataResult['success']) {
        await SupabaseService.client.auth.signOut();
        return {
          'success': false,
          'message': 'User data not found. Please contact support.',
        };
      }

      final userData = userDataResult['data'];

      // Save session
      await saveSession(userData, 'student');

      return {
        'success': true,
        'data': userData,
        'message': 'Login successful!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  /// Login with student ID and password (for backward compatibility)
  static Future<Map<String, dynamic>> loginWithStudentId({
    required String studentId,
    required String password,
  }) async {
    try {
      // Look up the user in auth_students table by student_id
      final userLookupResult = await _getUserByStudentIdFromAuthStudents(
        studentId,
      );

      if (!userLookupResult['success']) {
        return {
          'success': false,
          'message': 'Student ID not found. Please check your credentials.',
        };
      }

      final userData = userLookupResult['data'];
      final storedPassword = userData['password'];

      // Verify password using EncryptionService
      final isPasswordValid = EncryptionService.verifyPassword(
        password,
        storedPassword,
      );

      if (!isPasswordValid) {
        return {
          'success': false,
          'message': 'Invalid password. Please check your credentials.',
        };
      }

      // Save session with user data
      await saveSession(userData, 'student');

      return {
        'success': true,
        'data': userData,
        'message': 'Login successful!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  /// Direct login using student ID and password (alternative approach)
  static Future<Map<String, dynamic>> loginWithStudentIdDirect({
    required String studentId,
    required String password,
  }) async {
    try {
      // Look up the user in auth.users table by student_id in user_metadata
      final response =
          await SupabaseService.client
              .from('auth.users')
              .select('id, email, user_metadata')
              .eq('user_metadata->student_id', studentId)
              .maybeSingle();

      if (response == null) {
        return {
          'success': false,
          'message': 'Student ID not found. Please check your credentials.',
        };
      }

      final email = response['email'];

      // Authenticate with Supabase Auth
      final authResponse = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return {
          'success': false,
          'message': 'Invalid credentials. Please check your password.',
        };
      }

      // Get user data from auth_students table
      final userDataResult = await _getUserDataFromAuthStudents(
        authResponse.user!.id,
      );

      if (!userDataResult['success']) {
        await SupabaseService.client.auth.signOut();
        return {
          'success': false,
          'message': 'User data not found. Please contact support.',
        };
      }

      final userData = userDataResult['data'];

      // Save session
      await saveSession(userData, 'student');

      return {
        'success': true,
        'data': userData,
        'message': 'Login successful!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  /// Get user data from auth_students table
  static Future<Map<String, dynamic>> _getUserDataFromAuthStudents(
    String authUserId,
  ) async {
    try {
      final response =
          await SupabaseService.client
              .from(SupabaseConfig.authStudentsTable)
              .select()
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      if (response == null) {
        return {'success': false, 'message': 'User data not found'};
      }

      // Decrypt sensitive data before returning
      final decryptedData = EncryptionService.decryptUserData(response);
      return {'success': true, 'data': decryptedData};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user data: ${e.toString()}',
      };
    }
  }

  /// Get user by student ID from auth_students table
  static Future<Map<String, dynamic>> _getUserByStudentIdFromAuthStudents(
    String studentId,
  ) async {
    try {
      // Query auth_students table by student_id
      final response =
          await SupabaseService.client
              .from(SupabaseConfig.authStudentsTable)
              .select('*')
              .eq('student_id', studentId)
              .maybeSingle();

      if (response == null) {
        return {
          'success': false,
          'message': 'Student ID not found in auth_students',
        };
      }

      // Decrypt the user data
      final decryptedData = EncryptionService.decryptUserData(response);

      return {'success': true, 'data': decryptedData};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user: ${e.toString()}',
      };
    }
  }

  /// Get current user balance
  static double get currentUserBalance {
    if (_currentUserData != null) {
      return double.tryParse(_currentUserData!['balance'].toString()) ?? 0.0;
    }
    return 0.0;
  }

  /// Get current user name (should already be decrypted)
  static String get currentUserName {
    if (_currentUserData != null) {
      try {
        final name = _currentUserData!['name']?.toString() ?? 'Unknown User';
        return name;
      } catch (e) {
        print('Error getting user name: $e');
        return 'Unknown User';
      }
    }
    return 'Unknown User';
  }

  /// Get current user student ID (should already be decrypted)
  static String get currentUserStudentId {
    if (_currentUserData != null) {
      try {
        final studentId = _currentUserData!['student_id']?.toString() ?? '';
        return studentId;
      } catch (e) {
        print('Error getting student ID: $e');
        return '';
      }
    }
    return '';
  }

  /// Get current user course (should already be decrypted)
  static String get currentUserCourse {
    if (_currentUserData != null) {
      try {
        final course = _currentUserData!['course']?.toString() ?? '';

        // Check if the course is still encrypted (contains base64 characters)
        if (course.length > 20 &&
            (course.contains('=') || course.length % 4 == 0)) {
          // If it looks like encrypted data, show a placeholder
          return 'Student Course';
        }

        return course;
      } catch (e) {
        print('Error getting course: $e');
        return '';
      }
    }
    return '';
  }

  /// Update user balance (for transactions)
  static Future<void> updateUserBalance(double newBalance) async {
    if (_currentUserData != null) {
      _currentUserData!['balance'] = newBalance;
      await saveSession(_currentUserData!, _currentUserType!);
    }
  }

  /// Refresh user data from database
  static Future<void> refreshUserData() async {
    if (_currentUserData != null && _currentUserType == 'student') {
      final authUserId = _currentUserData!['auth_user_id'];
      final userDataResult = await _getUserDataFromAuthStudents(authUserId);

      if (userDataResult['success']) {
        await saveSession(userDataResult['data'], 'student');
      }
    }
  }

  /// Check if current user is admin
  static bool get isAdmin {
    return _currentUserType == 'admin';
  }

  /// Check if current user is service
  static bool get isService {
    return _currentUserType == 'service';
  }

  /// Check if current user is student
  static bool get isStudent {
    return _currentUserType == 'student';
  }
}
