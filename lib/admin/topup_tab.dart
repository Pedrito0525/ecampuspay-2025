import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';

class TopUpTab extends StatefulWidget {
  const TopUpTab({super.key});

  @override
  State<TopUpTab> createState() => _TopUpTabState();
}

class _TopUpTabState extends State<TopUpTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  final TextEditingController _schoolIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  Map<String, dynamic>? _selectedUser;
  bool _isLoading = false;
  String? _validationMessage;
  List<Map<String, dynamic>> _recentTopUps = [];
  bool _isLoadingRecentTopUps = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {}); // Rebuild when amount changes
    });
    _loadRecentTopUps(); // Load recent top-ups when the widget initializes
  }

  @override
  void dispose() {
    _amountController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth > 600 ? 24.0 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Top-Up Credits',
              style: TextStyle(
                fontSize: isMobile ? 24 : 28,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add credits to user accounts using School ID',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: isMobile ? 20 : 30),

            // Top-up form and user info
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWideScreen = constraints.maxWidth > 800;

                return isWideScreen
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildTopUpForm()),
                        const SizedBox(width: 30),
                        Expanded(flex: 1, child: _buildUserInfo()),
                      ],
                    )
                    : Column(
                      children: [
                        _buildTopUpForm(),
                        const SizedBox(height: 30),
                        _buildUserInfo(),
                      ],
                    );
              },
            ),

            const SizedBox(height: 30),
            _buildRecentTopUps(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top-Up User Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // School ID field with search
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'School ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _schoolIdController,
                onChanged: _searchUser,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: evsuRed),
                  hintText: 'Enter School ID (e.g., EVSU-2024-001)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: evsuRed),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top-Up Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.attach_money, color: evsuRed),
                  hintText: 'Enter amount (e.g., 100.00)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: evsuRed),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick amount buttons
          const Text(
            'Quick Amount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [50, 100, 150, 200, 500].map((amount) {
                  return GestureDetector(
                    onTap: () {
                      _amountController.text = amount.toString();
                      setState(() {}); // Force rebuild
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: evsuRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: evsuRed.withOpacity(0.3)),
                      ),
                      child: Text(
                        '₱$amount',
                        style: TextStyle(
                          color: evsuRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _selectedUser != null && _amountController.text.isNotEmpty
                          ? () => _showTopUpConfirmation()
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selectedUser != null &&
                                _amountController.text.isNotEmpty
                            ? evsuRed
                            : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _selectedUser == null
                        ? 'Select User First'
                        : _amountController.text.isEmpty
                        ? 'Enter Amount'
                        : 'Process Top-Up',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _clearForm,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: evsuRed),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Clear',
                  style: TextStyle(color: evsuRed, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading) ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.shade200,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: evsuRed),
                    const SizedBox(height: 8),
                    Text(
                      'Validating ID...',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_selectedUser != null) ...[
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: evsuRed,
                  child: Text(
                    _selectedUser!['name'].toString().substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedUser!['name'].toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'ID: ${_selectedUser!['student_id']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildUserDetailItem(
              'Student ID',
              _selectedUser!['student_id'].toString(),
            ),
            _buildUserDetailItem('Email', _selectedUser!['email'].toString()),
          ] else if (_validationMessage != null) ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                color:
                    _validationMessage == 'Not registered'
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _validationMessage == 'Not registered'
                          ? Colors.red.shade200
                          : Colors.orange.shade200,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _validationMessage == 'Not registered'
                          ? Icons.person_off
                          : Icons.error_outline,
                      color:
                          _validationMessage == 'Not registered'
                              ? Colors.red.shade600
                              : Colors.orange.shade600,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _validationMessage!,
                      style: TextStyle(
                        color:
                            _validationMessage == 'Not registered'
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade400, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Enter School ID to search user',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTopUps() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Top-Ups',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isLoadingRecentTopUps)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: evsuRed,
                  ),
                )
              else
                IconButton(
                  onPressed: _loadRecentTopUps,
                  icon: const Icon(Icons.refresh, color: evsuRed),
                  tooltip: 'Refresh',
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingRecentTopUps)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: evsuRed),
              ),
            )
          else if (_recentTopUps.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'No recent top-ups found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentTopUps.map((topup) => _buildTopUpItem(topup)).toList(),
        ],
      ),
    );
  }

  Widget _buildTopUpItem(Map<String, dynamic> topup) {
    final createdAt = DateTime.parse(topup['created_at']);
    final formattedDate =
        '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final formattedTime =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, color: Colors.green.shade700, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topup['student_name'] ?? 'Unknown Student',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${topup['student_id']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                Text(
                  '$formattedDate $formattedTime',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${(topup['amount'] as num).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _searchUser(String schoolId) async {
    if (schoolId.isEmpty) {
      setState(() {
        _selectedUser = null;
        _validationMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _validationMessage = null;
    });

    try {
      // Initialize Supabase if not already done
      await SupabaseService.initialize();

      // Search for student in auth_students table
      final response =
          await SupabaseService.adminClient
              .from('auth_students')
              .select('*')
              .eq('student_id', schoolId.trim())
              .maybeSingle();

      if (response != null) {
        // Decrypt the student data
        final decryptedData = _decryptStudentData(response);

        setState(() {
          _selectedUser = decryptedData;
          _validationMessage = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _selectedUser = null;
          _validationMessage = 'Not registered';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _selectedUser = null;
        _validationMessage = 'Error validating ID: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _decryptStudentData(Map<String, dynamic> studentData) {
    try {
      // Decrypt the student data
      final decryptedData = EncryptionService.decryptUserData(studentData);

      return {
        'name': decryptedData['name'] ?? 'N/A',
        'student_id': studentData['student_id'],
        'email': decryptedData['email'] ?? 'N/A',
        'course': decryptedData['course'] ?? 'N/A',
        'rfid_id': decryptedData['rfid_id'] ?? 'N/A',
        'balance': studentData['balance']?.toString() ?? '₱0.00',
        'status': 'Active',
        'raw_balance':
            studentData['balance']?.toDouble() ??
            0.0, // Store raw balance for calculations
      };
    } catch (e) {
      // If decryption fails, return basic data
      return {
        'name': 'N/A',
        'student_id': studentData['student_id'],
        'email': 'N/A',
        'course': 'N/A',
        'rfid_id': 'N/A',
        'balance': '₱0.00',
        'status': 'Active',
        'raw_balance': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> _updateUserBalance({
    required String studentId,
    required double topUpAmount,
  }) async {
    try {
      // Initialize Supabase if not already done
      await SupabaseService.initialize();

      // Use the database function to process top-up transaction
      final response = await SupabaseService.adminClient.rpc(
        'process_top_up_transaction',
        params: {
          'p_student_id': studentId,
          'p_amount': topUpAmount,
          'p_processed_by':
              'admin', // You can modify this to track which admin processed it
          'p_notes': 'Top-up via admin panel',
        },
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'data': {
            'previous_balance': response['data']['previous_balance'],
            'new_balance': response['data']['new_balance'],
            'top_up_amount': response['data']['amount'],
            'transaction_id': response['data']['transaction_id'],
          },
          'message': 'Balance updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Unknown error',
          'message': response['message'] ?? 'Failed to process top-up',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update balance: ${e.toString()}',
      };
    }
  }

  Future<void> _loadRecentTopUps() async {
    setState(() {
      _isLoadingRecentTopUps = true;
    });

    try {
      // Initialize Supabase if not already done
      await SupabaseService.initialize();

      // Use the database function to get recent top-up transactions
      final response = await SupabaseService.adminClient.rpc(
        'get_recent_top_up_transactions',
        params: {'p_limit': 10},
      );

      if (response['success'] == true) {
        final transactions = response['data'] as List<dynamic>;

        // Decrypt student names in the transactions
        List<Map<String, dynamic>> decryptedTransactions = [];
        for (var transaction in transactions) {
          Map<String, dynamic> decryptedTransaction = Map<String, dynamic>.from(
            transaction,
          );

          // Try to decrypt the student name if it looks encrypted
          String studentName = transaction['student_name'] ?? 'Unknown Student';
          if (studentName != 'Unknown Student' && studentName.length > 20) {
            try {
              // The name from database might be encrypted, try to decrypt it
              studentName = EncryptionService.decryptData(studentName);
            } catch (e) {
              // If decryption fails, use the original name
              print('Failed to decrypt student name: $e');
            }
          }

          decryptedTransaction['student_name'] = studentName;
          decryptedTransactions.add(decryptedTransaction);
        }

        setState(() {
          _recentTopUps = decryptedTransactions;
          _isLoadingRecentTopUps = false;
        });
      } else {
        setState(() {
          _recentTopUps = [];
          _isLoadingRecentTopUps = false;
        });
      }
    } catch (e) {
      setState(() {
        _recentTopUps = [];
        _isLoadingRecentTopUps = false;
      });
      print('Failed to load recent top-ups: $e');
    }
  }

  void _clearForm() {
    setState(() {
      _schoolIdController.clear();
      _amountController.clear();
      _selectedUser = null;
      _validationMessage = null;
      _isLoading = false;
    });
  }

  void _showTopUpConfirmation() {
    if (_selectedUser == null || _amountController.text.isEmpty) return;

    final topUpAmount = double.tryParse(_amountController.text) ?? 0.0;
    final currentBalance = _selectedUser!['raw_balance'] ?? 0.0;
    final newBalance = currentBalance + topUpAmount;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Top-Up'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${_selectedUser!['name']}'),
                Text('Student ID: ${_selectedUser!['student_id']}'),
                Text('Email: ${_selectedUser!['email']}'),
                Text('Course: ${_selectedUser!['course']}'),
                const SizedBox(height: 16),
                Text('Current Balance: ₱${currentBalance.toStringAsFixed(2)}'),
                Text(
                  'Top-Up Amount: ₱${topUpAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'New Balance: ₱${newBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: evsuRed,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processTopUp();
                },
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                child: const Text(
                  'Confirm Top-Up',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _processTopUp() async {
    if (_selectedUser == null || _amountController.text.isEmpty) return;

    final topUpAmount = double.tryParse(_amountController.text) ?? 0.0;
    final studentId = _selectedUser!['student_id'];

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: evsuRed),
                const SizedBox(height: 16),
                Text(
                  'Processing top-up of ₱${topUpAmount.toStringAsFixed(2)}...',
                ),
              ],
            ),
          ),
    );

    try {
      // Update the balance
      final result = await _updateUserBalance(
        studentId: studentId,
        topUpAmount: topUpAmount,
      );

      // Close loading dialog
      Navigator.pop(context);

      if (result['success']) {
        // Update the local user data
        setState(() {
          _selectedUser!['raw_balance'] = result['data']['new_balance'];
          _selectedUser!['balance'] =
              '₱${result['data']['new_balance'].toStringAsFixed(2)}';
        });

        // Refresh recent top-ups to show the new transaction
        _loadRecentTopUps();

        // Show success dialog
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    const SizedBox(width: 8),
                    const Text('Top-Up Successful'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User: ${_selectedUser!['name']}'),
                    Text('Student ID: ${_selectedUser!['student_id']}'),
                    const SizedBox(height: 16),
                    Text(
                      'Previous Balance: ₱${result['data']['previous_balance'].toStringAsFixed(2)}',
                    ),
                    Text(
                      'Top-Up Amount: ₱${result['data']['top_up_amount'].toStringAsFixed(2)}',
                    ),
                    Text(
                      'New Balance: ₱${result['data']['new_balance'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: evsuRed,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearForm();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        );
      } else {
        // Show error dialog
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 28),
                    const SizedBox(width: 8),
                    const Text('Top-Up Failed'),
                  ],
                ),
                content: Text(
                  result['message'] ??
                      'An error occurred while processing the top-up.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 28),
                  const SizedBox(width: 8),
                  const Text('Top-Up Failed'),
                ],
              ),
              content: Text('An unexpected error occurred: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }
}
