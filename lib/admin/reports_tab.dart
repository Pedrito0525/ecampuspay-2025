import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  static const Color evsuRed = Color(0xFFB01212);
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];

  bool _loading = false;
  double _topUpIncome = 0.0;
  double _loanIncome = 0.0;
  double _totalIncome = 0.0;
  int _topupCount = 0;
  int _loanDisbursementCount = 0;

  // Balance overview data
  double _totalStudentBalance = 0.0;
  double _totalServiceBalance = 0.0;
  double _totalSystemBalance = 0.0;
  int _studentCount = 0;
  int _serviceCount = 0;
  bool _balanceLoading = false;

  // Analysis data
  List<Map<String, dynamic>> _topupAnalysis = [];
  List<Map<String, dynamic>> _loanAnalysis = [];
  List<Map<String, dynamic>> _vendorTransactionCount = [];
  bool _analysisLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIncome();
    _loadBalanceOverview();
    _loadAnalysisData();
  }

  Future<void> _loadIncome() async {
    setState(() => _loading = true);
    try {
      final range = _getDateRangeFor(_selectedPeriod);
      final res = await SupabaseService.getIncomeSummary(
        start: range['start'],
        end: range['end'],
      );
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _topUpIncome = (data['top_up_income'] as num?)?.toDouble() ?? 0.0;
          _loanIncome = (data['loan_income'] as num?)?.toDouble() ?? 0.0;
          _totalIncome = (data['total_income'] as num?)?.toDouble() ?? 0.0;
          final counts = data['counts'] as Map<String, dynamic>?;
          _topupCount = counts != null ? (counts['topups'] as int? ?? 0) : 0;
          _loanDisbursementCount =
              counts != null ? (counts['paid_loans'] as int? ?? 0) : 0;
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBalanceOverview() async {
    setState(() => _balanceLoading = true);
    try {
      final res = await SupabaseService.getBalanceOverview();
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _totalStudentBalance =
              (data['total_student_balance'] as num?)?.toDouble() ?? 0.0;
          _totalServiceBalance =
              (data['total_service_balance'] as num?)?.toDouble() ?? 0.0;
          _totalSystemBalance =
              (data['total_system_balance'] as num?)?.toDouble() ?? 0.0;
          _studentCount = data['student_count'] as int? ?? 0;
          _serviceCount = data['service_count'] as int? ?? 0;
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  Future<void> _loadAnalysisData() async {
    setState(() => _analysisLoading = true);
    try {
      final range = _getDateRangeFor(_selectedPeriod);

      // Load all analysis data in parallel
      final results = await Future.wait([
        SupabaseService.getTopUpAnalysis(
          start: range['start'],
          end: range['end'],
        ),
        SupabaseService.getLoanAnalysis(
          start: range['start'],
          end: range['end'],
        ),
        SupabaseService.getVendorTransactionCountAnalysis(
          start: range['start'],
          end: range['end'],
        ),
      ]);

      if (mounted) {
        setState(() {
          // Top-up analysis
          if (results[0]['success'] == true) {
            _topupAnalysis =
                (results[0]['data']['topups'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }

          // Loan analysis
          if (results[1]['success'] == true) {
            _loanAnalysis =
                (results[1]['data']['loans'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }

          // Vendor transaction count analysis
          if (results[2]['success'] == true) {
            _vendorTransactionCount =
                (results[2]['data']['vendors'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _analysisLoading = false);
    }
  }

  Map<String, DateTime?> _getDateRangeFor(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Daily':
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return {'start': start, 'end': end};
      case 'Weekly':
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return {'start': start, 'end': end};
      case 'Monthly':
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return {'start': start, 'end': end};
      case 'Yearly':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        return {'start': start, 'end': end};
      default:
        return {'start': null, 'end': null};
    }
  }

  String _formatCurrency(double value) {
    return '₱${value.toStringAsFixed(2)}';
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
                        'Reports & Analytics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      Text(
                        'System performance overview',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _exportReports,
                  icon: const Icon(Icons.file_download, color: evsuRed),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_loading) const SizedBox(height: 16),

            // Period Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children:
                    _periods
                        .map(
                          (period) => Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedPeriod = period);
                                _loadIncome();
                                _loadAnalysisData();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedPeriod == period
                                          ? evsuRed
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  period,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        _selectedPeriod == period
                                            ? Colors.white
                                            : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Key Metrics
            Container(
              padding: const EdgeInsets.all(20),
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
                    '$_selectedPeriod Overview',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Income (Full Width)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: evsuRed.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Income',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: evsuRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(_totalIncome),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top-up and Loan Disbursement Overview
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Mobile: Stack vertically
                        return Column(
                          children: [
                            _IncomeMetricItem(
                              title: 'Top-up Income',
                              value: _formatCurrency(_topUpIncome),
                              count: _topupCount,
                              countLabel: 'Top-ups',
                              color: Colors.blue,
                              icon: Icons.account_balance_wallet,
                            ),
                            const SizedBox(height: 12),
                            _IncomeMetricItem(
                              title: 'Loan Income',
                              value: _formatCurrency(_loanIncome),
                              count: _loanDisbursementCount,
                              countLabel: 'Loan Disbursements',
                              color: Colors.green,
                              icon: Icons.credit_card,
                            ),
                          ],
                        );
                      } else {
                        // Desktop: Side by side
                        return Row(
                          children: [
                            Expanded(
                              child: _IncomeMetricItem(
                                title: 'Top-up Income',
                                value: _formatCurrency(_topUpIncome),
                                count: _topupCount,
                                countLabel: 'Top-ups',
                                color: Colors.blue,
                                icon: Icons.account_balance_wallet,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _IncomeMetricItem(
                                title: 'Loan Income',
                                value: _formatCurrency(_loanIncome),
                                count: _loanDisbursementCount,
                                countLabel: 'Loan Disbursements',
                                color: Colors.green,
                                icon: Icons.credit_card,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Balance Overview Section
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Icon(Icons.account_balance_wallet, color: evsuRed),
                      const SizedBox(width: 8),
                      const Text(
                        'Balance Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadBalanceOverview,
                        icon: const Icon(Icons.refresh, color: evsuRed),
                        tooltip: 'Refresh balance data',
                      ),
                      if (_balanceLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Track your actual cash flow - money you handle should equal total balances',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total System Balance
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: evsuRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.money, color: evsuRed, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total System Balance',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: evsuRed,
                                ),
                              ),
                              Text(
                                _formatCurrency(_totalSystemBalance),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: evsuRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${_totalSystemBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance Breakdown
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Mobile: Stack vertically
                        return Column(
                          children: [
                            _BalanceItem(
                              title: 'Student Balances',
                              value: _formatCurrency(_totalStudentBalance),
                              count: _studentCount,
                              color: Colors.blue,
                              icon: Icons.school,
                            ),
                            const SizedBox(height: 12),
                            _BalanceItem(
                              title: 'Service Balances',
                              value: _formatCurrency(_totalServiceBalance),
                              count: _serviceCount,
                              color: Colors.green,
                              icon: Icons.store,
                            ),
                          ],
                        );
                      } else {
                        // Desktop: Side by side
                        return Row(
                          children: [
                            Expanded(
                              child: _BalanceItem(
                                title: 'Student Balances',
                                value: _formatCurrency(_totalStudentBalance),
                                count: _studentCount,
                                color: Colors.blue,
                                icon: Icons.school,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BalanceItem(
                                title: 'Service Balances',
                                value: _formatCurrency(_totalServiceBalance),
                                count: _serviceCount,
                                color: Colors.green,
                                icon: Icons.store,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Balance Verification
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          _totalSystemBalance ==
                                  (_totalStudentBalance + _totalServiceBalance)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _totalSystemBalance ==
                                    (_totalStudentBalance +
                                        _totalServiceBalance)
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _totalSystemBalance ==
                                  (_totalStudentBalance + _totalServiceBalance)
                              ? Icons.check_circle
                              : Icons.warning,
                          color:
                              _totalSystemBalance ==
                                      (_totalStudentBalance +
                                          _totalServiceBalance)
                                  ? Colors.green
                                  : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _totalSystemBalance ==
                                    (_totalStudentBalance +
                                        _totalServiceBalance)
                                ? 'Balance verification: ✓ All balances match'
                                : 'Balance verification: ⚠ Balances do not match',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  _totalSystemBalance ==
                                          (_totalStudentBalance +
                                              _totalServiceBalance)
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Top-up Analysis
            Container(
              padding: const EdgeInsets.all(20),
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
                        'Top-up Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_topupAnalysis.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No top-up data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Top-up transactions will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topupAnalysis.length,
                      itemBuilder: (context, index) {
                        final item = _topupAnalysis[index];
                        return _TopUpItem(
                          amount: _formatCurrency(item['amount'] as double),
                          count: item['count'] as int,
                          percentage: item['percentage'] as double,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Loan Analysis
            Container(
              padding: const EdgeInsets.all(20),
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
                        'Loan Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loanAnalysis.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No loan data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Paid loan transactions will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _loanAnalysis.length,
                      itemBuilder: (context, index) {
                        final item = _loanAnalysis[index];
                        return _LoanItem(
                          amount: _formatCurrency(item['amount'] as double),
                          count: item['count'] as int,
                          percentage: item['percentage'] as double,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Vendor Transaction Count Analysis
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Expanded(
                        child: Text(
                          'Vendor Transaction Count Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Which vendors have the most transaction activity',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_vendorTransactionCount.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.analytics,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transaction data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Transaction count analysis will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _vendorTransactionCount.length,
                      itemBuilder: (context, index) {
                        final vendor = _vendorTransactionCount[index];
                        return _VendorTransactionCountItem(
                          name: vendor['service_name'] as String,
                          totalTransactions:
                              vendor['total_transactions'] as int,
                          rank: index + 1,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Export Options
            Container(
              padding: const EdgeInsets.all(20),
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
                    'Export Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ExportButton(
                          title: 'PDF Report',
                          icon: Icons.picture_as_pdf,
                          onTap: () => _exportAs('PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExportButton(
                          title: 'Excel Export',
                          icon: Icons.table_chart,
                          onTap: () => _exportAs('Excel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  void _exportReports() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Export Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Export as PDF'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportAs('PDF');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Export as Excel'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportAs('Excel');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: evsuRed),
                  title: const Text('Email Report'),
                  onTap: () {
                    Navigator.pop(context);
                    _emailReport();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _exportAs(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting $_selectedPeriod report as $format...'),
        backgroundColor: evsuRed,
      ),
    );
  }

  void _emailReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing email report...'),
        backgroundColor: evsuRed,
      ),
    );
  }
}

class _TopUpItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String amount;
  final int count;
  final double percentage;

  const _TopUpItem({
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: evsuRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                amount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: evsuRed,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count transactions',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _TopUpItem.evsuRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanItem extends StatelessWidget {
  final String amount;
  final int count;
  final double percentage;

  const _LoanItem({
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                amount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count loans',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeMetricItem extends StatelessWidget {
  final String title;
  final String value;
  final int count;
  final String countLabel;
  final Color color;
  final IconData icon;

  const _IncomeMetricItem({
    required this.title,
    required this.value,
    required this.count,
    required this.countLabel,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: color.withOpacity(0.7), size: 16),
              const SizedBox(width: 4),
              Text(
                '$count $countLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String title;
  final String value;
  final int count;
  final Color color;
  final IconData icon;

  const _BalanceItem({
    required this.title,
    required this.value,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count accounts',
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _VendorTransactionCountItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String name;
  final int totalTransactions;
  final int rank;

  const _VendorTransactionCountItem({
    required this.name,
    required this.totalTransactions,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: rank <= 3 ? evsuRed.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: rank <= 3 ? evsuRed.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3 ? evsuRed : Colors.grey[300],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      rank.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: rank <= 3 ? evsuRed : Colors.black87,
                        ),
                      ),
                      Text(
                        '$totalTransactions total transactions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  totalTransactions.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? evsuRed : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ExportButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _ExportButton.evsuRed.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: _ExportButton.evsuRed),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ExportButton.evsuRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
