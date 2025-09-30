import 'dart:async';
import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  StreamSubscription<List<Map<String, dynamic>>>? _balanceSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to balance updates only for Main accounts
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    if (operationalType == 'Main') {
      _subscribeToServiceBalance();
    }
  }

  @override
  void dispose() {
    try {
      _balanceSubscription?.cancel();
    } catch (_) {}
    super.dispose();
  }

  void _subscribeToServiceBalance() {
    // Safety: Only Main accounts should fetch balance
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    if (operationalType != 'Main') return;

    final serviceIdStr =
        SessionService.currentUserData?['service_id']?.toString();
    if (serviceIdStr == null || serviceIdStr.isEmpty) return;
    final int? serviceId = int.tryParse(serviceIdStr);
    if (serviceId == null) return;

    try {
      _balanceSubscription?.cancel();
    } catch (_) {}

    _balanceSubscription = SupabaseService.client
        .from('service_accounts')
        .stream(primaryKey: ['id'])
        .eq('id', serviceId)
        .limit(1)
        .listen((rows) {
          if (rows.isEmpty) return;
          final row = rows.first;
          final newBalance = double.tryParse(row['balance']?.toString() ?? '');
          if (newBalance != null) {
            SessionService.currentUserData?['balance'] = newBalance.toString();
            if (mounted) setState(() {});
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;

    final currentBalance =
        double.tryParse(
          SessionService.currentUserData?['balance']?.toString() ?? '0',
        ) ??
        0.0;

    final serviceName =
        SessionService.currentUserData?['service_name']?.toString() ??
        'Service';
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isWeb ? 24 : 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB91C1C).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isWeb ? 16 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isWeb ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            operationalType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (operationalType == 'Main') ...[
                  Text(
                    'Service Account Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isWeb ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWeb ? 42 : 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Available for transactions and student top-ups',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: isWeb ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Top Up Student',
                  subtitle:
                      operationalType == 'Main'
                          ? 'Transfer balance to students'
                          : 'Only available for Main accounts',
                  icon: Icons.person_add,
                  color: operationalType == 'Main' ? Colors.green : Colors.grey,
                  onTap:
                      operationalType == 'Main'
                          ? () => _showTopUpDialog()
                          : null,
                  isWeb: isWeb,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  title: 'Transaction History',
                  subtitle: 'View recent transactions',
                  icon: Icons.history,
                  color: Colors.blue,
                  onTap: () => _showTransactionHistory(),
                  isWeb: isWeb,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Balance Overview Cards
          Text(
            'Balance Overview',
            style: TextStyle(
              fontSize: isWeb ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Today\'s Sales',
                  value: '₱0.00',
                  icon: Icons.trending_up,
                  color: Colors.green,
                  isWeb: isWeb,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Top-ups Made',
                  value: '₱0.00',
                  icon: Icons.swap_horiz,
                  color: Colors.orange,
                  isWeb: isWeb,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'This Month',
                  value: '₱0.00',
                  icon: Icons.calendar_month,
                  color: Colors.blue,
                  isWeb: isWeb,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'Total Fees Earned',
                  value: '₱0.00',
                  icon: Icons.monetization_on,
                  color: Colors.purple,
                  isWeb: isWeb,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Activity
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isWeb ? 24 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: isWeb ? 18 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showTransactionHistory(),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildActivityItem(
                  'No recent activity',
                  'Start by topping up students or making sales',
                  Icons.info_outline,
                  Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required bool isWeb,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              isEnabled
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          children: [
            Container(
              width: isWeb ? 50 : 45,
              height: isWeb ? 50 : 45,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: isWeb ? 24 : 20),
            ),
            SizedBox(height: isWeb ? 12 : 10),
            Text(
              title,
              style: TextStyle(
                fontSize: isWeb ? 14 : 13,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.black : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isWeb ? 4 : 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isWeb ? 12 : 11,
                color: isEnabled ? Colors.grey[600] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isWeb,
  }) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 16 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isWeb ? 18 : 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isWeb ? 12 : 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isWeb ? 8 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isWeb ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTopUpDialog() {
    final amounts = [50, 100, 200, 500, 1000];
    int? selectedAmount = amounts.first;
    final TextEditingController studentIdController = TextEditingController();
    String? studentIdError;
    String? studentName;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Top Up Student Balance'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student ID Input
                        TextField(
                          controller: studentIdController,
                          decoration: InputDecoration(
                            labelText: 'Student ID',
                            border: const OutlineInputBorder(),
                            errorText: studentIdError,
                          ),
                          onChanged: (value) async {
                            if (value.isNotEmpty) {
                              final result = await _validateStudentId(value);
                              setState(() {
                                studentName = result['name'];
                                studentIdError = result['error'];
                              });
                            } else {
                              setState(() {
                                studentName = null;
                                studentIdError = null;
                              });
                            }
                          },
                        ),

                        if (studentName != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.green.shade100,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.shade300,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Student Found:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 36),
                                  child: Text(
                                    studentName ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        const Text(
                          'Select Amount:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              amounts.map((amount) {
                                final studentReceives = (amount * 0.98);
                                final youPay = (amount * 0.99);
                                return ChoiceChip(
                                  label: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('₱$amount'),
                                      if (selectedAmount == amount) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Student gets ₱${studentReceives.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.green,
                                          ),
                                        ),
                                        Text(
                                          'You pay ₱${youPay.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected: selectedAmount == amount,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        selectedAmount = amount;
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          studentName != null && selectedAmount != null
                              ? () {
                                Navigator.pop(context);
                                _processStudentTopUp(
                                  selectedAmount!,
                                  studentIdController.text,
                                  studentName!,
                                );
                              }
                              : null,
                      child: const Text('Transfer Balance'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<Map<String, dynamic>> _validateStudentId(String studentId) async {
    try {
      final response =
          await SupabaseService.client
              .from('auth_students')
              .select('student_id, name')
              .eq('student_id', studentId)
              .maybeSingle();

      if (response == null) {
        return {'error': 'Student ID not found'};
      }

      // Decrypt the student name
      String studentName = response['name']?.toString() ?? '';

      try {
        // Check if the name looks encrypted and decrypt it
        if (EncryptionService.looksLikeEncryptedData(studentName)) {
          studentName = EncryptionService.decryptData(studentName);
        }
      } catch (e) {
        print('Failed to decrypt student name: $e');
        // Keep the original name if decryption fails
      }

      return {'name': studentName};
    } catch (e) {
      return {'error': 'Error validating student ID: $e'};
    }
  }

  Future<void> _processStudentTopUp(
    int amount,
    String studentId,
    String studentName,
  ) async {
    // Calculate amounts
    final studentReceives = (amount * 0.98); // Student gets 98%
    final serviceDeduction = (amount * 0.99); // Service pays 99%

    final serviceAccountId = SessionService.currentUserData?['service_id'];
    if (serviceAccountId == null) {
      _showErrorSnackBar('Service account not found');
      return;
    }

    // Check service account balance
    final currentServiceBalance =
        double.tryParse(
          SessionService.currentUserData?['balance']?.toString() ?? '0',
        ) ??
        0.0;

    if (currentServiceBalance < serviceDeduction) {
      _showErrorSnackBar(
        'Insufficient balance. Need ₱${serviceDeduction.toStringAsFixed(2)} but have ₱${currentServiceBalance.toStringAsFixed(2)}',
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Processing transfer...'),
              ],
            ),
          ),
    );

    try {
      // Use the proper top-up transaction function that creates records in top_up_transactions table
      print(
        'DEBUG: Creating top-up transaction for studentId: "$studentId", amount: $studentReceives',
      );
      final topUpResult = await SupabaseService.client.rpc(
        'process_top_up_transaction',
        params: {
          'p_student_id': studentId,
          'p_amount': studentReceives,
          'p_processed_by':
              SessionService.currentUserName.isNotEmpty
                  ? SessionService.currentUserName
                  : 'Service Account',
          'p_notes':
              'Top-up from service account ${SessionService.currentUserName}',
        },
      );

      print('DEBUG: Top-up result: $topUpResult');

      if (topUpResult == null || topUpResult['success'] != true) {
        throw Exception(topUpResult?['message'] ?? 'Top-up transaction failed');
      }

      // Update service account balance
      final newServiceBalance = currentServiceBalance - serviceDeduction;
      await SupabaseService.client
          .from('service_accounts')
          .update({'balance': newServiceBalance})
          .eq('id', serviceAccountId);

      // Update local session data
      SessionService.currentUserData?['balance'] = newServiceBalance.toString();

      Navigator.pop(context); // Close loading dialog

      setState(() {}); // Refresh the UI

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully transferred ₱${studentReceives.toStringAsFixed(2)} to $studentName.\n'
            'Your balance: ₱${newServiceBalance.toStringAsFixed(2)} (₱${serviceDeduction.toStringAsFixed(2)} deducted)',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('Transfer failed: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showTransactionHistory() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Transaction History'),
            content: const Text(
              'Transaction history feature will be implemented here.\n\n'
              'This will show:\n'
              '• Student top-ups made\n'
              '• Payment transactions\n'
              '• Balance changes\n'
              '• Fee deductions',
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
}
