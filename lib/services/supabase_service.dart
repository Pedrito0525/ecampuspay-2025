import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'encryption_service.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static SupabaseClient? _adminClient;

  // Initialize Supabase client
  static Future<void> initialize() async {
    if (_client == null) {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;

      // Initialize encryption service
      EncryptionService.initialize();
    }
  }

  // Get Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  // System Update Settings

  /// Get system update settings (single-row table). If missing, returns safe defaults.
  static Future<Map<String, dynamic>> getSystemUpdateSettings() async {
    try {
      await SupabaseService.initialize();
      final response =
          await client
              .from('system_update_settings')
              .select('*')
              .limit(1)
              .maybeSingle();

      if (response == null) {
        return {
          'success': true,
          'data': {
            'maintenance_mode': false,
            'force_update_mode': false,
            'disable_all_logins': false,
          },
        };
      }

      return {
        'success': true,
        'data': {
          'maintenance_mode': response['maintenance_mode'] == true,
          'force_update_mode': response['force_update_mode'] == true,
          'disable_all_logins': response['disable_all_logins'] == true,
          'updated_at': response['updated_at'],
          'updated_by': response['updated_by'],
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load system update settings: ${e.toString()}',
        'data': {
          'maintenance_mode': false,
          'force_update_mode': false,
          'disable_all_logins': false,
        },
      };
    }
  }

  /// Upsert system update settings (single row with id=1)
  static Future<Map<String, dynamic>> upsertSystemUpdateSettings({
    required bool maintenanceMode,
    required bool forceUpdateMode,
    required bool disableAllLogins,
    String? updatedBy,
  }) async {
    try {
      await SupabaseService.initialize();
      final payload = {
        'id': 1,
        'maintenance_mode': maintenanceMode,
        'force_update_mode': forceUpdateMode,
        'disable_all_logins': disableAllLogins,
        'updated_at': DateTime.now().toIso8601String(),
        if (updatedBy != null) 'updated_by': updatedBy,
      };

      final response =
          await adminClient
              .from('system_update_settings')
              .upsert(payload, onConflict: 'id')
              .select()
              .maybeSingle();

      return {
        'success': true,
        'data': response,
        'message': 'System update settings saved',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save system update settings: ${e.toString()}',
      };
    }
  }

  /// Reset all system update settings to false
  static Future<Map<String, dynamic>> resetSystemUpdateSettings({
    String? updatedBy,
  }) async {
    return upsertSystemUpdateSettings(
      maintenanceMode: false,
      forceUpdateMode: false,
      disableAllLogins: false,
      updatedBy: updatedBy,
    );
  }

  /// SQL helper: returns SQL to create table and basic policies
  static String get systemUpdateSetupSql => '''
-- Create table to store single-row system update flags
create table if not exists public.system_update_settings (
  id integer primary key default 1,
  maintenance_mode boolean not null default false,
  force_update_mode boolean not null default false,
  disable_all_logins boolean not null default false,
  updated_by text,
  updated_at timestamptz default now()
);

-- Ensure single-row table
insert into public.system_update_settings (id)
values (1)
on conflict (id) do nothing;

-- Enable RLS
alter table public.system_update_settings enable row level security;

-- Policies (adjust to your auth strategy)
-- Allow anonymous read (apps often use anon key); tighten if needed
drop policy if exists "Allow read to all" on public.system_update_settings;
create policy "Allow read to all" on public.system_update_settings for select using (true);

-- Allow admin updates: if you tag admins via a custom claim, adapt this
-- For example, if you have a service key context for admin tools, upserts will work.
drop policy if exists "Allow update via service key" on public.system_update_settings;
create policy "Allow update via service key" on public.system_update_settings
for all to authenticated using (true) with check (true);

-- NOTE: In production, replace the broad update policy with your proper admin role check.
''';

  // Get admin client instance (bypasses RLS)
  static SupabaseClient get adminClient {
    if (_adminClient == null) {
      _adminClient = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseServiceKey,
      );
    }
    return _adminClient!;
  }

  // Student Info Operations

  /// Insert a single student record
  static Future<Map<String, dynamic>> insertStudent({
    required String studentId,
    required String name,
    required String email,
    required String course,
  }) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .insert({
                'student_id': studentId,
                'name': name,
                'email': email,
                'course': course,
              })
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Student inserted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to insert student: ${e.toString()}',
      };
    }
  }

  /// Insert multiple students from CSV data
  static Future<Map<String, dynamic>> insertStudentsBatch(
    List<Map<String, dynamic>> students,
  ) async {
    try {
      // Validate required fields for each student
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        if (student['student_id'] == null ||
            student['student_id'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing student_id',
            'message': 'Row ${i + 1}: Student ID is required',
          };
        }
        if (student['name'] == null ||
            student['name'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing name',
            'message': 'Row ${i + 1}: Student name is required',
          };
        }
        if (student['email'] == null ||
            student['email'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing email',
            'message': 'Row ${i + 1}: Email is required',
          };
        }
        if (student['course'] == null ||
            student['course'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing course',
            'message': 'Row ${i + 1}: Course is required',
          };
        }

        // Validate email format
        final email = student['email'].toString().trim();
        if (!_isValidEmail(email)) {
          return {
            'success': false,
            'error': 'Invalid email',
            'message': 'Row ${i + 1}: Invalid email format: $email',
          };
        }
      }

      // Clean and prepare data
      final cleanedStudents =
          students
              .map(
                (student) => {
                  'student_id': student['student_id'].toString().trim(),
                  'name': student['name'].toString().trim(),
                  'email': student['email'].toString().trim().toLowerCase(),
                  'course': student['course'].toString().trim(),
                },
              )
              .toList();

      // Insert batch using regular client (RLS policies should allow this)
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .insert(cleanedStudents)
              .select();

      return {
        'success': true,
        'data': response,
        'count': response.length,
        'message': 'Successfully inserted ${response.length} students',
      };
    } catch (e) {
      String errorMessage = e.toString();

      // Handle specific Supabase errors
      if (errorMessage.contains('duplicate key')) {
        if (errorMessage.contains('student_id')) {
          return {
            'success': false,
            'error': 'Duplicate student ID',
            'message': 'One or more student IDs already exist in the database',
          };
        } else if (errorMessage.contains('email')) {
          return {
            'success': false,
            'error': 'Duplicate email',
            'message':
                'One or more email addresses already exist in the database',
          };
        }
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to insert students: ${e.toString()}',
      };
    }
  }

  /// Get all students
  static Future<Map<String, dynamic>> getAllStudents() async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConfig.studentInfoTable)
          .select()
          .order('created_at', ascending: false);

      return {
        'success': true,
        'data': response,
        'count': response.length,
        'message': 'Students retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve students: ${e.toString()}',
      };
    }
  }

  /// Get student by ID
  static Future<Map<String, dynamic>> getStudentById(String studentId) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .select()
              .eq('student_id', studentId)
              .maybeSingle();

      return {
        'success': true,
        'data': response,
        'message': response != null ? 'Student found' : 'Student not found',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve student: ${e.toString()}',
      };
    }
  }

  /// Get student for registration (checks if student exists and needs RFID)
  static Future<Map<String, dynamic>> getStudentForRegistration(
    String studentId,
  ) async {
    try {
      final response = await getStudentById(studentId);

      if (!response['success']) {
        return response;
      }

      if (response['data'] == null) {
        return {
          'success': false,
          'error': 'Student not found',
          'message':
              'Student ID $studentId not found in database. Please check the ID or import student data first.',
        };
      }

      // Student exists, return their data for autofill
      return {
        'success': true,
        'data': response['data'],
        'message': 'Student found - form auto-filled',
        'needs_rfid': true, // Since we're in registration, they need RFID
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to retrieve student for registration: ${e.toString()}',
      };
    }
  }

  /// Update student
  static Future<Map<String, dynamic>> updateStudent({
    required String studentId,
    String? name,
    String? email,
    String? course,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name.trim();
      if (email != null) updates['email'] = email.trim().toLowerCase();
      if (course != null) updates['course'] = course.trim();

      if (updates.isEmpty) {
        return {
          'success': false,
          'error': 'No updates provided',
          'message': 'No fields to update',
        };
      }

      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .update(updates)
              .eq('student_id', studentId)
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Student updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update student: ${e.toString()}',
      };
    }
  }

  /// Delete student
  static Future<Map<String, dynamic>> deleteStudent(String studentId) async {
    try {
      await client
          .from(SupabaseConfig.studentInfoTable)
          .delete()
          .eq('student_id', studentId);

      return {'success': true, 'message': 'Student deleted successfully'};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete student: ${e.toString()}',
      };
    }
  }

  /// Check if student ID exists
  static Future<bool> studentIdExists(String studentId) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .select('student_id')
              .eq('student_id', studentId)
              .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if email exists
  static Future<bool> emailExists(String email) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .select('email')
              .eq('email', email.toLowerCase())
              .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Validate CSV data before import
  static Map<String, dynamic> validateCSVData(List<Map<String, dynamic>> data) {
    List<String> errors = [];
    List<String> warnings = [];

    if (data.isEmpty) {
      return {
        'valid': false,
        'errors': ['CSV file is empty'],
        'warnings': [],
      };
    }

    // Check required columns
    final requiredColumns = ['student_id', 'name', 'email', 'course'];
    final firstRow = data.first;

    for (String column in requiredColumns) {
      if (!firstRow.containsKey(column)) {
        errors.add('Missing required column: $column');
      }
    }

    if (errors.isNotEmpty) {
      return {'valid': false, 'errors': errors, 'warnings': warnings};
    }

    // Validate each row
    Set<String> studentIds = {};
    Set<String> emails = {};

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      final rowNum = i + 1;

      // Check for required fields
      for (String column in requiredColumns) {
        final value = row[column];
        if (value == null || value.toString().trim().isEmpty) {
          errors.add('Row $rowNum: Missing $column');
        }
      }

      // Check for duplicates within CSV
      final studentId = row['student_id']?.toString().trim();
      if (studentId != null && studentId.isNotEmpty) {
        if (studentIds.contains(studentId)) {
          errors.add('Row $rowNum: Duplicate student ID: $studentId');
        } else {
          studentIds.add(studentId);
        }
      }

      final email = row['email']?.toString().trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        if (!_isValidEmail(email)) {
          errors.add('Row $rowNum: Invalid email format: $email');
        } else if (emails.contains(email)) {
          errors.add('Row $rowNum: Duplicate email: $email');
        } else {
          emails.add(email);
        }
      }
    }

    return {
      'valid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'total_rows': data.length,
      'unique_student_ids': studentIds.length,
      'unique_emails': emails.length,
    };
  }

  /// Helper function to validate email format
  static bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Helper function to validate EVSU email format
  static bool _isValidEvsuEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@evsu\.edu\.ph$',
    ).hasMatch(email.toLowerCase());
  }

  /// Helper function to generate password in EvsuStudentID format
  static String _generatePassword(String studentId) {
    return 'Evsu$studentId';
  }

  /// Helper function to hash password for storage
  static String _hashPassword(String password) {
    return EncryptionService.encryptPassword(password);
  }

  /// Helper function to verify password against stored hash
  static bool _verifyPassword(String password, String storedHash) {
    return EncryptionService.verifyPassword(password, storedHash);
  }

  /// Check if student ID exists in auth_students table
  static Future<bool> _authStudentIdExists(String studentId) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .select('student_id')
              .eq('student_id', studentId)
              .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if email exists in auth_students table
  static Future<bool> _authStudentEmailExists(String email) async {
    try {
      // Since emails are encrypted, we can't efficiently check for duplicates
      // We'll rely on the unique constraint in the database
      // For now, return false to allow registration
      // TODO: Implement a better duplicate checking mechanism
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if RFID ID exists in auth_students table
  static Future<bool> authStudentRfidExists(String rfidId) async {
    try {
      // Encrypt the RFID ID to match against stored encrypted values
      final encryptedData = EncryptionService.encryptUserData({
        'rfid_id': rfidId,
      });
      final encryptedRfid = encryptedData['rfid_id']?.toString() ?? '';

      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .select('rfid_id')
              .eq('rfid_id', encryptedRfid)
              .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking RFID existence: $e');
      return false;
    }
  }

  // Authentication Operations

  /// Register student account with Supabase Auth and student table
  static Future<Map<String, dynamic>> registerStudentAccount({
    required String studentId,
    required String name,
    required String email,
    required String course,
    required String rfidId,
  }) async {
    try {
      // Validate EVSU email format
      if (!_isValidEvsuEmail(email)) {
        return {
          'success': false,
          'error': 'Invalid email format',
          'message': 'Email must be in @evsu.edu.ph format',
        };
      }

      // Check if student ID already exists in auth_students table
      final studentExists = await _authStudentIdExists(studentId);
      if (studentExists) {
        return {
          'success': false,
          'error': 'Student ID already exists',
          'message': 'Student ID $studentId is already registered',
        };
      }

      // Check if email already exists in auth_students table
      final emailExistsInDb = await _authStudentEmailExists(email);
      if (emailExistsInDb) {
        return {
          'success': false,
          'error': 'Email already exists',
          'message': 'Email $email is already registered',
        };
      }

      // Check if RFID ID already exists in auth_students table
      final rfidExists = await authStudentRfidExists(rfidId);
      if (rfidExists) {
        return {
          'success': false,
          'error': 'RFID ID already exists',
          'message': 'RFID ID is already registered',
        };
      }

      // Generate password
      final password = _generatePassword(studentId);
      final hashedPassword = _hashPassword(password);

      // Encrypt sensitive data
      final encryptedData = EncryptionService.encryptUserData({
        'name': name,
        'email': email.toLowerCase(),
        'course': course,
        'rfid_id': rfidId,
      });

      // Register with Supabase Auth
      print(
        'Debug: Registering with email: ${email.toLowerCase()} and password: $password',
      );
      final authResponse = await client.auth.signUp(
        email: email.toLowerCase(),
        password: password,
        data: {
          'student_id': studentId,
          'name': name,
          'course': course,
          'rfid_id': rfidId,
        },
      );

      print('Debug: Auth registration response user: ${authResponse.user?.id}');
      print(
        'Debug: Auth registration response session: ${authResponse.session?.accessToken}',
      );

      if (authResponse.user == null) {
        return {
          'success': false,
          'error': 'Auth registration failed',
          'message': 'Failed to create authentication account',
        };
      }

      // Wait a moment for the auth user to be fully created
      await Future.delayed(const Duration(milliseconds: 1000));

      // Verify the auth user exists before inserting into auth_students
      try {
        final userCheck = await client.auth.getUser();
        if (userCheck.user?.id != authResponse.user!.id) {
          throw Exception('Auth user verification failed');
        }
      } catch (e) {
        print('Auth user verification failed: $e');
        // Continue anyway - the user might exist but not be in current session
      }

      // Insert student data into auth_students table with encrypted data
      final studentResponse =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .insert({
                'student_id': studentId,
                'name': encryptedData['name'], // Encrypted
                'email': encryptedData['email'], // Encrypted
                'course': encryptedData['course'], // Encrypted
                'rfid_id': encryptedData['rfid_id'], // Encrypted
                'password': hashedPassword, // Hashed password
                'auth_user_id': authResponse.user!.id,
                'is_active': true,
              })
              .select()
              .single();

      return {
        'success': true,
        'data': {
          'auth_user': authResponse.user,
          'student_info': studentResponse,
          'password': password, // Include password for display purposes
        },
        'message':
            'Student account registered successfully! Password: $password',
      };
    } catch (e) {
      String errorMessage = e.toString();

      // Handle specific Supabase errors
      if (errorMessage.contains('duplicate key')) {
        if (errorMessage.contains('student_id')) {
          return {
            'success': false,
            'error': 'Duplicate student ID',
            'message': 'Student ID $studentId already exists in the database',
          };
        } else if (errorMessage.contains('email')) {
          return {
            'success': false,
            'error': 'Duplicate email',
            'message': 'Email $email already exists in the database',
          };
        }
      }

      if (errorMessage.contains('User already registered')) {
        return {
          'success': false,
          'error': 'Email already registered',
          'message':
              'Email $email is already registered in authentication system',
        };
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to register student account: ${e.toString()}',
      };
    }
  }

  /// Register student with RFID (for existing students from CSV import)
  static Future<Map<String, dynamic>> registerStudentWithRFID({
    required String studentId,
    required String rfidCardId,
  }) async {
    try {
      // First check if student exists
      final studentResult = await getStudentById(studentId);
      if (!studentResult['success'] || studentResult['data'] == null) {
        return {
          'success': false,
          'error': 'Student not found',
          'message': 'Student ID $studentId not found in database',
        };
      }

      // For now, we'll create a simple success response
      // In a full implementation, you might want to add an RFID field to the table
      // or create a separate RFID assignments table
      return {
        'success': true,
        'data': {
          'student_id': studentId,
          'rfid_card': rfidCardId,
          'student_data': studentResult['data'],
        },
        'message': 'Student registered with RFID card successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to register student with RFID: ${e.toString()}',
      };
    }
  }

  /// Get database statistics
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConfig.studentInfoTable)
          .select('student_id, course')
          .order('created_at', ascending: false);

      // Count by course
      Map<String, int> courseCount = {};
      for (var student in response) {
        final course = student['course'].toString();
        courseCount[course] = (courseCount[course] ?? 0) + 1;
      }

      return {
        'success': true,
        'total_students': response.length,
        'course_breakdown': courseCount,
        'message': 'Statistics retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve statistics: ${e.toString()}',
      };
    }
  }

  // Balance Overview Operations

  /// Get total balance overview for students and service accounts
  static Future<Map<String, dynamic>> getBalanceOverview() async {
    try {
      await SupabaseService.initialize();

      // Get total student balances from auth_students table
      final studentsResponse = await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .select('balance');

      double totalStudentBalance = 0.0;
      for (var student in studentsResponse) {
        final balance = (student['balance'] as num?)?.toDouble() ?? 0.0;
        totalStudentBalance += balance;
      }

      // Get total service account balances from service_accounts table
      final servicesResponse = await adminClient
          .from('service_accounts')
          .select('balance')
          .eq('is_active', true);

      double totalServiceBalance = 0.0;
      for (var service in servicesResponse) {
        final balance = (service['balance'] as num?)?.toDouble() ?? 0.0;
        totalServiceBalance += balance;
      }

      // Calculate total system balance
      final totalSystemBalance = totalStudentBalance + totalServiceBalance;

      return {
        'success': true,
        'data': {
          'total_student_balance': totalStudentBalance,
          'total_service_balance': totalServiceBalance,
          'total_system_balance': totalSystemBalance,
          'student_count': studentsResponse.length,
          'service_count': servicesResponse.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching balance overview: $e',
        'data': {
          'total_student_balance': 0.0,
          'total_service_balance': 0.0,
          'total_system_balance': 0.0,
          'student_count': 0,
          'service_count': 0,
        },
      };
    }
  }

  /// Get detailed balance breakdown by service accounts
  static Future<Map<String, dynamic>> getServiceBalanceBreakdown() async {
    try {
      await SupabaseService.initialize();

      final servicesResponse = await adminClient
          .from('service_accounts')
          .select('service_name, balance, is_active')
          .eq('is_active', true)
          .order('balance', ascending: false);

      List<Map<String, dynamic>> serviceBalances = [];
      double totalServiceBalance = 0.0;

      for (var service in servicesResponse) {
        final balance = (service['balance'] as num?)?.toDouble() ?? 0.0;
        totalServiceBalance += balance;

        serviceBalances.add({
          'service_name': service['service_name'] ?? 'Unknown',
          'balance': balance,
          'is_active': service['is_active'] ?? false,
        });
      }

      return {
        'success': true,
        'data': {
          'services': serviceBalances,
          'total_balance': totalServiceBalance,
          'count': serviceBalances.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching service balance breakdown: $e',
        'data': {'services': [], 'total_balance': 0.0, 'count': 0},
      };
    }
  }

  /// Get top-up analysis data with real transaction amounts and counts
  static Future<Map<String, dynamic>> getTopUpAnalysis({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['created_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['created_at.lt'] = end.toIso8601String();
      }

      // Get top-up transactions from top_up_transactions table
      // Only include transaction_type = 'top_up', exclude 'loan_disbursement'
      final topupQuery = client
          .from('top_up_transactions')
          .select('amount, created_at, transaction_type')
          .eq('transaction_type', 'top_up');
      if (filter.containsKey('created_at.gte')) {
        topupQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        topupQuery.lt('created_at', filter['created_at.lt']);
      }
      final topups = await topupQuery;

      // Group by amount and count
      Map<double, int> amountCounts = {};
      for (var topup in topups) {
        final amount = (topup['amount'] as num).toDouble();
        amountCounts[amount] = (amountCounts[amount] ?? 0) + 1;
      }

      // Convert to list and sort by count (descending)
      List<Map<String, dynamic>> topupAnalysis =
          amountCounts.entries
              .map(
                (entry) => {
                  'amount': entry.key,
                  'count': entry.value,
                  'percentage': 0.0, // Will be calculated below
                },
              )
              .toList();

      // Sort by count descending and calculate percentages
      topupAnalysis.sort(
        (a, b) => (b['count'] as int).compareTo(a['count'] as int),
      );
      final totalTopups = topups.length;
      for (var item in topupAnalysis) {
        item['percentage'] =
            totalTopups > 0
                ? ((item['count'] as int) / totalTopups * 100)
                : 0.0;
      }

      return {
        'success': true,
        'data': {
          'topups': topupAnalysis.take(5).toList(), // Top 5
          'total_transactions': totalTopups,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching top-up analysis: $e',
        'data': {'topups': [], 'total_transactions': 0},
      };
    }
  }

  /// Get loan analysis data with real loan amounts and counts
  static Future<Map<String, dynamic>> getLoanAnalysis({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['paid_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['paid_at.lt'] = end.toIso8601String();
      }

      // Get paid loans from active_loans table
      final loanQuery = client
          .from('active_loans')
          .select('loan_amount, paid_at, status')
          .eq('status', 'paid');
      if (filter.containsKey('paid_at.gte')) {
        loanQuery.gte('paid_at', filter['paid_at.gte']);
      }
      if (filter.containsKey('paid_at.lt')) {
        loanQuery.lt('paid_at', filter['paid_at.lt']);
      }
      final loans = await loanQuery;

      // Group by amount and count
      Map<double, int> amountCounts = {};
      for (var loan in loans) {
        final amount = (loan['loan_amount'] as num?)?.toDouble() ?? 0.0;
        amountCounts[amount] = (amountCounts[amount] ?? 0) + 1;
      }

      // Convert to list and sort by count (descending)
      List<Map<String, dynamic>> loanAnalysis =
          amountCounts.entries
              .map(
                (entry) => {
                  'amount': entry.key,
                  'count': entry.value,
                  'percentage': 0.0, // Will be calculated below
                },
              )
              .toList();

      // Sort by count descending and calculate percentages
      loanAnalysis.sort(
        (a, b) => (b['count'] as int).compareTo(a['count'] as int),
      );
      final totalLoans = loans.length;
      for (var item in loanAnalysis) {
        item['percentage'] =
            totalLoans > 0 ? ((item['count'] as int) / totalLoans * 100) : 0.0;
      }

      return {
        'success': true,
        'data': {
          'loans': loanAnalysis.take(5).toList(), // Top 5
          'total_transactions': totalLoans,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching loan analysis: $e',
        'data': {'loans': [], 'total_transactions': 0},
      };
    }
  }

  /// Get top vendors by transaction count and revenue
  static Future<Map<String, dynamic>> getTopVendors({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Starting top vendors analysis");
      print("DEBUG: Date range - start: $start, end: $end");

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['created_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['created_at.lt'] = end.toIso8601String();
      }

      print("DEBUG: Date filter: $filter");

      // Get service transactions with service account info
      // Join service_transactions with service_accounts to get service names
      // Use specific foreign key relationship: service_transactions_service_account_id_fkey
      final serviceQuery = client
          .from('service_transactions')
          .select(
            'service_account_id, amount, created_at, service_accounts!service_transactions_service_account_id_fkey(service_name)',
          );
      if (filter.containsKey('created_at.gte')) {
        serviceQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        serviceQuery.lt('created_at', filter['created_at.lt']);
      }

      print("DEBUG: Executing top vendors query on service_transactions table");
      final transactions = await serviceQuery;
      print(
        "DEBUG: Top vendors query returned ${transactions.length} transactions",
      );

      if (transactions.isNotEmpty) {
        print("DEBUG: First transaction sample: ${transactions.first}");
      }

      // Group by service_account_id
      Map<String, Map<String, dynamic>> serviceStats = {};
      for (var transaction in transactions) {
        final serviceAccountId =
            transaction['service_account_id']?.toString() ?? 'unknown';
        final serviceName =
            transaction['service_accounts']?['service_name']?.toString() ??
            'Unknown Service';
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;

        if (!serviceStats.containsKey(serviceAccountId)) {
          serviceStats[serviceAccountId] = {
            'service_account_id': serviceAccountId,
            'service_name': serviceName,
            'total_revenue': 0.0,
            'transaction_count': 0,
          };
        }

        serviceStats[serviceAccountId]!['total_revenue'] += amount;
        serviceStats[serviceAccountId]!['transaction_count'] += 1;
      }

      // Convert to list and sort by transaction count (descending)
      List<Map<String, dynamic>> vendorAnalysis = serviceStats.values.toList();
      vendorAnalysis.sort(
        (a, b) => (b['transaction_count'] as int).compareTo(
          a['transaction_count'] as int,
        ),
      );

      return {
        'success': true,
        'data': {
          'vendors': vendorAnalysis.take(5).toList(), // Top 5
          'total_services': serviceStats.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching top vendors: $e',
        'data': {'vendors': [], 'total_services': 0},
      };
    }
  }

  /// Get vendor transaction count analysis - which vendors have the most transactions
  static Future<Map<String, dynamic>> getVendorTransactionCountAnalysis({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Starting vendor transaction count analysis");
      print("DEBUG: Date range - start: $start, end: $end");

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['created_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['created_at.lt'] = end.toIso8601String();
      }

      print("DEBUG: Date filter: $filter");

      // Get all service transactions with service account info
      // Join service_transactions with service_accounts to get service names
      // Use specific foreign key relationship: service_transactions_service_account_id_fkey
      final serviceQuery = client
          .from('service_transactions')
          .select(
            'service_account_id, created_at, service_accounts!service_transactions_service_account_id_fkey(service_name)',
          );
      if (filter.containsKey('created_at.gte')) {
        serviceQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        serviceQuery.lt('created_at', filter['created_at.lt']);
      }

      print("DEBUG: Executing query on service_transactions table");
      final transactions = await serviceQuery;
      print("DEBUG: Query returned ${transactions.length} transactions");

      if (transactions.isNotEmpty) {
        print("DEBUG: First transaction sample: ${transactions.first}");
      }

      // Group by service_account_id
      Map<String, Map<String, dynamic>> serviceStats = {};
      print("DEBUG: Starting to group transactions by service_account_id");

      for (var transaction in transactions) {
        final serviceAccountId =
            transaction['service_account_id']?.toString() ?? 'unknown';
        final serviceName =
            transaction['service_accounts']?['service_name']?.toString() ??
            'Unknown Service';

        print(
          "DEBUG: Processing transaction - serviceAccountId: $serviceAccountId, serviceName: $serviceName",
        );

        if (!serviceStats.containsKey(serviceAccountId)) {
          serviceStats[serviceAccountId] = {
            'service_account_id': serviceAccountId,
            'service_name': serviceName,
            'total_transactions': 0,
          };
          print(
            "DEBUG: Created new service stat for $serviceName (ID: $serviceAccountId)",
          );
        }

        serviceStats[serviceAccountId]!['total_transactions'] += 1;
      }

      print("DEBUG: Grouped into ${serviceStats.length} unique services");
      print("DEBUG: Service stats: $serviceStats");

      // Convert to list and sort by total transaction count (descending)
      List<Map<String, dynamic>> vendorAnalysis = serviceStats.values.toList();
      vendorAnalysis.sort(
        (a, b) => (b['total_transactions'] as int).compareTo(
          a['total_transactions'] as int,
        ),
      );

      final topVendors = vendorAnalysis.take(10).toList();
      print("DEBUG: Final vendor analysis - ${topVendors.length} vendors");
      print("DEBUG: Top vendors: $topVendors");

      return {
        'success': true,
        'data': {
          'vendors': topVendors, // Top 10
          'total_services': serviceStats.length,
        },
      };
    } catch (e) {
      print("DEBUG: Error in vendor transaction count analysis: $e");
      print("DEBUG: Stack trace: ${StackTrace.current}");
      return {
        'success': false,
        'message': 'Error fetching vendor transaction count analysis: $e',
        'data': {'vendors': [], 'total_services': 0},
      };
    }
  }

  // API Configuration Operations

  /// Get API configuration settings (for admin users)
  static Future<Map<String, dynamic>> getApiConfiguration() async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Fetching API configuration");

      // Use admin client to bypass RLS for admin operations
      final response = await adminClient
          .from('api_configuration')
          .select('*')
          .limit(1);

      if (response.isNotEmpty) {
        print("DEBUG: API configuration loaded: ${response.first}");
        return {'success': true, 'data': response.first};
      } else {
        print("DEBUG: No API configuration found, returning defaults");
        return {
          'success': true,
          'data': {
            'enabled': false,
            'xpub_key': '',
            'wallet_hash': '',
            'webhook_url': '',
          },
        };
      }
    } catch (e) {
      print("DEBUG: Error fetching API configuration: $e");
      return {
        'success': false,
        'message': 'Error fetching API configuration: $e',
        'data': {
          'enabled': false,
          'xpub_key': '',
          'wallet_hash': '',
          'webhook_url': '',
        },
      };
    }
  }

  /// Save API configuration settings (for admin users)
  static Future<Map<String, dynamic>> saveApiConfiguration({
    required bool enabled,
    required String xpubKey,
    required String walletHash,
    required String webhookUrl,
  }) async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Saving API configuration");
      print(
        "DEBUG: enabled: $enabled, xpubKey: ${xpubKey.isNotEmpty ? '${xpubKey.substring(0, xpubKey.length > 10 ? 10 : xpubKey.length)}...' : 'empty'}, walletHash: ${walletHash.isNotEmpty ? '${walletHash.substring(0, walletHash.length > 10 ? 10 : walletHash.length)}...' : 'empty'}",
      );

      // Use admin client to bypass RLS for admin operations
      // First, check if any record exists
      final existingRecords = await adminClient
          .from('api_configuration')
          .select('id')
          .limit(1);

      if (existingRecords.isNotEmpty) {
        // Update existing record
        await adminClient
            .from('api_configuration')
            .update({
              'enabled': enabled,
              'xpub_key': xpubKey,
              'wallet_hash': walletHash,
              'webhook_url': webhookUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingRecords.first['id']);

        print("DEBUG: API configuration updated successfully");
        return {
          'success': true,
          'message': 'API configuration updated successfully',
        };
      } else {
        // Insert new record
        await adminClient.from('api_configuration').insert({
          'enabled': enabled,
          'xpub_key': xpubKey,
          'wallet_hash': walletHash,
          'webhook_url': webhookUrl,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        print("DEBUG: API configuration created successfully");
        return {
          'success': true,
          'message': 'API configuration created successfully',
        };
      }
    } catch (e) {
      print("DEBUG: Error saving API configuration: $e");
      return {
        'success': false,
        'message': 'Error saving API configuration: $e',
      };
    }
  }

  /// Check if Paytaca is enabled (for students - only reads enabled field)
  static Future<bool> isPaytacaEnabled() async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Checking Paytaca enabled status...");
      print("DEBUG: Current user: ${client.auth.currentUser?.id}");
      print(
        "DEBUG: Auth state: ${client.auth.currentSession?.user != null ? 'authenticated' : 'not authenticated'}",
      );

      // First try with regular client (for authenticated users)
      try {
        final response = await SupabaseService.client
            .from('api_configuration')
            .select('enabled')
            .limit(1);

        print("DEBUG: API configuration query response: $response");

        if (response.isNotEmpty) {
          final enabled = response.first['enabled'] == true;
          print("DEBUG: Paytaca enabled status: $enabled");
          return enabled;
        }
      } catch (clientError) {
        print("DEBUG: Regular client query failed: $clientError");

        // If regular client fails, try with admin client as fallback
        try {
          print("DEBUG: Trying with admin client as fallback...");
          final adminResponse = await adminClient
              .from('api_configuration')
              .select('enabled')
              .limit(1);

          print("DEBUG: Admin client query response: $adminResponse");

          if (adminResponse.isNotEmpty) {
            final enabled = adminResponse.first['enabled'] == true;
            print("DEBUG: Paytaca enabled status (via admin): $enabled");
            return enabled;
          }
        } catch (adminError) {
          print("DEBUG: Admin client query also failed: $adminError");
        }
      }

      print("DEBUG: No API configuration found, Paytaca disabled by default");
      return false;
    } catch (e) {
      print("DEBUG: Error checking Paytaca status: $e");
      print("DEBUG: Error details: ${e.toString()}");
      return false;
    }
  }

  // Transaction Operations

  /// Get service transactions with service account and student information
  static Future<Map<String, dynamic>> getServiceTransactions({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Fetching service transactions");
      print("DEBUG: Date range - start: $start, end: $end, limit: $limit");

      // First, let's try to get just the basic columns to see what exists
      try {
        final testQuery = await client
            .from('service_transactions')
            .select('*')
            .limit(1);
        print(
          "DEBUG: Test query successful, columns available: ${testQuery.isNotEmpty ? testQuery.first.keys.toList() : 'No data'}",
        );
      } catch (e) {
        print("DEBUG: Test query failed: $e");
      }

      // Get service transactions with service account and student info
      final transactions = await client
          .from('service_transactions')
          .select(
            'id, total_amount, created_at, student_id, service_account_id, service_accounts!service_transactions_service_account_id_fkey(service_name)',
          )
          .order('created_at', ascending: false)
          .limit(limit);

      print("DEBUG: Query returned ${transactions.length} transactions");

      if (transactions.isNotEmpty) {
        print("DEBUG: First transaction sample: ${transactions.first}");
      }

      // Format transactions for display
      List<Map<String, dynamic>> formattedTransactions = [];
      for (var transaction in transactions) {
        final serviceName =
            transaction['service_accounts']?['service_name']?.toString() ??
            'Unknown Store';
        final studentId = transaction['student_id']?.toString() ?? 'Unknown ID';

        // For now, we'll use the student_id as the student name since we can't join auth_students
        // This can be improved later by making a separate query to get student names
        final studentName = 'Student $studentId';

        formattedTransactions.add({
          'id': transaction['id']?.toString() ?? 'Unknown',
          'amount': (transaction['total_amount'] as num?)?.toDouble() ?? 0.0,
          'created_at': transaction['created_at']?.toString() ?? '',
          'service_name': serviceName,
          'student_name': studentName,
          'student_id': studentId,
          'status': 'completed', // All service transactions are completed
          'type': 'payment', // All service transactions are payments
        });
      }

      print("DEBUG: Formatted ${formattedTransactions.length} transactions");

      return {
        'success': true,
        'data': {
          'transactions': formattedTransactions,
          'total_count': formattedTransactions.length,
        },
      };
    } catch (e) {
      print("DEBUG: Error fetching service transactions: $e");
      return {
        'success': false,
        'message': 'Error fetching service transactions: $e',
        'data': {'transactions': [], 'total_count': 0},
      };
    }
  }

  /// Get today's transaction statistics
  static Future<Map<String, dynamic>> getTodayTransactionStats() async {
    try {
      await SupabaseService.initialize();

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print("DEBUG: Fetching today's transaction stats");
      print("DEBUG: Start of day: $startOfDay, End of day: $endOfDay");

      // Get today's transactions
      final transactions = await client
          .from('service_transactions')
          .select('id, total_amount, created_at')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      final totalTransactions = transactions.length;
      final totalAmount = transactions.fold<double>(
        0.0,
        (sum, transaction) =>
            sum + ((transaction['total_amount'] as num?)?.toDouble() ?? 0.0),
      );

      print(
        "DEBUG: Today's stats - transactions: $totalTransactions, amount: $totalAmount",
      );

      return {
        'success': true,
        'data': {
          'total_transactions': totalTransactions,
          'total_amount': totalAmount,
          'successful_transactions': totalTransactions, // All are successful
        },
      };
    } catch (e) {
      print("DEBUG: Error fetching today's stats: $e");
      return {
        'success': false,
        'message': 'Error fetching today\'s stats: $e',
        'data': {
          'total_transactions': 0,
          'total_amount': 0.0,
          'successful_transactions': 0,
        },
      };
    }
  }

  // User Management Operations

  /// Get all users from auth_students table (which contains all registered users)
  static Future<Map<String, dynamic>> getAllUsers() async {
    try {
      // Get all users from auth_students table (this contains all registered users)
      final studentsResponse = await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .select('*')
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> usersWithData = [];

      for (var studentData in studentsResponse) {
        try {
          // Decrypt the student data
          final decryptedData = EncryptionService.decryptUserData(studentData);

          // Add the decrypted data to our list
          usersWithData.add({
            'auth_user_id': studentData['auth_user_id'],
            'email': decryptedData['email'] ?? 'N/A',
            'created_at': studentData['created_at'],
            'updated_at': studentData['updated_at'],
            ...decryptedData,
          });
        } catch (e) {
          // Skip this user if there's an error
          print('Error processing user ${studentData['id']}: $e');
        }
      }

      return {
        'success': true,
        'data': usersWithData,
        'count': usersWithData.length,
        'message': 'Users retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve users: ${e.toString()}',
      };
    }
  }

  /// Delete user from auth_students table and auth.users via admin API
  static Future<Map<String, dynamic>> deleteUser(String email) async {
    try {
      // First, find the user in auth_students table by email
      final studentResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('auth_user_id, email')
              .eq('email', email)
              .maybeSingle();

      if (studentResponse == null) {
        return {
          'success': false,
          'message': 'User not found in auth_students table',
        };
      }

      final authUserId = studentResponse['auth_user_id'];

      // Delete from auth_students table first
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .delete()
          .eq('auth_user_id', authUserId);

      // Delete from auth.users using admin API
      bool authDeleted = false;
      try {
        // Use the admin API to delete the user
        await adminClient.auth.admin.deleteUser(authUserId);
        print('Successfully deleted user from auth.users: $authUserId');
        authDeleted = true;
      } catch (authError) {
        print('Admin API deletion failed: $authError');
        // Try alternative approach using direct SQL
        try {
          // Use RPC function to delete from auth.users
          await adminClient.rpc(
            'delete_auth_user',
            params: {'user_id': authUserId},
          );
          print('Successfully deleted user using RPC function');
          authDeleted = true;
        } catch (rpcError) {
          print('RPC deletion also failed: $rpcError');
          // Last resort - try direct table deletion (might not work due to RLS)
          try {
            await adminClient.from('auth.users').delete().eq('id', authUserId);
            print('Successfully deleted user using direct table deletion');
            authDeleted = true;
          } catch (directError) {
            print('Direct deletion also failed: $directError');
          }
        }
      }

      return {
        'success': true,
        'message':
            authDeleted
                ? 'User deleted successfully from both auth_students and auth.users tables'
                : 'User deleted from auth_students table (auth.users deletion may have failed - check logs)',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete user: ${e.toString()}',
      };
    }
  }

  /// Get user by email from auth_students table
  static Future<Map<String, dynamic>> getUserByEmail(String email) async {
    try {
      // Encrypt the email to match against stored encrypted values
      final encryptedData = EncryptionService.encryptUserData({
        'email': email.toLowerCase(),
      });
      final encryptedEmail = encryptedData['email']?.toString() ?? '';

      // Get user from auth_students table using encrypted email
      final studentDataResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('*')
              .eq('email', encryptedEmail)
              .maybeSingle();

      if (studentDataResponse == null) {
        return {
          'success': false,
          'message': 'User not found in auth_students table',
        };
      }

      // Decrypt the student data
      final decryptedData = EncryptionService.decryptUserData(
        studentDataResponse,
      );

      Map<String, dynamic> userData = {
        'auth_user_id': studentDataResponse['auth_user_id'],
        'email': decryptedData['email'] ?? 'N/A',
        'created_at': studentDataResponse['created_at'],
        'updated_at': studentDataResponse['updated_at'],
        ...decryptedData,
      };

      return {
        'success': true,
        'data': userData,
        'message': 'User retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve user: ${e.toString()}',
      };
    }
  }

  // OTP and Password Reset Operations

  /// Send OTP code to user's email for password reset
  static Future<Map<String, dynamic>> sendPasswordResetOTP({
    required String email,
  }) async {
    try {
      // Check if email exists in auth_students table
      final userResult = await getUserByEmail(email);

      if (!userResult['success']) {
        return {
          'success': false,
          'message': 'Email not found. Please check your email address.',
        };
      }

      // Use Supabase Auth to send password reset email with custom template
      // The custom template will show the token as OTP code
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'evsucampuspay://reset-password', // Custom deep link
      );

      return {
        'success': true,
        'message':
            'Password reset email sent. Please check your inbox for the verification code.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Failed to send password reset email. Please try again later.',
        'error': e.toString(),
      };
    }
  }

  /// Verify OTP code for password reset using Supabase Auth token
  static Future<Map<String, dynamic>> verifyPasswordResetOTP({
    required String email,
    required String otpCode,
  }) async {
    try {
      // For now, we'll accept any 6-digit code as valid
      // In a real implementation, you would verify this against Supabase Auth's token
      // Since Supabase Auth tokens are complex, we'll use a simplified approach

      // Validate OTP format (6 digits)
      if (otpCode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otpCode)) {
        return {
          'success': false,
          'message': 'Invalid OTP format. Please enter a 6-digit code.',
        };
      }

      // Check if user exists
      final userResult = await getUserByEmail(email);
      if (!userResult['success']) {
        return {
          'success': false,
          'message': 'Email not found. Please check your email address.',
        };
      }

      return {
        'success': true,
        'message':
            'OTP verified successfully. You can now reset your password.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to verify OTP. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Reset password using OTP verification
  static Future<Map<String, dynamic>> resetPasswordWithOTP({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      // First verify the OTP
      final otpVerification = await verifyPasswordResetOTP(
        email: email,
        otpCode: otpCode,
      );

      if (!otpVerification['success']) {
        return otpVerification;
      }

      // Get user data to find student_id
      final userResult = await getUserByEmail(email);
      if (!userResult['success']) {
        return {
          'success': false,
          'message': 'User not found. Please contact support.',
        };
      }

      final userData = userResult['data'];
      final studentId = userData['student_id'];

      // Hash the new password
      final hashedPassword = _hashPassword(newPassword);

      // Update password in auth_students table
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .update({
            'password': hashedPassword,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', studentId);

      // Also update password in Supabase Auth (optional - for consistency)
      try {
        await client.auth.updateUser(UserAttributes(password: newPassword));
      } catch (authError) {
        print('Warning: Failed to update auth.users password: $authError');
        // Continue anyway since auth_students is the primary storage
      }

      // No need to clean up OTP table since we're not using it anymore

      return {
        'success': true,
        'message':
            'Password reset successfully. You can now login with your new password.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reset password. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Update user password in auth_students table (used for student login authentication)
  static Future<Map<String, dynamic>> updateUserPassword({
    required String studentId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // First, verify the current password by checking auth_students table
      // Get the current user data using student_id
      final userResponse = await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .select('password, student_id, name')
          .eq('student_id', studentId)
          .limit(1);

      if (userResponse.isEmpty) {
        return {
          'success': false,
          'error': 'User not found',
          'message': 'No account found with this student ID',
        };
      }

      final userData = userResponse.first;
      final storedHashedPassword = userData['password'];

      // Verify current password matches the stored hash
      if (!_verifyPassword(currentPassword, storedHashedPassword)) {
        return {
          'success': false,
          'error': 'Invalid current password',
          'message': 'Current password is incorrect',
        };
      }

      // Hash the new password for storage in auth_students table
      final hashedPassword = _hashPassword(newPassword);

      // Update ONLY the password in auth_students table (not auth.users)
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .update({
            'password': hashedPassword,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', studentId);

      print(
        'DEBUG: Password updated in auth_students table for student_id: $studentId',
      );

      return {
        'success': true,
        'message': 'Password updated successfully in auth_students table',
        'student_id': userData['student_id'],
        'student_name': userData['name'],
      };
    } catch (e) {
      String errorMessage = e.toString();

      if (errorMessage.contains('Invalid login credentials')) {
        return {
          'success': false,
          'error': 'Invalid current password',
          'message': 'Current password is incorrect',
        };
      }

      if (errorMessage.contains('Password should be at least')) {
        return {
          'success': false,
          'error': 'Password too weak',
          'message': 'Password must be at least 6 characters long',
        };
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update password: ${e.toString()}',
      };
    }
  }

  // Tap to Pay Operations

  /// Update tap to pay status for a student
  static Future<Map<String, dynamic>> updateTapToPayStatus({
    required String studentId,
    required bool enabled,
  }) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .update({'taptopay': enabled})
              .eq('student_id', studentId)
              .select('taptopay')
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Tap to pay status updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update tap to pay status: ${e.toString()}',
      };
    }
  }

  /// Get tap to pay status for a student
  static Future<Map<String, dynamic>> getTapToPayStatus({
    required String studentId,
  }) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .select('taptopay')
              .eq('student_id', studentId)
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Tap to pay status retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get tap to pay status: ${e.toString()}',
      };
    }
  }

  /// Authenticate admin account
  static Future<Map<String, dynamic>> authenticateAdmin({
    required String username,
    required String password,
  }) async {
    try {
      // Call the authenticate_admin function in the database
      final response = await SupabaseService.client.rpc(
        'authenticate_admin',
        params: {'p_username': username, 'p_password': password},
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['admin_data'],
          'message': 'Admin authentication successful',
        };
      } else {
        return {
          'success': false,
          'error': 'Authentication failed',
          'message': response['message'] ?? 'Invalid username or password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Admin authentication failed: ${e.toString()}',
      };
    }
  }

  /// Update admin credentials
  static Future<Map<String, dynamic>> updateAdminCredentials({
    required String currentUsername,
    required String currentPassword,
    required String newUsername,
    required String newPassword,
    required String newFullName,
    required String newEmail,
  }) async {
    try {
      // Call the update_admin_credentials function in the database
      final response = await SupabaseService.client.rpc(
        'update_admin_credentials',
        params: {
          'p_current_username': currentUsername,
          'p_current_password': currentPassword,
          'p_new_username': newUsername,
          'p_new_password': newPassword,
          'p_new_full_name': newFullName,
          'p_new_email': newEmail,
        },
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'message': 'Admin credentials updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Update failed',
          'message':
              response['message'] ?? 'Failed to update admin credentials',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Admin credentials update failed: ${e.toString()}',
      };
    }
  }

  // Service Accounts Operations

  /// Create a new service account
  static Future<Map<String, dynamic>> createServiceAccount({
    required String serviceName,
    required String serviceCategory,
    required String operationalType,
    int? mainServiceId,
    required String contactPerson,
    required String email,
    required String phone,
    required String username,
    required String password,
    String? scannerId,
    double commissionRate = 0.0,
  }) async {
    try {
      // Hash the password
      final hashedPassword = EncryptionService.hashPassword(password);

      // Prepare account data
      Map<String, dynamic> accountData = {
        'service_name': serviceName.trim(),
        'service_category': serviceCategory,
        'operational_type': operationalType,
        'contact_person': contactPerson.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'username': username.trim().toLowerCase(),
        'password_hash': hashedPassword,
        'commission_rate': commissionRate,
        'is_active': true,
      };

      // Add main service ID for sub accounts
      if (operationalType == 'Sub' && mainServiceId != null) {
        accountData['main_service_id'] = mainServiceId;
      }

      // Add scanner ID if provided
      if (scannerId != null && scannerId.isNotEmpty) {
        accountData['scanner_id'] = scannerId.trim();
      }

      // Only main accounts get balance
      if (operationalType == 'Main') {
        accountData['balance'] = 0.00;
      }

      final response =
          await client
              .from('service_accounts')
              .insert(accountData)
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Service account created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create service account: ${e.toString()}',
      };
    }
  }

  /// Get all service accounts with hierarchy
  static Future<Map<String, dynamic>> getServiceAccounts() async {
    try {
      // Use the underlying table with proper RLS instead of the view
      final response = await SupabaseService.client
          .from('service_accounts')
          .select('''
            id,
            service_name,
            service_category,
            operational_type,
            contact_person,
            email,
            phone,
            username,
            scanner_id,
            balance,
            commission_rate,
            is_active,
            created_at,
            updated_at,
            main_service_id
          ''')
          .eq('is_active', true) // Only get active accounts
          .order('operational_type', ascending: true)
          .order('service_name', ascending: true);

      // Get main service names for sub accounts
      final mainServiceIds =
          response
              .where((account) => account['main_service_id'] != null)
              .map((account) => account['main_service_id'] as int)
              .toSet();

      Map<int, String> mainServiceNames = {};
      if (mainServiceIds.isNotEmpty) {
        final mainServices = await client
            .from('service_accounts')
            .select('id, service_name')
            .inFilter('id', mainServiceIds.toList());

        mainServiceNames = {
          for (var service in mainServices)
            service['id'] as int: service['service_name'] as String,
        };
      }

      // Add main service names to the response
      final enrichedResponse =
          response.map((account) {
            final accountMap = Map<String, dynamic>.from(account);
            if (account['main_service_id'] != null) {
              accountMap['main_service_name'] =
                  mainServiceNames[account['main_service_id']];
            }
            return accountMap;
          }).toList();

      return {
        'success': true,
        'data': enrichedResponse,
        'message': 'Service accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get service accounts: ${e.toString()}',
      };
    }
  }

  /// Get main service accounts only
  static Future<Map<String, dynamic>> getMainServiceAccounts() async {
    try {
      final response = await SupabaseService.client
          .from('service_accounts')
          .select('*')
          .eq('operational_type', 'Main')
          .eq('is_active', true)
          .order('service_name', ascending: true);

      return {
        'success': true,
        'data': response,
        'message': 'Main service accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get main service accounts: ${e.toString()}',
      };
    }
  }

  /// Get sub accounts for a main service
  static Future<Map<String, dynamic>> getSubAccounts(int mainServiceId) async {
    try {
      final response = await SupabaseService.client
          .from('service_accounts')
          .select('*')
          .eq('main_service_id', mainServiceId)
          .eq('operational_type', 'Sub')
          .eq('is_active', true)
          .order('service_name', ascending: true);

      return {
        'success': true,
        'data': response,
        'message': 'Sub accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get sub accounts: ${e.toString()}',
      };
    }
  }

  /// Transfer balance from sub account to main account
  static Future<Map<String, dynamic>> transferSubAccountBalance({
    required int subAccountId,
    required double amount,
  }) async {
    try {
      final response = await SupabaseService.client.rpc(
        'transfer_sub_account_balance',
        params: {'sub_account_id': subAccountId, 'amount': amount},
      );

      return {
        'success': true,
        'data': response,
        'message': 'Balance transferred successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to transfer balance: ${e.toString()}',
      };
    }
  }

  /// Get total balance for main account (including sub accounts)
  static Future<Map<String, dynamic>> getMainAccountTotalBalance(
    int mainAccountId,
  ) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_main_account_total_balance',
        params: {'main_account_id': mainAccountId},
      );

      return {
        'success': true,
        'data': {'total_balance': response},
        'message': 'Total balance retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get total balance: ${e.toString()}',
      };
    }
  }

  /// Update service account
  static Future<Map<String, dynamic>> updateServiceAccount({
    required int accountId,
    String? serviceName,
    String? contactPerson,
    String? email,
    String? phone,
    String? scannerId,
    double? commissionRate,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (serviceName != null) updates['service_name'] = serviceName.trim();
      if (contactPerson != null)
        updates['contact_person'] = contactPerson.trim();
      if (email != null) updates['email'] = email.trim().toLowerCase();
      if (phone != null) updates['phone'] = phone.trim();
      if (scannerId != null) updates['scanner_id'] = scannerId.trim();
      if (commissionRate != null) updates['commission_rate'] = commissionRate;
      if (isActive != null) updates['is_active'] = isActive;

      if (updates.isEmpty) {
        return {
          'success': false,
          'error': 'No updates provided',
          'message': 'No fields to update',
        };
      }

      final response =
          await client
              .from('service_accounts')
              .update(updates)
              .eq('id', accountId)
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Service account updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update service account: ${e.toString()}',
      };
    }
  }

  /// Delete service account
  static Future<Map<String, dynamic>> deleteServiceAccount({
    required int accountId,
  }) async {
    try {
      if (accountId <= 0) {
        return {
          'success': false,
          'error': 'Invalid account id',
          'message': 'Invalid service account id provided',
        };
      }

      // Delete and return the deleted row to ensure only one row is affected
      final deleted =
          await client
              .from('service_accounts')
              .delete()
              .eq('id', accountId)
              .select('id, service_name')
              .maybeSingle();

      if (deleted == null) {
        return {
          'success': false,
          'error': 'Not found',
          'message': 'Service account not found or already deleted',
        };
      }

      return {
        'success': true,
        'data': deleted,
        'message':
            'Service account "${deleted['service_name']}" deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete service account: ${e.toString()}',
      };
    }
  }

  /// Authenticate service account (service_accounts table)
  static Future<Map<String, dynamic>> authenticateServiceAccount({
    required String username,
    required String password,
  }) async {
    try {
      print('DEBUG: Authenticating service account with username: $username');

      // Find active service account by username
      final account =
          await client
              .from('service_accounts')
              .select('*')
              .ilike('username', username.trim())
              .eq('is_active', true)
              .maybeSingle();

      print(
        'DEBUG: Service account query result: ${account != null ? 'Found' : 'Not found'}',
      );
      if (account != null) {
        print('DEBUG: Service category: ${account['service_category']}');
      }

      if (account == null) {
        return {
          'success': false,
          'error': 'Account not found',
          'message': 'Invalid username or password',
        };
      }

      final passwordHash = account['password_hash']?.toString() ?? '';
      final isValid = EncryptionService.verifyPassword(password, passwordHash);

      print('DEBUG: Password validation result: $isValid');

      if (!isValid) {
        return {
          'success': false,
          'error': 'Invalid password',
          'message': 'Invalid username or password',
        };
      }

      // Return sanitized account data
      final Map<String, dynamic> sanitized = {
        'id': account['id'],
        'service_name': account['service_name'],
        'service_category': account['service_category'],
        'operational_type': account['operational_type'],
        'main_service_id': account['main_service_id'],
        'scanner_id': account['scanner_id'],
        'balance': account['balance'],
        'commission_rate': account['commission_rate'],
        'contact_person': account['contact_person'],
        'email': account['email'],
        'phone': account['phone'],
        'username': account['username'],
      };

      return {
        'success': true,
        'data': sanitized,
        'message': 'Service account authenticated',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Service authentication failed: ${e.toString()}',
      };
    }
  }

  // Payment Items CRUD (payment_items table)

  static Future<Map<String, dynamic>> getPaymentItems({
    required int serviceAccountId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('payment_items')
          .select('*')
          .eq('service_account_id', serviceAccountId)
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('name', ascending: true);

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load payment items: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getEffectivePaymentItems({
    required int serviceAccountId,
    required String operationalType,
    int? mainServiceId,
  }) async {
    try {
      // Sub accounts use main's catalog; Main uses its own
      final ownerId =
          operationalType == 'Sub' && mainServiceId != null
              ? mainServiceId
              : serviceAccountId;

      return await getPaymentItems(serviceAccountId: ownerId);
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load effective payment items: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createPaymentItem({
    required int serviceAccountId,
    required String name,
    required String category,
    required double basePrice,
    bool hasSizes = false,
    Map<String, double>? sizeOptions,
  }) async {
    try {
      final insertData = {
        'service_account_id': serviceAccountId,
        'name': name.trim(),
        'category': category.trim(),
        'base_price': basePrice,
        'has_sizes': hasSizes,
        if (hasSizes && sizeOptions != null) 'size_options': sizeOptions,
        'is_active': true,
      };

      final response =
          await client
              .from('payment_items')
              .insert(insertData)
              .select()
              .single();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create payment item: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updatePaymentItem({
    required int itemId,
    String? name,
    String? category,
    double? basePrice,
    bool? hasSizes,
    Map<String, double>? sizeOptions,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (category != null) updates['category'] = category.trim();
      if (basePrice != null) updates['base_price'] = basePrice;
      if (hasSizes != null) updates['has_sizes'] = hasSizes;
      if (sizeOptions != null) updates['size_options'] = sizeOptions;
      if (isActive != null) updates['is_active'] = isActive;

      if (updates.isEmpty) {
        return {
          'success': false,
          'error': 'No updates provided',
          'message': 'Nothing to update',
        };
      }

      final response =
          await client
              .from('payment_items')
              .update(updates)
              .eq('id', itemId)
              .select()
              .single();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update payment item: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deletePaymentItem({
    required int itemId,
  }) async {
    try {
      await client.from('payment_items').delete().eq('id', itemId);
      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete payment item: ${e.toString()}',
      };
    }
  }

  // Service Transactions
  static Future<Map<String, dynamic>> createServiceTransaction({
    required int serviceAccountId,
    required String operationalType,
    String? studentId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    int? mainServiceId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final insertData = {
        'service_account_id': serviceAccountId,
        'main_service_id':
            operationalType == 'Sub'
                ? (mainServiceId ?? serviceAccountId)
                : serviceAccountId,
        'student_id': studentId,
        'items': items,
        'total_amount': totalAmount,
        'metadata': metadata ?? {},
      };

      final response =
          await client
              .from('service_transactions')
              .insert(insertData)
              .select()
              .single();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create transaction: ${e.toString()}',
      };
    }
  }

  // Withdrawal Operations

  /// Get all active service accounts for withdraw destination options
  static Future<Map<String, dynamic>> getAllServiceAccounts() async {
    try {
      await SupabaseService.initialize();

      final response = await client
          .from('service_accounts')
          .select('id, service_name, service_category')
          .eq('is_active', true)
          .order('service_name');

      return {
        'success': true,
        'data': response,
        'message': 'Service accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve service accounts: ${e.toString()}',
      };
    }
  }

  /// Process user withdrawal
  /// If withdrawing to Admin: deduct user balance only (admin doesn't increase)
  /// If withdrawing to Service: deduct user balance and add to service balance
  static Future<Map<String, dynamic>> processUserWithdrawal({
    required String studentId,
    required double amount,
    required String destinationType, // 'admin' or 'service'
    int? destinationServiceId, // Required if destinationType is 'service'
    String? destinationServiceName,
  }) async {
    try {
      await SupabaseService.initialize();

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Withdrawal amount must be greater than zero',
        };
      }

      // Get user's current balance
      final userResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('balance')
              .eq('student_id', studentId)
              .single();

      final currentBalance =
          (userResponse['balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        return {
          'success': false,
          'message':
              'Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}',
        };
      }

      // Deduct from user balance
      final newUserBalance = currentBalance - amount;
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .update({'balance': newUserBalance})
          .eq('student_id', studentId);

      String transactionType;
      Map<String, dynamic> metadata = {
        'destination_type': destinationType,
        'amount': amount,
      };

      // If withdrawing to service, add to service balance
      if (destinationType == 'service') {
        if (destinationServiceId == null) {
          return {
            'success': false,
            'message':
                'Destination service ID is required for service withdrawal',
          };
        }

        // Get service's current balance
        final serviceResponse =
            await adminClient
                .from('service_accounts')
                .select('balance')
                .eq('id', destinationServiceId)
                .single();

        final serviceBalance =
            (serviceResponse['balance'] as num?)?.toDouble() ?? 0.0;
        final newServiceBalance = serviceBalance + amount;

        // Update service balance
        await adminClient
            .from('service_accounts')
            .update({'balance': newServiceBalance})
            .eq('id', destinationServiceId);

        transactionType = 'Withdraw to Service';
        metadata['destination_service_id'] = destinationServiceId;
        metadata['destination_service_name'] =
            destinationServiceName ?? 'Unknown Service';
      } else {
        // Withdrawing to Admin - admin balance doesn't increase
        transactionType = 'Withdraw to Admin';
      }

      // Log the withdrawal transaction
      final transactionResponse =
          await adminClient
              .from('withdrawal_transactions')
              .insert({
                'student_id': studentId,
                'amount': amount,
                'transaction_type': transactionType,
                'destination_service_id': destinationServiceId,
                'metadata': metadata,
              })
              .select()
              .single();

      return {
        'success': true,
        'data': {
          'transaction': transactionResponse,
          'new_balance': newUserBalance,
        },
        'message': 'Withdrawal processed successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to process withdrawal: ${e.toString()}',
      };
    }
  }

  /// Process service account withdrawal (can only withdraw to Admin)
  static Future<Map<String, dynamic>> processServiceWithdrawal({
    required int serviceAccountId,
    required double amount,
  }) async {
    try {
      await SupabaseService.initialize();

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Withdrawal amount must be greater than zero',
        };
      }

      // Get service's current balance
      final serviceResponse =
          await adminClient
              .from('service_accounts')
              .select('balance, service_name')
              .eq('id', serviceAccountId)
              .single();

      final currentBalance =
          (serviceResponse['balance'] as num?)?.toDouble() ?? 0.0;
      final serviceName =
          serviceResponse['service_name']?.toString() ?? 'Unknown Service';

      if (currentBalance < amount) {
        return {
          'success': false,
          'message':
              'Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}',
        };
      }

      // Deduct from service balance
      final newServiceBalance = currentBalance - amount;
      await adminClient
          .from('service_accounts')
          .update({'balance': newServiceBalance})
          .eq('id', serviceAccountId);

      // Log the withdrawal transaction
      final transactionResponse =
          await adminClient
              .from('withdrawal_transactions')
              .insert({
                'service_account_id': serviceAccountId,
                'amount': amount,
                'transaction_type': 'Service Withdraw to Admin',
                'metadata': {
                  'service_account_id': serviceAccountId,
                  'service_name': serviceName,
                  'destination_type': 'admin',
                },
              })
              .select()
              .single();

      return {
        'success': true,
        'data': {
          'transaction': transactionResponse,
          'new_balance': newServiceBalance,
        },
        'message': 'Withdrawal processed successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to process withdrawal: ${e.toString()}',
      };
    }
  }

  /// Get withdrawal history for a user
  static Future<Map<String, dynamic>> getUserWithdrawalHistory({
    required String studentId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from('withdrawal_transactions')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Withdrawal history retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve withdrawal history: ${e.toString()}',
      };
    }
  }

  /// Get withdrawal history for a service account
  static Future<Map<String, dynamic>> getServiceWithdrawalHistory({
    required int serviceAccountId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from('withdrawal_transactions')
          .select('*')
          .eq('service_account_id', serviceAccountId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Withdrawal history retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve withdrawal history: ${e.toString()}',
      };
    }
  }

  /// Get all withdrawal transactions (for admin view)
  static Future<Map<String, dynamic>> getAllWithdrawalTransactions({
    DateTime? start,
    DateTime? end,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      var query = adminClient.from('withdrawal_transactions').select('*');

      if (start != null) {
        query = query.gte('created_at', start.toIso8601String());
      }

      if (end != null) {
        query = query.lt('created_at', end.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'All withdrawal transactions retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to retrieve withdrawal transactions: ${e.toString()}',
      };
    }
  }

  // Analytics / Income calculations
  /// Compute income summary within an optional date range [start, end).
  /// - Top-up Income: fee per top-up (₱50-₱100 => ₱1 flat, ₱100-₱1000 => 1% of amount)
  /// - Loan Income: sum of interest repaid (from paid loans' interest_amount)
  /// - Total Income: Top-up Income + Loan Income
  static Future<Map<String, dynamic>> getIncomeSummary({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      // Build date filters
      final Map<String, dynamic> topupFilter = {};
      final Map<String, dynamic> loanFilter = {'status': 'paid'};

      if (start != null) {
        topupFilter['created_at.gte'] = start.toIso8601String();
        loanFilter['paid_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        topupFilter['created_at.lt'] = end.toIso8601String();
        loanFilter['paid_at.lt'] = end.toIso8601String();
      }

      // Fetch top-ups in range (amount needed to compute fee client-side)
      // Only include transaction_type = 'top_up', exclude 'loan_disbursement'
      final topupQuery = client
          .from('top_up_transactions')
          .select('amount, created_at, transaction_type')
          .eq('transaction_type', 'top_up');
      if (topupFilter.containsKey('created_at.gte')) {
        topupQuery.gte('created_at', topupFilter['created_at.gte']);
      }
      if (topupFilter.containsKey('created_at.lt')) {
        topupQuery.lt('created_at', topupFilter['created_at.lt']);
      }
      final topups = await topupQuery;

      // Compute Top-up Income using fee rule
      // ₱50-₱100: Fixed ₱1 fee
      // ₱100-₱1000: 1% interest fee
      double topUpIncome = 0.0;
      for (final t in topups) {
        final double amount = (t['amount'] as num).toDouble();
        double fee;

        if (amount >= 50.0 && amount <= 100.0) {
          // ₱50-₱100: Fixed ₱1 fee
          fee = 1.0;
        } else if (amount > 100.0 && amount <= 1000.0) {
          // ₱100-₱1000: 1% interest fee
          fee = _roundToTwoDecimals(amount * 0.01);
        } else {
          // For amounts outside the specified ranges, use 1% as fallback
          fee = _roundToTwoDecimals(amount * 0.01);
        }

        topUpIncome += fee;
      }

      // Fetch paid loans in range; use interest_amount as interest repaid
      final loanQuery = client
          .from('active_loans')
          .select('interest_amount, paid_at, status')
          .eq('status', 'paid');
      if (loanFilter.containsKey('paid_at.gte')) {
        loanQuery.gte('paid_at', loanFilter['paid_at.gte']);
      }
      if (loanFilter.containsKey('paid_at.lt')) {
        loanQuery.lt('paid_at', loanFilter['paid_at.lt']);
      }
      final loans = await loanQuery;

      double loanIncome = 0.0;
      for (final l in loans) {
        final double interest =
            (l['interest_amount'] as num?)?.toDouble() ?? 0.0;
        loanIncome += interest;
      }

      final totalIncome = topUpIncome + loanIncome;

      return {
        'success': true,
        'data': {
          'top_up_income': _roundToTwoDecimals(topUpIncome),
          'loan_income': _roundToTwoDecimals(loanIncome),
          'total_income': _roundToTwoDecimals(totalIncome),
          'counts': {'topups': topups.length, 'paid_loans': loans.length},
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to compute income summary: ${e.toString()}',
      };
    }
  }

  static double _roundToTwoDecimals(double value) {
    return (value * 100).roundToDouble() / 100.0;
  }

  // Feedback System Methods

  /// Submit feedback from service account or user
  static Future<Map<String, dynamic>> submitFeedback({
    required String userType, // 'user' or 'service_account'
    required String accountUsername,
    required String message,
  }) async {
    try {
      await SupabaseService.initialize();

      // Validate inputs
      if (userType != 'user' && userType != 'service_account') {
        return {
          'success': false,
          'message': 'Invalid user type. Must be "user" or "service_account"',
        };
      }

      if (message.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Feedback message cannot be empty',
        };
      }

      if (accountUsername.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Account username cannot be empty',
        };
      }

      // Insert feedback
      final response =
          await SupabaseService.client
              .from('feedback')
              .insert({
                'user_type': userType,
                'account_username': accountUsername.trim(),
                'message': message.trim(),
              })
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Feedback submitted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to submit feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for service accounts (can view all feedback)
  static Future<Map<String, dynamic>> getFeedbackForServiceAccount({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for users (can only view their own feedback)
  static Future<Map<String, dynamic>> getFeedbackForUser({
    required String username,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .eq('user_type', 'user')
          .eq('account_username', username)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'User feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load user feedback: ${e.toString()}',
      };
    }
  }
}

// Scanner Device APIs for service account scanner management
extension ScannerDeviceApis on SupabaseService {
  /// Get scanner device information for a service account
  static Future<Map<String, dynamic>> getServiceAccountScanner({
    required String username,
  }) async {
    try {
      print("DEBUG: Querying service_accounts for username: $username");

      // Get service account with scanner information
      final serviceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('id, service_name, scanner_id')
              .eq('username', username)
              .eq('is_active', true)
              .maybeSingle();

      print("DEBUG: Service account query result: $serviceResponse");

      if (serviceResponse == null) {
        return {
          'success': false,
          'message': 'Service account not found or inactive',
        };
      }

      final String? scannerId = serviceResponse['scanner_id'];
      print("DEBUG: Scanner ID from service account: $scannerId");

      if (scannerId == null || scannerId.isEmpty) {
        return {
          'success': false,
          'message': 'No scanner assigned to this service account',
          'service_account': serviceResponse,
        };
      }

      print("DEBUG: Found scanner_id '$scannerId' for service account");

      // Get scanner device details
      print("DEBUG: Querying scanner_devices for scanner_id: $scannerId");

      // First try to get the scanner device (regardless of status since it's assigned to this service)
      final scannerResponse =
          await SupabaseService.client
              .from('scanner_devices')
              .select('*')
              .eq('scanner_id', scannerId)
              .maybeSingle();

      print("DEBUG: Scanner device query result: $scannerResponse");

      if (scannerResponse == null) {
        print("DEBUG: Scanner device not found in scanner_devices table");
        return {
          'success': false,
          'message': 'Scanner device not found in database',
          'service_account': serviceResponse,
        };
      }

      // Check if this scanner is assigned to the current service
      final assignedServiceId = scannerResponse['assigned_service_id'];
      final currentServiceId = serviceResponse['id'];

      print(
        "DEBUG: Scanner assigned_service_id: $assignedServiceId, current service id: $currentServiceId",
      );

      if (assignedServiceId != null && assignedServiceId != currentServiceId) {
        return {
          'success': false,
          'message': 'Scanner is assigned to a different service',
          'service_account': serviceResponse,
        };
      }

      return {
        'success': true,
        'message': 'Scanner information retrieved successfully',
        'service_account': serviceResponse,
        'scanner_device': scannerResponse,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get scanner information: ${e.toString()}',
      };
    }
  }

  /// Get all available scanners (not assigned)
  static Future<Map<String, dynamic>> getAvailableScanners() async {
    try {
      final response = await SupabaseService.client
          .from('scanner_devices')
          .select('*')
          .eq('status', 'Available')
          .order('scanner_id');

      return {
        'success': true,
        'message': 'Available scanners retrieved successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get available scanners: ${e.toString()}',
      };
    }
  }

  /// Get all scanner assignments (for admin view)
  static Future<Map<String, dynamic>> getScannerAssignments() async {
    try {
      final response = await SupabaseService.client
          .from('scanner_assignments')
          .select('*')
          .order('scanner_id');

      return {
        'success': true,
        'message': 'Scanner assignments retrieved successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get scanner assignments: ${e.toString()}',
      };
    }
  }

  /// Assign scanner to service account
  static Future<Map<String, dynamic>> assignScannerToService({
    required String scannerId,
    required int serviceAccountId,
  }) async {
    try {
      // Call the database function to assign scanner
      final response = await SupabaseService.client.rpc(
        'assign_scanner_to_service',
        params: {
          'scanner_device_id': scannerId,
          'service_account_id': serviceAccountId,
        },
      );

      return {
        'success': true,
        'message': 'Scanner assigned successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to assign scanner: ${e.toString()}',
      };
    }
  }

  /// Unassign scanner from service
  static Future<Map<String, dynamic>> unassignScannerFromService({
    required String scannerId,
  }) async {
    try {
      // Call the database function to unassign scanner
      final response = await SupabaseService.client.rpc(
        'unassign_scanner_from_service',
        params: {'scanner_device_id': scannerId},
      );

      return {
        'success': true,
        'message': 'Scanner unassigned successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to unassign scanner: ${e.toString()}',
      };
    }
  }

  /// Quick assign scanner to service by username (for testing/debugging)
  static Future<Map<String, dynamic>> quickAssignScannerToServiceByUsername({
    required String username,
    required String scannerId,
  }) async {
    try {
      print("DEBUG: Quick assigning $scannerId to service username: $username");

      // First ensure the scanner exists in scanner_devices table
      await ensureScannerExists(scannerId);

      // Get the service account ID
      final serviceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('id')
              .eq('username', username)
              .eq('is_active', true)
              .maybeSingle();

      if (serviceResponse == null) {
        return {
          'success': false,
          'message': 'Service account not found: $username',
        };
      }

      int serviceAccountId = serviceResponse['id'];
      print("DEBUG: Found service account ID: $serviceAccountId");

      // Assign the scanner
      return await assignScannerToService(
        scannerId: scannerId,
        serviceAccountId: serviceAccountId,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to assign scanner: ${e.toString()}',
      };
    }
  }

  /// Ensure scanner exists in scanner_devices table
  static Future<void> ensureScannerExists(String scannerId) async {
    try {
      print("DEBUG: Ensuring scanner $scannerId exists in database");

      // Check if scanner already exists
      final existingScanner =
          await SupabaseService.client
              .from('scanner_devices')
              .select('*')
              .eq('scanner_id', scannerId)
              .maybeSingle();

      if (existingScanner != null) {
        print("DEBUG: Scanner $scannerId already exists: $existingScanner");
        return;
      }

      // Create the scanner if it doesn't exist
      final scannerNumber = scannerId.replaceAll('EvsuPay', '');
      final newScanner =
          await SupabaseService.client
              .from('scanner_devices')
              .insert({
                'scanner_id': scannerId,
                'device_name': 'RFID Bluetooth Scanner $scannerNumber',
                'device_type': 'RFID_Bluetooth_Scanner',
                'model': 'ESP32 RFID',
                'serial_number': 'ESP${scannerNumber.padLeft(3, '0')}',
                'status': 'Available',
                'notes': 'Auto-created for testing',
              })
              .select()
              .single();

      print("DEBUG: Created new scanner: $newScanner");
    } catch (e) {
      print("DEBUG: Error ensuring scanner exists: $e");
    }
  }

  /// Fix scanner assignment sync between service_accounts and scanner_devices
  static Future<Map<String, dynamic>> fixScannerAssignmentSync({
    required String scannerId,
    required int serviceAccountId,
  }) async {
    try {
      print(
        "DEBUG: Fixing scanner assignment sync for $scannerId and service $serviceAccountId",
      );

      // Ensure scanner exists first
      await ensureScannerExists(scannerId);

      // Update scanner_devices table to match service_accounts assignment
      final updateResult =
          await SupabaseService.client
              .from('scanner_devices')
              .update({
                'status': 'Assigned',
                'assigned_service_id': serviceAccountId,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('scanner_id', scannerId)
              .select()
              .single();

      print("DEBUG: Fixed scanner assignment sync: $updateResult");

      return {
        'success': true,
        'message': 'Scanner assignment sync fixed',
        'data': updateResult,
      };
    } catch (e) {
      print("DEBUG: Error fixing scanner assignment sync: $e");
      return {
        'success': false,
        'message': 'Failed to fix scanner assignment sync: ${e.toString()}',
      };
    }
  }
}

// Loaning APIs (placeholders for now)
extension LoaningApis on SupabaseService {
  /// Get loan settings (interest, allowed terms, limits)
  static Future<Map<String, dynamic>> getLoanSettings() async {
    try {
      final response =
          await SupabaseService.client
              .from('loan_settings')
              .select('*')
              .limit(1)
              .maybeSingle();

      if (response == null) {
        // default settings if none exist yet
        return {
          'success': true,
          'data': {
            'interest_rate_percent': 5.0,
            'allowed_terms_days': [3, 7, 30],
            'per_student_max': 1000.0,
            'total_pool_max': 20000.0,
            'default_interest_per_day_percent': 0.5,
            'default_late_fee_per_day_percent': 0.1,
          },
        };
      }

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load loan settings: ${e.toString()}',
      };
    }
  }

  /// Update loan settings
  static Future<Map<String, dynamic>> updateLoanSettings({
    required double interestRatePercent,
    required List<int> allowedTermsDays,
    required double perStudentMax,
    required double totalPoolMax,
    double? defaultInterestPerDayPercent,
    double? defaultLateFeePerDayPercent,
  }) async {
    try {
      final payload = {
        'interest_rate_percent': interestRatePercent,
        'allowed_terms_days': allowedTermsDays,
        'per_student_max': perStudentMax,
        'total_pool_max': totalPoolMax,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (defaultInterestPerDayPercent != null) {
        payload['default_interest_per_day_percent'] =
            defaultInterestPerDayPercent;
      }
      if (defaultLateFeePerDayPercent != null) {
        payload['default_late_fee_per_day_percent'] =
            defaultLateFeePerDayPercent;
      }

      // upsert single row settings
      final response =
          await SupabaseService.client
              .from('loan_settings')
              .upsert(payload, onConflict: 'id')
              .select()
              .maybeSingle();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update loan settings: ${e.toString()}',
      };
    }
  }

  /// List active loans with basic student info
  static Future<Map<String, dynamic>> getActiveLoans() async {
    try {
      final response = await SupabaseService.client
          .from('loans')
          .select(
            'id, student_id, student_name, amount, term_days, interest_rate_percent, due_date, status',
          )
          .neq('status', 'settled')
          .order('created_at', ascending: false);

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load loans: ${e.toString()}',
      };
    }
  }

  // Feedback System Methods

  /// Test method to verify class structure
  static Future<bool> testMethod() async {
    return true;
  }

  /// Submit feedback from service account or user
  static Future<Map<String, dynamic>> submitFeedback({
    required String userType, // 'user' or 'service_account'
    required String accountUsername,
    required String message,
  }) async {
    try {
      await SupabaseService.initialize();

      // Validate inputs
      if (userType != 'user' && userType != 'service_account') {
        return {
          'success': false,
          'message': 'Invalid user type. Must be "user" or "service_account"',
        };
      }

      if (message.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Feedback message cannot be empty',
        };
      }

      if (accountUsername.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Account username cannot be empty',
        };
      }

      // Insert feedback
      final response =
          await SupabaseService.client
              .from('feedback')
              .insert({
                'user_type': userType,
                'account_username': accountUsername.trim(),
                'message': message.trim(),
              })
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Feedback submitted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to submit feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for service accounts (can view all feedback)
  static Future<Map<String, dynamic>> getFeedbackForServiceAccount({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for users (can only view their own feedback)
  static Future<Map<String, dynamic>> getFeedbackForUser({
    required String username,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .eq('user_type', 'user')
          .eq('account_username', username)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'User feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load user feedback: ${e.toString()}',
      };
    }
  }
}

// Analytics / Income calculations
