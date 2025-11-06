import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import 'service_withdraw_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  StreamSubscription<List<Map<String, dynamic>>>? _balanceSubscription;
  double _todaysSales = 0.0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    // Subscribe to balance updates only for Main accounts
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    // ignore: avoid_print
    print('DEBUG HomeTab: init, operationalType=$operationalType');
    if (operationalType == 'Main') {
      _fetchInitialServiceBalance();
      _subscribeToServiceBalance();
    }
    _loadTodaysSales();
    _loadRecentActivities();
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

    // ignore: avoid_print
    print('DEBUG HomeTab: subscribing to service_accounts id=$serviceId');

    try {
      _balanceSubscription?.cancel();
    } catch (_) {}

    _balanceSubscription = SupabaseService.client
        .from('service_accounts')
        .stream(primaryKey: ['id'])
        .eq('id', serviceId)
        .limit(1)
        .listen((rows) {
          // ignore: avoid_print
          print('DEBUG HomeTab: realtime rows len=${rows.length}');
          if (rows.isEmpty) return;
          final row = rows.first;
          final newBalance = double.tryParse(row['balance']?.toString() ?? '');
          if (newBalance != null) {
            // ignore: avoid_print
            print('DEBUG HomeTab: realtime balance=$newBalance');
            SessionService.currentUserData?['balance'] = newBalance.toString();
            if (mounted) setState(() {});
          }
        });
  }

  Future<void> _fetchInitialServiceBalance() async {
    try {
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString();
      if (serviceIdStr == null || serviceIdStr.isEmpty) return;
      final int? serviceId = int.tryParse(serviceIdStr);
      if (serviceId == null) return;

      // ignore: avoid_print
      print('DEBUG HomeTab: fetching initial balance for id=$serviceId');
      final row =
          await SupabaseService.client
              .from('service_accounts')
              .select('balance')
              .eq('id', serviceId)
              .maybeSingle();
      if (row != null) {
        final newBalance = double.tryParse(row['balance']?.toString() ?? '');
        if (newBalance != null) {
          // ignore: avoid_print
          print('DEBUG HomeTab: initial balance=$newBalance');
          SessionService.currentUserData?['balance'] = newBalance.toString();
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG HomeTab: initial balance error: $e');
      // ignore errors; realtime will still update
    }
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
    final todaysSalesStr = '₱${_todaysSales.toStringAsFixed(2)}';

    final serviceName =
        SessionService.currentUserData?['service_name']?.toString() ??
        'Service';
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    final serviceCategory =
        SessionService.currentUserData?['service_category']?.toString() ?? '';
    final bool vendorAllowed = serviceCategory == 'Vendor';

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
              if (vendorAllowed) ...[
                Expanded(
                  child: _buildActionCard(
                    title: 'Top Up Student',
                    subtitle: 'Transfer balance to students',
                    icon: Icons.person_add,
                    color: Colors.green,
                    onTap: () => _showTopUpDialog(),
                    isWeb: isWeb,
                  ),
                ),
                const SizedBox(width: 16),
              ],
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

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Profile Settings',
                  subtitle: 'Update service information',
                  icon: Icons.settings,
                  color: Colors.purple,
                  onTap: () => _showProfileSettingsDialog(),
                  isWeb: isWeb,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  title: 'Withdraw',
                  subtitle:
                      operationalType == 'Main'
                          ? 'Withdraw funds to admin'
                          : 'Only available for Main accounts',
                  icon: Icons.account_balance_wallet,
                  color:
                      operationalType == 'Main'
                          ? Colors.red.shade700
                          : Colors.grey,
                  onTap:
                      operationalType == 'Main'
                          ? () => _navigateToWithdraw()
                          : null,
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
                  value: todaysSalesStr,
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
                if (_isLoadingActivities) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_recentActivities.isEmpty) ...[
                  _buildActivityItem(
                    'No recent activity',
                    'Start by topping up students or making sales',
                    Icons.info_outline,
                    Colors.grey,
                    null,
                  ),
                ] else ...[
                  ..._recentActivities.map(
                    (activity) => _buildActivityItem(
                      activity['title'] as String,
                      activity['subtitle'] as String,
                      activity['icon'] as IconData,
                      activity['color'] as Color,
                      DateTime.parse(activity['created_at'] as String),
                      activityData: activity,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTodaysSales() async {
    try {
      await SupabaseService.initialize();
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day);
      final localEndNext = localStart.add(const Duration(days: 1));
      final from = localStart.toUtc().toIso8601String();
      final to = localEndNext.toUtc().toIso8601String();

      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';
      final mainServiceIdStr =
          SessionService.currentUserData?['main_service_id']?.toString();
      final rootMainId =
          operationalType == 'Sub'
              ? (int.tryParse(mainServiceIdStr ?? '') ?? serviceId)
              : serviceId;

      // ignore: avoid_print
      print(
        'DEBUG HomeTab: today localStart=$localStart localEndNext=$localEndNext, UTC from=$from to=$to, rootMainId=$rootMainId',
      );

      final res = await SupabaseService.client
          .from('service_transactions')
          .select(
            'total_amount, main_service_id, service_account_id, created_at',
          )
          .or(
            'main_service_id.eq.${rootMainId},service_account_id.eq.${rootMainId}',
          )
          .gte('created_at', from)
          .lt('created_at', to);

      double sum = 0.0;
      for (final row in (res as List)) {
        sum += ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
      }
      // ignore: avoid_print
      print(
        'DEBUG HomeTab: today sales rows=${(res as List).length}, sum=$sum',
      );
      if (mounted) setState(() => _todaysSales = sum);
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG HomeTab: load today sales error: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      await SupabaseService.initialize();
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';

      final List<Map<String, dynamic>> activities = [];

      // Get top-up transactions (where this service account processed top-ups)
      try {
        final topUpTransactions = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, created_at, processed_by, transaction_type, service_accounts!top_up_transactions_processed_by_fkey(service_name)',
            )
            .eq('processed_by', SessionService.currentUserName)
            .order('created_at', ascending: false)
            .limit(10);

        for (final transaction in topUpTransactions) {
          final serviceName =
              (transaction['service_accounts']?['service_name']?.toString()) ??
              (transaction['processed_by']?.toString() ?? 'Unknown Service');

          activities.add({
            'id': transaction['id'],
            'type': 'top_up',
            'title': 'Student Top-up',
            'subtitle':
                'Topped up ₱${(transaction['amount'] as num).toStringAsFixed(2)} to student ${transaction['student_id']} • Processed by: $serviceName',
            'amount': transaction['amount'],
            'created_at': transaction['created_at'],
            'icon': Icons.person_add,
            'color': Colors.green,
          });
        }
      } catch (e) {
        print('DEBUG HomeTab: Error loading top-up transactions: $e');
      }

      // Get service transactions (payments made by students to this service)
      try {
        final serviceTransactions = await SupabaseService.client
            .from('service_transactions')
            .select(
              'id, student_id, total_amount, created_at, items, service_account_id, service_accounts!service_transactions_service_account_id_fkey(service_name)',
            )
            .or(
              operationalType == 'Main'
                  ? 'main_service_id.eq.${serviceId},service_account_id.eq.${serviceId}'
                  : 'service_account_id.eq.${serviceId}',
            )
            .order('created_at', ascending: false)
            .limit(10);

        for (final transaction in serviceTransactions) {
          final items = transaction['items'] as List?;
          final firstItem = items?.isNotEmpty == true ? items!.first : null;
          final itemName = firstItem?['name']?.toString() ?? 'Service Payment';
          final serviceName =
              (transaction['service_accounts']?['service_name']?.toString()) ??
              'Unknown Service';

          // Debug: Print transaction data to understand the structure
          print('DEBUG: Transaction data: ${transaction.toString()}');
          print(
            'DEBUG: Service accounts data: ${transaction['service_accounts']}',
          );
          print('DEBUG: Service name extracted: $serviceName');

          activities.add({
            'id': transaction['id'],
            'type': 'payment',
            'title': 'Payment Received',
            'subtitle':
                '₱${(transaction['total_amount'] as num).toStringAsFixed(2)} for $itemName from student ${transaction['student_id']} • Service: $serviceName',
            'amount': transaction['total_amount'],
            'created_at': transaction['created_at'],
            'icon': Icons.payment,
            'color': Colors.blue,
          });
        }
      } catch (e) {
        print('DEBUG HomeTab: Error loading service transactions: $e');
      }

      // Get withdrawal transactions (where users withdrew to this service account)
      try {
        print(
          'DEBUG HomeTab: Fetching withdrawal transactions for service ID: $serviceId',
        );
        final withdrawalResult = await SupabaseService.adminClient
            .from('withdrawal_transactions')
            .select(
              'id, student_id, amount, created_at, transaction_type, metadata',
            )
            .eq('destination_service_id', serviceId)
            .eq('transaction_type', 'Withdraw to Service')
            .order('created_at', ascending: false)
            .limit(10);

        print(
          'DEBUG HomeTab: Withdrawal transactions found: ${withdrawalResult.length}',
        );

        for (final withdrawal in (withdrawalResult as List)) {
          final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
          final studentId = withdrawal['student_id']?.toString() ?? 'Unknown';

          activities.add({
            'id': withdrawal['id'],
            'type': 'withdrawal',
            'title': 'Balance Transfer Received',
            'subtitle':
                '₱${amount.toStringAsFixed(2)} transferred from student $studentId',
            'amount': amount,
            'created_at': withdrawal['created_at'],
            'icon': Icons.account_balance_wallet,
            'color': Colors.purple,
          });
        }
      } catch (e) {
        print('DEBUG HomeTab: Error loading withdrawal transactions: $e');
      }

      // Sort all activities by created_at (most recent first)
      activities.sort((a, b) {
        final aTime = DateTime.parse(a['created_at']);
        final bTime = DateTime.parse(b['created_at']);
        return bTime.compareTo(aTime);
      });

      // Take only the 10 most recent activities for home tab
      if (mounted) {
        setState(() {
          _recentActivities = activities.take(10).toList();
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      print('DEBUG HomeTab: Error loading recent activities: $e');
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
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
    DateTime? dateTime, {
    Map<String, dynamic>? activityData,
  }) {
    return GestureDetector(
      onTap:
          activityData != null
              ? () => _showTransactionDetailModal(activityData)
              : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  if (dateTime != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(dateTime),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            if (activityData != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 16),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    // Convert UTC to local time (assuming UTC+8 for Philippines)
    // Supabase stores datetime in UTC, so we add 8 hours to get local time
    final localDateTime = dateTime.add(const Duration(hours: 8));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
    );

    String dateStr;
    if (activityDate == today) {
      dateStr = 'Today';
    } else if (activityDate == yesterday) {
      dateStr = 'Yesterday';
    } else {
      // Format as "Oct 1, 2025"
      final months = [
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
      dateStr =
          '${months[localDateTime.month - 1]} ${localDateTime.day}, ${localDateTime.year}';
    }

    // Format time as "9:56 am" using local time
    final hour =
        localDateTime.hour == 0
            ? 12
            : (localDateTime.hour > 12
                ? localDateTime.hour - 12
                : localDateTime.hour);
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    final amPm = localDateTime.hour < 12 ? 'am' : 'pm';
    final timeStr = '$hour:$minute $amPm';

    return '$dateStr $timeStr';
  }

  Future<void> _navigateToWithdraw() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ServiceWithdrawScreen()),
    );

    // If withdrawal was successful, refresh the UI
    if (result == true && mounted) {
      setState(() {
        // This will refresh the balance display
      });
    }
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
      _loadRecentActivities(); // Refresh recent activities

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

  Future<List<Map<String, dynamic>>> _loadAllTransactions() async {
    try {
      await SupabaseService.initialize();
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';

      final List<Map<String, dynamic>> activities = [];

      // Get top-up transactions (where this service account processed top-ups)
      try {
        final topUpTransactions = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, created_at, processed_by, transaction_type, service_accounts!top_up_transactions_processed_by_fkey(service_name)',
            )
            .eq('processed_by', SessionService.currentUserName)
            .order('created_at', ascending: false)
            .limit(50); // Load more for history modal

        for (final transaction in topUpTransactions) {
          final serviceName =
              (transaction['service_accounts']?['service_name']?.toString()) ??
              (transaction['processed_by']?.toString() ?? 'Unknown Service');

          activities.add({
            'id': transaction['id'],
            'type': 'top_up',
            'title': 'Student Top-up',
            'subtitle':
                'Topped up ₱${(transaction['amount'] as num).toStringAsFixed(2)} to student ${transaction['student_id']} • Processed by: $serviceName',
            'amount': transaction['amount'],
            'created_at': transaction['created_at'],
            'icon': Icons.person_add,
            'color': Colors.green,
          });
        }
      } catch (e) {
        print(
          'DEBUG HomeTab: Error loading top-up transactions for history: $e',
        );
      }

      // Get service transactions (payments made by students to this service)
      try {
        final serviceTransactions = await SupabaseService.client
            .from('service_transactions')
            .select(
              'id, student_id, total_amount, created_at, items, service_account_id, service_accounts!service_transactions_service_account_id_fkey(service_name)',
            )
            .or(
              operationalType == 'Main'
                  ? 'main_service_id.eq.${serviceId},service_account_id.eq.${serviceId}'
                  : 'service_account_id.eq.${serviceId}',
            )
            .order('created_at', ascending: false)
            .limit(50);

        for (final transaction in serviceTransactions) {
          final items = transaction['items'] as List?;
          final firstItem = items?.isNotEmpty == true ? items!.first : null;
          final itemName = firstItem?['name']?.toString() ?? 'Service Payment';
          final serviceName =
              (transaction['service_accounts']?['service_name']?.toString()) ??
              'Unknown Service';

          // Debug: Print transaction data to understand the structure
          print('DEBUG History: Transaction data: ${transaction.toString()}');
          print(
            'DEBUG History: Service accounts data: ${transaction['service_accounts']}',
          );
          print('DEBUG History: Service name extracted: $serviceName');

          activities.add({
            'id': transaction['id'],
            'type': 'payment',
            'title': 'Payment Received',
            'subtitle':
                '₱${(transaction['total_amount'] as num).toStringAsFixed(2)} for $itemName from student ${transaction['student_id']} • Service: $serviceName',
            'amount': transaction['total_amount'],
            'created_at': transaction['created_at'],
            'icon': Icons.payment,
            'color': Colors.blue,
          });
        }
      } catch (e) {
        print(
          'DEBUG HomeTab: Error loading service transactions for history: $e',
        );
      }

      // Get withdrawal transactions (where users withdrew to this service account)
      try {
        print(
          'DEBUG HomeTab: Fetching withdrawal transactions for history, service ID: $serviceId',
        );
        final withdrawalResult = await SupabaseService.adminClient
            .from('withdrawal_transactions')
            .select(
              'id, student_id, amount, created_at, transaction_type, metadata',
            )
            .eq('destination_service_id', serviceId)
            .eq('transaction_type', 'Withdraw to Service')
            .order('created_at', ascending: false)
            .limit(50); // Load more for history modal

        print(
          'DEBUG HomeTab: Withdrawal transactions found for history: ${withdrawalResult.length}',
        );

        for (final withdrawal in (withdrawalResult as List)) {
          final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
          final studentId = withdrawal['student_id']?.toString() ?? 'Unknown';

          activities.add({
            'id': withdrawal['id'],
            'type': 'withdrawal',
            'title': 'Balance Transfer Received',
            'subtitle':
                '₱${amount.toStringAsFixed(2)} transferred from student $studentId',
            'amount': amount,
            'created_at': withdrawal['created_at'],
            'icon': Icons.account_balance_wallet,
            'color': Colors.purple,
          });
        }
      } catch (e) {
        print(
          'DEBUG HomeTab: Error loading withdrawal transactions for history: $e',
        );
      }

      // Sort all activities by created_at (most recent first)
      activities.sort((a, b) {
        final aTime = DateTime.parse(a['created_at']);
        final bTime = DateTime.parse(b['created_at']);
        return bTime.compareTo(aTime);
      });

      return activities;
    } catch (e) {
      print('DEBUG HomeTab: Error loading all transactions: $e');
      return [];
    }
  }

  void _showTransactionHistory() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              final screenSize = MediaQuery.of(context).size;
              final isSmallScreen = screenSize.width < 600;

              return Dialog(
                insetPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 32,
                  vertical: isSmallScreen ? 16 : 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width * (isSmallScreen ? 0.95 : 0.9),
                    maxHeight: screenSize.height * (isSmallScreen ? 0.9 : 0.8),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Transaction History',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),

                        // Loading or Content
                        Expanded(
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _loadAllTransactions(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Error loading transactions: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              final activities = snapshot.data ?? [];

                              if (activities.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No transaction history found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: activities.length,
                                itemBuilder: (context, index) {
                                  final activity = activities[index];
                                  return _buildActivityItem(
                                    activity['title'] as String,
                                    activity['subtitle'] as String,
                                    activity['icon'] as IconData,
                                    activity['color'] as Color,
                                    DateTime.parse(
                                      activity['created_at'] as String,
                                    ),
                                    activityData: activity,
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        // Footer
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  void _showProfileSettingsDialog() {
    final currentData = SessionService.currentUserData;

    final serviceNameController = TextEditingController(
      text: currentData?['service_name']?.toString() ?? '',
    );
    final contactPersonController = TextEditingController(
      text: currentData?['contact_person']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: currentData?['phone']?.toString() ?? '',
    );
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool showPassword = false;
    bool showConfirmPassword = false;
    bool isUpdating = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Profile Settings'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service Name
                        TextField(
                          controller: serviceNameController,
                          decoration: const InputDecoration(
                            labelText: 'Service Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Contact Person
                        TextField(
                          controller: contactPersonController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Person',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          decoration: InputDecoration(
                            labelText: 'New Password (optional)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: !showConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  showConfirmPassword = !showConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Password validation note
                        Text(
                          'Note: Leave password fields empty to keep current password unchanged',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isUpdating ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isUpdating
                              ? null
                              : () async {
                                setState(() {
                                  isUpdating = true;
                                });

                                try {
                                  await _updateProfile(
                                    serviceName:
                                        serviceNameController.text.trim(),
                                    contactPerson:
                                        contactPersonController.text.trim(),
                                    phone: phoneController.text.trim(),
                                    newPassword: passwordController.text.trim(),
                                    confirmPassword:
                                        confirmPasswordController.text.trim(),
                                  );
                                  Navigator.pop(context);
                                } catch (e) {
                                  _showErrorSnackBar(
                                    'Failed to update profile: $e',
                                  );
                                } finally {
                                  setState(() {
                                    isUpdating = false;
                                  });
                                }
                              },
                      child:
                          isUpdating
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Update Profile'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _updateProfile({
    required String serviceName,
    required String contactPerson,
    required String phone,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      // Validate password if provided
      if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
        if (newPassword != confirmPassword) {
          throw Exception('Passwords do not match');
        }
        if (newPassword.length < 6) {
          throw Exception('Password must be at least 6 characters long');
        }
      }

      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString();
      if (serviceIdStr == null || serviceIdStr.isEmpty) {
        throw Exception('Service account not found');
      }

      final serviceId = int.tryParse(serviceIdStr);
      if (serviceId == null) {
        throw Exception('Invalid service account ID');
      }

      // Prepare update data - only include non-empty fields
      Map<String, dynamic> updateData = {};

      if (serviceName.isNotEmpty) {
        updateData['service_name'] = serviceName;
      }
      if (contactPerson.isNotEmpty) {
        updateData['contact_person'] = contactPerson;
      }
      if (phone.isNotEmpty) {
        updateData['phone'] = phone;
      }

      // Handle password update if provided
      if (newPassword.isNotEmpty) {
        // Import the encryption service for password hashing
        updateData['password_hash'] = EncryptionService.hashPassword(
          newPassword,
        );
      }

      if (updateData.isEmpty) {
        throw Exception('No changes to update');
      }

      // Update the service account
      final result = await SupabaseService.updateServiceAccount(
        accountId: serviceId,
        serviceName: updateData['service_name'],
        contactPerson: updateData['contact_person'],
        phone: updateData['phone'],
      );

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to update profile');
      }

      // Update local session data
      if (serviceName.isNotEmpty) {
        SessionService.currentUserData?['service_name'] = serviceName;
      }
      if (contactPerson.isNotEmpty) {
        SessionService.currentUserData?['contact_person'] = contactPerson;
      }
      if (phone.isNotEmpty) {
        SessionService.currentUserData?['phone'] = phone;
      }

      // Refresh the UI
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('DEBUG HomeTab: Profile update error: $e');
      rethrow;
    }
  }

  void _showTransactionDetailModal(Map<String, dynamic> activity) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch actual transaction data based on activity type
      final transactionData = await _fetchServiceTransactionData(activity);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show transaction details modal
      showDialog(
        context: context,
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          final isSmallScreen = screenSize.width < 600;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 32,
              vertical: isSmallScreen ? 16 : 32,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenSize.width * 0.98,
                maxHeight: screenSize.height * 0.9,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFB91C1C),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTransactionTitle(transactionData?['type']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Transaction Details',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Transaction Details
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Transaction ID
                          _buildReceiptRow(
                            'Transaction ID',
                            '#${transactionData?['id']?.toString().padLeft(8, '0') ?? activity['id']?.toString().padLeft(8, '0') ?? 'N/A'}',
                          ),

                          // Amount
                          if (activity['amount'] != null)
                            _buildReceiptRow(
                              'Amount',
                              '₱${(activity['amount'] as num).toStringAsFixed(2)}',
                              isAmount: true,
                            ),

                          // Date and Time
                          _buildReceiptRow(
                            'Date & Time',
                            _formatDateTime(
                              DateTime.parse(activity['created_at']),
                            ),
                          ),

                          // Status
                          _buildReceiptRow(
                            'Status',
                            _getTransactionStatus(transactionData?['type']),
                            statusColor: _getTransactionStatusColor(
                              transactionData?['type'],
                            ),
                          ),

                          // Additional transaction-specific details
                          ..._buildTransactionDetails(transactionData),

                          const SizedBox(height: 20),

                          // Close button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB91C1C),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load transaction details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchServiceTransactionData(
    Map<String, dynamic> activity,
  ) async {
    try {
      final transactionId = activity['id'];
      final transactionType = activity['type'];

      if (transactionId == null) return null;

      switch (transactionType) {
        case 'payment':
          {
            // Fetch service transaction details with service name
            final result =
                await SupabaseService.client
                    .from('service_transactions')
                    .select(
                      '*, service_accounts!service_transactions_service_account_id_fkey(service_name)',
                    )
                    .eq('id', transactionId)
                    .single();

            // Add service name to result
            if (result['service_accounts'] != null) {
              result['service_name'] =
                  result['service_accounts']['service_name']?.toString() ??
                  'Unknown Service';
            } else {
              result['service_name'] = 'Unknown Service';
            }

            // Attempt to fetch and decrypt student name
            try {
              final studentId = result['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String studentName = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(studentName)) {
                    studentName = EncryptionService.decryptData(studentName);
                  }
                  result['student_name'] = studentName;
                }
              }
            } catch (_) {}

            return {
              'type': 'service_payment',
              'data': result,
              'id': transactionId,
            };
          }

        case 'top_up':
          {
            // Fetch top-up transaction details with service name
            final result =
                await SupabaseService.client
                    .from('top_up_transactions')
                    .select(
                      '*, service_accounts!top_up_transactions_processed_by_fkey(service_name)',
                    )
                    .eq('id', transactionId)
                    .single();

            // Add service name to result
            if (result['service_accounts'] != null) {
              result['service_name'] =
                  result['service_accounts']['service_name']?.toString() ??
                  'Unknown Service';
            } else {
              result['service_name'] =
                  result['processed_by']?.toString() ?? 'Unknown Service';
            }

            // Attempt to fetch and decrypt student name
            try {
              final studentId = result['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String studentName = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(studentName)) {
                    studentName = EncryptionService.decryptData(studentName);
                  }
                  result['student_name'] = studentName;
                }
              }
            } catch (_) {}

            return {'type': 'top_up', 'data': result, 'id': transactionId};
          }

        case 'withdrawal':
          {
            // Fetch withdrawal transaction details
            final result =
                await SupabaseService.adminClient
                    .from('withdrawal_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .single();

            // Attempt to fetch and decrypt student name
            try {
              final studentId = result['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String studentName = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(studentName)) {
                    studentName = EncryptionService.decryptData(studentName);
                  }
                  result['student_name'] = studentName;
                }
              }
            } catch (_) {}

            return {'type': 'withdrawal', 'data': result, 'id': transactionId};
          }

        default:
          return null;
      }
    } catch (e) {
      print('Error fetching service transaction data: $e');
      return null;
    }
  }

  String _getTransactionTitle(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        return 'Top-up Transaction';
      case 'service_payment':
        return 'Service Payment';
      case 'withdrawal':
        return 'Balance Transfer Received';
      default:
        return 'Transaction';
    }
  }

  String _getTransactionStatus(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'service_payment':
      case 'withdrawal':
        return 'Completed';
      default:
        return 'Processed';
    }
  }

  Color _getTransactionStatusColor(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'service_payment':
      case 'withdrawal':
        return Colors.green[700]!;
      default:
        return Colors.blue[700]!;
    }
  }

  List<Widget> _buildTransactionDetails(Map<String, dynamic>? transactionData) {
    if (transactionData == null) return [];

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final transactionType = transactionData['type'] as String?;
    final List<Widget> details = [];

    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        details.add(
          _buildReceiptRow(
            'Student ID',
            data['student_id']?.toString() ?? 'N/A',
          ),
        );
        if (data['student_name'] != null &&
            (data['student_name'] as String).isNotEmpty) {
          details.add(
            _buildReceiptRow('Student Name', data['student_name'] as String),
          );
        }
        details.add(
          _buildReceiptRow(
            'Top-up Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'New Balance',
            '₱${_safeParseNumber(data['new_balance']).toStringAsFixed(2)}',
          ),
        );
        if (data['processed_by'] != null) {
          details.add(
            _buildReceiptRow('Processed By', data['processed_by'].toString()),
          );
        }
        if (data['service_name'] != null) {
          details.add(
            _buildReceiptRow('Service Name', data['service_name'].toString()),
          );
        }
        break;

      case 'service_payment':
        details.add(
          _buildReceiptRow(
            'Student ID',
            data['student_id']?.toString() ?? 'N/A',
          ),
        );
        if (data['student_name'] != null &&
            (data['student_name'] as String).isNotEmpty) {
          details.add(
            _buildReceiptRow('Student Name', data['student_name'] as String),
          );
        }
        details.add(
          _buildReceiptRow(
            'Total Amount',
            '₱${_safeParseNumber(data['total_amount']).toStringAsFixed(2)}',
          ),
        );

        // Add service name
        if (data['service_name'] != null) {
          details.add(
            _buildReceiptRow('Service Name', data['service_name'].toString()),
          );
        }

        // Display purchased items from service_transactions.items
        final dynamic rawItems = data['items'];
        List<dynamic> itemsList = [];
        if (rawItems is String) {
          try {
            final decoded = jsonDecode(rawItems);
            if (decoded is List) itemsList = decoded;
          } catch (_) {}
        } else if (rawItems is List) {
          itemsList = rawItems;
        }

        if (itemsList.isNotEmpty) {
          details.add(const SizedBox(height: 12));
          details.add(_buildReceiptRow('Items', '${itemsList.length} item(s)'));

          for (final item in itemsList) {
            try {
              final map = (item is Map) ? Map<String, dynamic>.from(item) : {};
              final String name =
                  (map['name'] ?? map['item_name'] ?? 'Item').toString();
              final double qty = _safeParseNumber(
                map['quantity'] ?? map['qty'],
              );
              final double price = _safeParseNumber(
                map['price'] ?? map['unit_price'] ?? map['amount'],
              );
              final double lineTotal =
                  map.containsKey('total')
                      ? _safeParseNumber(map['total'])
                      : (qty > 0 && price > 0 ? qty * price : price);

              details.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          qty > 0
                              ? 'x${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}  •  ₱${lineTotal.toStringAsFixed(2)}'
                              : '₱${lineTotal.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (_) {
              // Fallback: show raw item string
              details.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    item.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            }
          }
        }
        break;

      case 'withdrawal':
        details.add(
          _buildReceiptRow(
            'Student ID',
            data['student_id']?.toString() ?? 'N/A',
          ),
        );
        if (data['student_name'] != null &&
            (data['student_name'] as String).isNotEmpty) {
          details.add(
            _buildReceiptRow('Student Name', data['student_name'] as String),
          );
        }
        details.add(
          _buildReceiptRow(
            'Transfer Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Transfer Type',
            data['transaction_type']?.toString() ?? 'Withdraw to Service',
          ),
        );

        final metadata = data['metadata'] as Map<String, dynamic>?;
        if (metadata != null && metadata['destination_service_name'] != null) {
          details.add(
            _buildReceiptRow(
              'Destination Service',
              metadata['destination_service_name'].toString(),
            ),
          );
        }
        break;
    }

    return details;
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isHeader = false,
    bool isAmount = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isHeader ? 16 : 14,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
                color: isHeader ? const Color(0xFFB91C1C) : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isHeader ? 16 : 14,
                fontWeight:
                    isHeader || isAmount ? FontWeight.bold : FontWeight.normal,
                color:
                    statusColor ??
                    (isAmount ? const Color(0xFFB91C1C) : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  double _safeParseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
