import 'package:flutter/material.dart';
// removed unused: import 'dart:convert';
// removed unused: import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'security_privacy_screen.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import '../services/notification_service.dart';
import '../services/loan_reminder_service.dart';
import '../login_page.dart';
import 'dart:async'; // Added for StreamSubscription
import '../services/paytaca_invoice_service.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  static const Color evsuRed = Color(0xFFB91C1C);
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const _HomeTab(),
    const _InboxTab(),
    const _TransactionsTab(),
    const _ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkSession();
    _initializeNotificationSystem();
  }

  Future<void> _initializeNotificationSystem() async {
    try {
      print('DEBUG DASHBOARD: Initializing notification system...');

      // Initialize notification types and tables
      print('DEBUG DASHBOARD: Initializing notification types...');
      await NotificationService.initializeNotificationTypes();

      print('DEBUG DASHBOARD: Creating notifications table...');
      await NotificationService.createNotificationsTable();

      // Create loan due date notifications
      print('DEBUG DASHBOARD: Creating loan due notifications...');
      await LoanReminderService.checkAndCreateLoanReminders();

      print('DEBUG DASHBOARD: Notification system initialization completed');
    } catch (e) {
      print('ERROR DASHBOARD: Error initializing notification system: $e');
    }
  }

  void _checkSession() {
    if (!SessionService.isLoggedIn || !SessionService.isStudent) {
      // Redirect to login if not logged in or not a student
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: evsuRed,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          backgroundColor: evsuRed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                size: 20,
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 1 ? Icons.mail : Icons.mail_outline,
                size: 20,
              ),
              label: 'Inbox',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 2
                    ? Icons.credit_card
                    : Icons.credit_card_outlined,
                size: 20,
              ),
              label: 'Transactions',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == 3 ? Icons.person : Icons.person_outline,
                size: 20,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  static const Color evsuRedDark = Color(0xFF7F1D1D);

  int _selectedTab = 0; // 0 for Wallet, 1 for Borrow
  bool _balanceVisible = true;

  // Realtime recent transactions for current student
  final List<Map<String, dynamic>> _recentTransactions = [];
  StreamSubscription<List<Map<String, dynamic>>>? _homeTopUpSub;
  StreamSubscription<List<Map<String, dynamic>>>? _homeServiceTxSub;
  StreamSubscription<List<Map<String, dynamic>>>? _homeLoanSub;
  StreamSubscription<List<Map<String, dynamic>>>? _homeTransferSub;

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
    _subscribeRecentTransactions();
  }

  @override
  void dispose() {
    try {
      _homeTopUpSub?.cancel();
    } catch (_) {}
    try {
      _homeServiceTxSub?.cancel();
    } catch (_) {}
    try {
      _homeLoanSub?.cancel();
    } catch (_) {}
    try {
      _homeTransferSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadRecentTransactions() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;
      print('DEBUG: Loading recent transactions for studentId: "$studentId"');
      if (studentId.isEmpty) {
        print('DEBUG: StudentId is empty, returning');
        return;
      }

      // Fetch last 5 top-ups
      print('DEBUG: Querying top_up_transactions for studentId: "$studentId"');
      final topups = await SupabaseService.client
          .from('top_up_transactions')
          .select(
            'id, student_id, amount, new_balance, created_at, processed_by',
          )
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(5);

      print('DEBUG: Top-up query result: $topups');

      // Debug: Check if any top-up transactions exist at all
      try {
        final allTopups = await SupabaseService.client
            .from('top_up_transactions')
            .select('id, student_id, amount, created_at')
            .limit(10);
        print(
          'DEBUG: Sample of all top_up_transactions in database: $allTopups',
        );
      } catch (e) {
        print('DEBUG: Error querying all top-ups: $e');
      }

      // Debug: Raw SQL query to see exact data for this student
      try {
        final rawResult = await SupabaseService.client.rpc(
          'debug_student_topups',
          params: {'p_student_id': studentId},
        );
        print('DEBUG: Raw SQL result for student "$studentId": $rawResult');
      } catch (e) {
        print('DEBUG: Raw SQL query failed (function might not exist): $e');

        // Alternative: Try direct query with different approaches
        try {
          // Query with exact match
          final exactMatch = await SupabaseService.client
              .from('top_up_transactions')
              .select('*')
              .eq('student_id', studentId);
          print('DEBUG: Exact match query result: $exactMatch');

          // Query with LIKE to check for similar IDs
          final likeMatch = await SupabaseService.client
              .from('top_up_transactions')
              .select('student_id, amount, created_at')
              .like('student_id', '%${studentId}%');
          print('DEBUG: LIKE match query result: $likeMatch');

          // Get all distinct student_ids to see what's actually in the table
          final distinctStudents = await SupabaseService.client
              .from('top_up_transactions')
              .select('student_id')
              .limit(20);
          print(
            'DEBUG: All student_ids in top_up_transactions: $distinctStudents',
          );
        } catch (altError) {
          print('DEBUG: Alternative queries failed: $altError');
        }
      }

      // Fetch last 5 payments (service_transactions) - filter by student_id column
      final payments = await SupabaseService.client
          .from('service_transactions')
          .select('total_amount, created_at, student_id')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(5);

      // Fetch user transfers (both sent and received) for recent transactions
      List<Map<String, dynamic>> transfers = [];
      try {
        print('DEBUG: Attempting to query user_transfers table...');

        // First, let's check if the table exists by trying a simple query
        final testQuery = await SupabaseService.client
            .from('user_transfers')
            .select('id')
            .limit(1);
        print('DEBUG: user_transfers table test query result: $testQuery');

        // Now try the actual query
        transfers = await SupabaseService.client
            .from('user_transfers')
            .select(
              'id, sender_student_id, recipient_student_id, amount, sender_new_balance, recipient_new_balance, created_at, status',
            )
            .or(
              'sender_student_id.eq.$studentId,recipient_student_id.eq.$studentId',
            )
            .order('created_at', ascending: false)
            .limit(5);

        print(
          'DEBUG: user_transfers query successful, found ${transfers.length} records',
        );
      } catch (e) {
        print('DEBUG: Error querying user_transfers table: $e');
        // Try alternative query without OR condition
        try {
          print('DEBUG: Trying alternative query for user_transfers...');
          transfers = await SupabaseService.client
              .from('user_transfers')
              .select('*')
              .limit(10);
          print('DEBUG: Alternative query found ${transfers.length} records');
        } catch (altError) {
          print('DEBUG: Alternative query also failed: $altError');
          transfers = [];
        }
      }

      print('DEBUG: Recent transactions - studentId: "$studentId"');
      print(
        'DEBUG: Admin top-ups (from top_up_transactions): ${topups.length} rows',
      );
      if (topups.isNotEmpty) {
        print('DEBUG: Top-ups sample: ${topups.first}');
      }
      print(
        'DEBUG: Service payments (from service_transactions): ${payments.length} rows',
      );
      if (payments.isNotEmpty) {
        print('DEBUG: Payments sample: ${payments.first}');
      }
      print('DEBUG: User transfers (recent): ${transfers.length} rows');
      if (transfers.isNotEmpty) {
        print('DEBUG: Transfers sample: ${transfers.first}');
      }

      final List<Map<String, dynamic>> merged = [];
      for (final t in (topups as List)) {
        merged.add({
          'type': 'top_up',
          'amount': (t['amount'] as num?) ?? 0,
          'created_at':
              t['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          'new_balance': (t['new_balance'] as num?) ?? 0,
        });
      }
      for (final p in (payments as List)) {
        merged.add({
          'type': 'payment',
          'amount': (p['total_amount'] as num?) ?? 0,
          'created_at':
              p['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        });
      }
      for (final transfer in (transfers as List)) {
        final isSent = transfer['sender_student_id'] == studentId;
        merged.add({
          'type': 'transfer',
          'amount': (transfer['amount'] as num?) ?? 0,
          'created_at':
              transfer['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
          'new_balance':
              isSent
                  ? (transfer['sender_new_balance'] as num?) ?? 0
                  : (transfer['recipient_new_balance'] as num?) ?? 0,
          'transfer_direction': isSent ? 'sent' : 'received',
          'sender_student_id': transfer['sender_student_id'],
          'recipient_student_id': transfer['recipient_student_id'],
          'status': transfer['status'],
        });
      }
      merged.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      setState(() {
        _recentTransactions
          ..clear()
          ..addAll(merged.take(10));
      });
    } catch (e) {
      print('DEBUG: Error loading recent transactions: $e');
      setState(() {
        _recentTransactions.clear();
      });
    }
  }

  void _subscribeRecentTransactions() {
    final studentId = SessionService.currentUserStudentId;
    if (studentId.isEmpty) return;

    try {
      _homeTopUpSub?.cancel();
    } catch (_) {}
    _homeTopUpSub = SupabaseService.client
        .from('top_up_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'type': 'top_up',
                      'amount': (r['amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                      'new_balance': (r['new_balance'] as num?) ?? 0,
                    },
                  )
                  .toList();
          _mergeHomeRecent(additions);
        });

    try {
      _homeServiceTxSub?.cancel();
    } catch (_) {}
    _homeServiceTxSub = SupabaseService.client
        .from('service_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'type': 'payment',
                      'amount': (r['total_amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                    },
                  )
                  .toList();
          _mergeHomeRecent(additions);
        });

    // Subscribe to loan payments for real-time updates
    try {
      _homeLoanSub?.cancel();
    } catch (_) {}
    _homeLoanSub = SupabaseService.client
        .from('loan_payments')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          // Trigger UI refresh when loan payments are made
          setState(() {});
        });

    // Subscribe to user transfers for real-time updates
    try {
      _homeTransferSub?.cancel();
    } catch (_) {}
    _homeTransferSub = SupabaseService.client
        .from('user_transfers')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          // Filter rows to include only transfers involving this student
          final filteredRows =
              rows
                  .where(
                    (row) =>
                        row['sender_student_id'] == studentId ||
                        row['recipient_student_id'] == studentId,
                  )
                  .toList();
          final additions =
              filteredRows.map((r) {
                final isSent = r['sender_student_id'] == studentId;
                return {
                  'type': 'transfer',
                  'amount': (r['amount'] as num?) ?? 0,
                  'created_at':
                      r['created_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  'new_balance':
                      isSent
                          ? (r['sender_new_balance'] as num?) ?? 0
                          : (r['recipient_new_balance'] as num?) ?? 0,
                  'transfer_direction': isSent ? 'sent' : 'received',
                  'sender_student_id': r['sender_student_id'],
                  'recipient_student_id': r['recipient_student_id'],
                  'status': r['status'],
                };
              }).toList();
          _mergeHomeRecent(additions);
        });
  }

  void _mergeHomeRecent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;
    final List<Map<String, dynamic>> merged = List.from(_recentTransactions);
    merged.insertAll(0, items);
    merged.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );
    setState(() {
      _recentTransactions
        ..clear()
        ..addAll(merged.take(10));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [evsuRed, evsuRedDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(),

              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tab Navigation
                      _buildTabNavigation(),

                      // Tab Content
                      Expanded(
                        child:
                            _selectedTab == 0
                                ? _buildWalletContent()
                                : _buildBorrowContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'E',
                    style: TextStyle(
                      color: evsuRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'HELLO!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'WELCOME',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            SessionService.currentUserName,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? evsuRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      _selectedTab == 0
                          ? [
                            BoxShadow(
                              color: evsuRed.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  'Wallet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 0 ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? evsuRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      _selectedTab == 1
                          ? [
                            BoxShadow(
                              color: evsuRed.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  'Borrow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 1 ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            margin: const EdgeInsets.only(bottom: 25),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [evsuRed, evsuRedDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: evsuRed.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          () => setState(
                            () => _balanceVisible = !_balanceVisible,
                          ),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(
                          _balanceVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  _balanceVisible
                      ? '₱ ${SessionService.currentUserBalance.toStringAsFixed(2)}'
                      : '₱ •••••',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showTransferDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: evsuRed,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Transfer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showTapToPayDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tap_and_play,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to Pay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Actions
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Top Up',
                  subtitle: 'Add money to your wallet',
                  icon: '💰',
                  onTap: () => _showTopUpDialog(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          // Transaction History
          _buildTransactionHistory(),
        ],
      ),
    );
  }

  Widget _buildBorrowContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [evsuRed, evsuRedDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('💸', style: TextStyle(fontSize: 35)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Need Quick Cash?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Borrow money instantly and pay later.\nAvailable for verified students with good standing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 30),

          // Active Loan Display
          _buildActiveLoanDisplay(),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () => _showAvailableLoans(),
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Apply Loan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 30),

          // Loan History
          _buildLoanHistory(),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [evsuRed, evsuRedDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'No recent activity',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final mapped =
        _recentTransactions.map<Map<String, String>>((t) {
          final isTopUp = (t['type'] == 'top_up');
          final amount = (t['amount'] as num).toDouble();
          final dt =
              DateTime.tryParse(t['created_at']?.toString() ?? '') ??
              DateTime.now();
          final timeStr =
              '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          return {
            'title': isTopUp ? 'Top-up' : 'Payment',
            'time': timeStr,
            'amount': '${isTopUp ? '+' : '-'}₱${amount.toStringAsFixed(2)}',
            'icon': isTopUp ? '💰' : '🧾',
            'type': isTopUp ? 'income' : 'expense',
          };
        }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () => _showAllTransactions(),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: evsuRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...mapped.map((m) => _buildTransactionItem(m)).toList(),
        ],
      ),
    );
  }

  Widget _buildActiveLoanDisplay() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadActiveLoan(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: evsuRed),
            ),
          );
        }

        final activeLoans = snapshot.data ?? [];
        final activeLoan = activeLoans.isNotEmpty ? activeLoans.first : null;

        if (activeLoan == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No Active Loans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You can apply for a loan when needed',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: evsuRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Active Loan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          activeLoan['status'] == 'overdue'
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      activeLoan['status'] == 'overdue' ? 'Overdue' : 'Active',
                      style: TextStyle(
                        color:
                            activeLoan['status'] == 'overdue'
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Loan Details
              _buildLoanDetailRow(
                'Loan Plan',
                activeLoan['loan_plan_name'] ?? 'N/A',
              ),
              _buildLoanDetailRow(
                'Borrowed Amount',
                '₱${(activeLoan['loan_amount'] as num).toStringAsFixed(2)}',
              ),
              _buildLoanDetailRow(
                'Interest',
                '₱${(activeLoan['interest_amount'] as num).toStringAsFixed(2)}',
              ),
              _buildLoanDetailRow(
                'Total Due',
                '₱${(activeLoan['total_amount'] as num).toStringAsFixed(2)}',
              ),
              _buildLoanDetailRow(
                'Due Date',
                _formatDate(
                  DateTime.tryParse(activeLoan['due_date']?.toString() ?? '') ??
                      DateTime.now(),
                ),
              ),

              const SizedBox(height: 16),

              // Payment Options
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentOptions(activeLoan),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadActiveLoan() async {
    await SupabaseService.initialize();
    final studentId = SessionService.currentUserStudentId;

    print('DEBUG: Loading active loans for studentId: "$studentId"');

    if (studentId.isEmpty) {
      print('DEBUG: StudentId is empty, returning empty list');
      return [];
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_active_student_loans',
        params: {'p_student_id': studentId},
      );

      print('DEBUG: Active loans response: $response');

      if (response == null) {
        print('DEBUG: Response is null');
        return [];
      }

      final data = response as Map<String, dynamic>;
      print('DEBUG: Response data: $data');

      final loans = data['active_loans'] as List<dynamic>;
      print('DEBUG: Active loans list: $loans');

      // Convert to Map<String, dynamic> list
      final activeLoans =
          loans.map((loan) => Map<String, dynamic>.from(loan)).toList();

      print('DEBUG: Converted active loans: $activeLoans');
      return activeLoans;
    } catch (e) {
      print('DEBUG: Error loading active loan: $e');
      print('DEBUG: Error type: ${e.runtimeType}');

      // Fallback: Try direct query to active_loans table
      try {
        print('DEBUG: Attempting fallback direct query...');
        final directResponse = await SupabaseService.client
            .from('active_loans')
            .select('''
              id,
              student_id,
              loan_amount,
              interest_amount,
              penalty_amount,
              total_amount,
              term_days,
              due_date,
              status,
              created_at,
              paid_at,
              loan_plans!inner(name)
            ''')
            .eq('student_id', studentId)
            .inFilter('status', ['active', 'overdue'])
            .order('created_at', ascending: false);

        print('DEBUG: Direct query response: $directResponse');

        if (directResponse.isNotEmpty) {
          final loans =
              (directResponse as List)
                  .map(
                    (loan) => {
                      'id': loan['id'],
                      'loan_plan_name': loan['loan_plans']['name'],
                      'loan_amount': loan['loan_amount'],
                      'interest_amount': loan['interest_amount'],
                      'penalty_amount': loan['penalty_amount'],
                      'total_amount': loan['total_amount'],
                      'term_days': loan['term_days'],
                      'due_date': loan['due_date'],
                      'status': loan['status'],
                      'created_at': loan['created_at'],
                      'paid_at': loan['paid_at'],
                      'days_left': _calculateDaysLeft(loan['due_date']),
                    },
                  )
                  .toList();

          print('DEBUG: Fallback loans: $loans');
          return loans;
        }
      } catch (fallbackError) {
        print('DEBUG: Fallback query also failed: $fallbackError');
      }

      return [];
    }
  }

  void _showPaymentOptions(Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder:
          (context) => _PaymentOptionsDialog(
            loan: loan,
            onPayFull: () => _payLoanFull(loan),
            onPayPartial: (amount) => _payLoanPartial(loan, amount),
          ),
    );
  }

  Future<void> _payLoanFull(Map<String, dynamic> loan) async {
    try {
      final loanId = loan['id'] as int;
      final studentId = SessionService.currentUserStudentId;

      final response = await SupabaseService.client.rpc(
        'pay_off_loan',
        params: {'p_loan_id': loanId, 'p_student_id': studentId},
      );

      if (response == null) {
        _showErrorSnackBar('Failed to process payment');
        return;
      }

      final data = response as Map<String, dynamic>;

      if (data['success'] == true) {
        Navigator.pop(context); // Close dialog
        _showSuccessSnackBar(data['message'] ?? 'Loan paid successfully!');

        // Refresh user data and UI
        await SessionService.refreshUserData();
        // Only refresh the current widget state, don't trigger full transaction history reload
        if (mounted) {
          setState(() {}); // Refresh UI
        }
      } else {
        _showErrorSnackBar(data['message'] ?? 'Failed to pay loan');
      }
    } catch (e) {
      _showErrorSnackBar('Error paying loan: ${e.toString()}');
    }
  }

  Future<void> _payLoanPartial(Map<String, dynamic> loan, double amount) async {
    try {
      final loanId = loan['id'] as int;
      final studentId = SessionService.currentUserStudentId;

      final response = await SupabaseService.client.rpc(
        'make_partial_loan_payment',
        params: {
          'p_loan_id': loanId,
          'p_student_id': studentId,
          'p_payment_amount': amount,
        },
      );

      if (response == null) {
        _showErrorSnackBar('Failed to process payment');
        return;
      }

      final data = response as Map<String, dynamic>;

      if (data['success'] == true) {
        Navigator.pop(context); // Close dialog
        _showSuccessSnackBar(
          data['message'] ?? 'Payment processed successfully!',
        );

        // Refresh user data and UI
        await SessionService.refreshUserData();
        // Only refresh the current widget state, don't trigger full transaction history reload
        if (mounted) {
          setState(() {}); // Refresh UI
        }
      } else {
        _showErrorSnackBar(data['message'] ?? 'Failed to process payment');
      }
    } catch (e) {
      _showErrorSnackBar('Error processing payment: ${e.toString()}');
    }
  }

  Widget _buildLoanHistory() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadStudentLoans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: evsuRed),
            ),
          );
        }

        final loans = snapshot.data ?? [];
        final paidLoans =
            loans.where((loan) => loan['status'] == 'paid').toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Loan History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAllLoans(),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: evsuRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (paidLoans.isEmpty)
                const Text(
                  'No loan history found',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                )
              else
                ...paidLoans
                    .take(3)
                    .map((loan) => _buildLoanItem(loan))
                    .toList(),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadStudentLoans() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;

      if (studentId.isEmpty) return [];

      final response = await SupabaseService.client.rpc(
        'get_student_loans',
        params: {'p_student_id': studentId},
      );

      if (response == null) return [];

      final data = response as Map<String, dynamic>;
      final loans = data['loans'] as List<dynamic>;

      return loans.map((loan) => Map<String, dynamic>.from(loan)).toList();
    } catch (e) {
      print('Error loading student loans: $e');
      return [];
    }
  }

  Widget _buildTransactionItem(Map<String, String> transaction) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    transaction['type'] == 'income'
                        ? [Colors.green, Colors.green[700]!]
                        : [Colors.red, Colors.red[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                transaction['icon']!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['title']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction['time']!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            transaction['amount']!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  transaction['type'] == 'income' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanItem(Map<String, dynamic> loan) {
    final status = loan['status'] as String;
    final amount = (loan['total_amount'] as num).toDouble();
    final dueDate =
        DateTime.tryParse(loan['due_date']?.toString() ?? '') ?? DateTime.now();
    final daysLeft = loan['days_left'] as int;
    final isOverdue = daysLeft < 0;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'paid':
        statusText = 'Paid';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'overdue':
        statusText = 'Overdue';
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case 'active':
      default:
        statusText = isOverdue ? 'Overdue' : 'Active';
        statusColor = isOverdue ? Colors.red : Colors.orange;
        statusIcon = isOverdue ? Icons.warning : Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(statusIcon, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan['loan_plan_name'] ?? 'Loan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status == 'paid'
                      ? 'Paid on ${_formatDate(DateTime.tryParse(loan['paid_at']?.toString() ?? '') ?? DateTime.now())}'
                      : 'Due: ${_formatDate(dueDate)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (status == 'active' && !isOverdue)
                  Text(
                    '$daysLeft days left',
                    style: TextStyle(fontSize: 10, color: Colors.orange[600]),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _calculateDaysLeft(dynamic dueDate) {
    if (dueDate == null) return 0;

    final due = DateTime.tryParse(dueDate.toString());
    if (due == null) return 0;

    final now = DateTime.now();
    if (due.isBefore(now)) {
      // Overdue - return negative days
      return -now.difference(due).inDays;
    } else {
      // Not due yet - return positive days
      return due.difference(now).inDays;
    }
  }

  // Dialog methods
  void _showTransferDialog() {
    showDialog(
      context: context,
      builder: (context) => _TransferStudentIdDialog(),
    );
  }

  void _showTopUpDialog() async {
    // Check if Paytaca is enabled
    final isPaytacaEnabled = await SupabaseService.isPaytacaEnabled();

    if (!isPaytacaEnabled) {
      _showMaintenanceModal();
      return;
    }

    final amounts = [50, 100, 200, 500];
    int? selectedAmount = amounts.first;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  scrollable: true,
                  title: const Text('Cash In'),
                  content: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select amount to cash in:'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children:
                                amounts.map((amt) {
                                  final isSelected = selectedAmount == amt;
                                  return ChoiceChip(
                                    label: Text('₱' + amt.toString()),
                                    selected: isSelected,
                                    onSelected:
                                        (_) => setState(
                                          () => selectedAmount = amt,
                                        ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Payment will proceed via Paytaca invoice checkout.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedAmount == null) return;
                        Navigator.pop(context);
                        await _startPaytacaInvoiceXpub(
                          amountPhp: selectedAmount!,
                        );
                      },
                      child: const Text('Continue'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _startPaytacaInvoiceXpub({required num amountPhp}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final studentId = SessionService.currentUserStudentId;

      // First, insert a record into paytaca_invoices table
      final providerTxId =
          await PaytacaInvoiceService.insertPaytacaInvoiceRecord(
            studentId: studentId,
            amount: amountPhp,
            currency: 'PHP',
          );

      if (providerTxId == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to create invoice record.')),
        );
        return;
      }

      // Use provided xpub and wallet hash
      const xpubKey =
          'xpub6Cuc71TPTK7jc6mxmaLwHFEQfXRKxWV6bWCr4jQCT9nbcCr3muJz7n6ATaEUkGSzsT8qgwA4e3Qo9dBkVVXVbgrjHsNiMdJCH6AyYXK3xPR';
      const walletHash =
          '2a30d6e75fb1e421de80701ce9d6e4aee76942573155c40fc29e86ffd28571f3';
      const index = 0; // adjust if you need unique address per invoice

      final invoice = await PaytacaInvoiceService.createInvoiceWithXpub(
        amount: amountPhp,
        xpubKey: xpubKey,
        index: index,
        walletHash: walletHash,
        providerTxId: providerTxId,
        currency: 'PHP',
        memo: 'Wallet top-up',
      );

      if (invoice == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to create Paytaca invoice.')),
        );
        return;
      }

      final url = PaytacaInvoiceService.extractPaymentUrl(invoice);
      if (url == null || url.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No Paytaca payment URL found.')),
        );
        return;
      }

      // Extract invoice ID from the response (adjust based on actual Paytaca response structure)
      final invoiceId =
          invoice['id']?.toString() ??
          invoice['invoice_id']?.toString() ??
          providerTxId;

      // Update the paytaca_invoices record with invoice details
      await PaytacaInvoiceService.updatePaytacaInvoiceRecord(
        providerTxId: providerTxId,
        invoiceId: invoiceId,
      );

      // Launch the payment URL
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Paytaca request failed: ' + e.toString())),
      );
    }
  }

  void _showMaintenanceModal() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.build_circle, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Under Maintenance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top-up service is currently unavailable.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Our payment system is temporarily under maintenance. Please try again later or contact support for assistance.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We apologize for any inconvenience caused.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showTapToPayDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Tap to Pay'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tap_and_play, size: 64, color: evsuRed),
                const SizedBox(height: 16),
                const Text(
                  'Hold your phone near the RFID reader to make a quick payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Make sure NFC is enabled and your phone is unlocked.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  _showErrorSnackBar('Tap to Pay feature coming soon!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: evsuRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enable NFC'),
              ),
            ],
          ),
    );
  }

  Future<void> _showAvailableLoans() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;

      if (studentId.isEmpty) {
        _showErrorSnackBar('Student ID not found. Please log in again.');
        return;
      }

      // Get available loan plans for student (server-calculated)
      final response = await SupabaseService.client.rpc(
        'get_available_loan_plans',
        params: {'p_student_id': studentId},
      );

      if (response == null) {
        _showErrorSnackBar('Failed to load loan plans');
        return;
      }

      final data = response as Map<String, dynamic>;
      final availablePlans = data['available_plans'] as List<dynamic>;
      final totalTopup = data['total_topup'] as num;

      // Recompute clean total top-up EXCLUDING any loan disbursements
      double cleanTotalTopup = 0.0;
      try {
        final topups = await SupabaseService.client
            .from('top_up_transactions')
            .select('amount, transaction_type, student_id')
            .eq('student_id', studentId);

        for (final row in (topups as List)) {
          final String? txType = row['transaction_type'] as String?;
          // Include only real top-ups; exclude explicit loan disbursements
          if (txType == null || txType == 'top_up') {
            cleanTotalTopup += ((row['amount'] as num?)?.toDouble() ?? 0.0);
          }
        }
      } catch (e) {
        // Fallback to server-provided total if schema/column differs
        cleanTotalTopup = totalTopup.toDouble();
      }

      // Adjust eligibility client-side to prevent loan disbursement inflating eligibility
      final List<Map<String, dynamic>> adjustedPlans =
          availablePlans.map((p) {
            final plan = Map<String, dynamic>.from(p as Map);
            final double minTopup = (plan['min_topup'] as num).toDouble();
            final bool serverEligible = (plan['is_eligible'] as bool? ?? false);
            final bool eligibleByCleanTopup = cleanTotalTopup >= minTopup;
            plan['is_eligible'] = serverEligible && eligibleByCleanTopup;
            return plan;
          }).toList();

      if (availablePlans.isEmpty) {
        _showErrorSnackBar('No loan plans available at the moment');
        return;
      }

      showDialog(
        context: context,
        builder:
            (context) => _LoanPlansDialog(
              plans: adjustedPlans,
              totalTopup: cleanTotalTopup,
              onApplyLoan: _applyForLoan,
            ),
      );
    } catch (e) {
      _showErrorSnackBar('Error loading loan plans: ${e.toString()}');
    }
  }

  Future<void> _applyForLoan(int planId) async {
    try {
      final studentId = SessionService.currentUserStudentId;

      final response = await SupabaseService.client.rpc(
        'apply_for_loan',
        params: {'p_student_id': studentId, 'p_loan_plan_id': planId},
      );

      if (response == null) {
        _showErrorSnackBar('Failed to apply for loan');
        return;
      }

      final data = response as Map<String, dynamic>;

      if (data['success'] == true) {
        Navigator.pop(context); // Close dialog
        _showSuccessSnackBar(data['message'] ?? 'Loan applied successfully!');

        // Refresh user data to update balance
        await SessionService.refreshUserData();
        setState(() {}); // Refresh UI
      } else {
        _showErrorSnackBar(data['message'] ?? 'Failed to apply for loan');
      }
    } catch (e) {
      _showErrorSnackBar('Error applying for loan: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    // Check if it's a network-related error
    final messageLower = message.toLowerCase();
    if (messageLower.contains('network') ||
        messageLower.contains('connection') ||
        messageLower.contains('internet') ||
        messageLower.contains('timeout') ||
        messageLower.contains('unreachable') ||
        messageLower.contains('socket') ||
        messageLower.contains('failed host lookup') ||
        messageLower.contains('connection refused') ||
        messageLower.contains('connection reset')) {
      // Show responsive modal for network errors
      _showNetworkErrorModal(message);
    } else {
      // Show snackbar for other errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showNetworkErrorModal(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) =>
              _buildResponsiveNetworkErrorModal(context, message: message),
    );
  }

  Widget _buildResponsiveNetworkErrorModal(
    BuildContext context, {
    required String message,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive calculations
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;
    final isLandscape = screenHeight < screenWidth;

    // Dynamic sizing based on screen size
    final modalMaxWidth =
        isSmallScreen ? screenWidth * 0.95 : screenWidth * 0.85;
    final modalMaxHeight =
        isLandscape ? screenHeight * 0.8 : screenHeight * 0.6;
    final iconSize =
        isVerySmallScreen
            ? 20.0
            : isSmallScreen
            ? 24.0
            : 28.0;
    final titleFontSize =
        isVerySmallScreen
            ? 16.0
            : isSmallScreen
            ? 18.0
            : 20.0;
    final messageFontSize =
        isVerySmallScreen
            ? 12.0
            : isSmallScreen
            ? 13.0
            : 14.0;
    final buttonFontSize = isVerySmallScreen ? 14.0 : 16.0;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: modalMaxWidth,
          maxHeight: modalMaxHeight,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background circle
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off,
                  color: Colors.orange,
                  size: iconSize,
                ),
              ),

              SizedBox(height: isSmallScreen ? 16 : 20),

              // Title
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // Message Content
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: messageFontSize,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 20 : 24),

              // Action Buttons
              Row(
                children: [
                  // Retry button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Retry the operation (refresh the current page)
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 14,
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),

                  // OK button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 14,
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllTransactions() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Transaction History'),
            content: const Text('Loading complete transaction history...'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showAllLoans() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Loan History'),
            content: const Text('Loading complete loan history...'),
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

class _InboxTab extends StatefulWidget {
  const _InboxTab();

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;
  String _selectedFilter = 'All';
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    print('DEBUG INBOX: initState called');
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserData?['student_id'] ?? '';

      print('DEBUG: Loading notifications for student: $studentId');

      // DEBUG: Test loan_payments table for inbox
      await _debugLoanPaymentsTableInbox(studentId);

      if (studentId.isEmpty) {
        print('ERROR: Student ID is empty, cannot load notifications');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get actual notifications from the notifications table
      print('DEBUG: Fetching notifications from database...');
      final notifications = await NotificationService.getUserNotifications(
        studentId,
      );

      // Get loan disbursements from top_up_transactions
      List<Map<String, dynamic>> loanDisbursements = [];
      try {
        loanDisbursements = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, new_balance, created_at, processed_by',
            )
            .eq('student_id', studentId)
            .eq('transaction_type', 'loan_disbursement')
            .order('created_at', ascending: false)
            .limit(50);
        print('DEBUG: Loan disbursements found: ${loanDisbursements.length}');
      } catch (e) {
        print('DEBUG: Error fetching loan disbursements: $e');
      }

      // Get active loans from loan_actives
      List<Map<String, dynamic>> activeLoans = [];
      try {
        activeLoans = await SupabaseService.client
            .from('loan_actives')
            .select(
              'id, student_id, loan_amount, remaining_balance, created_at, loan_plan_id',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(50);
        print('DEBUG: Active loans found: ${activeLoans.length}');
      } catch (e) {
        print('DEBUG: Error fetching active loans: $e');
      }

      // Get loan payments from loan_payments
      List<Map<String, dynamic>> loanPayments = [];
      try {
        print('DEBUG INBOX: Querying loan payments for student: "$studentId"');
        loanPayments = await SupabaseService.client
            .from('loan_payments')
            .select(
              'id, student_id, payment_amount, remaining_balance, created_at, loan_id',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(50);
        print(
          'DEBUG INBOX: Raw loan payments query result: ${loanPayments.length}',
        );

        if (loanPayments.isNotEmpty) {
          print(
            'DEBUG INBOX: First loan payment sample: ${loanPayments.first}',
          );
        }
      } catch (e) {
        print('DEBUG INBOX: Error fetching loan payments: $e');
        print('DEBUG INBOX: Error type: ${e.runtimeType}');
      }

      // Get service transactions
      List<Map<String, dynamic>> serviceTransactions = [];
      try {
        serviceTransactions = await SupabaseService.client
            .from('service_transactions')
            .select('id, student_id, total_amount, created_at')
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(50);
        print(
          'DEBUG: Service transactions found: ${serviceTransactions.length}',
        );
      } catch (e) {
        print('DEBUG: Error fetching service transactions: $e');
      }

      // Get top-up transactions
      List<Map<String, dynamic>> topUpTransactions = [];
      try {
        topUpTransactions = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, new_balance, created_at, processed_by',
            )
            .eq('student_id', studentId)
            .eq('transaction_type', 'top_up')
            .order('created_at', ascending: false)
            .limit(50);
        print('DEBUG: Top-up transactions found: ${topUpTransactions.length}');
      } catch (e) {
        print('DEBUG: Error fetching top-up transactions: $e');
      }

      // Convert loan data to notification-like format
      final List<Map<String, dynamic>> allNotifications = List.from(
        notifications,
      );

      // Add loan disbursements as notifications
      for (final disbursement in loanDisbursements) {
        allNotifications.add({
          'id': 'disbursement_${disbursement['id']}',
          'title': 'Loan Disbursement',
          'message':
              'Your loan of ₱${disbursement['amount']} has been disbursed to your account.',
          'type': 'loan_disbursement',
          'created_at': disbursement['created_at'],
          'is_read': true, // Mark as read by default
          'is_urgent': false,
          'transaction_id': disbursement['id'],
          'amount': disbursement['amount'],
          'new_balance': disbursement['new_balance'],
        });
      }

      // Add active loans as notifications
      for (final loan in activeLoans) {
        allNotifications.add({
          'id': 'active_loan_${loan['id']}',
          'title': 'Active Loan',
          'message':
              'You have an active loan of ₱${loan['loan_amount']} with remaining balance of ₱${loan['remaining_balance']}.',
          'type': 'active_loan',
          'created_at': loan['created_at'],
          'is_read': true, // Mark as read by default
          'is_urgent': false,
          'transaction_id': loan['id'],
          'loan_amount': loan['loan_amount'],
          'remaining_balance': loan['remaining_balance'],
          'loan_plan_id': loan['loan_plan_id'],
        });
      }

      // Add loan payments as notifications
      print(
        'DEBUG INBOX: Processing ${loanPayments.length} loan payments for notifications...',
      );
      for (final payment in loanPayments) {
        print(
          'DEBUG INBOX: Processing loan payment: ${payment['id']}, amount: ${payment['payment_amount']}',
        );

        final notificationData = {
          'id': 'loan_payment_${payment['id']}',
          'title': 'Loan Payment',
          'message':
              'You made a loan payment of ₱${payment['payment_amount']}. Remaining balance: ₱${payment['remaining_balance']}.',
          'type': 'loan_payment',
          'created_at': payment['created_at'],
          'is_read': true, // Mark as read by default
          'is_urgent': false,
          'transaction_id': payment['id'],
          'payment_amount': payment['payment_amount'],
          'remaining_balance': payment['remaining_balance'],
          'loan_id': payment['loan_id'],
        };

        print(
          'DEBUG INBOX: Adding loan payment notification: $notificationData',
        );
        allNotifications.add(notificationData);
      }
      print(
        'DEBUG INBOX: Total loan payment notifications added: ${allNotifications.where((n) => n['type'] == 'loan_payment').length}',
      );

      // Add service transactions as notifications
      for (final service in serviceTransactions) {
        allNotifications.add({
          'id': 'service_${service['id']}',
          'title': 'Service Payment',
          'message':
              'You made a service payment of ₱${service['total_amount']}.',
          'type': 'service_payment',
          'created_at': service['created_at'],
          'is_read': true, // Mark as read by default
          'is_urgent': false,
          'transaction_id': service['id'],
          'total_amount': service['total_amount'],
        });
      }

      // Add top-up transactions as notifications
      for (final topup in topUpTransactions) {
        allNotifications.add({
          'id': 'topup_${topup['id']}',
          'title': 'Account Top-up',
          'message':
              'Your account has been topped up with ₱${topup['amount']}. New balance: ₱${topup['new_balance']}.',
          'type': 'top_up',
          'created_at': topup['created_at'],
          'is_read': true, // Mark as read by default
          'is_urgent': false,
          'transaction_id': topup['id'],
          'amount': topup['amount'],
          'new_balance': topup['new_balance'],
          'processed_by': topup['processed_by'],
        });
      }

      // Sort all notifications by date (newest first)
      allNotifications.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      final unreadCount = allNotifications.where((n) => !n['is_read']).length;
      print(
        'DEBUG: Total notifications including loan data: ${allNotifications.length}',
      );
      print('DEBUG: Unread count: $unreadCount');

      setState(() {
        _notifications = allNotifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });

      print(
        'DEBUG: Inbox state updated with ${_notifications.length} notifications',
      );
    } catch (e) {
      print('ERROR: Failed to load notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _subscribeToNotifications() {
    try {
      final studentId = SessionService.currentUserData?['student_id'] ?? '';
      print('DEBUG INBOX: Setting up subscription for student: $studentId');

      if (studentId.isNotEmpty) {
        print('DEBUG INBOX: Creating notification stream subscription...');
        _notificationSub = NotificationService.subscribeToNotifications(
          studentId,
        ).listen(
          (notifications) {
            print(
              'DEBUG INBOX: Stream received ${notifications.length} notifications',
            );
            setState(() {
              _notifications = notifications;
              _unreadCount = notifications.where((n) => !n['is_read']).length;
            });
            print(
              'DEBUG INBOX: State updated with ${_notifications.length} notifications, $_unreadCount unread',
            );
          },
          onError: (error) {
            print('ERROR INBOX: Error in notification stream: $error');
          },
        );
        print('DEBUG INBOX: Subscription created successfully');
      } else {
        print(
          'ERROR INBOX: Student ID is empty, cannot subscribe to notifications',
        );
      }
    } catch (e) {
      print('ERROR INBOX: Error subscribing to notifications: $e');
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      // The stream will automatically update the UI
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    print('DEBUG INBOX: Filtering notifications with filter: $_selectedFilter');
    print(
      'DEBUG INBOX: Total notifications before filtering: ${_notifications.length}',
    );

    List<Map<String, dynamic>> filtered;

    if (_selectedFilter == 'All') {
      filtered = _notifications;
    } else if (_selectedFilter == 'Loans') {
      filtered =
          _notifications.where((n) {
            final type = n['type']?.toString() ?? '';
            return type == 'loan_disbursement' ||
                type == 'active_loan' ||
                type == 'loan_payment' ||
                type.contains('loan');
          }).toList();
    } else if (_selectedFilter == 'Transactions') {
      filtered =
          _notifications.where((n) {
            final type = n['type']?.toString() ?? '';
            return type == 'transaction_success' ||
                type == 'payment_success' ||
                type == 'transfer_sent' ||
                type == 'transfer_received' ||
                type == 'service_payment' ||
                type == 'topup_success' ||
                type == 'top_up' ||
                type.contains('transaction') ||
                type.contains('payment') ||
                type.contains('transfer');
          }).toList();
    } else {
      filtered = _notifications;
    }

    print('DEBUG INBOX: Filtered notifications count: ${filtered.length}');
    if (filtered.isNotEmpty) {
      print('DEBUG INBOX: Sample filtered notification: ${filtered.first}');
    }

    return filtered;
  }

  String _getTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Color _getNotificationColor(Map<String, dynamic> notification) {
    if (notification['is_urgent'] == true) {
      return Colors.red;
    }

    // Get color based on notification type
    final type = notification['type']?.toString() ?? '';
    switch (type) {
      case 'transaction_success':
      case 'payment_success':
      case 'topup_success':
      case 'top_up':
        return Colors.green;
      case 'transfer_sent':
      case 'transfer_received':
        return Colors.blue;
      case 'loan_disbursement':
        return Colors.purple;
      case 'active_loan':
        return Colors.orange;
      case 'loan_payment':
        return Colors.blue;
      case 'loan_due_soon':
      case 'loan_reminder':
        return Colors.orange;
      case 'loan_overdue':
        return Colors.red;
      case 'security_alert':
        return Colors.red;
      case 'system_notification':
        return Colors.grey;
      case 'welcome':
        return Colors.purple;
      default:
        return evsuRed;
    }
  }

  IconData _getNotificationIcon(Map<String, dynamic> notification) {
    // Get icon based on notification type
    final type = notification['type']?.toString() ?? '';
    switch (type) {
      case 'transaction_success':
      case 'topup_success':
      case 'top_up':
        return Icons.check_circle;
      case 'payment_success':
        return Icons.payment;
      case 'transfer_sent':
        return Icons.send;
      case 'transfer_received':
        return Icons.call_received;
      case 'loan_disbursement':
        return Icons.account_balance;
      case 'active_loan':
        return Icons.credit_card;
      case 'loan_payment':
        return Icons.payment;
      case 'loan_due_soon':
        return Icons.schedule;
      case 'loan_overdue':
        return Icons.warning;
      case 'loan_reminder':
        return Icons.alarm;
      case 'security_alert':
        return Icons.security;
      case 'system_notification':
        return Icons.info;
      case 'welcome':
        return Icons.celebration;
      default:
        // Fallback based on notification type
        if (type.contains('loan')) {
          return Icons.account_balance;
        } else if (type.contains('payment') || type.contains('transfer')) {
          return Icons.payment;
        } else if (type.contains('security')) {
          return Icons.security;
        }
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG INBOX: build() called');
    print('DEBUG INBOX: _isLoading: $_isLoading');
    print('DEBUG INBOX: _notifications.length: ${_notifications.length}');
    print('DEBUG INBOX: _unreadCount: $_unreadCount');
    print('DEBUG INBOX: _selectedFilter: $_selectedFilter');

    final filteredNotifications = _getFilteredNotifications();
    print(
      'DEBUG INBOX: filteredNotifications.length: ${filteredNotifications.length}',
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Inbox',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: evsuRed,
                  ),
                ),
                const Spacer(),
                if (_unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),

            const SizedBox(height: 16),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Loans'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Transactions'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notifications list
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: evsuRed),
                      )
                      : _notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        itemCount: filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = filteredNotifications[index];
                          print(
                            'DEBUG INBOX: Building notification card for index $index: ${notification['title']}',
                          );
                          return _buildNotificationCard(notification);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: evsuRed.withOpacity(0.2),
      checkmarkColor: evsuRed,
      labelStyle: TextStyle(
        color: isSelected ? evsuRed : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    print(
      'DEBUG INBOX: Building notification card for: ${notification['title']}',
    );
    print('DEBUG INBOX: Notification data: $notification');

    final isRead = notification['is_read'] == true;
    final isUrgent = notification['is_urgent'] == true;
    final createdAt = DateTime.parse(notification['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final notificationColor = _getNotificationColor(notification);
    final notificationIcon = _getNotificationIcon(notification);

    print(
      'DEBUG INBOX: Card properties - isRead: $isRead, isUrgent: $isUrgent, timeAgo: $timeAgo',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isUrgent ? 4 : 1,
      color: isUrgent ? Colors.red.withOpacity(0.05) : null,
      child: InkWell(
        onTap: () {
          print('DEBUG INBOX: Notification tapped: ${notification['title']}');
          if (!isRead) {
            // Only mark as read if it's a real notification (not a transaction notification)
            final notificationId = notification['id'];
            if (notificationId is int) {
              _markAsRead(notificationId);
            } else {
              print(
                'DEBUG INBOX: Skipping mark as read for transaction notification: $notificationId',
              );
            }
          }
          _showTransactionDetailModal(notification);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notificationColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  notificationIcon,
                  color: notificationColor,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                              color: isUrgent ? Colors.red : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: evsuRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['message'] ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    print('DEBUG INBOX: Building empty state');
    print(
      'DEBUG INBOX: Current state - _isLoading: $_isLoading, _notifications.length: ${_notifications.length}',
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          // Debug information
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(
                  'DEBUG INFO:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text('Loading: $_isLoading', style: TextStyle(fontSize: 10)),
                Text(
                  'Notifications: ${_notifications.length}',
                  style: TextStyle(fontSize: 10),
                ),
                Text(
                  'Filter: $_selectedFilter',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailModal(Map<String, dynamic> notification) async {
    print('DEBUG MODAL: Starting _showTransactionDetailModal');
    print('DEBUG MODAL: Notification data: $notification');

    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) =>
              const Center(child: CircularProgressIndicator(color: evsuRed)),
    );

    try {
      // Fetch actual transaction data based on notification type
      print('DEBUG MODAL: Fetching transaction data...');
      final transactionData = await _fetchTransactionData(notification);
      print('DEBUG MODAL: Transaction data fetched: $transactionData');

      // Close loading dialog
      Navigator.of(context).pop();

      // Show transaction details modal
      print('DEBUG MODAL: Showing transaction details modal...');
      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with receipt-like styling
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: evsuRed,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getTransactionIcon(transactionData?['type']),
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getTransactionTitle(transactionData?['type']),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ECampusPay',
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
                            // Transaction Type and Status
                            _buildReceiptRow(
                              'Transaction Type',
                              _getTransactionTitle(transactionData?['type']),
                              isHeader: true,
                            ),
                            const SizedBox(height: 16),

                            // Transaction ID
                            _buildReceiptRow(
                              'Transaction ID',
                              '#${transactionData?['id']?.toString().padLeft(8, '0') ?? notification['id']?.toString().padLeft(8, '0') ?? 'N/A'}',
                            ),

                            // Amount (if available in transaction data)
                            if (_getTransactionAmountFromData(
                                  transactionData,
                                ) !=
                                null)
                              _buildReceiptRow(
                                'Amount',
                                '₱${_getTransactionAmountFromData(transactionData)?.toStringAsFixed(2)}',
                                isAmount: true,
                              ),

                            // Date and Time
                            _buildReceiptRow(
                              'Date & Time',
                              _formatDateTime(
                                transactionData?['data']?['created_at'] ??
                                    notification['created_at'],
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
                            ..._buildTransactionSpecificDetails(
                              transactionData,
                            ),

                            const SizedBox(height: 20),

                            // Message/Description
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Description',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notification['message'] ??
                                        notification['title'] ??
                                        'No description available',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Additional Info if urgent
                            if (notification['is_urgent'] == true) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning,
                                      color: Colors.red[600],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'This is an urgent notification requiring immediate attention.',
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Footer Actions
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(color: evsuRed),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: TextStyle(color: evsuRed),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  // Add share functionality here if needed
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: evsuRed,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Share',
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
            ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to load transaction details: $e'),
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

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isHeader = false,
    bool isAmount = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                color: isHeader ? evsuRed : Colors.grey[700],
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
                    (isAmount ? Colors.green[700] : Colors.grey[800]),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      String timeStr;
      if (difference.inDays > 0) {
        timeStr =
            '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        timeStr =
            '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        timeStr =
            '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        timeStr = 'Just now';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ($timeStr)';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Helper methods for transaction modal
  IconData _getTransactionIcon(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        return Icons.add_circle;
      case 'loan_disbursement':
        return Icons.account_balance;
      case 'active_loan':
        return Icons.credit_card;
      case 'loan_payment':
        return Icons.payment;
      case 'service_payment':
        return Icons.receipt;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.receipt_long;
    }
  }

  String _getTransactionTitle(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        return 'Account Top-up Receipt';
      case 'loan_disbursement':
        return 'Loan Disbursement Receipt';
      case 'active_loan':
        return 'Active Loan Details';
      case 'loan_payment':
        return 'Loan Payment Receipt';
      case 'service_payment':
        return 'Service Payment Receipt';
      case 'transfer':
        return 'Transfer Receipt';
      default:
        return 'Transaction Receipt';
    }
  }

  String _getTransactionStatus(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'loan_disbursement':
      case 'loan_payment':
      case 'service_payment':
      case 'transfer':
        return 'Completed';
      case 'active_loan':
        return 'Active';
      default:
        return 'Processed';
    }
  }

  Color _getTransactionStatusColor(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'loan_disbursement':
      case 'loan_payment':
      case 'service_payment':
      case 'transfer':
        return Colors.green[700]!;
      case 'active_loan':
        return Colors.blue[700]!;
      default:
        return Colors.blue[700]!;
    }
  }

  double? _getTransactionAmountFromData(Map<String, dynamic>? transactionData) {
    if (transactionData == null) return null;

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    final transactionType = transactionData['type'] as String?;

    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'loan_disbursement':
        return _safeParseNumber(data['amount']);
      case 'loan_payment':
        return _safeParseNumber(data['payment_amount']);
      case 'service_payment':
        return _safeParseNumber(data['total_amount']);
      case 'transfer':
        return _safeParseNumber(data['amount']);
      case 'active_loan':
        return _safeParseNumber(data['loan_amount']);
      default:
        return null;
    }
  }

  List<Widget> _buildTransactionSpecificDetails(
    Map<String, dynamic>? transactionData,
  ) {
    if (transactionData == null) return [];

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final transactionType = transactionData['type'] as String?;
    final List<Widget> details = [];

    switch (transactionType?.toLowerCase()) {
      case 'top_up':
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
        break;

      case 'loan_disbursement':
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
        break;

      case 'active_loan':
        details.add(
          _buildReceiptRow(
            'Loan Amount',
            '₱${_safeParseNumber(data['loan_amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Remaining Balance',
            '₱${_safeParseNumber(data['remaining_balance']).toStringAsFixed(2)}',
          ),
        );
        if (data['loan_plan_id'] != null) {
          details.add(
            _buildReceiptRow('Loan Plan ID', data['loan_plan_id'].toString()),
          );
        }
        break;

      case 'loan_payment':
        details.add(
          _buildReceiptRow(
            'Payment Amount',
            '₱${_safeParseNumber(data['payment_amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Remaining Balance',
            '₱${_safeParseNumber(data['remaining_balance']).toStringAsFixed(2)}',
          ),
        );
        if (data['loan_id'] != null) {
          details.add(_buildReceiptRow('Loan ID', data['loan_id'].toString()));
        }
        break;

      case 'service_payment':
        details.add(
          _buildReceiptRow(
            'Total Amount',
            '₱${_safeParseNumber(data['total_amount']).toStringAsFixed(2)}',
          ),
        );
        break;

      case 'transfer':
        final studentId = SessionService.currentUserStudentId;
        final isSent = data['sender_student_id'] == studentId;

        details.add(
          _buildReceiptRow('Transfer Direction', isSent ? 'Sent' : 'Received'),
        );
        details.add(
          _buildReceiptRow(
            'New Balance',
            '₱${_safeParseNumber(data[isSent ? 'sender_new_balance' : 'recipient_new_balance']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow('Status', data['status']?.toString() ?? 'Completed'),
        );
        break;
    }

    if (details.isNotEmpty) {
      details.insert(0, const SizedBox(height: 16));
    }

    return details;
  }

  // Safe number parsing helper method
  double _safeParseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  // Fetch actual transaction data based on notification
  Future<Map<String, dynamic>?> _fetchTransactionData(
    Map<String, dynamic> notification,
  ) async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;
      final notificationType = notification['type']?.toString().toLowerCase();
      final notificationId = notification['id'];

      if (studentId.isEmpty) return null;

      // Try to extract transaction ID from notification data or message
      String? transactionId;
      if (notification['transaction_id'] != null) {
        transactionId = notification['transaction_id'].toString();
      } else {
        // Try to parse transaction ID from message
        final message = notification['message']?.toString() ?? '';
        final idMatch = RegExp(r'#(\d+)').firstMatch(message);
        if (idMatch != null) {
          transactionId = idMatch.group(1);
        }
      }

      // Fetch data based on notification type
      switch (notificationType) {
        case 'topup_success':
        case 'transaction_success':
        case 'top_up':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('top_up_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {'type': 'top_up', 'data': result, 'id': transactionId};
          }
          break;

        case 'loan_disbursement':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('top_up_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .eq('transaction_type', 'loan_disbursement')
                    .single();
            return {
              'type': 'loan_disbursement',
              'data': result,
              'id': transactionId,
            };
          }
          break;

        case 'loan_payment':
        case 'loan_reminder':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('loan_payments')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {
              'type': 'loan_payment',
              'data': result,
              'id': transactionId,
            };
          }
          break;

        case 'active_loan':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('loan_actives')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {'type': 'active_loan', 'data': result, 'id': transactionId};
          }
          break;

        case 'transfer_sent':
        case 'transfer_received':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('user_transfers')
                    .select('*')
                    .eq('id', transactionId)
                    .or(
                      'sender_student_id.eq.$studentId,recipient_student_id.eq.$studentId',
                    )
                    .single();
            return {'type': 'transfer', 'data': result, 'id': transactionId};
          }
          break;

        case 'service_payment':
        case 'payment_success':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('service_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {
              'type': 'service_payment',
              'data': result,
              'id': transactionId,
            };
          }
          break;

        case 'loan_due_soon':
        case 'loan_overdue':
          // For loan reminders, try to get active loan data
          final activeLoans = await SupabaseService.client
              .from('loan_actives')
              .select('*')
              .eq('student_id', studentId)
              .order('created_at', ascending: false)
              .limit(1);
          if (activeLoans.isNotEmpty) {
            return {
              'type': 'active_loan',
              'data': activeLoans.first,
              'id': activeLoans.first['id'].toString(),
            };
          }
          break;
      }

      // If no specific transaction found, return notification data
      // For loan-related notifications, the data might already be in the notification
      if (notificationType == 'loan_disbursement' ||
          notificationType == 'active_loan' ||
          notificationType == 'loan_payment' ||
          notificationType == 'service_payment' ||
          notificationType == 'top_up') {
        return {
          'type': notificationType,
          'data': notification,
          'id': notificationId?.toString(),
        };
      }

      return {
        'type': notificationType ?? 'unknown',
        'data': notification,
        'id': notificationId?.toString(),
      };
    } catch (e) {
      print('DEBUG: Error fetching transaction data: $e');
      return {
        'type': notification['type']?.toString() ?? 'unknown',
        'data': notification,
        'id': notification['id']?.toString(),
      };
    }
  }

  // DEBUG: Comprehensive loan_payments table debugging for inbox
  Future<void> _debugLoanPaymentsTableInbox(String studentId) async {
    print('\n=== DEBUG LOAN PAYMENTS TABLE INBOX START ===');
    print('DEBUG INBOX: Student ID: "$studentId"');

    try {
      // Test 1: Check if table exists and is accessible
      print('DEBUG INBOX: Testing loan_payments table accessibility...');
      await SupabaseService.client
          .from('loan_payments')
          .select('count')
          .limit(1);
      print('DEBUG INBOX: Table accessibility test passed');

      // Test 2: Get all loan payments for this student
      print(
        'DEBUG INBOX: Getting all loan payments for student "$studentId"...',
      );
      final allPayments = await SupabaseService.client
          .from('loan_payments')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(50);
      print('DEBUG INBOX: Loan payments found: ${allPayments.length}');

      if (allPayments.isNotEmpty) {
        print('DEBUG INBOX: Sample loan payment data:');
        for (int i = 0; i < allPayments.length && i < 3; i++) {
          final payment = allPayments[i];
          print('DEBUG INBOX: Payment ${i + 1}:');
          print('  - ID: ${payment['id']}');
          print('  - Student ID: ${payment['student_id']}');
          print(
            '  - Payment Amount: ${payment['payment_amount']} (type: ${payment['payment_amount'].runtimeType})',
          );
          print(
            '  - Remaining Balance: ${payment['remaining_balance']} (type: ${payment['remaining_balance'].runtimeType})',
          );
          print('  - Created At: ${payment['created_at']}');
          print('  - Loan ID: ${payment['loan_id']}');
        }
      } else {
        print('DEBUG INBOX: No loan payments found for student "$studentId"');

        // Check if there are any loan payments at all
        print(
          'DEBUG INBOX: Checking if there are any loan payments in the entire table...',
        );
        final anyPayments = await SupabaseService.client
            .from('loan_payments')
            .select('id, student_id, payment_amount, created_at')
            .limit(5);
        print('DEBUG INBOX: Any loan payments in table: ${anyPayments.length}');
        if (anyPayments.isNotEmpty) {
          print('DEBUG INBOX: Sample loan payments from entire table:');
          for (final payment in anyPayments) {
            print(
              '  - ID: ${payment['id']}, Student: ${payment['student_id']}, Amount: ${payment['payment_amount']}',
            );
          }
        }
      }
    } catch (e) {
      print('DEBUG INBOX: Error during loan_payments debugging: $e');
      print('DEBUG INBOX: Error type: ${e.runtimeType}');
    }

    print('=== DEBUG LOAN PAYMENTS TABLE INBOX END ===\n');
  }
}

class _TransactionsTab extends StatefulWidget {
  const _TransactionsTab();

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  StreamSubscription<List<Map<String, dynamic>>>? _topUpSub;
  StreamSubscription<List<Map<String, dynamic>>>? _serviceTxSub;
  StreamSubscription<List<Map<String, dynamic>>>? _transferSub;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    try {
      _topUpSub?.cancel();
    } catch (_) {}
    try {
      _serviceTxSub?.cancel();
    } catch (_) {}
    try {
      _transferSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;
      print('DEBUG: Loading transaction history for studentId: "$studentId"');

      // DEBUG: Test loan_payments table specifically
      await _debugLoanPaymentsTable(studentId);

      if (studentId.isEmpty) {
        print('DEBUG: StudentId is empty in transactions tab, returning');
        setState(() {
          _transactions = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> merged = [];

      // 1. Query top-up transactions (only actual top-ups, not loan disbursements)
      try {
        print('DEBUG: Querying top_up_transactions for actual top-ups...');
        final topups = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, new_balance, created_at, processed_by, transaction_type',
            )
            .eq('student_id', studentId)
            .eq('transaction_type', 'top_up') // Only get actual top-ups
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Top-up transactions found: ${topups.length}');
        for (final t in (topups as List)) {
          merged.add({
            'id': t['id'],
            'transaction_type': 'top_up',
            'amount': _safeParseNumber(t['amount']),
            'created_at':
                t['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'new_balance': _safeParseNumber(t['new_balance']),
            'processed_by': t['processed_by'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying top-up transactions: $e');
      }

      // 2. Query loan disbursements separately
      try {
        print('DEBUG: Querying loan disbursements...');
        final loanDisbursements = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, new_balance, created_at, processed_by, transaction_type',
            )
            .eq('student_id', studentId)
            .eq('transaction_type', 'loan_disbursement')
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Loan disbursements found: ${loanDisbursements.length}');
        for (final ld in (loanDisbursements as List)) {
          merged.add({
            'id': ld['id'],
            'transaction_type': 'loan_disbursement',
            'amount': _safeParseNumber(ld['amount']),
            'created_at':
                ld['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'new_balance': _safeParseNumber(ld['new_balance']),
            'processed_by': ld['processed_by'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying loan disbursements: $e');
      }

      // 3. Query active loans
      try {
        print('DEBUG: Querying active loans...');
        final activeLoans = await SupabaseService.client
            .from('loan_actives')
            .select(
              'id, student_id, loan_amount, remaining_balance, created_at, loan_plan_id',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Active loans found: ${activeLoans.length}');
        for (final al in (activeLoans as List)) {
          merged.add({
            'id': al['id'],
            'transaction_type': 'active_loan',
            'amount': _safeParseNumber(al['loan_amount']),
            'created_at':
                al['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'remaining_balance': _safeParseNumber(al['remaining_balance']),
            'loan_plan_id': al['loan_plan_id'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying active loans: $e');
      }

      // 4. Query loan payments
      try {
        print('DEBUG: Querying loan payments...');
        print('DEBUG: Student ID for loan payments query: "$studentId"');

        final loanPayments = await SupabaseService.client
            .from('loan_payments')
            .select(
              'id, student_id, payment_amount, remaining_balance, created_at, loan_id',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Raw loan payments query result: ${loanPayments.length}');
        print('DEBUG: Loan payments data type: ${loanPayments.runtimeType}');

        if (loanPayments.isNotEmpty) {
          print('DEBUG: First loan payment sample: ${loanPayments.first}');
        }

        for (final lp in (loanPayments as List)) {
          print(
            'DEBUG: Processing loan payment: ${lp['id']}, amount: ${lp['payment_amount']}, remaining: ${lp['remaining_balance']}',
          );

          final parsedAmount = _safeParseNumber(lp['payment_amount']);
          final parsedBalance = _safeParseNumber(lp['remaining_balance']);

          print(
            'DEBUG: Parsed amount: $parsedAmount, Parsed balance: $parsedBalance',
          );

          final transactionData = {
            'id': lp['id'],
            'transaction_type': 'loan_payment',
            'amount': parsedAmount,
            'created_at':
                lp['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'remaining_balance': parsedBalance,
            'loan_id': lp['loan_id'],
          };

          print('DEBUG: Adding loan payment transaction: $transactionData');
          merged.add(transactionData);
        }

        print(
          'DEBUG: Total loan payments added to merged list: ${merged.where((t) => t['transaction_type'] == 'loan_payment').length}',
        );
      } catch (e) {
        print('DEBUG: Error querying loan payments: $e');
        print('DEBUG: Error type: ${e.runtimeType}');
        print('DEBUG: Stack trace: ${StackTrace.current}');
      }

      // 5. Query service transactions
      try {
        print('DEBUG: Querying service transactions...');
        final payments = await SupabaseService.client
            .from('service_transactions')
            .select('id, total_amount, created_at, student_id')
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Service transactions found: ${payments.length}');
        for (final p in (payments as List)) {
          merged.add({
            'id': p['id'],
            'transaction_type': 'service_payment',
            'amount': _safeParseNumber(p['total_amount']),
            'created_at':
                p['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('DEBUG: Error querying service transactions: $e');
      }

      // 6. Query user transfers
      try {
        print('DEBUG: Querying user transfers...');
        final transfers = await SupabaseService.client
            .from('user_transfers')
            .select(
              'id, sender_student_id, recipient_student_id, amount, sender_new_balance, recipient_new_balance, created_at, status',
            )
            .or(
              'sender_student_id.eq.$studentId,recipient_student_id.eq.$studentId',
            )
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: User transfers found: ${transfers.length}');
        for (final transfer in (transfers as List)) {
          final isSent = transfer['sender_student_id'] == studentId;
          merged.add({
            'id': transfer['id'],
            'transaction_type': 'transfer',
            'amount': _safeParseNumber(transfer['amount']),
            'created_at':
                transfer['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'new_balance':
                isSent
                    ? _safeParseNumber(transfer['sender_new_balance'])
                    : _safeParseNumber(transfer['recipient_new_balance']),
            'transfer_direction': isSent ? 'sent' : 'received',
            'sender_student_id': transfer['sender_student_id'],
            'recipient_student_id': transfer['recipient_student_id'],
            'status': transfer['status'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying user transfers: $e');
      }

      // Sort all transactions by date
      merged.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      setState(() {
        _transactions = merged;
        _isLoading = false;
      });

      print('DEBUG: Total transactions loaded: ${merged.length}');

      // Debug: Count transactions by type
      final typeCounts = <String, int>{};
      for (final transaction in merged) {
        final type = transaction['transaction_type'] as String;
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      print('DEBUG: Transaction type counts: $typeCounts');

      // Debug: Show loan payment transactions specifically
      final loanPayments =
          merged.where((t) => t['transaction_type'] == 'loan_payment').toList();
      print(
        'DEBUG: Loan payment transactions in final list: ${loanPayments.length}',
      );
      for (final lp in loanPayments) {
        print(
          'DEBUG: Loan payment - ID: ${lp['id']}, Amount: ${lp['amount']}, Date: ${lp['created_at']}',
        );
      }
    } catch (e) {
      print('DEBUG: Error loading transactions: $e');
      setState(() {
        _transactions = [];
        _isLoading = false;
      });
    }
  }

  // Safe number parsing helper method
  double _safeParseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  void _subscribeRealtime() {
    final studentId = SessionService.currentUserStudentId;
    if (studentId.isEmpty) return;

    try {
      _topUpSub?.cancel();
    } catch (_) {}
    _topUpSub = SupabaseService.client
        .from('top_up_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'transaction_type': 'top_up',
                      'amount': (r['amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                      'new_balance': (r['new_balance'] as num?) ?? 0,
                    },
                  )
                  .toList();
          _mergeAndRefresh(additions);
        });

    try {
      _serviceTxSub?.cancel();
    } catch (_) {}
    _serviceTxSub = SupabaseService.client
        .from('service_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'transaction_type': 'payment',
                      'amount': (r['total_amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                    },
                  )
                  .toList();
          _mergeAndRefresh(additions);
        });

    // Subscribe to user transfers for real-time updates
    try {
      _transferSub?.cancel();
    } catch (_) {}
    _transferSub = SupabaseService.client
        .from('user_transfers')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          // Filter rows to include only transfers involving this student
          final filteredRows =
              rows
                  .where(
                    (row) =>
                        row['sender_student_id'] == studentId ||
                        row['recipient_student_id'] == studentId,
                  )
                  .toList();
          final additions =
              filteredRows.map((r) {
                final isSent = r['sender_student_id'] == studentId;
                return {
                  'transaction_type': 'transfer',
                  'amount': (r['amount'] as num?) ?? 0,
                  'created_at':
                      r['created_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  'new_balance':
                      isSent
                          ? (r['sender_new_balance'] as num?) ?? 0
                          : (r['recipient_new_balance'] as num?) ?? 0,
                  'transfer_direction': isSent ? 'sent' : 'received',
                  'sender_student_id': r['sender_student_id'],
                  'recipient_student_id': r['recipient_student_id'],
                  'status': r['status'],
                };
              }).toList();
          _mergeAndRefresh(additions);
        });
  }

  void _mergeAndRefresh(List<Map<String, dynamic>> newItems) {
    if (newItems.isEmpty) return;
    final List<Map<String, dynamic>> merged = List.from(_transactions);
    merged.insertAll(0, newItems);
    merged.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );
    setState(() {
      _transactions = merged;
    });
  }

  // Public method to refresh transactions (can be called externally)
  Future<void> refreshTransactions() async {
    await _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: evsuRed,
                  ),
                ),
                IconButton(
                  onPressed: _loadTransactions,
                  icon: const Icon(Icons.refresh, color: evsuRed),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter tabs
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _selectedFilter == 'All',
                      onTap: () => setState(() => _selectedFilter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Top-ups',
                      isSelected: _selectedFilter == 'Top-ups',
                      onTap: () => setState(() => _selectedFilter = 'Top-ups'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Loans',
                      isSelected: _selectedFilter == 'Loans',
                      onTap: () => setState(() => _selectedFilter = 'Loans'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Payments',
                      isSelected: _selectedFilter == 'Payments',
                      onTap: () => setState(() => _selectedFilter = 'Payments'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Transfers',
                      isSelected: _selectedFilter == 'Transfers',
                      onTap:
                          () => setState(() => _selectedFilter = 'Transfers'),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: evsuRed),
                      )
                      : _transactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        itemCount: _getFilteredTransactions().length,
                        itemBuilder: (context, index) {
                          final transaction = _getFilteredTransactions()[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // DEBUG: Comprehensive loan_payments table debugging
  Future<void> _debugLoanPaymentsTable(String studentId) async {
    print('\n=== DEBUG LOAN PAYMENTS TABLE START ===');
    print('DEBUG: Student ID: "$studentId"');

    try {
      // Test 1: Check if table exists and is accessible
      print('DEBUG: Testing table accessibility...');
      await SupabaseService.client
          .from('loan_payments')
          .select('count')
          .limit(1);
      print('DEBUG: Table accessibility test passed');

      // Test 2: Get total count of loan payments
      print('DEBUG: Getting total count of loan payments...');
      final countResult = await SupabaseService.client
          .from('loan_payments')
          .select('*');
      print('DEBUG: Total loan payments in table: ${countResult.length}');

      // Test 3: Get all loan payments for this student
      print('DEBUG: Getting all loan payments for student "$studentId"...');
      final allPayments = await SupabaseService.client
          .from('loan_payments')
          .select('*')
          .eq('student_id', studentId);
      print('DEBUG: Loan payments for this student: ${allPayments.length}');

      if (allPayments.isNotEmpty) {
        print('DEBUG: Sample loan payment data:');
        for (int i = 0; i < allPayments.length && i < 3; i++) {
          final payment = allPayments[i];
          print('DEBUG: Payment ${i + 1}:');
          print('  - ID: ${payment['id']}');
          print('  - Student ID: ${payment['student_id']}');
          print(
            '  - Payment Amount: ${payment['payment_amount']} (type: ${payment['payment_amount'].runtimeType})',
          );
          print(
            '  - Remaining Balance: ${payment['remaining_balance']} (type: ${payment['remaining_balance'].runtimeType})',
          );
          print('  - Created At: ${payment['created_at']}');
          print('  - Loan ID: ${payment['loan_id']}');
        }
      } else {
        print('DEBUG: No loan payments found for student "$studentId"');

        // Test 4: Check if there are any loan payments at all
        print(
          'DEBUG: Checking if there are any loan payments in the entire table...',
        );
        final anyPayments = await SupabaseService.client
            .from('loan_payments')
            .select('id, student_id, payment_amount, created_at')
            .limit(5);
        print('DEBUG: Any loan payments in table: ${anyPayments.length}');
        if (anyPayments.isNotEmpty) {
          print('DEBUG: Sample loan payments from entire table:');
          for (final payment in anyPayments) {
            print(
              '  - ID: ${payment['id']}, Student: ${payment['student_id']}, Amount: ${payment['payment_amount']}',
            );
          }
        }
      }

      // Test 5: Check table schema
      print('DEBUG: Checking table schema...');
      try {
        await SupabaseService.client.from('loan_payments').select('*').limit(0);
        print('DEBUG: Schema test passed - table exists');
      } catch (e) {
        print('DEBUG: Schema test failed: $e');
      }
    } catch (e) {
      print('DEBUG: Error during loan_payments debugging: $e');
      print('DEBUG: Error type: ${e.runtimeType}');

      // Test alternative queries
      try {
        print('DEBUG: Trying alternative query...');
        await SupabaseService.client
            .from('loan_payments')
            .select('id')
            .limit(1);
        print('DEBUG: Alternative query successful');
      } catch (altError) {
        print('DEBUG: Alternative query also failed: $altError');
      }
    }

    print('=== DEBUG LOAN PAYMENTS TABLE END ===\n');
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    if (_selectedFilter == 'All') {
      return _transactions;
    } else if (_selectedFilter == 'Top-ups') {
      return _transactions
          .where((t) => t['transaction_type'] == 'top_up')
          .toList();
    } else if (_selectedFilter == 'Loans') {
      final filtered =
          _transactions
              .where(
                (t) =>
                    t['transaction_type'] == 'loan_disbursement' ||
                    t['transaction_type'] == 'active_loan' ||
                    t['transaction_type'] == 'loan_payment',
              )
              .toList();
      print(
        'DEBUG FILTER: Loans filter applied - found ${filtered.length} transactions',
      );
      for (final t in filtered) {
        print(
          'DEBUG FILTER: ${t['transaction_type']} - ID: ${t['id']}, Amount: ${t['amount']}',
        );
      }
      return filtered;
    } else if (_selectedFilter == 'Payments') {
      return _transactions
          .where((t) => t['transaction_type'] == 'service_payment')
          .toList();
    } else if (_selectedFilter == 'Transfers') {
      return _transactions
          .where((t) => t['transaction_type'] == 'transfer')
          .toList();
    }
    return _transactions;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final transactionType = transaction['transaction_type'] as String;
    final amount = _safeParseNumber(transaction['amount']);
    final createdAt = DateTime.parse(transaction['created_at']);
    final formattedDate =
        '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final formattedTime =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    // Determine transaction details based on type
    String title;
    String subtitle;
    IconData icon;
    List<Color> gradientColors;
    String amountPrefix;
    Color amountColor;
    String? balanceText;

    switch (transactionType) {
      case 'top_up':
        title = 'Account Top-up';
        subtitle = 'Balance credited';
        icon = Icons.add;
        gradientColors = [Colors.green, Colors.green[700]!];
        amountPrefix = '+';
        amountColor = Colors.green;
        balanceText =
            '₱${_safeParseNumber(transaction['new_balance']).toStringAsFixed(2)}';
        break;

      case 'loan_disbursement':
        title = 'Loan Disbursement';
        subtitle = 'Loan amount credited';
        icon = Icons.account_balance;
        gradientColors = [Colors.purple, Colors.purple[700]!];
        amountPrefix = '+';
        amountColor = Colors.purple;
        balanceText =
            '₱${_safeParseNumber(transaction['new_balance']).toStringAsFixed(2)}';
        break;

      case 'active_loan':
        title = 'Active Loan';
        subtitle = 'Outstanding loan';
        icon = Icons.credit_card;
        gradientColors = [Colors.orange, Colors.orange[700]!];
        amountPrefix = '';
        amountColor = Colors.orange;
        balanceText =
            'Remaining: ₱${_safeParseNumber(transaction['remaining_balance']).toStringAsFixed(2)}';
        break;

      case 'loan_payment':
        title = 'Loan Payment';
        subtitle = 'Payment made';
        icon = Icons.payment;
        gradientColors = [Colors.blue, Colors.blue[700]!];
        amountPrefix = '-';
        amountColor = Colors.blue;
        balanceText =
            'Remaining: ₱${_safeParseNumber(transaction['remaining_balance']).toStringAsFixed(2)}';
        break;

      case 'service_payment':
        title = 'Service Payment';
        subtitle = 'Payment processed';
        icon = Icons.remove;
        gradientColors = [evsuRed, const Color(0xFF7F1D1D)];
        amountPrefix = '-';
        amountColor = evsuRed;
        break;

      case 'transfer':
        final transferDirection = transaction['transfer_direction'] as String?;
        final isSent = transferDirection == 'sent';
        title = isSent ? 'Money Sent' : 'Money Received';
        subtitle = isSent ? 'Transfer to friend' : 'Transfer from friend';
        icon = isSent ? Icons.send : Icons.call_received;
        gradientColors =
            isSent
                ? [Colors.orange, Colors.orange[700]!]
                : [Colors.blue, Colors.blue[700]!];
        amountPrefix = isSent ? '-' : '+';
        amountColor = isSent ? Colors.orange : Colors.blue;
        balanceText =
            '₱${_safeParseNumber(transaction['new_balance']).toStringAsFixed(2)}';
        break;

      default:
        title = 'Transaction';
        subtitle = 'Transaction processed';
        icon = Icons.payment;
        gradientColors = [Colors.grey, Colors.grey[700]!];
        amountPrefix = '-';
        amountColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 16)),
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
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '$formattedDate $formattedTime',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amountPrefix}₱${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                if (balanceText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    balanceText,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB91C1C) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  static const Color evsuRed = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [evsuRed, Color(0xFF7F1D1D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    SessionService.currentUserName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Student ID: ${SessionService.currentUserStudentId}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Course: ${SessionService.currentUserCourse}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'Verified Student',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Spent',
                    value: '₱2,450',
                    icon: Icons.trending_down,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'This Month',
                    value: '₱890',
                    icon: Icons.calendar_month,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Menu Items
            _buildMenuSection('Account', [
              _MenuItem(
                icon: Icons.person_outline,
                title: 'Personal Information',
                subtitle: 'Update your profile details',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.security,
                title: 'Security & Privacy',
                subtitle: 'Manage your account security',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SecurityPrivacyScreen(),
                      ),
                    ),
              ),
              _MenuItem(
                icon: Icons.credit_card,
                title: 'Payment Methods',
                subtitle: 'Manage linked accounts',
                onTap: () => _showComingSoon(context),
              ),
            ]),

            const SizedBox(height: 20),

            _buildMenuSection('Preferences', [
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Configure alert preferences',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                subtitle: 'Light mode',
                onTap: () => _showComingSoon(context),
              ),
            ]),

            const SizedBox(height: 20),

            _buildMenuSection('Support', [
              _MenuItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help with your account',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                subtitle: 'Share your experience',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.info_outline,
                title: 'About eCampusPay',
                subtitle: 'Version 1.0.0',
                onTap: () => _showComingSoon(context),
              ),
            ]),

            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const Spacer()]),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: items.map((item) => _buildMenuItem(item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: evsuRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(item.icon, color: evsuRed, size: 20),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle:
          item.subtitle != null
              ? Text(
                item.subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              )
              : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: item.onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Coming Soon'),
            content: const Text(
              'This feature will be available in a future update.',
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    Navigator.pop(context);
                    await SessionService.clearSession();

                    // Navigate to login page using direct navigation
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  } catch (e) {
                    print('Logout error: $e');
                    // Fallback navigation
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}

class _LoanPlansDialog extends StatelessWidget {
  final List<dynamic> plans;
  final double totalTopup;
  final Function(int) onApplyLoan;

  const _LoanPlansDialog({
    required this.plans,
    required this.totalTopup,
    required this.onApplyLoan,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFB91C1C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Available Loan Plans',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top-up info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your total top-up: ₱${totalTopup.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Loan plans
                    ...plans
                        .map((plan) => _buildLoanPlanCard(context, plan))
                        .toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanPlanCard(BuildContext context, Map<String, dynamic> plan) {
    final isEligible = plan['is_eligible'] as bool;
    final amount = (plan['amount'] as num).toDouble();
    final termDays = plan['term_days'] as int;
    final interestRate = (plan['interest_rate'] as num).toDouble();
    final totalRepayable = (plan['total_repayable'] as num).toDouble();
    final minTopup = (plan['min_topup'] as num).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isEligible
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEligible ? 'Eligible' : 'Not Eligible',
                    style: TextStyle(
                      color:
                          isEligible
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Amount',
                    '₱${amount.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(child: _buildInfoItem('Term', '$termDays days')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Interest',
                    '${interestRate.toStringAsFixed(1)}%',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Total Due',
                    '₱${totalRepayable.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              'Min. Top-up Required',
              '₱${minTopup.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isEligible
                        ? () => _showLoanAgreementDialog(
                          context,
                          plan: plan,
                          onConfirm: () => onApplyLoan(plan['id'] as int),
                        )
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isEligible ? const Color(0xFFB91C1C) : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isEligible ? 'Apply for this Loan' : 'Not Eligible',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (!isEligible) ...[
              const SizedBox(height: 8),
              Text(
                'You need at least ₱${minTopup.toStringAsFixed(0)} in total top-ups to apply for this loan.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showLoanAgreementDialog(
    BuildContext context, {
    required Map<String, dynamic> plan,
    required VoidCallback onConfirm,
  }) {
    bool agreed = false;
    final amount = (plan['amount'] as num?)?.toDouble() ?? 0.0;
    final interestRate = (plan['interest_rate'] as num?)?.toDouble() ?? 0.0;
    final totalRepayable =
        (plan['total_repayable'] as num?)?.toDouble() ??
        (amount + (amount * interestRate / 100));
    final termDays = (plan['term_days'] as num?)?.toInt();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 500,
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loan Agreement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan['name'] != null
                              ? plan['name'].toString()
                              : 'Selected Loan Plan',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Loan Amount: ₱${amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Interest/Fee: ${interestRate.toStringAsFixed(1)}% (shown before you confirm)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total Repayable: ₱${totalRepayable.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (termDays != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Repayment Term: $termDays days',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'By applying for a loan in eCampusPay, you agree to the following:\n\n'
                                  '• The loan amount will be added to your eCampusPay balance.\n'
                                  '• You must repay the loan on or before the due date shown.\n'
                                  '• Repayment includes the loan amount plus the interest/fee (shown before you confirm).\n'
                                  '• If you do not pay on time, your account may be restricted until payment is completed.\n'
                                  '• Only one active loan is allowed at a time.\n'
                                  '• The admin may adjust loan rules (amount, interest, or repayment days) when needed.\n\n'
                                  'Note: eCampusPay is a campus payment system, not a bank. Borrow responsibly.',
                                  style: TextStyle(fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: agreed,
                                      onChanged:
                                          (v) => setState(
                                            () => agreed = v == true,
                                          ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'I have read and agree to the Loan Terms and Conditions.',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    agreed
                                        ? () {
                                          Navigator.pop(context);
                                          onConfirm();
                                        }
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB91C1C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Apply Loan',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}

class _PaymentOptionsDialog extends StatefulWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onPayFull;
  final Function(double) onPayPartial;

  const _PaymentOptionsDialog({
    required this.loan,
    required this.onPayFull,
    required this.onPayPartial,
  });

  @override
  State<_PaymentOptionsDialog> createState() => _PaymentOptionsDialogState();
}

class _PaymentOptionsDialogState extends State<_PaymentOptionsDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _isPartialPayment = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = (widget.loan['total_amount'] as num).toDouble();
    final currentBalance = SessionService.currentUserBalance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB91C1C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Color(0xFFB91C1C),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Payment Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
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

            const SizedBox(height: 16),

            // Loan Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Total Due',
                    '₱${totalAmount.toStringAsFixed(2)}',
                  ),
                  _buildSummaryRow(
                    'Your Balance',
                    '₱${currentBalance.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    'Can Pay Full',
                    currentBalance >= totalAmount ? 'Yes' : 'No',
                    valueColor:
                        currentBalance >= totalAmount
                            ? Colors.green
                            : Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Type Selection
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPartialPayment = false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            !_isPartialPayment
                                ? const Color(0xFFB91C1C)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              !_isPartialPayment
                                  ? const Color(0xFFB91C1C)
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        'Pay Full',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              !_isPartialPayment
                                  ? Colors.white
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPartialPayment = true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _isPartialPayment
                                ? const Color(0xFFB91C1C)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _isPartialPayment
                                  ? const Color(0xFFB91C1C)
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        'Pay Partial',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              _isPartialPayment
                                  ? Colors.white
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_isPartialPayment) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount to Pay',
                  hintText: 'Enter amount (₱)',
                  prefixText: '₱',
                  border: const OutlineInputBorder(),
                  errorText: _getAmountError(),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed() ? _handlePayment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isPartialPayment ? 'Pay Partial' : 'Pay Full',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String? _getAmountError() {
    if (!_isPartialPayment) return null;

    final amountText = _amountController.text;
    if (amountText.isEmpty) return null;

    final amount = double.tryParse(amountText);
    if (amount == null) return 'Invalid amount';

    final totalAmount = (widget.loan['total_amount'] as num).toDouble();
    final currentBalance = SessionService.currentUserBalance;

    if (amount <= 0) return 'Amount must be greater than 0';
    if (amount > totalAmount) return 'Amount cannot exceed total due';
    if (amount > currentBalance) return 'Insufficient balance';

    return null;
  }

  bool _canProceed() {
    if (!_isPartialPayment) {
      final totalAmount = (widget.loan['total_amount'] as num).toDouble();
      final currentBalance = SessionService.currentUserBalance;
      return currentBalance >= totalAmount;
    }

    return _getAmountError() == null && _amountController.text.isNotEmpty;
  }

  void _handlePayment() {
    if (_isPartialPayment) {
      final amount = double.tryParse(_amountController.text);
      if (amount != null) {
        widget.onPayPartial(amount);
      }
    } else {
      widget.onPayFull();
    }
  }
}

// Transfer Dialog Classes
class _TransferStudentIdDialog extends StatefulWidget {
  @override
  _TransferStudentIdDialogState createState() =>
      _TransferStudentIdDialogState();
}

class _TransferStudentIdDialogState extends State<_TransferStudentIdDialog> {
  final _studentIdController = TextEditingController();
  bool _isValidating = false;
  String? _recipientName;
  String? _recipientCourse;
  String? _validationError;

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.person_add,
            color: const Color(0xFFB91C1C),
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(
              'Transfer Money',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the Student ID of the recipient:',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            TextField(
              controller: _studentIdController,
              decoration: InputDecoration(
                labelText: 'Student ID',
                hintText: 'e.g., EVSU2024001',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _validateStudentId(value.trim());
                } else {
                  setState(() {
                    _recipientName = null;
                    _recipientCourse = null;
                    _validationError = null;
                  });
                }
              },
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            if (_isValidating)
              Row(
                children: [
                  SizedBox(
                    width: isSmallScreen ? 14 : 16,
                    height: isSmallScreen ? 14 : 16,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Validating...',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            if (_validationError != null)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: isSmallScreen ? 14 : 16,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_recipientName != null)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade600,
                          size: isSmallScreen ? 14 : 16,
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Text(
                          'Recipient Found:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      'Name: $_recipientName',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (_recipientCourse != null)
                      Text(
                        'Course: $_recipientCourse',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      actions: [
        if (isSmallScreen)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _recipientName != null && !_isValidating
                          ? () {
                            Navigator.pop(context);
                            _showAmountDialog(
                              context,
                              _studentIdController.text.trim(),
                              _recipientName!,
                            );
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      _recipientName != null && !_isValidating
                          ? () {
                            Navigator.pop(context);
                            _showAmountDialog(
                              context,
                              _studentIdController.text.trim(),
                              _recipientName!,
                            );
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _validateStudentId(String studentId) async {
    if (studentId == SessionService.currentUserStudentId) {
      setState(() {
        _validationError = 'Cannot transfer to yourself';
        _recipientName = null;
        _recipientCourse = null;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationError = null;
      _recipientName = null;
      _recipientCourse = null;
    });

    try {
      await SupabaseService.initialize();

      // Look up student in auth_students table
      final response =
          await SupabaseService.client
              .from('auth_students')
              .select('student_id, name, course')
              .eq('student_id', studentId)
              .eq('is_active', true)
              .maybeSingle();

      if (response == null) {
        setState(() {
          _validationError = 'Student ID not found or inactive';
          _recipientName = null;
          _recipientCourse = null;
        });
      } else {
        // Decrypt the student name and course
        String decryptedName = response['name']?.toString() ?? 'Unknown';
        String decryptedCourse = response['course']?.toString() ?? '';

        try {
          // Check if the name looks encrypted and decrypt it
          if (EncryptionService.looksLikeEncryptedData(decryptedName)) {
            decryptedName = EncryptionService.decryptData(decryptedName);
          }

          // Check if the course looks encrypted and decrypt it
          if (EncryptionService.looksLikeEncryptedData(decryptedCourse)) {
            decryptedCourse = EncryptionService.decryptData(decryptedCourse);
          }
        } catch (e) {
          print('Failed to decrypt student data: $e');
          // Keep the original values if decryption fails
        }

        setState(() {
          _recipientName = decryptedName;
          _recipientCourse =
              decryptedCourse.isNotEmpty ? decryptedCourse : null;
          _validationError = null;
        });
      }
    } catch (e) {
      setState(() {
        _validationError = 'Error validating student ID: $e';
        _recipientName = null;
        _recipientCourse = null;
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }
}

class _AmountDialog extends StatefulWidget {
  final String recipientStudentId;
  final String recipientName;

  const _AmountDialog({
    required this.recipientStudentId,
    required this.recipientName,
  });

  @override
  _AmountDialogState createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _amountController = TextEditingController();
  double? _currentBalance;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;

      final response =
          await SupabaseService.client
              .from('auth_students')
              .select('balance')
              .eq('student_id', studentId)
              .single();

      setState(() {
        _currentBalance = (response['balance'] as num?)?.toDouble() ?? 0.0;
        _isLoadingBalance = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.attach_money,
            color: const Color(0xFFB91C1C),
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(
              'Transfer Amount',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transferring to:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    widget.recipientName,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  Text(
                    'Student ID: ${widget.recipientStudentId}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            if (_isLoadingBalance)
              Row(
                children: [
                  SizedBox(
                    width: isSmallScreen ? 14 : 16,
                    height: isSmallScreen ? 14 : 16,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Loading balance...',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB91C1C).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: const Color(0xFFB91C1C),
                      size: isSmallScreen ? 16 : 18,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Text(
                      'Your balance: ₱${_currentBalance?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 13 : 14,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to Transfer',
                hintText: '0.00',
                prefixText: '₱',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              'Quick Amount:',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Wrap(
              spacing: isSmallScreen ? 6 : 8,
              runSpacing: isSmallScreen ? 6 : 8,
              children: [
                _buildQuickAmountButton(50, isSmallScreen),
                _buildQuickAmountButton(100, isSmallScreen),
                _buildQuickAmountButton(200, isSmallScreen),
                _buildQuickAmountButton(500, isSmallScreen),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            if (_amountController.text.isNotEmpty)
              _buildValidationMessage(isSmallScreen),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      actions: [
        if (isSmallScreen)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canTransfer() ? _proceedToSummary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _canTransfer() ? _proceedToSummary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildQuickAmountButton(double amount, bool isSmallScreen) {
    final isSelected = _amountController.text == amount.toString();
    return GestureDetector(
      onTap: () {
        _amountController.text = amount.toString();
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10 : 12,
          vertical: isSmallScreen ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB91C1C) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          '₱${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildValidationMessage(bool isSmallScreen) {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: isSmallScreen ? 14 : 16,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                'Please enter a valid amount',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_currentBalance != null && amount > _currentBalance!) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: isSmallScreen ? 14 : 16,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                'Insufficient balance',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_currentBalance != null && amount > _currentBalance! - 0.01) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_outlined,
              color: Colors.orange.shade600,
              size: isSmallScreen ? 14 : 16,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                'Warning: This will leave minimal balance',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade600,
            size: isSmallScreen ? 14 : 16,
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          Expanded(
            child: Text(
              'Amount is valid',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: isSmallScreen ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canTransfer() {
    final amount = double.tryParse(_amountController.text);
    return amount != null &&
        amount > 0 &&
        _currentBalance != null &&
        amount <= _currentBalance!;
  }

  void _proceedToSummary() {
    final amount = double.parse(_amountController.text);
    Navigator.pop(context);
    _showTransferSummaryDialog(
      widget.recipientStudentId,
      widget.recipientName,
      amount,
    );
  }

  void _showTransferSummaryDialog(
    String recipientStudentId,
    String recipientName,
    double amount,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => _TransferSummaryDialog(
            recipientStudentId: recipientStudentId,
            recipientName: recipientName,
            amount: amount,
            currentBalance: _currentBalance!,
          ),
    );
  }
}

class _TransferSummaryDialog extends StatefulWidget {
  final String recipientStudentId;
  final String recipientName;
  final double amount;
  final double currentBalance;

  const _TransferSummaryDialog({
    required this.recipientStudentId,
    required this.recipientName,
    required this.amount,
    required this.currentBalance,
  });

  @override
  _TransferSummaryDialogState createState() => _TransferSummaryDialogState();
}

class _TransferSummaryDialogState extends State<_TransferSummaryDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.receipt_long,
            color: const Color(0xFFB91C1C),
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(
              'Transfer Summary',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please review your transfer details:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildSummaryRow(
                    'Recipient:',
                    widget.recipientName,
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildSummaryRow(
                    'Student ID:',
                    widget.recipientStudentId,
                    isSmallScreen: isSmallScreen,
                  ),
                  const Divider(height: 20),
                  _buildSummaryRow(
                    'Amount:',
                    '₱${widget.amount.toStringAsFixed(2)}',
                    isSmallScreen: isSmallScreen,
                    isAmount: true,
                  ),
                  _buildSummaryRow(
                    'Current Balance:',
                    '₱${widget.currentBalance.toStringAsFixed(2)}',
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildSummaryRow(
                    'New Balance:',
                    '₱${(widget.currentBalance - widget.amount).toStringAsFixed(2)}',
                    isSmallScreen: isSmallScreen,
                    isNewBalance: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: isSmallScreen ? 16 : 18,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'This transaction will be recorded in your transaction history.',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      actions: [
        if (isSmallScreen)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isProcessing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Confirm Transfer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isProcessing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Confirm Transfer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isSmallScreen = false,
    bool isAmount = false,
    bool isNewBalance = false,
  }) {
    Color valueColor = Colors.black87;
    if (isAmount) {
      valueColor = const Color(0xFFB91C1C);
    } else if (isNewBalance) {
      valueColor = Colors.green.shade700;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 13 : 14,
                color: valueColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processTransfer() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await SupabaseService.initialize();
      final senderStudentId = SessionService.currentUserStudentId;

      // Try using the database function first
      try {
        final result = await SupabaseService.client.rpc(
          'process_user_transfer',
          params: {
            'p_sender_student_id': senderStudentId,
            'p_recipient_student_id': widget.recipientStudentId,
            'p_amount': widget.amount,
          },
        );

        if (result != null) {
          final data = result as Map<String, dynamic>;

          if (data['success'] == true) {
            // Close all dialogs first
            Navigator.pop(context);

            // Show success message immediately
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Successfully transferred ₱${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
            }

            // Refresh user data
            await SessionService.refreshUserData();

            // Force refresh the entire dashboard
            if (mounted) {
              // Trigger a rebuild of the entire dashboard
              setState(() {});

              // Also refresh the transactions tab if it exists
              // This will be handled by the parent widget's setState
            }
            return;
          } else {
            throw Exception(
              data['message'] ?? data['error'] ?? 'Transfer failed',
            );
          }
        }
      } catch (rpcError) {
        print('RPC function failed, trying manual transfer: $rpcError');
        // Fall through to manual implementation
      }

      // Fallback: Manual transfer implementation
      await _processTransferManually(senderStudentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processTransferManually(String senderStudentId) async {
    // Get current balances with retry logic
    Map<String, dynamic>? senderResponse;
    Map<String, dynamic>? recipientResponse;

    try {
      senderResponse =
          await SupabaseService.client
              .from('auth_students')
              .select('balance')
              .eq('student_id', senderStudentId)
              .eq('is_active', true)
              .single();

      recipientResponse =
          await SupabaseService.client
              .from('auth_students')
              .select('balance')
              .eq('student_id', widget.recipientStudentId)
              .eq('is_active', true)
              .single();
    } catch (e) {
      throw Exception('Failed to fetch user balances: $e');
    }

    final senderBalance =
        (senderResponse['balance'] as num?)?.toDouble() ?? 0.0;
    final recipientBalance =
        (recipientResponse['balance'] as num?)?.toDouble() ?? 0.0;

    // Check if sender has sufficient balance
    if (senderBalance < widget.amount) {
      throw Exception(
        'Insufficient balance. Available: ₱${senderBalance.toStringAsFixed(2)}, Required: ₱${widget.amount.toStringAsFixed(2)}',
      );
    }

    // Calculate new balances
    final newSenderBalance = senderBalance - widget.amount;
    final newRecipientBalance = recipientBalance + widget.amount;

    try {
      // Update sender balance using atomic increment/decrement
      final senderUpdateResult =
          await SupabaseService.client
              .from('auth_students')
              .update({
                'balance': newSenderBalance,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('student_id', senderStudentId)
              .eq('balance', senderBalance) // Ensure balance hasn't changed
              .select();

      if (senderUpdateResult.isEmpty) {
        throw Exception(
          'Sender balance was modified by another transaction. Please try again.',
        );
      }

      // Update recipient balance
      await SupabaseService.client
          .from('auth_students')
          .update({
            'balance': newRecipientBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', widget.recipientStudentId);

      // Create transfer record (if table exists)
      try {
        await SupabaseService.client.from('user_transfers').insert({
          'sender_student_id': senderStudentId,
          'recipient_student_id': widget.recipientStudentId,
          'amount': widget.amount,
          'sender_previous_balance': senderBalance,
          'sender_new_balance': newSenderBalance,
          'recipient_previous_balance': recipientBalance,
          'recipient_new_balance': newRecipientBalance,
          'transaction_type': 'transfer',
          'status': 'completed',
          'notes': 'User-to-user transfer',
        });
        print(
          'DEBUG: Transfer record created successfully in user_transfers table',
        );
      } catch (transferRecordError) {
        print(
          'Could not create transfer record (table might not exist): $transferRecordError',
        );

        // Fallback: Try to create a simple record in a different table or store locally
        try {
          // Try to insert into a generic transactions table if it exists
          await SupabaseService.client.from('transactions').insert({
            'student_id': senderStudentId,
            'type': 'transfer_out',
            'amount': widget.amount,
            'description': 'Transfer to ${widget.recipientStudentId}',
            'balance_after': newSenderBalance,
            'created_at': DateTime.now().toIso8601String(),
          });

          await SupabaseService.client.from('transactions').insert({
            'student_id': widget.recipientStudentId,
            'type': 'transfer_in',
            'amount': widget.amount,
            'description': 'Transfer from $senderStudentId',
            'balance_after': newRecipientBalance,
            'created_at': DateTime.now().toIso8601String(),
          });

          print('DEBUG: Transfer recorded in fallback transactions table');
        } catch (fallbackError) {
          print(
            'DEBUG: Fallback transfer recording also failed: $fallbackError',
          );
          // Continue anyway - the main transfer is successful
        }
      }

      // Create notifications for both sender and recipient
      try {
        // Notification for sender
        await NotificationService.createNotification(
          studentId: senderStudentId,
          type: 'transfer_sent',
          title: 'Transfer Sent',
          message:
              'You sent ₱${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
          actionData: 'transfer_id:${DateTime.now().millisecondsSinceEpoch}',
        );

        // Notification for recipient
        await NotificationService.createNotification(
          studentId: widget.recipientStudentId,
          type: 'transfer_received',
          title: 'Transfer Received',
          message:
              'You received ₱${widget.amount.toStringAsFixed(2)} from ${SessionService.currentUserData?['name'] ?? 'User'}',
          actionData: 'transfer_id:${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (notificationError) {
        print('Error creating transfer notifications: $notificationError');
        // Don't fail the transfer if notifications fail
      }

      // Close all dialogs first
      Navigator.pop(context);

      // Show success message immediately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully transferred ₱${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Refresh user data
      await SessionService.refreshUserData();

      // Force refresh the entire dashboard
      if (mounted) {
        // Trigger a rebuild of the entire dashboard
        setState(() {});

        // This will refresh all tabs including transactions
        print('DEBUG: Dashboard refreshed after transfer completion');
      }
    } catch (e) {
      // If we failed to update sender balance, we need to try to revert recipient balance
      if (e.toString().contains('Sender balance was modified')) {
        try {
          await SupabaseService.client
              .from('auth_students')
              .update({
                'balance': recipientBalance, // Revert recipient balance
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('student_id', widget.recipientStudentId);
        } catch (revertError) {
          print('Failed to revert recipient balance: $revertError');
        }
      }
      throw e;
    }
  }
}

// Helper function to show amount dialog
void _showAmountDialog(
  BuildContext context,
  String studentId,
  String recipientName,
) {
  showDialog(
    context: context,
    builder:
        (context) => _AmountDialog(
          recipientStudentId: studentId,
          recipientName: recipientName,
        ),
  );
}
