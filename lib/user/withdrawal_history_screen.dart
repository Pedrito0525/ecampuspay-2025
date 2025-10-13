import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  final String userType; // 'user' or 'service'

  const WithdrawalHistoryScreen({Key? key, required this.userType})
    : super(key: key);

  @override
  State<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  static const Color evsuRed = Color(0xFFB91C1C);

  List<Map<String, dynamic>> _withdrawals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWithdrawalHistory();
  }

  Future<void> _loadWithdrawalHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;

      if (widget.userType == 'user') {
        final studentId =
            SessionService.currentUserData?['student_id']?.toString();
        if (studentId == null) {
          throw Exception('Student ID not found');
        }
        result = await SupabaseService.getUserWithdrawalHistory(
          studentId: studentId,
          limit: 100,
        );
      } else {
        final serviceIdStr =
            SessionService.currentUserData?['service_id']?.toString();
        if (serviceIdStr == null) {
          throw Exception('Service ID not found');
        }
        final serviceId = int.parse(serviceIdStr);
        result = await SupabaseService.getServiceWithdrawalHistory(
          serviceAccountId: serviceId,
          limit: 100,
        );
      }

      if (result['success'] == true) {
        setState(() {
          _withdrawals = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              result['message'] ?? 'Failed to load withdrawal history';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Withdrawal History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: evsuRed,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWithdrawalHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadWithdrawalHistory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _withdrawals.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No withdrawal history',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your withdrawal transactions will appear here',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(isWeb ? 24 : 16),
                itemCount: _withdrawals.length,
                itemBuilder: (context, index) {
                  final withdrawal = _withdrawals[index];
                  return _buildWithdrawalCard(withdrawal, isWeb);
                },
              ),
    );
  }

  Widget _buildWithdrawalCard(Map<String, dynamic> withdrawal, bool isWeb) {
    final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
    final transactionType =
        withdrawal['transaction_type']?.toString() ?? 'Unknown';
    final createdAt = withdrawal['created_at']?.toString();
    final metadata = withdrawal['metadata'] as Map<String, dynamic>?;

    DateTime? dateTime;
    if (createdAt != null) {
      dateTime = DateTime.tryParse(createdAt);
    }

    String formattedDate = 'Unknown date';
    String formattedTime = '';
    if (dateTime != null) {
      formattedDate = _formatDate(dateTime);
      formattedTime = _formatTime(dateTime);
    }

    String destination = 'Admin';
    String destinationSubtitle = 'Cash withdrawal';
    IconData icon = Icons.admin_panel_settings;
    Color iconColor = Colors.orange;

    if (transactionType == 'Withdraw to Service') {
      destination =
          metadata?['destination_service_name']?.toString() ??
          'Service Account';
      destinationSubtitle = 'Transfer to service';
      icon = Icons.store;
      iconColor = Colors.blue;
    } else if (transactionType == 'Service Withdraw to Admin') {
      destination = 'Admin';
      destinationSubtitle = 'Service cash withdrawal';
      icon = Icons.admin_panel_settings;
      iconColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Withdraw to $destination',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destinationSubtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-₱${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      formattedTime,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
