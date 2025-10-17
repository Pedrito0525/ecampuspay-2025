import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import 'admin_dashboard.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  static const Color evsuRed = Color(0xFFB01212);

  // Dashboard data
  int _totalUsers = 0;
  int _activeUsersToday = 0;
  double _totalTransactions = 0.0;
  int _totalServices = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Chart data
  List<FlSpot> _transactionSpots = [];
  List<PieChartSectionData> _balanceDistributionSections = [];
  List<PieChartSectionData> _categoryBreakdownSections = [];
  bool _isChartLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize chart data with empty/default values
    _initializeChartData();
    _loadDashboardData();
  }

  void _initializeChartData() {
    // Initialize with sample data to prevent LateInitializationError
    _generateTransactionChartData();
    _generateBalanceDistributionData();
    _generateCategoryBreakdownData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the combined dashboard stats function for better performance
      final response = await SupabaseService.client.rpc(
        'get_dashboard_stats',
        params: {},
      );

      if (response['success']) {
        final data = response['data'];
        setState(() {
          _totalUsers = data['total_users'] ?? 0;
          _activeUsersToday = data['active_users_today'] ?? 0;
          _totalTransactions =
              (data['today_transactions'] as num?)?.toDouble() ?? 0.0;
          _totalServices = data['total_services'] ?? 0;
          _isLoading = false;
        });
      } else {
        // Fallback to individual calls if combined function fails
        final results = await Future.wait([
          SupabaseService.getAllUsers(),
          SupabaseService.getServiceAccounts(),
          _getTodayTransactions(),
          _getActiveUsersToday(),
        ]);

        final usersResult = results[0] as Map<String, dynamic>;
        final servicesResult = results[1] as Map<String, dynamic>;
        final todayTransactions = results[2] as double;
        final activeUsersToday = results[3] as int;

        setState(() {
          _totalUsers =
              usersResult['success'] ? (usersResult['data'] as List).length : 0;
          _totalServices =
              servicesResult['success']
                  ? (servicesResult['data'] as List).length
                  : 0;
          _totalTransactions = todayTransactions;
          _activeUsersToday = activeUsersToday;
          _isLoading = false;
        });
      }

      // Load chart data
      await _loadChartData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading dashboard data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<double> _getTodayTransactions() async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_today_transaction_total',
        params: {},
      );
      return (response['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<int> _getActiveUsersToday() async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_active_users_today',
        params: {},
      );
      return (response['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isChartLoading = true;
    });

    try {
      // Load real data from Supabase
      await _loadTransactionChartData();
      await _loadBalanceDistributionData();
      await _loadCategoryBreakdownData();
    } catch (e) {
      print('Error loading chart data: $e');
      // Keep the initialized sample data as fallback
    } finally {
      setState(() {
        _isChartLoading = false;
      });
    }
  }

  Future<void> _loadTransactionChartData() async {
    try {
      final now = DateTime.now();
      _transactionSpots = [];

      // Get data for last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        // Adjust for Philippines timezone (+8 hours)
        final phStartOfDay = startOfDay.add(const Duration(hours: 8));
        final phEndOfDay = endOfDay.add(const Duration(hours: 8));

        double dailyTotal = 0.0;

        // Get top-up transactions
        final topupResult = await SupabaseService.client
            .from('top_up_transactions')
            .select('amount')
            .eq('transaction_type', 'top_up')
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in topupResult) {
          dailyTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // Get service transactions
        final serviceResult = await SupabaseService.client
            .from('service_transactions')
            .select('total_amount')
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in serviceResult) {
          dailyTotal +=
              (transaction['total_amount'] as num?)?.toDouble() ?? 0.0;
        }

        // Get user transfers
        final transferResult = await SupabaseService.client
            .from('user_transfers')
            .select('amount')
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in transferResult) {
          dailyTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // Get loan disbursements
        final loanResult = await SupabaseService.client
            .from('top_up_transactions')
            .select('amount')
            .eq('transaction_type', 'loan_disbursement')
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in loanResult) {
          dailyTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        }

        _transactionSpots.add(FlSpot((6 - i).toDouble(), dailyTotal));
      }
    } catch (e) {
      print('Error loading transaction chart data: $e');
      // Fallback to sample data
      _generateTransactionChartData();
    }
  }

  Future<void> _loadBalanceDistributionData() async {
    try {
      // Get total user balance from auth_students
      final usersResult = await SupabaseService.client
          .from('auth_students')
          .select('balance');

      double totalUserBalance = 0.0;
      for (var user in usersResult) {
        totalUserBalance += (user['balance'] as num?)?.toDouble() ?? 0.0;
      }

      // Get total service balance from service_accounts
      final servicesResult = await SupabaseService.client
          .from('service_accounts')
          .select('balance');

      double totalServiceBalance = 0.0;
      for (var service in servicesResult) {
        totalServiceBalance += (service['balance'] as num?)?.toDouble() ?? 0.0;
      }

      // Calculate admin income
      double adminIncome = 0.0;

      // Top-up income (fees from top-up transactions)
      final topupIncomeResult = await SupabaseService.client
          .from('top_up_transactions')
          .select('amount, transaction_type')
          .eq('transaction_type', 'top_up');

      for (var transaction in topupIncomeResult) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        // Calculate fee: ₱50-₱100 => ₱1 flat, ₱100-₱1000 => 1% of amount
        if (amount >= 50 && amount <= 100) {
          adminIncome += 1.0;
        } else if (amount > 100 && amount <= 1000) {
          adminIncome += amount * 0.01;
        }
      }

      // Loan interest income from paid loans
      final loanIncomeResult = await SupabaseService.client
          .from('active_loans')
          .select('interest_amount')
          .eq('status', 'paid');

      for (var loan in loanIncomeResult) {
        adminIncome += (loan['interest_amount'] as num?)?.toDouble() ?? 0.0;
      }

      final totalBalance = totalUserBalance + totalServiceBalance + adminIncome;

      if (totalBalance > 0) {
        final userPercentage = (totalUserBalance / totalBalance * 100);
        final servicePercentage = (totalServiceBalance / totalBalance * 100);
        final adminPercentage = (adminIncome / totalBalance * 100);

        _balanceDistributionSections = [
          PieChartSectionData(
            color: Colors.blue,
            value: userPercentage,
            title: 'Users\n${userPercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: Colors.green,
            value: servicePercentage,
            title: 'Services\n${servicePercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: evsuRed,
            value: adminPercentage,
            title: 'Admin\n${adminPercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ];
      } else {
        // Fallback to sample data if no data available
        _generateBalanceDistributionData();
      }
    } catch (e) {
      print('Error loading balance distribution data: $e');
      // Fallback to sample data
      _generateBalanceDistributionData();
    }
  }

  Future<void> _loadCategoryBreakdownData() async {
    try {
      double topupTotal = 0.0;
      double serviceTotal = 0.0;
      double loanTotal = 0.0;
      double transferTotal = 0.0;

      // Get top-up transactions total
      final topupResult = await SupabaseService.client
          .from('top_up_transactions')
          .select('amount')
          .eq('transaction_type', 'top_up');

      for (var transaction in topupResult) {
        topupTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Get service transactions total
      final serviceResult = await SupabaseService.client
          .from('service_transactions')
          .select('total_amount');

      for (var transaction in serviceResult) {
        serviceTotal +=
            (transaction['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Get loan disbursements total
      final loanResult = await SupabaseService.client
          .from('top_up_transactions')
          .select('amount')
          .eq('transaction_type', 'loan_disbursement');

      for (var transaction in loanResult) {
        loanTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Get user transfers total
      final transferResult = await SupabaseService.client
          .from('user_transfers')
          .select('amount');

      for (var transaction in transferResult) {
        transferTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final totalTransactions =
          topupTotal + serviceTotal + loanTotal + transferTotal;

      if (totalTransactions > 0) {
        final topupPercentage = (topupTotal / totalTransactions * 100);
        final servicePercentage = (serviceTotal / totalTransactions * 100);
        final loanPercentage = (loanTotal / totalTransactions * 100);
        final transferPercentage = (transferTotal / totalTransactions * 100);

        _categoryBreakdownSections = [
          PieChartSectionData(
            color: Colors.orange,
            value: topupPercentage,
            title: 'Top-up\n${topupPercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: Colors.purple,
            value: servicePercentage,
            title: 'Service\n${servicePercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: Colors.teal,
            value: loanPercentage,
            title: 'Loaning\n${loanPercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: Colors.indigo,
            value: transferPercentage,
            title: 'Transfer\n${transferPercentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ];
      } else {
        // Fallback to sample data if no data available
        _generateCategoryBreakdownData();
      }
    } catch (e) {
      print('Error loading category breakdown data: $e');
      // Fallback to sample data
      _generateCategoryBreakdownData();
    }
  }

  // Fallback methods for sample data
  void _generateTransactionChartData() {
    // Sample data for last 7 days
    _transactionSpots = List.generate(7, (index) {
      final amount = 1000 + (index * 200) + (index % 3 == 0 ? 500 : 0);
      return FlSpot(index.toDouble(), amount.toDouble());
    });
  }

  void _generateBalanceDistributionData() {
    _balanceDistributionSections = [
      PieChartSectionData(
        color: Colors.blue,
        value: 60,
        title: 'Users\n60%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.green,
        value: 25,
        title: 'Services\n25%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: evsuRed,
        value: 15,
        title: 'Admin\n15%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  void _generateCategoryBreakdownData() {
    _categoryBreakdownSections = [
      PieChartSectionData(
        color: Colors.orange,
        value: 35,
        title: 'Top-up\n35%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.purple,
        value: 30,
        title: 'Service\n30%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.teal,
        value: 25,
        title: 'Loaning\n25%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.indigo,
        value: 10,
        title: 'Transfer\n10%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  List<PieChartSectionData> _getEmptyPieChartData() {
    return [
      PieChartSectionData(
        color: Colors.grey,
        value: 100,
        title: 'No Data',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      Text(
                        'EVSU eCampusPay System',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: evsuRed.withOpacity(0.1),
                  child: const Icon(Icons.admin_panel_settings, color: evsuRed),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Cards
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Users',
                          value: _totalUsers.toString(),
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Active Today',
                          value: _activeUsersToday.toString(),
                          icon: Icons.online_prediction,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Today\'s Transactions',
                          value: '₱${_totalTransactions.toStringAsFixed(2)}',
                          icon: Icons.attach_money,
                          color: evsuRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Service Accounts',
                          value: _totalServices.toString(),
                          icon: Icons.business_center,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: evsuRed,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive crossAxisCount based on screen width
                int crossAxisCount = 2; // Default for mobile
                double childAspectRatio = 1.5; // Default aspect ratio

                if (constraints.maxWidth > 1200) {
                  // Large desktop screens
                  crossAxisCount = 4;
                  childAspectRatio = 1.2;
                } else if (constraints.maxWidth > 800) {
                  // Tablet and small desktop
                  crossAxisCount = 3;
                  childAspectRatio = 1.3;
                } else if (constraints.maxWidth > 600) {
                  // Large mobile/small tablet
                  crossAxisCount = 2;
                  childAspectRatio = 1.4;
                }

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: childAspectRatio,
                  children: [
                    _QuickActionCard(
                      title: 'User Management',
                      icon: Icons.manage_accounts,
                      onTap:
                          () => _handleQuickAction(context, 'User Management'),
                    ),
                    _QuickActionCard(
                      title: 'System Settings',
                      icon: Icons.settings,
                      onTap:
                          () => _handleQuickAction(context, 'System Settings'),
                    ),
                    _QuickActionCard(
                      title: 'Reports & Analytics',
                      icon: Icons.analytics,
                      onTap: () => _handleQuickAction(context, 'Reports'),
                    ),
                    _QuickActionCard(
                      title: 'Service Management',
                      icon: Icons.business_center,
                      onTap:
                          () =>
                              _handleQuickAction(context, 'Service Management'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Charts Section
            _buildChartsSection(),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transaction Overview Chart
        _buildChartCard(
          title: 'Transaction Overview',
          subtitle: 'Daily transaction totals for the last 7 days',
          child: SizedBox(
            height: 200,
            child:
                _isChartLoading
                    ? const Center(child: CircularProgressIndicator())
                    : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 500,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '₱${value.toInt()}',
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final days = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ];
                                return Text(
                                  days[value.toInt() % 7],
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots:
                                _transactionSpots.isNotEmpty
                                    ? _transactionSpots
                                    : [
                                      FlSpot(0, 0),
                                    ], // Fallback to prevent error
                            isCurved: true,
                            color: evsuRed,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: evsuRed.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 16),

        // Charts Row
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              // Desktop layout - side by side
              return Row(
                children: [
                  Expanded(
                    child: _buildChartCard(
                      title: 'Balance Distribution',
                      subtitle: 'How funds are distributed',
                      child: SizedBox(
                        height: 200,
                        child:
                            _isChartLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : PieChart(
                                  PieChartData(
                                    sections:
                                        _balanceDistributionSections.isNotEmpty
                                            ? _balanceDistributionSections
                                            : _getEmptyPieChartData(),
                                    centerSpaceRadius: 40,
                                    sectionsSpace: 2,
                                  ),
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildChartCard(
                      title: 'Transaction Categories',
                      subtitle: 'Breakdown by transaction type',
                      child: SizedBox(
                        height: 200,
                        child:
                            _isChartLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : PieChart(
                                  PieChartData(
                                    sections:
                                        _categoryBreakdownSections.isNotEmpty
                                            ? _categoryBreakdownSections
                                            : _getEmptyPieChartData(),
                                    centerSpaceRadius: 40,
                                    sectionsSpace: 2,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Mobile layout - stacked
              return Column(
                children: [
                  _buildChartCard(
                    title: 'Balance Distribution',
                    subtitle: 'How funds are distributed',
                    child: SizedBox(
                      height: 200,
                      child:
                          _isChartLoading
                              ? const Center(child: CircularProgressIndicator())
                              : PieChart(
                                PieChartData(
                                  sections:
                                      _balanceDistributionSections.isNotEmpty
                                          ? _balanceDistributionSections
                                          : _getEmptyPieChartData(),
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 2,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildChartCard(
                    title: 'Transaction Categories',
                    subtitle: 'Breakdown by transaction type',
                    child: SizedBox(
                      height: 200,
                      child:
                          _isChartLoading
                              ? const Center(child: CircularProgressIndicator())
                              : PieChart(
                                PieChartData(
                                  sections:
                                      _categoryBreakdownSections.isNotEmpty
                                          ? _categoryBreakdownSections
                                          : _getEmptyPieChartData(),
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 2,
                                ),
                              ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: evsuRed,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _handleQuickAction(BuildContext context, String action) {
    // Find the parent AdminDashboard widget and update its tab index
    final adminDashboard =
        context.findAncestorStateOfType<State<AdminDashboard>>();

    if (adminDashboard != null) {
      switch (action) {
        case 'Service Management':
          // Navigate to vendors tab (index 6)
          (adminDashboard as dynamic).changeTabIndex(6);
          break;
        case 'User Management':
          // Navigate to user management tab (index 5)
          (adminDashboard as dynamic).changeTabIndex(5);
          break;
        case 'System Settings':
          // Navigate to settings tab (index 4)
          (adminDashboard as dynamic).changeTabIndex(4);
          break;
        case 'Reports':
          // Navigate to reports tab (index 1)
          (adminDashboard as dynamic).changeTabIndex(1);
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $action...'),
              backgroundColor: evsuRed,
            ),
          );
      }
    } else {
      // Fallback if parent AdminDashboard is not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to navigate to $action'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _DashboardTabState.evsuRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _DashboardTabState.evsuRed, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
